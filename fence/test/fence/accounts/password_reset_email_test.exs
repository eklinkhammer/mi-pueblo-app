defmodule Fence.Accounts.PasswordResetEmailTest do
  use ExUnit.Case, async: true

  alias Fence.Accounts.PasswordResetEmail

  describe "build/2" do
    test "builds email with correct fields" do
      user = %{display_name: "Jane Doe", email: "jane@example.com"}
      email = PasswordResetEmail.build(user, "123456")

      assert email.to == [{"Jane Doe", "jane@example.com"}]
      assert email.from == {"Fence", "noreply@fence.app"}
      assert email.subject == "Your password reset code"
      assert email.text_body =~ "123456"
      assert email.text_body =~ "Jane Doe"
      assert email.text_body =~ "15 minutes"
    end
  end
end
