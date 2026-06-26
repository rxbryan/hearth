defmodule Hearth.AccessTest do
  use ExUnit.Case, async: false
  alias Hearth.Access
  alias Hearth.Access.Token

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

  test "an owner can mint an invite for their room", %{room: room} do
    {:ok, owner} = Access.claim_room(room)
    assert {:ok, invite} = Access.mint_invite(owner)
    assert {:ok, %{room: ^room, role: :member}} = Token.verify(room, invite)
  end

  test "a token whose secret does not match the claim cannot mint", %{room: room} do
    {:ok, _real_owner} = Access.claim_room(room)
    # a forged owner token for the same room, with the wrong secret
    forged = Token.mint_owner(room, "not-the-real-secret")
    assert {:error, :not_owner} = Access.mint_invite(forged)
  end

  test "an invite token cannot mint further invites", %{room: room} do
    {:ok, owner} = Access.claim_room(room)
    {:ok, invite} = Access.mint_invite(owner)
    assert {:error, :not_owner_token} = Access.mint_invite(invite)
  end
end
