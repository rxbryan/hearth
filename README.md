# Hearth

Hearth is a real-time chat server built on Elixir and Phoenix that scales out to
many small, private rooms. It began as a study of how the BEAM models the
constraints of real-time messaging, and it is still that at the core.

Hearth does not authenticate users in the traditional sense, no emails, passwords. It issues
capabilities and lets holders manage identity themselves. The server never learns
who an owner or a joiner is: only that the bearer of a valid token may act on a
given room.

A developer building on Hearth can stand up their own page where people generate invites to their room. Hearth only need to validate the capability.

## The fireside model

A room is a hearth, a fixed place that holds its warmth while people are gathered around it. 
People (client connections) gather, take part in recent conversations, and drift off without disturbing it. 
With no one around for some time, the fire burns out and is persisted. The next connections relight the embers from this persisted history. On a crash,  the supervisor rebuilds the hearth from the same persisted history and the connections to it stay untouched.


Hearth has two planes:
**runtime plane**: 
 Each active room is a Genserver, started by the supervisor on first connection, and the next connections finds it active. It holds a recent message buffer and stamps every message with a monotonic sequence, every participant agrees on this order.

 when the last client/person disconnects, the room process idles out and is not restarted by the supervisor. 

 On the next connection, it relights and rehydrates the hearth with the last N messages (same process as a restart on crash).
- **control plane**: Durable and separate from the runtime.
Claiming a room creates a durable room record and returns an owner token.
Owners mint invite tokens, which can expire. The plane verifies tokens. It is
exposed as a small JSON API and backed by Postgres.

The runtime serves rooms and the control plane gates entry


## Auth
You create a room by giving it a name. The server returns a token scoped to that
room and signed with a secret only the server holds.

- **Owner token**   your durable key to the room. it is long-lived, and can be used to mint invites.
- **Invite token**  a limited capability you hand to someone else to join.
Single-use, N-use, or time-boxed. Invites are short-lived by
design. Their expiry is also part of how an abandoned room eventually becomes
unreachable, and then sweepable.

### Persistense

Hearth uses Postgres as the database. A running room serves reads from ETS and rebuilds that cache from Postgres when it relights.

- **Room records**: one per hearth, tiny, grow with number of rooms. Cheap
- **Messages**: bounded per room. This is the history a hearth needs to restart.

Messages stay bounded because a room keeps a recent tail, not a transcript.

Picture  scenarios where a user creates a hearth for a Worldcup watch party, this room accumulates tens of thousands of messages in one evening and not much after. Old messages fall
off the tail continuously as new ones arrive, so a busy room stays bounded while
it is busy, and the cold room is swept later.

**Sweep policies**

- Per-room tail cap: keep only the recent tail (last N messages, or a recent
time window). Runs continuously. Keeps a busy room bounded during
its busy hours.
- Whole-room TTL: a room untouched for N days is swept entirely, record and
remaining messages gone. Handles abandoned rooms.
- Invite expiry — short-lived invites mean abandoned rooms become unreachable
on their own.



## SDK

A client SDK accompanies the server, with two faces: a runtime face (join, send,
presence, reconnect-with-replay) and a control face (claim a room, mint invites).

## Run


`mix setup` install dependencies and set up the database
`mix phx.server`, or `iex -S mix phx.server` to run inside IEx
