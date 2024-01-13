defmodule HappyHanger.ProductsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HappyHanger.Products` context.
  """

  @doc """
  Generate a product.
  """
  def product_fixture(attrs \\ %{}) do
    {:ok, product} =
      attrs
      |> Enum.into(%{
        cost_price: "120.5",
        description: "some description",
        name: "some name",
        notes: "some notes",
        price: "120.5",
        sku: "some sku",
        stock_level: 42
      })
      |> HappyHanger.Products.create_product()

    product
  end
end
