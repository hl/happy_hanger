defmodule HappyHanger.Repo.Migrations.CreateSellersAuthTables do
  use Ecto.Migration

  def change do
    create table(:sellers) do
      add :email, :string, null: false, collate: :nocase
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps(type: :utc_datetime)
    end

    create unique_index(:sellers, [:email])

    create table(:sellers_tokens) do
      add :seller_id, references(:sellers, on_delete: :delete_all), null: false
      add :token, :binary, null: false, size: 32
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:sellers_tokens, [:seller_id])
    create unique_index(:sellers_tokens, [:context, :token])
  end
end
