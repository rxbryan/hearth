defmodule HearthWeb.RoomChannel do
  use HearthWeb, :channel

  @impl true
  def join("room:" <> name, payload, socket) do
    with {:ok, token} <- fetch_token(payload),
         {:ok, _claims} <- Hearth.Access.Token.verify(name, token) do
      # `who` is a display string the client supplies since hearth does
      # not track identity
      # TODO: generate fun tags, if user fails to supply identity
      who = Map.get(payload, "who", "anon-#{System.unique_integer([:positive])}")
      Hearth.Room.ensure_started(name)
      send(self(), :after_join)
      {:ok, assign(socket, room: name, who: who)}
    else
      {:error, reason} -> {:error, %{reason: to_string(reason)}}
    end
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

  @impl true
  def handle_in("typing", %{"typing" => typing}, socket) when is_boolean(typing) do
    {:ok, _} =
      HearthWeb.Presence.update(socket, socket.assigns.who, fn meta ->
        Map.put(meta, :typing, typing)
      end)

    {:reply, :ok, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    {:ok, _} =
      HearthWeb.Presence.track(socket, socket.assigns.who, %{
        online_at: System.system_time(:second),
        typing: false
      })

    push(socket, "presence_state", HearthWeb.Presence.list(socket))
    {:noreply, socket}
  end

  defp fetch_token(%{"token" => token}) when is_binary(token), do: {:ok, token}
  defp fetch_token(_), do: {:error, :missing_token}
end
