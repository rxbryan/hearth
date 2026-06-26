defmodule Hearth.Repo.Migrations.CreateClaims do
  use Ecto.Migration

  def change do
    create table(:claims) do
      add :room, :string, null: false
      add :owner_secret, :string, null: false
      timestamps(updated_at: false)
    end

    create unique_index(:claims, [:room])
  end
end
