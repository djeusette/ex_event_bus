defmodule ExEventBus.EctoRepoWrapper do
  @moduledoc """
  Wraps the Ecto Repo functions to add event support with the same interface
  """

  def add_changes_to_event_opts(opts, %{} = changes) do
    updated_event_opts =
      opts
      |> Keyword.get(:event_opts, [])
      |> Keyword.put(:changes, changes)

    Keyword.put(opts, :event_opts, updated_event_opts)
  end

  def add_initial_data_to_event_opts(opts, %{} = initial_data) do
    updated_event_opts =
      opts
      |> Keyword.get(:event_opts, [])
      |> Keyword.put(:initial_data, initial_data)

    Keyword.put(opts, :event_opts, updated_event_opts)
  end

  def get_changes(%Ecto.Changeset{changes: changes}) when is_map(changes) do
    Enum.reduce(changes, %{}, fn {key, value}, acc ->
      Map.put(acc, key, get_changes(value))
    end)
  end

  def get_changes(list) when is_list(list) do
    Enum.reduce(list, [], fn value, acc ->
      [get_changes(value) | acc]
    end)
    |> Enum.reverse()
  end

  def get_changes(value), do: value

  def get_initial_data(%Ecto.Changeset{data: data, changes: changes}) do
    for {key, _new_value} <- changes, into: %{} do
      {key, Map.get(data, key)}
    end
  end

  def should_publish_event?(
        record,
        operation,
        opts
      )
      when operation in [:insert, :insert!] do
    no_event_on_upsert_update = Keyword.get(opts, :no_event_on_upsert_update, false)

    with true <- no_event_on_upsert_update,
         %{inserted_at: inserted_at, updated_at: updated_at} when inserted_at != updated_at <-
           record do
      false
    else
      _ ->
        true
    end
  end

  def should_publish_event?(
        _record,
        operation,
        opts
      )
      when operation in [:update, :update!] do
    case Keyword.get(opts, :changes) do
      %{} = changes when map_size(changes) == 0 ->
        false

      _ ->
        true
    end
  end

  def should_publish_event?(_record, _operation, _opts),
    do: true

  defmacro redeffn(fun) when is_atom(fun) do
    quote do
      def unquote(fun)(%Ecto.Changeset{} = changeset, opts) do
        wrapped_fun = fn -> super(changeset, opts) end

        wrap_repo_function(
          wrapped_fun,
          opts
          |> add_changes_to_event_opts(get_changes(changeset))
          |> add_initial_data_to_event_opts(get_initial_data(changeset)),
          unquote(fun)
        )
      end

      def unquote(fun)(query, opts) do
        wrapped_fun = fn -> super(query, opts) end

        wrap_repo_function(
          wrapped_fun,
          opts
          |> add_changes_to_event_opts(%{})
          |> add_initial_data_to_event_opts(%{}),
          unquote(fun)
        )
      end
    end
  end

  defmacro __using__(opts) do
    if not Keyword.has_key?(opts, :ex_event_bus) do
      raise ArgumentError, "EctoRepoWrapper requires a :ex_event_bus option to be set"
    end

    quote bind_quoted: [opts: opts], location: :keep do
      import ExEventBus.EctoRepoWrapper

      @event_bus Keyword.fetch!(opts, :ex_event_bus)

      if Code.ensure_loaded?(Ecto.Repo) do
        alias Ecto.Multi

        defoverridable delete: 2,
                       delete!: 2,
                       insert: 2,
                       insert!: 2,
                       update: 2,
                       update!: 2,
                       insert_or_update: 2,
                       insert_or_update!: 2

        redeffn(:delete)
        redeffn(:delete!)
        redeffn(:insert)
        redeffn(:insert!)
        redeffn(:update)
        redeffn(:update!)
        redeffn(:insert_or_update)
        redeffn(:insert_or_update!)

        defp wrap_repo_function(repo_func, opts, operation) when is_function(repo_func, 0) do
          success_event = Keyword.get(opts, :success_event)
          event_opts = Keyword.get(opts, :event_opts, [])

          execute_repo_function(repo_func, operation, success_event, event_opts)
        end

        defp execute_repo_function(repo_func, _operation, nil, _opts), do: repo_func.()

        defp execute_repo_function(repo_func, operation, event, opts) do
          Multi.new()
          |> Multi.run(:repo_operation, fn _repo, _state ->
            repo_func.()
          end)
          |> Multi.merge(fn %{repo_operation: result} ->
            maybe_publish_events_in_multi(result, operation, event, opts)
          end)
          |> transaction()
          |> case do
            {:ok, %{repo_operation: result}} -> {:ok, result}
            {:error, _, changeset, _} -> {:error, changeset}
          end
        end

        defp maybe_publish_events_in_multi(result, operation, event, opts) do
          if should_publish_event?(result, operation, opts) do
            changes = Keyword.get(opts, :changes)
            initial_data = Keyword.get(opts, :initial_data)
            metadata = Keyword.get(opts, :event_metadata)
            events = ExEventBus.Event.build_events(event, result, changes, initial_data, metadata)

            @event_bus.publish(Multi.new(), events)
          else
            Multi.new()
          end
        end
      end
    end
  end
end
