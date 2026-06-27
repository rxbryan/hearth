defmodule HearthWeb.RoomController do
  use HearthWeb, :controller
  alias Hearth.Access

  def claim(conn, %{"room" => room}) do
    case Access.claim_room(room) do
      {:ok, owner_token} ->
        conn
        |> put_status(:created)
        |> json(%{room: room, owner_token: owner_token})

      {:error, :already_claimed} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "room_already_claimed"})
    end
  end

  def claim(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_room"})
  end
end
