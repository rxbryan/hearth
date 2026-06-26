defmodule Hearth.AccessTest do
  use ExUnit.Case, async: false
  alias Hearth.Access

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Hearth.Repo)
    %{room: "room-#{System.unique_integer([:positive])}"}
  end

  test "claiming a free room returns an owner token", %{room: room} do
    assert {:ok, token} = Access.claim_room(room)
    assert is_binary(token)
  end

  test "claiming of an already-claimed room is rejected", %{room: room} do
    assert {:ok, _} = Access.claim_room(room)
    assert {:error, :already_claimed} = Access.claim_room(room)
  end
end
