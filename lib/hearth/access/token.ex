defmodule Hearth.Access.Token do
  @moduledoc """
  Mints and verifies room-scoped bearer capabilities.

  Possession is authorization as Hearth does not track identity. Owner tokens never expire
  Invite tokens carry their own expiry in the payload.
  """
  @salt "hearth room access"

  @doc "Long-lived owner capability for a room. Can later authorize minting of invites."
  def mint_owner(room, secret) do
    Phoenix.Token.sign(HearthWeb.Endpoint, @salt, %{room: room, role: :owner, secret: secret})
  end

  @doc "Short-lived invite capability."
  def mint_invite(room, ttl_seconds) do
    exp = System.system_time(:second) + ttl_seconds
    Phoenix.Token.sign(HearthWeb.Endpoint, @salt, %{room: room, role: :member, exp: exp})
  end

  @doc "Verify a token is valid for `room` and has not expired."
  def verify(room, token) do
    case Phoenix.Token.verify(HearthWeb.Endpoint, @salt, token, max_age: :infinity) do
      {:ok, %{room: ^room} = claims} ->
        if expired?(claims), do: {:error, :expired}, else: {:ok, claims}

      {:ok, _other_room} ->
        {:error, :wrong_room}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Verify a token's signature and decode its claims, without pre-binding a room."
  def verify_owner(token) do
    case Phoenix.Token.verify(HearthWeb.Endpoint, @salt, token, max_age: :infinity) do
      {:ok, %{role: :owner} = claims} -> {:ok, claims}
      {:ok, _} -> {:error, :not_owner_token}
      {:error, reason} -> {:error, reason}
    end
  end

  defp expired?(%{exp: exp}), do: System.system_time(:second) >= exp
  defp expired?(_), do: false
end
