defmodule HearthWeb.RoomControllerTest do
  use HearthWeb.ConnCase, async: false

  setup do
    %{room: "room-#{System.unique_integer([:positive])}"}
  end

  test "POST /api/rooms claims a free room", %{conn: conn, room: room} do
    conn = post(conn, ~p"/api/rooms", %{room: room})
    assert %{"room" => ^room, "owner_token" => token} = json_response(conn, 201)
    assert is_binary(token)
  end

  test "claiming a taken room returns 409", %{conn: conn, room: room} do
    post(conn, ~p"/api/rooms", %{room: room})
    conn = post(conn, ~p"/api/rooms", %{room: room})
    assert %{"error" => "room_already_claimed"} = json_response(conn, 409)
  end

  test "missing room returns 400", %{conn: conn} do
    conn = post(conn, ~p"/api/rooms", %{})
    assert json_response(conn, 400)
  end
end
