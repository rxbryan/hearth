defmodule Hearth.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :room, :string
    field :seq, :integer
    field :body, :string
    timestamps(updated_at: false)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:room, :seq, :body])
    |> validate_required([:room, :seq, :body])
    |> unique_constraint([:room, :seq])
  end
end
