defmodule HappyHanger.Sellers do
  @moduledoc """
  The Sellers context.
  """

  import Ecto.Query, warn: false
  alias HappyHanger.Repo

  alias HappyHanger.Sellers.{Seller, SellerToken, SellerNotifier}

  ## Database getters

  @doc """
  Gets a seller by email.

  ## Examples

      iex> get_seller_by_email("foo@example.com")
      %Seller{}

      iex> get_seller_by_email("unknown@example.com")
      nil

  """
  def get_seller_by_email(email) when is_binary(email) do
    Repo.get_by(Seller, email: email)
  end

  @doc """
  Gets a seller by email and password.

  ## Examples

      iex> get_seller_by_email_and_password("foo@example.com", "correct_password")
      %Seller{}

      iex> get_seller_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_seller_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    seller = Repo.get_by(Seller, email: email)
    if Seller.valid_password?(seller, password), do: seller
  end

  @doc """
  Gets a single seller.

  Raises `Ecto.NoResultsError` if the Seller does not exist.

  ## Examples

      iex> get_seller!(123)
      %Seller{}

      iex> get_seller!(456)
      ** (Ecto.NoResultsError)

  """
  def get_seller!(id), do: Repo.get!(Seller, id)

  ## Seller registration

  @doc """
  Registers a seller.

  ## Examples

      iex> register_seller(%{field: value})
      {:ok, %Seller{}}

      iex> register_seller(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_seller(attrs) do
    %Seller{}
    |> Seller.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking seller changes.

  ## Examples

      iex> change_seller_registration(seller)
      %Ecto.Changeset{data: %Seller{}}

  """
  def change_seller_registration(%Seller{} = seller, attrs \\ %{}) do
    Seller.registration_changeset(seller, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the seller email.

  ## Examples

      iex> change_seller_email(seller)
      %Ecto.Changeset{data: %Seller{}}

  """
  def change_seller_email(seller, attrs \\ %{}) do
    Seller.email_changeset(seller, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_seller_email(seller, "valid password", %{email: ...})
      {:ok, %Seller{}}

      iex> apply_seller_email(seller, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_seller_email(seller, password, attrs) do
    seller
    |> Seller.email_changeset(attrs)
    |> Seller.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the seller email using the given token.

  If the token matches, the seller email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_seller_email(seller, token) do
    context = "change:#{seller.email}"

    with {:ok, query} <- SellerToken.verify_change_email_token_query(token, context),
         %SellerToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(seller_email_multi(seller, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp seller_email_multi(seller, email, context) do
    changeset =
      seller
      |> Seller.email_changeset(%{email: email})
      |> Seller.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:seller, changeset)
    |> Ecto.Multi.delete_all(:tokens, SellerToken.by_seller_and_contexts_query(seller, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given seller.

  ## Examples

      iex> deliver_seller_update_email_instructions(seller, current_email, &url(~p"/sellers/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_seller_update_email_instructions(%Seller{} = seller, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, seller_token} = SellerToken.build_email_token(seller, "change:#{current_email}")

    Repo.insert!(seller_token)
    SellerNotifier.deliver_update_email_instructions(seller, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the seller password.

  ## Examples

      iex> change_seller_password(seller)
      %Ecto.Changeset{data: %Seller{}}

  """
  def change_seller_password(seller, attrs \\ %{}) do
    Seller.password_changeset(seller, attrs, hash_password: false)
  end

  @doc """
  Updates the seller password.

  ## Examples

      iex> update_seller_password(seller, "valid password", %{password: ...})
      {:ok, %Seller{}}

      iex> update_seller_password(seller, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_seller_password(seller, password, attrs) do
    changeset =
      seller
      |> Seller.password_changeset(attrs)
      |> Seller.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:seller, changeset)
    |> Ecto.Multi.delete_all(:tokens, SellerToken.by_seller_and_contexts_query(seller, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{seller: seller}} -> {:ok, seller}
      {:error, :seller, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_seller_session_token(seller) do
    {token, seller_token} = SellerToken.build_session_token(seller)
    Repo.insert!(seller_token)
    token
  end

  @doc """
  Gets the seller with the given signed token.
  """
  def get_seller_by_session_token(token) do
    {:ok, query} = SellerToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_seller_session_token(token) do
    Repo.delete_all(SellerToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given seller.

  ## Examples

      iex> deliver_seller_confirmation_instructions(seller, &url(~p"/sellers/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_seller_confirmation_instructions(confirmed_seller, &url(~p"/sellers/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_seller_confirmation_instructions(%Seller{} = seller, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if seller.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, seller_token} = SellerToken.build_email_token(seller, "confirm")
      Repo.insert!(seller_token)
      SellerNotifier.deliver_confirmation_instructions(seller, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a seller by the given token.

  If the token matches, the seller account is marked as confirmed
  and the token is deleted.
  """
  def confirm_seller(token) do
    with {:ok, query} <- SellerToken.verify_email_token_query(token, "confirm"),
         %Seller{} = seller <- Repo.one(query),
         {:ok, %{seller: seller}} <- Repo.transaction(confirm_seller_multi(seller)) do
      {:ok, seller}
    else
      _ -> :error
    end
  end

  defp confirm_seller_multi(seller) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:seller, Seller.confirm_changeset(seller))
    |> Ecto.Multi.delete_all(:tokens, SellerToken.by_seller_and_contexts_query(seller, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given seller.

  ## Examples

      iex> deliver_seller_reset_password_instructions(seller, &url(~p"/sellers/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_seller_reset_password_instructions(%Seller{} = seller, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, seller_token} = SellerToken.build_email_token(seller, "reset_password")
    Repo.insert!(seller_token)
    SellerNotifier.deliver_reset_password_instructions(seller, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the seller by reset password token.

  ## Examples

      iex> get_seller_by_reset_password_token("validtoken")
      %Seller{}

      iex> get_seller_by_reset_password_token("invalidtoken")
      nil

  """
  def get_seller_by_reset_password_token(token) do
    with {:ok, query} <- SellerToken.verify_email_token_query(token, "reset_password"),
         %Seller{} = seller <- Repo.one(query) do
      seller
    else
      _ -> nil
    end
  end

  @doc """
  Resets the seller password.

  ## Examples

      iex> reset_seller_password(seller, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %Seller{}}

      iex> reset_seller_password(seller, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_seller_password(seller, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:seller, Seller.password_changeset(seller, attrs))
    |> Ecto.Multi.delete_all(:tokens, SellerToken.by_seller_and_contexts_query(seller, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{seller: seller}} -> {:ok, seller}
      {:error, :seller, changeset, _} -> {:error, changeset}
    end
  end
end
