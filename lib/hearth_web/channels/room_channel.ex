defmodule HearthWeb.RoomChannel do
  use HearthWeb, :channel

  @impl true
  def join("room:" <> name, _payload, socket) do
    Hearth.Room.ensure_started(name)
    {:ok, assign(socket, :room, name)}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (room:lobby).
  @impl true
  def handle_in("shout", %{"body" => body}, socket) do
    {:ok, seq} = Hearth.Room.post(socket.assigns.room, body)
    {:reply, {:ok, %{seq: seq}}, socket}
  end
end
