defmodule Fence.Workers.PasswordResetEmailWorker do
  use Oban.Worker, queue: :notifications, max_attempts: 3

  alias Fence.Accounts
  alias Fence.Accounts.PasswordResetEmail
  alias Fence.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "code" => code}}) do
    case Accounts.get_user(user_id) do
      nil ->
        :ok

      user ->
        user
        |> PasswordResetEmail.build(code)
        |> Mailer.deliver()

        :ok
    end
  end
end
