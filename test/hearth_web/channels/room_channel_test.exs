defmodule HearthWeb.RoomChannelTest do
  use HearthWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      HearthWeb.UserSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(HearthWeb.RoomChannel, "room:lobby")

    %{socket: socket}
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push(socket, "ping", %{"hello" => "there"})
    assert_reply ref, :ok, %{"hello" => "there"}
  end

  test "shout broadcasts to room:<name>", %{socket: socket} do
    ref = push(socket, "shout", %{"body" => "hi"})
    assert_reply ref, :ok, %{seq: 1}
    assert_broadcast "shout", %{body: "hi", seq: 1}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from!(socket, "broadcast", %{"some" => "data"})
    assert_push "broadcast", %{"some" => "data"}
  end
end
