defmodule Fence.Accounts.GoogleTokenMock do
  @valid_token "valid_google_token"
  @unverified_email_token "unverified_email_google_token"

  def verify_and_extract(@valid_token) do
    {:ok,
     %{
       google_id: "google_123",
       email: "googleuser@example.com",
       name: "Google User",
       email_verified: true
     }}
  end

  def verify_and_extract("valid_google_token_" <> suffix) do
    {:ok,
     %{
       google_id: "google_#{suffix}",
       email: "googleuser_#{suffix}@example.com",
       name: "Google User #{suffix}",
       email_verified: true
     }}
  end

  def verify_and_extract("linking_token_" <> email) do
    {:ok,
     %{
       google_id: "google_link_#{email}",
       email: email,
       name: "Linked User",
       email_verified: true
     }}
  end

  def verify_and_extract(@unverified_email_token) do
    {:error, :email_not_verified}
  end

  def verify_and_extract(_invalid_token) do
    {:error, :invalid_token}
  end
end
