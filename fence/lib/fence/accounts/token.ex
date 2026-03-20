defmodule Fence.Accounts.Token do
  use Joken.Config

  @impl true
  def token_config do
    default_claims(skip: [:aud, :iss])
  end

  def generate_access_token(user) do
    config = Application.get_env(:fence, __MODULE__)
    secret = Joken.Signer.create("HS256", config[:secret_key])

    claims = %{
      "sub" => user.id,
      "type" => "access",
      "exp" => System.os_time(:second) + config[:access_token_ttl]
    }

    Joken.generate_and_sign(token_config(), claims, secret)
  end

  def generate_refresh_token(user) do
    config = Application.get_env(:fence, __MODULE__)
    secret = Joken.Signer.create("HS256", config[:secret_key])

    claims = %{
      "sub" => user.id,
      "type" => "refresh",
      "exp" => System.os_time(:second) + config[:refresh_token_ttl]
    }

    Joken.generate_and_sign(token_config(), claims, secret)
  end

  def verify_token(token, expected_type) do
    config = Application.get_env(:fence, __MODULE__)
    secret = Joken.Signer.create("HS256", config[:secret_key])

    case Joken.verify_and_validate(token_config(), token, secret) do
      {:ok, %{"sub" => user_id, "type" => ^expected_type}} ->
        {:ok, user_id}

      {:ok, %{"type" => _wrong_type}} ->
        {:error, :invalid_token_type}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
