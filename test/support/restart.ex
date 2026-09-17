defmodule ExEventBus.Restart do
  @moduledoc """
  Crashes a named process the way a runtime failure would and waits for its
  supervisor to bring a new one up under the same name.
  """

  import ExUnit.CaptureLog

  @attempts 200
  @interval_in_ms 10

  @doc """
  Kills the process registered as `name` and returns once a different process
  is registered under it. Raises when no restart happens in time.
  """
  @spec crash_and_await(name :: atom) :: :ok
  def crash_and_await(name) when is_atom(name) do
    old_pid = Process.whereis(name)

    capture_log(fn ->
      Process.exit(old_pid, :kill)
      await_restart(name, old_pid, @attempts)
    end)

    :ok
  end

  defp await_restart(name, _old_pid, 0), do: raise("#{inspect(name)} was not restarted")

  defp await_restart(name, old_pid, attempts_left) do
    case Process.whereis(name) do
      pid when is_pid(pid) and pid != old_pid ->
        :ok

      _ ->
        Process.sleep(@interval_in_ms)
        await_restart(name, old_pid, attempts_left - 1)
    end
  end
end
