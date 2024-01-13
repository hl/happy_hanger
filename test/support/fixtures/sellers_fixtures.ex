defmodule HappyHanger.SellersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HappyHanger.Sellers` context.
  """

  def unique_seller_email, do: "seller#{System.unique_integer()}@example.com"
  def valid_seller_password, do: "hello world!"

  def valid_seller_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_seller_email(),
      password: valid_seller_password()
    })
  end

  def seller_fixture(attrs \\ %{}) do
    {:ok, seller} =
      attrs
      |> valid_seller_attributes()
      |> HappyHanger.Sellers.register_seller()

    seller
  end

  def extract_seller_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
