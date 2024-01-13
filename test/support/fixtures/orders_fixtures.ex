defmodule HappyHanger.OrdersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `HappyHanger.Orders` context.
  """

  @doc """
  Generate a order.
  """
  def order_fixture(attrs \\ %{}) do
    {:ok, order} =
      attrs
      |> Enum.into(%{
        line_items: %{},
        name: "some name",
        notes: "some notes",
        shipping_costs: "120.5",
        subtotal: "120.5",
        total: "120.5"
      })
      |> HappyHanger.Orders.create_order()

    order
  end
end
