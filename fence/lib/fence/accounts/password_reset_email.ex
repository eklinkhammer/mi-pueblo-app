defmodule Fence.Accounts.PasswordResetEmail do
  import Swoosh.Email

  def build(user, code) do
    new()
    |> to({user.display_name, user.email})
    |> from({"Fence", "noreply@fence.app"})
    |> subject("Your password reset code")
    |> text_body("""
    Hi #{user.display_name},

    Your password reset code is: #{code}

    This code expires in 15 minutes. If you did not request a password reset, you can safely ignore this email.
    """)
  end
end
