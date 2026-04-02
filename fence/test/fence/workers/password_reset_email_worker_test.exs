defmodule Fence.Workers.PasswordResetEmailWorkerTest do
  use Fence.DataCase, async: false

  use Oban.Testing, repo: Fence.Repo

  alias Fence.Workers.PasswordResetEmailWorker
  import Fence.Factory

  describe "perform/1" do
    test "sends email to existing user" do
      user = create_user()

      assert :ok =
               perform_job(PasswordResetEmailWorker, %{
                 "user_id" => user.id,
                 "code" => "123456"
               })

      assert_receive {:email, email}
      assert email.to == [{user.display_name, user.email}]
      assert email.text_body =~ "123456"
    end

    test "returns ok for non-existent user" do
      assert :ok =
               perform_job(PasswordResetEmailWorker, %{
                 "user_id" => Ecto.UUID.generate(),
                 "code" => "123456"
               })

      refute_receive {:email, _}
    end
  end
end
