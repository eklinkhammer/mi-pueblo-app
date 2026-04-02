defmodule Fence.Accounts.PasswordResetCode do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @max_attempts 5
  @ttl_minutes 15

  schema "password_reset_codes" do
    field :code_hash, :string
    field :code, :string, virtual: true
    field :attempts, :integer, default: 0
    field :expires_at, :utc_datetime
    field :used_at, :utc_datetime

    belongs_to :user, Fence.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(reset_code, attrs) do
    reset_code
    |> cast(attrs, [:user_id, :code])
    |> validate_required([:user_id, :code])
    |> put_code_hash()
    |> put_expires_at()
  end

  def generate_code do
    Enum.random(0..999_999)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  def used?(%__MODULE__{used_at: used_at}), do: used_at != nil

  def max_attempts_exceeded?(%__MODULE__{attempts: attempts}) do
    attempts >= @max_attempts
  end

  defp put_code_hash(%{valid?: true, changes: %{code: code}} = changeset) do
    put_change(changeset, :code_hash, Bcrypt.hash_pwd_salt(code))
  end

  defp put_code_hash(changeset), do: changeset

  defp put_expires_at(%{valid?: true} = changeset) do
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(@ttl_minutes * 60)
      |> DateTime.truncate(:second)

    put_change(changeset, :expires_at, expires_at)
  end

  defp put_expires_at(changeset), do: changeset
end
