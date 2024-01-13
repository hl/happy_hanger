defmodule HappyHanger.OrdersTest do
  use HappyHanger.DataCase

  alias HappyHanger.Orders

  describe "orders" do
    alias HappyHanger.Orders.Order

    import HappyHanger.OrdersFixtures

    @invalid_attrs %{name: nil, total: nil, notes: nil, subtotal: nil, shipping_costs: nil, line_items: nil}

    test "list_orders/0 returns all orders" do
      order = order_fixture()
      assert Orders.list_orders() == [order]
    end

    test "get_order!/1 returns the order with given id" do
      order = order_fixture()
      assert Orders.get_order!(order.id) == order
    end

    test "create_order/1 with valid data creates a order" do
      valid_attrs = %{name: "some name", total: "120.5", notes: "some notes", subtotal: "120.5", shipping_costs: "120.5", line_items: %{}}

      assert {:ok, %Order{} = order} = Orders.create_order(valid_attrs)
      assert order.name == "some name"
      assert order.total == Decimal.new("120.5")
      assert order.notes == "some notes"
      assert order.subtotal == Decimal.new("120.5")
      assert order.shipping_costs == Decimal.new("120.5")
      assert order.line_items == %{}
    end

    test "create_order/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Orders.create_order(@invalid_attrs)
    end

    test "update_order/2 with valid data updates the order" do
      order = order_fixture()
      update_attrs = %{name: "some updated name", total: "456.7", notes: "some updated notes", subtotal: "456.7", shipping_costs: "456.7", line_items: %{}}

      assert {:ok, %Order{} = order} = Orders.update_order(order, update_attrs)
      assert order.name == "some updated name"
      assert order.total == Decimal.new("456.7")
      assert order.notes == "some updated notes"
      assert order.subtotal == Decimal.new("456.7")
      assert order.shipping_costs == Decimal.new("456.7")
      assert order.line_items == %{}
    end

    test "update_order/2 with invalid data returns error changeset" do
      order = order_fixture()
      assert {:error, %Ecto.Changeset{}} = Orders.update_order(order, @invalid_attrs)
      assert order == Orders.get_order!(order.id)
    end

    test "delete_order/1 deletes the order" do
      order = order_fixture()
      assert {:ok, %Order{}} = Orders.delete_order(order)
      assert_raise Ecto.NoResultsError, fn -> Orders.get_order!(order.id) end
    end

    test "change_order/1 returns a order changeset" do
      order = order_fixture()
      assert %Ecto.Changeset{} = Orders.change_order(order)
    end
  end
end
