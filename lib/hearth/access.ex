defmodule Hearth.Access do
  @moduledoc "Control plane: claiming rooms and minting capabilities."
  alias Hearth.{Repo, Access.Claim, Access.Token}

  @doc """
  Claim a room name. Succeeds once per name;
  Returns the owner token on success.
  """
  def claim_room(room) do
    secret = generate_secret()

    %Claim{}
    |> Claim.changeset(%{room: room, owner_secret: secret})
    |> Repo.insert()
    |> case do
      {:ok, _claim} ->
        {:ok, Token.mint_owner(room, secret)}

      {:error, changeset} ->
        if Keyword.has_key?(changeset.errors, :room) do
          {:error, :already_claimed}
        else
          {:error, changeset}
        end
    end
  end

  @doc """
  Mint a short-lived invite for a room.
  Returns {:ok, invite_token}.
  """
  def mint_invite(owner_token, ttl_seconds \\ 3600) do
    with {:ok, %{room: room, role: :owner, secret: secret}} <- Token.verify_owner(owner_token),
         %Claim{owner_secret: ^secret} <- Repo.get_by(Claim, room: room) do
      {:ok, Token.mint_invite(room, ttl_seconds)}
    else
      nil -> {:error, :no_claim}
      %Claim{} -> {:error, :not_owner}
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_secret do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
