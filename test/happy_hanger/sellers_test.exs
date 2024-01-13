defmodule HappyHanger.SellersTest do
  use HappyHanger.DataCase

  alias HappyHanger.Sellers

  import HappyHanger.SellersFixtures
  alias HappyHanger.Sellers.{Seller, SellerToken}

  describe "get_seller_by_email/1" do
    test "does not return the seller if the email does not exist" do
      refute Sellers.get_seller_by_email("unknown@example.com")
    end

    test "returns the seller if the email exists" do
      %{id: id} = seller = seller_fixture()
      assert %Seller{id: ^id} = Sellers.get_seller_by_email(seller.email)
    end
  end

  describe "get_seller_by_email_and_password/2" do
    test "does not return the seller if the email does not exist" do
      refute Sellers.get_seller_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the seller if the password is not valid" do
      seller = seller_fixture()
      refute Sellers.get_seller_by_email_and_password(seller.email, "invalid")
    end

    test "returns the seller if the email and password are valid" do
      %{id: id} = seller = seller_fixture()

      assert %Seller{id: ^id} =
               Sellers.get_seller_by_email_and_password(seller.email, valid_seller_password())
    end
  end

  describe "get_seller!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Sellers.get_seller!(-1)
      end
    end

    test "returns the seller with the given id" do
      %{id: id} = seller = seller_fixture()
      assert %Seller{id: ^id} = Sellers.get_seller!(seller.id)
    end
  end

  describe "register_seller/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Sellers.register_seller(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Sellers.register_seller(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Sellers.register_seller(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = seller_fixture()
      {:error, changeset} = Sellers.register_seller(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Sellers.register_seller(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers sellers with a hashed password" do
      email = unique_seller_email()
      {:ok, seller} = Sellers.register_seller(valid_seller_attributes(email: email))
      assert seller.email == email
      assert is_binary(seller.hashed_password)
      assert is_nil(seller.confirmed_at)
      assert is_nil(seller.password)
    end
  end

  describe "change_seller_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Sellers.change_seller_registration(%Seller{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_seller_email()
      password = valid_seller_password()

      changeset =
        Sellers.change_seller_registration(
          %Seller{},
          valid_seller_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_seller_email/2" do
    test "returns a seller changeset" do
      assert %Ecto.Changeset{} = changeset = Sellers.change_seller_email(%Seller{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_seller_email/3" do
    setup do
      %{seller: seller_fixture()}
    end

    test "requires email to change", %{seller: seller} do
      {:error, changeset} = Sellers.apply_seller_email(seller, valid_seller_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{seller: seller} do
      {:error, changeset} =
        Sellers.apply_seller_email(seller, valid_seller_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{seller: seller} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Sellers.apply_seller_email(seller, valid_seller_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{seller: seller} do
      %{email: email} = seller_fixture()
      password = valid_seller_password()

      {:error, changeset} = Sellers.apply_seller_email(seller, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{seller: seller} do
      {:error, changeset} =
        Sellers.apply_seller_email(seller, "invalid", %{email: unique_seller_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{seller: seller} do
      email = unique_seller_email()
      {:ok, seller} = Sellers.apply_seller_email(seller, valid_seller_password(), %{email: email})
      assert seller.email == email
      assert Sellers.get_seller!(seller.id).email != email
    end
  end

  describe "deliver_seller_update_email_instructions/3" do
    setup do
      %{seller: seller_fixture()}
    end

    test "sends token through notification", %{seller: seller} do
      token =
        extract_seller_token(fn url ->
          Sellers.deliver_seller_update_email_instructions(seller, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert seller_token = Repo.get_by(SellerToken, token: :crypto.hash(:sha256, token))
      assert seller_token.seller_id == seller.id
      assert seller_token.sent_to == seller.email
      assert seller_token.context == "change:current@example.com"
    end
  end

  describe "update_seller_email/2" do
    setup do
      seller = seller_fixture()
      email = unique_seller_email()

      token =
        extract_seller_token(fn url ->
          Sellers.deliver_seller_update_email_instructions(%{seller | email: email}, seller.email, url)
        end)

      %{seller: seller, token: token, email: email}
    end

    test "updates the email with a valid token", %{seller: seller, token: token, email: email} do
      assert Sellers.update_seller_email(seller, token) == :ok
      changed_seller = Repo.get!(Seller, seller.id)
      assert changed_seller.email != seller.email
      assert changed_seller.email == email
      assert changed_seller.confirmed_at
      assert changed_seller.confirmed_at != seller.confirmed_at
      refute Repo.get_by(SellerToken, seller_id: seller.id)
    end

    test "does not update email with invalid token", %{seller: seller} do
      assert Sellers.update_seller_email(seller, "oops") == :error
      assert Repo.get!(Seller, seller.id).email == seller.email
      assert Repo.get_by(SellerToken, seller_id: seller.id)
    end

    test "does not update email if seller email changed", %{seller: seller, token: token} do
      assert Sellers.update_seller_email(%{seller | email: "current@example.com"}, token) == :error
      assert Repo.get!(Seller, seller.id).email == seller.email
      assert Repo.get_by(SellerToken, seller_id: seller.id)
    end

    test "does not update email if token expired", %{seller: seller, token: token} do
      {1, nil} = Repo.update_all(SellerToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Sellers.update_seller_email(seller, token) == :error
      assert Repo.get!(Seller, seller.id).email == seller.email
      assert Repo.get_by(SellerToken, seller_id: seller.id)
    end
  end

  describe "change_seller_password/2" do
    test "returns a seller changeset" do
      assert %Ecto.Changeset{} = changeset = Sellers.change_seller_password(%Seller{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Sellers.change_seller_password(%Seller{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_seller_password/3" do
    setup do
      %{seller: seller_fixture()}
    end

    test "validates password", %{seller: seller} do
      {:error, changeset} =
        Sellers.update_seller_password(seller, valid_seller_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{seller: seller} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Sellers.update_seller_password(seller, valid_seller_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{seller: seller} do
      {:error, changeset} =
        Sellers.update_seller_password(seller, "invalid", %{password: valid_seller_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{seller: seller} do
      {:ok, seller} =
        Sellers.update_seller_password(seller, valid_seller_password(), %{
          password: "new valid password"
        })

      assert is_nil(seller.password)
      assert Sellers.get_seller_by_email_and_password(seller.email, "new valid password")
    end

    test "deletes all tokens for the given seller", %{seller: seller} do
      _ = Sellers.generate_seller_session_token(seller)

      {:ok, _} =
        Sellers.update_seller_password(seller, valid_seller_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(SellerToken, seller_id: seller.id)
    end
  end

  describe "generate_seller_session_token/1" do
    setup do
      %{seller: seller_fixture()}
    end

    test "generates a token", %{seller: seller} do
      token = Sellers.generate_seller_session_token(seller)
      assert seller_token = Repo.get_by(SellerToken, token: token)
      assert seller_token.context == "session"

      # Creating the same token for another seller should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%SellerToken{
          token: seller_token.token,
          seller_id: seller_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_seller_by_session_token/1" do
    setup do
      seller = seller_fixture()
      token = Sellers.generate_seller_session_token(seller)
      %{seller: seller, token: token}
    end

    test "returns seller by token", %{seller: seller, token: token} do
      assert session_seller = Sellers.get_seller_by_session_token(token)
      assert session_seller.id == seller.id
    end

    test "does not return seller for invalid token" do
      refute Sellers.get_seller_by_session_token("oops")
    end

    test "does not return seller for expired token", %{token: token} do
      {1, nil} = Repo.update_all(SellerToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Sellers.get_seller_by_session_token(token)
    end
  end

  describe "delete_seller_session_token/1" do
    test "deletes the token" do
      seller = seller_fixture()
      token = Sellers.generate_seller_session_token(seller)
      assert Sellers.delete_seller_session_token(token) == :ok
      refute Sellers.get_seller_by_session_token(token)
    end
  end

  describe "deliver_seller_confirmation_instructions/2" do
    setup do
      %{seller: seller_fixture()}
    end

    test "sends token through notification", %{seller: seller} do
      token =
        extract_seller_token(fn url ->
          Sellers.deliver_seller_confirmation_instructions(seller, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert seller_token = Repo.get_by(SellerToken, token: :crypto.hash(:sha256, token))
      assert seller_token.seller_id == seller.id
      assert seller_token.sent_to == seller.email
      assert seller_token.context == "confirm"
    end
  end

  describe "confirm_seller/1" do
    setup do
      seller = seller_fixture()

      token =
        extract_seller_token(fn url ->
          Sellers.deliver_seller_confirmation_instructions(seller, url)
        end)

      %{seller: seller, token: token}
    end

    test "confirms the email with a valid token", %{seller: seller, token: token} do
      assert {:ok, confirmed_seller} = Sellers.confirm_seller(token)
      assert confirmed_seller.confirmed_at
      assert confirmed_seller.confirmed_at != seller.confirmed_at
      assert Repo.get!(Seller, seller.id).confirmed_at
      refute Repo.get_by(SellerToken, seller_id: seller.id)
    end

    test "does not confirm with invalid token", %{seller: seller} do
      assert Sellers.confirm_seller("oops") == :error
      refute Repo.get!(Seller, seller.id).confirmed_at
      assert Repo.get_by(SellerToken, seller_id: seller.id)
    end

    test "does not confirm email if token expired", %{seller: seller, token: token} do
      {1, nil} = Repo.update_all(SellerToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Sellers.confirm_seller(token) == :error
      refute Repo.get!(Seller, seller.id).confirmed_at
      assert Repo.get_by(SellerToken, seller_id: seller.id)
    end
  end

  describe "deliver_seller_reset_password_instructions/2" do
    setup do
      %{seller: seller_fixture()}
    end

    test "sends token through notification", %{seller: seller} do
      token =
        extract_seller_token(fn url ->
          Sellers.deliver_seller_reset_password_instructions(seller, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert seller_token = Repo.get_by(SellerToken, token: :crypto.hash(:sha256, token))
      assert seller_token.seller_id == seller.id
      assert seller_token.sent_to == seller.email
      assert seller_token.context == "reset_password"
    end
  end

  describe "get_seller_by_reset_password_token/1" do
    setup do
      seller = seller_fixture()

      token =
        extract_seller_token(fn url ->
          Sellers.deliver_seller_reset_password_instructions(seller, url)
        end)

      %{seller: seller, token: token}
    end

    test "returns the seller with valid token", %{seller: %{id: id}, token: token} do
      assert %Seller{id: ^id} = Sellers.get_seller_by_reset_password_token(token)
      assert Repo.get_by(SellerToken, seller_id: id)
    end

    test "does not return the seller with invalid token", %{seller: seller} do
      refute Sellers.get_seller_by_reset_password_token("oops")
      assert Repo.get_by(SellerToken, seller_id: seller.id)
    end

    test "does not return the seller if token expired", %{seller: seller, token: token} do
      {1, nil} = Repo.update_all(SellerToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Sellers.get_seller_by_reset_password_token(token)
      assert Repo.get_by(SellerToken, seller_id: seller.id)
    end
  end

  describe "reset_seller_password/2" do
    setup do
      %{seller: seller_fixture()}
    end

    test "validates password", %{seller: seller} do
      {:error, changeset} =
        Sellers.reset_seller_password(seller, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{seller: seller} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Sellers.reset_seller_password(seller, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{seller: seller} do
      {:ok, updated_seller} = Sellers.reset_seller_password(seller, %{password: "new valid password"})
      assert is_nil(updated_seller.password)
      assert Sellers.get_seller_by_email_and_password(seller.email, "new valid password")
    end

    test "deletes all tokens for the given seller", %{seller: seller} do
      _ = Sellers.generate_seller_session_token(seller)
      {:ok, _} = Sellers.reset_seller_password(seller, %{password: "new valid password"})
      refute Repo.get_by(SellerToken, seller_id: seller.id)
    end
  end

  describe "inspect/2 for the Seller module" do
    test "does not include password" do
      refute inspect(%Seller{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
