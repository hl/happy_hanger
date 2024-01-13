defmodule HappyHanger.Products.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name, :string
    field :description, :string
    field :sku, :string
    field :cost_price, :decimal
    field :price, :decimal
    field :stock_level, :integer
    field :notes, :string
    field :seller_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :sku, :description, :cost_price, :price, :stock_level, :notes])
    |> validate_required([:name, :sku, :description, :cost_price, :price, :stock_level, :notes])
  end
end
