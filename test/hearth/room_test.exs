defmodule Hearth.RoomTest do
  use ExUnit.Case, async: false

  alias Hearth.Room

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Hearth.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Hearth.Repo, {:shared, self()})

    # Kill room process on test completion
    on_exit(fn ->
      for {_, pid, _, _} <- DynamicSupervisor.which_children(Hearth.RoomSupervisor),
          is_pid(pid) do
        ref = Process.monitor(pid)
        DynamicSupervisor.terminate_child(Hearth.RoomSupervisor, pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, _} -> :ok
        after
          1000 -> :ok
        end
      end
    end)

    %{
      a: "a-#{System.unique_integer([:positive])}",
      b: "b-#{System.unique_integer([:positive])}"
    }
  end

  @tag capture_log: true
  test "a crashed room is restarted while siblings stay untouched", %{a: a, b: b} do
    Room.ensure_started(a)
    Room.ensure_started(b)

    pid_a = Room.whereis(a)
    pid_b = Room.whereis(b)

    {:ok, 1} = Room.post(a, "hello")
    assert Room.history(a) == [%{body: "hello", seq: 1}]

    # Abnormal exit, hence restart
    Process.exit(pid_a, :kill)

    new_pid_a = wait_for_restart(a, pid_a)

    assert new_pid_a != pid_a
    assert Process.alive?(new_pid_a)

    # the message survived the crash, room rehydrated correctly from the store?
    assert Room.history(a) == [%{body: "hello", seq: 1}]

    # B still alive?
    assert Room.whereis(b) == pid_b
    assert Process.alive?(pid_b)
  end

  @tag capture_log: true
  test "a room with a cold cache rehydrates from Postgres", %{a: a} do
    alias Hearth.MessageStore

    Room.ensure_started(a)
    {:ok, 1} = Room.post(a, "first")
    {:ok, 2} = Room.post(a, "second")

    pid = Room.whereis(a)

    # stop cleanly, so room process does not restart.
    :ok = GenServer.stop(pid, :normal)
    wait_until_gone(a)

    # drop cache.
    MessageStore.evict(a)
    # Prove ETS really is empty for this room,
    # so a populated history below can ONLY have come from Postgres
    assert :ets.select(:hearth_messages, [{{{a, :_}, :"$1"}, [], [:"$1"]}]) == []

    # a fresh process must rebuild from DB alone
    Room.ensure_started(a)

    assert Room.history(a) == [
             %{body: "first", seq: 1},
             %{body: "second", seq: 2}
           ]

    # seq resumed from Postgres, not reset, the next message is 3, not 1
    assert {:ok, 3} = Room.post(a, "third")
  end

  defp wait_until_gone(name, attempts \\ 50) do
    cond do
      Room.whereis(name) == nil ->
        :ok

      attempts > 0 ->
        Process.sleep(10)
        wait_until_gone(name, attempts - 1)

      true ->
        flunk("room #{name} still registered")
    end
  end

  defp wait_for_restart(name, old_pid, attempts \\ 50) do
    case Room.whereis(name) do
      pid when is_pid(pid) and pid != old_pid ->
        pid

      _ ->
        if attempts > 0 do
          Process.sleep(10)
          wait_for_restart(name, old_pid, attempts - 1)
        else
          flunk("room #{name} was not restarted")
        end
    end
  end
end
