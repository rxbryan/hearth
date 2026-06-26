defmodule HearthWeb.RoomChannelTest do
  use HearthWeb.ChannelCase

  setup do
    token = Hearth.Access.Token.mint_owner("lobby")

    {:ok, _, socket} =
      HearthWeb.UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(HearthWeb.RoomChannel, "room:lobby", %{
        "token" => token,
        "who" => "tester"
      })

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

  test "join is rejected without a token" do
    assert {:error, %{reason: "missing_token"}} =
             HearthWeb.UserSocket
             |> socket("user_id", %{})
             |> subscribe_and_join(HearthWeb.RoomChannel, "room:lobby", %{})
  end

  test "join is rejected with a token for another room" do
    token = Hearth.Access.Token.mint_owner("other")

    assert {:error, %{reason: "wrong_room"}} =
             HearthWeb.UserSocket
             |> socket("user_id", %{})
             |> subscribe_and_join(HearthWeb.RoomChannel, "room:lobby", %{"token" => token})
  end

  test "presence reports the joiner and typing state", %{socket: socket} do
    assert_push "presence_state", state
    assert Map.has_key?(state, "tester")

    ref = push(socket, "typing", %{"typing" => true})
    assert_reply ref, :ok
    assert_broadcast "presence_diff", _diff
  end
end
