defmodule Hearth.Access.Claim do
  use Ecto.Schema
  import Ecto.Changeset

  schema "claims" do
    field :room, :string
    field :owner_secret, :string
    timestamps(updated_at: false)
  end

  def changeset(claim, attrs) do
    claim
    |> cast(attrs, [:room, :owner_secret])
    |> validate_required([:room, :owner_secret])
    |> unique_constraint(:room)
  end
end
