defmodule Fence.Accounts.TokenTest do
  use Fence.DataCase, async: true

  alias Fence.Accounts.Token

  @user_id "00000000-0000-0000-0000-000000000001"
  @user %{id: @user_id}

  describe "generate_access_token/1" do
    test "generates a valid JWT" do
      assert {:ok, token, claims} = Token.generate_access_token(@user)
      assert is_binary(token)
      assert claims["sub"] == @user_id
      assert claims["type"] == "access"
      assert is_integer(claims["exp"])
    end
  end

  describe "generate_refresh_token/1" do
    test "generates a refresh JWT" do
      assert {:ok, token, claims} = Token.generate_refresh_token(@user)
      assert is_binary(token)
      assert claims["type"] == "refresh"
    end

    test "refresh token has longer TTL than access token" do
      {:ok, _, access_claims} = Token.generate_access_token(@user)
      {:ok, _, refresh_claims} = Token.generate_refresh_token(@user)
      assert refresh_claims["exp"] > access_claims["exp"]
    end
  end

  describe "verify_token/2" do
    test "verifies a valid access token" do
      {:ok, token, _} = Token.generate_access_token(@user)
      assert {:ok, user_id} = Token.verify_token(token, "access")
      assert user_id == @user_id
    end

    test "verifies a valid refresh token" do
      {:ok, token, _} = Token.generate_refresh_token(@user)
      assert {:ok, user_id} = Token.verify_token(token, "refresh")
      assert user_id == @user_id
    end

    test "rejects wrong token type" do
      {:ok, token, _} = Token.generate_access_token(@user)
      assert {:error, :invalid_token_type} = Token.verify_token(token, "refresh")
    end

    test "rejects invalid token" do
      assert {:error, _} = Token.verify_token("invalid.token.here", "access")
    end

    test "rejects expired token" do
      config = Application.get_env(:fence, Token)
      secret = Joken.Signer.create("HS256", config[:secret_key])

      claims = %{
        "sub" => @user_id,
        "type" => "access",
        "exp" => System.os_time(:second) - 3600
      }

      {:ok, token, _} = Joken.generate_and_sign(Token.token_config(), claims, secret)
      assert {:error, _} = Token.verify_token(token, "access")
    end
  end
end
