defmodule HappyHanger.ProductsTest do
  use HappyHanger.DataCase

  alias HappyHanger.Products

  describe "products" do
    alias HappyHanger.Products.Product

    import HappyHanger.ProductsFixtures

    @invalid_attrs %{name: nil, description: nil, sku: nil, cost_price: nil, price: nil, stock_level: nil, notes: nil}

    test "list_products/0 returns all products" do
      product = product_fixture()
      assert Products.list_products() == [product]
    end

    test "get_product!/1 returns the product with given id" do
      product = product_fixture()
      assert Products.get_product!(product.id) == product
    end

    test "create_product/1 with valid data creates a product" do
      valid_attrs = %{name: "some name", description: "some description", sku: "some sku", cost_price: "120.5", price: "120.5", stock_level: 42, notes: "some notes"}

      assert {:ok, %Product{} = product} = Products.create_product(valid_attrs)
      assert product.name == "some name"
      assert product.description == "some description"
      assert product.sku == "some sku"
      assert product.cost_price == Decimal.new("120.5")
      assert product.price == Decimal.new("120.5")
      assert product.stock_level == 42
      assert product.notes == "some notes"
    end

    test "create_product/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Products.create_product(@invalid_attrs)
    end

    test "update_product/2 with valid data updates the product" do
      product = product_fixture()
      update_attrs = %{name: "some updated name", description: "some updated description", sku: "some updated sku", cost_price: "456.7", price: "456.7", stock_level: 43, notes: "some updated notes"}

      assert {:ok, %Product{} = product} = Products.update_product(product, update_attrs)
      assert product.name == "some updated name"
      assert product.description == "some updated description"
      assert product.sku == "some updated sku"
      assert product.cost_price == Decimal.new("456.7")
      assert product.price == Decimal.new("456.7")
      assert product.stock_level == 43
      assert product.notes == "some updated notes"
    end

    test "update_product/2 with invalid data returns error changeset" do
      product = product_fixture()
      assert {:error, %Ecto.Changeset{}} = Products.update_product(product, @invalid_attrs)
      assert product == Products.get_product!(product.id)
    end

    test "delete_product/1 deletes the product" do
      product = product_fixture()
      assert {:ok, %Product{}} = Products.delete_product(product)
      assert_raise Ecto.NoResultsError, fn -> Products.get_product!(product.id) end
    end

    test "change_product/1 returns a product changeset" do
      product = product_fixture()
      assert %Ecto.Changeset{} = Products.change_product(product)
    end
  end
end
