defmodule HearthWeb.RoomChannelTest do
  use HearthWeb.ChannelCase

  setup do
    token = Hearth.Access.Token.mint_owner("lobby", "test-secret")

    {:ok, _, socket} =
      HearthWeb.UserSocket
      |> socket("user_id", %{})
      |> subscribe_and_join(HearthWeb.RoomChannel, "room:lobby", %{
        "token" => token,
        "who" => "tester"
      })

    %{socket: socket}
  end

  test "join is rejected without a token" do
    assert {:error, %{reason: "missing_token"}} =
             HearthWeb.UserSocket
             |> socket("user_id", %{})
             |> subscribe_and_join(HearthWeb.RoomChannel, "room:lobby", %{})
  end

  test "join is rejected with a token for another room" do
    # We don't want the test reaching DB, so we mint a token directly.
    token = Hearth.Access.Token.mint_owner("other", "test-secret")

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
