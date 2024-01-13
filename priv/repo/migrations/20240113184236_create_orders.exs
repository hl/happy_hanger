defmodule HappyHanger.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders) do
      add :name, :text, null: false
      add :notes, :text
      add :subtotal, :decimal
      add :total, :decimal
      add :shipping_costs, :decimal
      add :line_items, :map
      add :seller_id, references(:sellers, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:orders, [:seller_id])
    create unique_index(:orders, [:name, :seller_id])
  end
end
