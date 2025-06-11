defmodule ExEventBus.Testing do
  @moduledoc """
  Defines functions to perform event assertions
  """

  alias ExEventBus.ObanDrainer

  defmacro __using__(opts) do
    if not Keyword.has_key?(opts, :ex_event_bus) do
      raise ArgumentError, "testing requires a :ex_event_bus option to be set"
    end

    quote do
      @event_bus Keyword.fetch!(unquote(opts), :ex_event_bus)
      @repo @event_bus.repo()

      def assert_event_received(event, opts \\ [], timeout \\ :none) do
        if timeout == :none do
          Oban.Testing.assert_enqueued(build_oban_opts_with_event(event, opts))
        else
          Oban.Testing.assert_enqueued(build_oban_opts_with_event(event, opts), timeout)
        end
      end

      def refute_event_received(event, opts \\ [], timeout \\ :none) do
        if timeout == :none do
          Oban.Testing.refute_enqueued(build_oban_opts_with_event(event, opts))
        else
          Oban.Testing.refute_enqueued(build_oban_opts_with_event(event, opts), timeout)
        end
      end

      def all_received(opts \\ []), do: Oban.Testing.all_enqueued(build_oban_opts(opts))

      def execute_events(opts \\ []) do
        ObanDrainer.drain(
          Oban.config(@event_bus.Oban),
          opts
          |> Keyword.put_new(:queue, :ex_event_bus)
          |> Keyword.put_new(:with_safety, false)
        )
      end

      defp build_oban_opts_with_event(event, opts) do
        updated_args =
          Keyword.get(opts, :args, %{})
          |> Map.put(:event, event)

        build_oban_opts(opts)
        |> Keyword.put(:args, updated_args)
      end

      defp build_oban_opts(opts) do
        opts
        |> Keyword.put(:queue, :ex_event_bus)
        |> Keyword.put(:worker, ExEventBus.Worker)
        |> Keyword.put(:repo, @repo)
      end
    end
  end
end
