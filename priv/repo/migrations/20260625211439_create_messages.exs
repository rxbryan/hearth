defmodule Hearth.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :room, :string, null: false
      add :seq, :bigint, null: false
      add :body, :text, null: false
      timestamps(updated_at: false)
    end

    create unique_index(:messages, [:room, :seq])
  end
end
