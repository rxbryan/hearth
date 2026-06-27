defmodule Hearth.Room do
  use GenServer, restart: :transient

  def start_link(name), do: GenServer.start_link(__MODULE__, name, name: via(name))
  def post(name, body), do: GenServer.call(via(name), {:post, body})

  def ensure_started(name) do
    case DynamicSupervisor.start_child(Hearth.RoomSupervisor, {__MODULE__, name}) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  def history(name), do: GenServer.call(via(name), :history)

  # returns new messages since last seen.
  def replay(name, since_seq), do: GenServer.call(via(name), {:replay, since_seq})

  def whereis(name) do
    case Registry.lookup(Hearth.RoomRegistry, name) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  defp via(name), do: {:via, Registry, {Hearth.RoomRegistry, name}}

  @impl true
  def init(name) do
    {:ok, %{name: name, seq: 0, buffer: []}, {:continue, :load}}
  end

  @impl true
  def handle_continue(:load, state) do
    recent = Hearth.MessageStore.recent(state.name)

    seq =
      case List.last(recent) do
        nil -> 0
        %{seq: s} -> s
      end

    {:noreply, %{state | buffer: Enum.reverse(recent), seq: seq}}
  end

  @impl true
  def handle_call({:post, body}, _from, state) do
    seq = state.seq + 1
    msg = %{body: body, seq: seq}
    :ok = Hearth.MessageStore.append(state.name, msg)
    HearthWeb.Endpoint.broadcast("room:" <> state.name, "shout", msg)
    {:reply, {:ok, seq}, %{state | seq: seq, buffer: [msg | state.buffer]}}
  end

  @impl true
  def handle_call(:history, _from, state) do
    {:reply, Enum.reverse(state.buffer), state}
  end

  @impl true
  def handle_call({:replay, since_seq}, _from, state) do
    missed =
      state.buffer
      |> Enum.reverse()
      |> Enum.filter(&(&1.seq > since_seq))

    {:reply, missed, state}
  end
end
