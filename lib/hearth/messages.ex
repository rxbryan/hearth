defmodule Hearth.Messages do
  @moduledoc "Messages context module wrapping postgres"
  import Ecto.Query
  alias Hearth.{Repo, Message}

  def insert(room, seq, body) do
    %Message{}
    |> Message.changeset(%{room: room, seq: seq, body: body})
    |> Repo.insert()
  end

  @doc "Most recent `limit` messages for a room, oldest-first."
  def recent(room, limit) do
    Message
    |> where(room: ^room)
    |> order_by(desc: :seq)
    |> limit(^limit)
    |> select([m], %{body: m.body, seq: m.seq})
    |> Repo.all()
    |> Enum.reverse()
  end
end
