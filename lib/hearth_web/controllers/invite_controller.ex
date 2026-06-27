defmodule HearthWeb.InviteController do
  use HearthWeb, :controller
  alias Hearth.Access

  def create(conn, %{"room" => room, "owner_token" => token} = params) do
    ttl = Map.get(params, "ttl_seconds", 3600)

    case Access.mint_invite(token, ttl) do
      {:ok, invite_token} ->
        conn
        |> put_status(:created)
        |> json(%{room: room, invite_token: invite_token, ttl_seconds: ttl})

      {:error, reason} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: to_string(reason)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "missing_owner_token"})
  end
end
