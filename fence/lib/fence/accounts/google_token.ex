defmodule Fence.Accounts.GoogleToken do
  @moduledoc """
  Verifies Google OAuth ID tokens using Google's public JWKS keys.
  Uses Req to fetch keys and JOSE for RS256 signature verification.
  """

  @google_issuer "https://accounts.google.com"

  defmodule KeyStore do
    @moduledoc false
    use GenServer

    @google_certs_url "https://www.googleapis.com/oauth2/v3/certs"

    def start_link(_opts) do
      GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
    end

    def get_keys do
      GenServer.call(__MODULE__, :get_keys)
    end

    @impl true
    def init(:ok) do
      {:ok, %{keys: %{}, fetched_at: nil}}
    end

    @impl true
    def handle_call(:get_keys, _from, state) do
      now = System.monotonic_time(:second)
      # Cache for 1 hour
      if state.fetched_at && now - state.fetched_at < 3600 do
        {:reply, {:ok, state.keys}, state}
      else
        case fetch_keys() do
          {:ok, keys} ->
            {:reply, {:ok, keys}, %{keys: keys, fetched_at: now}}

          {:error, _} = error ->
            if state.keys != %{} do
              {:reply, {:ok, state.keys}, state}
            else
              {:reply, error, state}
            end
        end
      end
    end

    defp fetch_keys do
      case Req.get(@google_certs_url) do
        {:ok, %{status: 200, body: %{"keys" => keys}}} ->
          jwk_map =
            for key <- keys, into: %{} do
              {key["kid"], JOSE.JWK.from_map(key)}
            end

          {:ok, jwk_map}

        _ ->
          {:error, :fetch_failed}
      end
    end
  end

  def verify_and_extract(id_token) do
    client_ids = Application.get_env(:fence, :google_oauth_client_ids, [])

    with {:ok, claims} <- verify_signature(id_token),
         :ok <- verify_claims(claims, client_ids) do
      {:ok,
       %{
         google_id: claims["sub"],
         email: claims["email"],
         name: claims["name"] || claims["email"],
         email_verified: claims["email_verified"]
       }}
    end
  end

  defp verify_signature(id_token) do
    try do
      # Extract kid from JWT header
      protected = id_token |> String.split(".") |> List.first()

      header =
        protected
        |> Base.url_decode64!(padding: false)
        |> Jason.decode!()

      kid = header["kid"]

      with {:ok, keys} <- KeyStore.get_keys(),
           %JOSE.JWK{} = jwk <- Map.get(keys, kid) do
        case JOSE.JWT.verify_strict(jwk, ["RS256"], id_token) do
          {true, %JOSE.JWT{fields: claims}, _jws} ->
            {:ok, claims}

          {false, _, _} ->
            {:error, :invalid_signature}
        end
      else
        nil -> {:error, :unknown_kid}
        error -> error
      end
    rescue
      _ -> {:error, :malformed_token}
    end
  end

  defp verify_claims(claims, client_ids) do
    now = System.os_time(:second)

    cond do
      claims["iss"] != @google_issuer ->
        {:error, :invalid_issuer}

      client_ids != [] and claims["aud"] not in client_ids ->
        {:error, :invalid_audience}

      claims["email_verified"] != true ->
        {:error, :email_not_verified}

      not is_integer(claims["exp"]) ->
        {:error, :missing_exp}

      claims["exp"] < now ->
        {:error, :token_expired}

      true ->
        :ok
    end
  end
end
