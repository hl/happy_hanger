defmodule HappyHanger.Orders.Order do
  use Ecto.Schema
  import Ecto.Changeset

  schema "orders" do
    field :name, :string
    field :total, :decimal
    field :notes, :string
    field :subtotal, :decimal
    field :shipping_costs, :decimal
    field :line_items, :map
    field :seller_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [:name, :notes, :subtotal, :total, :shipping_costs, :line_items])
    |> validate_required([:name, :notes, :subtotal, :total, :shipping_costs])
  end
end
