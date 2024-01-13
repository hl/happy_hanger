defmodule HappyHanger.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :name, :text
      add :sku, :text, null: false
      add :description, :text
      add :cost_price, :decimal
      add :price, :decimal, null: false
      add :stock_level, :integer, default: 1
      add :notes, :text
      add :seller_id, references(:sellers, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:products, [:seller_id])
    create unique_index(:products, [:sku, :seller_id])
  end
end
