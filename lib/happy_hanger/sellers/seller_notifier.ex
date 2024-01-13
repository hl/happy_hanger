defmodule HappyHanger.Sellers.SellerNotifier do
  import Swoosh.Email

  alias HappyHanger.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"HappyHanger", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(seller, url) do
    deliver(seller.email, "Confirmation instructions", """

    ==============================

    Hi #{seller.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a seller password.
  """
  def deliver_reset_password_instructions(seller, url) do
    deliver(seller.email, "Reset password instructions", """

    ==============================

    Hi #{seller.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a seller email.
  """
  def deliver_update_email_instructions(seller, url) do
    deliver(seller.email, "Update email instructions", """

    ==============================

    Hi #{seller.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end
