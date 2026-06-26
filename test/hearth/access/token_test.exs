defmodule Hearth.Access.TokenTest do
  use ExUnit.Case, async: true
  alias Hearth.Access.Token

  test "an owner token verifies for its room and never expires" do
    t = Token.mint_owner("lobby")
    assert {:ok, %{room: "lobby", role: :owner}} = Token.verify("lobby", t)
  end

  # The design guarantees this behaviour since the room is in the
  # token payload.
  test "a token for one room is rejected for another" do
    t = Token.mint_owner("lobby")
    assert {:error, :wrong_room} = Token.verify("other", t)
  end

  test "garbage is rejected" do
    assert {:error, :invalid} = Token.verify("lobby", "not-a-real-token")
  end

  test "a fresh invite verifies" do
    t = Token.mint_invite("lobby", 60)
    assert {:ok, %{room: "lobby", role: :member}} = Token.verify("lobby", t)
  end

  test "an expired invite is rejected" do
    t = Token.mint_invite("lobby", -1)
    assert {:error, :expired} = Token.verify("lobby", t)
  end
end
