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

      # TODO: validate that since_seq is an integer or coerce
      since = Map.get(payload, "since_seq", 0)
      Hearth.Room.ensure_started(name)
      send(self(), :after_join)
      {:ok, assign(socket, room: name, who: who, since_seq: since)}
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

  # The sender receives the message twice.
  @impl true
  def handle_in("message", %{"body" => body}, socket) do
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

    # batch and replay anything the client missed since its last-seen sequence
    missed = Hearth.Room.replay(socket.assigns.room, socket.assigns.since_seq)
    if missed != [], do: push(socket, "replay", %{messages: missed})

    {:noreply, socket}
  end

  defp fetch_token(%{"token" => token}) when is_binary(token), do: {:ok, token}
  defp fetch_token(_), do: {:error, :missing_token}
end
