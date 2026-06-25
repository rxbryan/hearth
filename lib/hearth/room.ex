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

  defp via(name), do: {:via, Registry, {Hearth.RoomRegistry, name}}

  @impl true
  def init(name), do: {:ok, %{name: name, seq: 0, buffer: []}}

  @impl true
  def handle_call({:post, body}, _from, state) do
    seq = state.seq + 1
    msg = %{body: body, seq: seq}
    HearthWeb.Endpoint.broadcast("room:" <> state.name, "shout", msg)
    {:reply, {:ok, seq}, %{state | seq: seq, buffer: [msg | state.buffer]}}
  end
end
