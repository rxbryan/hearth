defmodule Hearth.MessageStore do
  @moduledoc """
  Hot read cache (ETS) in front of the durable store (Postgres).

  This process exists only to keep the table alive, hence
  does not handle writes, so per-room concurrency is preserved.
  """
  use GenServer
  alias Hearth.Messages

  @table :hearth_messages
  @tail 50

  def start_link(_), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc "Write-through to both postgres and cache."
  def append(room, %{seq: seq} = msg) do
    :ets.insert(@table, {{room, seq}, msg})
    {:ok, _} = Messages.insert(room, seq, msg.body)
    :ok
  end

  @doc "Recent tail, oldest-first. ETS first; fall through to Postgres on a cold cache."
  def recent(room, limit \\ @tail) do
    case ets_recent(room, limit) do
      [] -> warm_from_db(room, limit)
      msgs -> msgs
    end
  end

  @impl true
  def init(:ok) do
    :ets.new(@table, [
      :ordered_set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, %{}}
  end

  @doc "Drop a room's messages from the hot cache. Leaves DB untouched."
  def evict(room), do: :ets.match_delete(@table, {{room, :_}, :_})

  defp ets_recent(room, limit) do
    @table
    |> :ets.select([{{{room, :_}, :"$1"}, [], [:"$1"]}])
    |> Enum.take(-limit)
  end

  defp warm_from_db(room, limit) do
    msgs = Messages.recent(room, limit)
    Enum.each(msgs, fn %{seq: seq} = m -> :ets.insert(@table, {{room, seq}, m}) end)
    msgs
  end
end
