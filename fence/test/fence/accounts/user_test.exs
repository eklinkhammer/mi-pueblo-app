defmodule Fence.Accounts.UserTest do
  use Fence.DataCase, async: true

  alias Fence.Accounts.User

  @valid_attrs %{email: "test@example.com", password: "password123", display_name: "Test User"}

  describe "registration_changeset/2" do
    test "valid attrs produce valid changeset" do
      changeset = User.registration_changeset(%User{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires email" do
      changeset = User.registration_changeset(%User{}, Map.delete(@valid_attrs, :email))
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires password" do
      changeset = User.registration_changeset(%User{}, Map.delete(@valid_attrs, :password))
      assert %{password: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires display_name" do
      changeset = User.registration_changeset(%User{}, Map.delete(@valid_attrs, :display_name))
      assert %{display_name: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email format" do
      changeset = User.registration_changeset(%User{}, %{@valid_attrs | email: "invalid"})
      assert %{email: ["has invalid format"]} = errors_on(changeset)
    end

    test "validates email format rejects spaces" do
      changeset =
        User.registration_changeset(%User{}, %{@valid_attrs | email: "user @example.com"})

      assert %{email: ["has invalid format"]} = errors_on(changeset)
    end

    test "validates password minimum length" do
      changeset = User.registration_changeset(%User{}, %{@valid_attrs | password: "short"})
      assert %{password: [msg]} = errors_on(changeset)
      assert msg =~ "at least"
    end

    test "accepts 8 character password" do
      changeset = User.registration_changeset(%User{}, %{@valid_attrs | password: "12345678"})
      assert changeset.valid?
    end

    test "validates display_name max length" do
      long_name = String.duplicate("a", 101)
      changeset = User.registration_changeset(%User{}, %{@valid_attrs | display_name: long_name})
      assert %{display_name: [_]} = errors_on(changeset)
    end

    test "hashes password when valid" do
      changeset = User.registration_changeset(%User{}, @valid_attrs)
      assert changeset.changes[:password_hash]
      assert changeset.changes[:password_hash] != "password123"
    end

    test "does not hash password when invalid" do
      changeset = User.registration_changeset(%User{}, %{@valid_attrs | password: "short"})
      refute changeset.changes[:password_hash]
    end

    test "email uniqueness enforced on insert" do
      {:ok, _} = Repo.insert(User.registration_changeset(%User{}, @valid_attrs))
      {:error, changeset} = Repo.insert(User.registration_changeset(%User{}, @valid_attrs))
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "password_changeset/2" do
    test "valid password produces valid changeset" do
      changeset = User.password_changeset(%User{}, %{password: "newpassword123"})
      assert changeset.valid?
      assert changeset.changes[:password_hash]
    end

    test "requires password" do
      changeset = User.password_changeset(%User{}, %{})
      assert %{password: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates password minimum length" do
      changeset = User.password_changeset(%User{}, %{password: "short"})
      assert %{password: [msg]} = errors_on(changeset)
      assert msg =~ "at least"
    end

    test "hashes password" do
      changeset = User.password_changeset(%User{}, %{password: "newpassword123"})
      assert Bcrypt.verify_pass("newpassword123", changeset.changes[:password_hash])
    end
  end

  describe "oauth_changeset/2" do
    @oauth_attrs %{email: "oauth@example.com", display_name: "OAuth User", google_id: "g_123"}

    test "valid attrs produce valid changeset" do
      changeset = User.oauth_changeset(%User{}, @oauth_attrs)
      assert changeset.valid?
    end

    test "requires email, display_name, google_id" do
      changeset = User.oauth_changeset(%User{}, %{})
      errors = errors_on(changeset)
      assert %{email: ["can't be blank"]} = errors
      assert %{display_name: ["can't be blank"]} = errors
      assert %{google_id: ["can't be blank"]} = errors
    end

    test "validates email format" do
      changeset = User.oauth_changeset(%User{}, %{@oauth_attrs | email: "invalid"})
      assert %{email: ["has invalid format"]} = errors_on(changeset)
    end

    test "validates display_name max length" do
      long_name = String.duplicate("a", 101)
      changeset = User.oauth_changeset(%User{}, %{@oauth_attrs | display_name: long_name})
      assert %{display_name: [_]} = errors_on(changeset)
    end
  end

  describe "anonymous_changeset/2" do
    test "valid attrs produce valid changeset" do
      changeset = User.anonymous_changeset(%User{}, %{display_name: "Anon User"})
      assert changeset.valid?
      assert changeset.changes[:is_anonymous] == true
    end

    test "requires display_name" do
      changeset = User.anonymous_changeset(%User{}, %{})
      assert %{display_name: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates display_name max length" do
      long_name = String.duplicate("a", 101)
      changeset = User.anonymous_changeset(%User{}, %{display_name: long_name})
      assert %{display_name: [_]} = errors_on(changeset)
    end

    test "does not require email or password" do
      changeset = User.anonymous_changeset(%User{}, %{display_name: "Anon"})
      assert changeset.valid?
      refute changeset.changes[:email]
      refute changeset.changes[:password]
    end
  end

  describe "link_google_changeset/2" do
    test "valid attrs produce valid changeset" do
      changeset = User.link_google_changeset(%User{}, %{google_id: "g_456"})
      assert changeset.valid?
    end

    test "requires google_id" do
      changeset = User.link_google_changeset(%User{}, %{})
      assert %{google_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_changeset/2" do
    test "updates display_name" do
      changeset = User.update_changeset(%User{display_name: "Old"}, %{display_name: "New"})
      assert changeset.valid?
      assert changeset.changes.display_name == "New"
    end

    test "validates display_name max length" do
      long = String.duplicate("a", 101)
      changeset = User.update_changeset(%User{}, %{display_name: long})
      assert %{display_name: [_]} = errors_on(changeset)
    end

    test "does not allow email changes" do
      changeset = User.update_changeset(%User{}, %{email: "new@example.com"})
      refute changeset.changes[:email]
    end
  end
end
