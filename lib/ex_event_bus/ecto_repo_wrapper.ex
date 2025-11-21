defmodule ExEventBus.EctoRepoWrapper do
  @moduledoc """
  Wraps the Ecto Repo functions to add event support with the same interface
  """

  # Primary key helpers

  defp extract_primary_key_from_struct(struct) when is_struct(struct) do
    schema = struct.__struct__

    case schema.__schema__(:primary_key) do
      [pk_field] ->
        # Single primary key (common case)
        {pk_field, Map.get(struct, pk_field)}

      [] ->
        # No primary key
        nil

      pk_fields when is_list(pk_fields) ->
        # Composite primary key - return as map
        for pk_field <- pk_fields, into: %{} do
          {pk_field, Map.get(struct, pk_field)}
        end
    end
  end

  defp get_primary_key_value(%Ecto.Changeset{} = changeset) do
    extract_primary_key_from_struct(changeset.data)
  end

  defp add_primary_key(map, struct) when is_struct(struct) do
    case extract_primary_key_from_struct(struct) do
      nil ->
        map

      {pk_field, pk_value} ->
        Map.put(map, pk_field, pk_value)

      pk_map when is_map(pk_map) ->
        Map.merge(map, pk_map)
    end
  end

  defp index_by_primary_key(list) when is_list(list) do
    Enum.reduce(list, %{}, fn struct, acc ->
      case extract_primary_key_from_struct(struct) do
        nil ->
          acc

        {_pk_field, pk_value} ->
          Map.put(acc, pk_value, struct)

        pk_map when is_map(pk_map) ->
          # Composite keys - use tuple of values as key
          pk_tuple = pk_map |> Map.values() |> List.to_tuple()
          Map.put(acc, pk_tuple, struct)
      end
    end)
  end

  defp extract_changed_fields(initial_struct, %Ecto.Changeset{} = changeset) do
    changed_fields = Map.keys(changeset.changes)

    result =
      for field <- changed_fields, into: %{} do
        {field, Map.get(initial_struct, field)}
      end

    add_primary_key(result, initial_struct)
  end

  # Public API

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

  def get_changes(%Ecto.Changeset{} = changeset) do
    # For root changeset: process nested associations but don't add own PK
    Enum.reduce(changeset.changes, %{}, fn {key, value}, acc ->
      Map.put(acc, key, get_nested_changes(value))
    end)
  end

  def get_changes(value), do: value

  defp get_nested_changes(%Ecto.Changeset{} = changeset) do
    # For nested associations: process changes AND add PK
    base_changes =
      Enum.reduce(changeset.changes, %{}, fn {key, value}, acc ->
        Map.put(acc, key, get_nested_changes(value))
      end)

    # Add primary key to nested association changes
    case get_primary_key_value(changeset) do
      nil ->
        base_changes

      {pk_field, pk_value} ->
        Map.put(base_changes, pk_field, pk_value)

      pk_map when is_map(pk_map) ->
        Map.merge(base_changes, pk_map)
    end
  end

  defp get_nested_changes(list) when is_list(list) do
    Enum.map(list, &get_nested_changes/1)
  end

  defp get_nested_changes(value), do: value

  def get_initial_data(%Ecto.Changeset{data: data, changes: changes}) do
    for {key, new_value} <- changes, into: %{} do
      initial_value = Map.get(data, key)
      {key, get_initial_value(initial_value, new_value)}
    end
  end

  defp get_initial_value(%Ecto.Association.NotLoaded{__cardinality__: :one}, _new_value),
    do: nil

  defp get_initial_value(%Ecto.Association.NotLoaded{__cardinality__: :many}, _new_value),
    do: []

  defp get_initial_value(initial_struct, %Ecto.Changeset{} = new_changeset)
       when is_struct(initial_struct) do
    # For has_one associations: extract only changed fields + PK
    extract_changed_fields(initial_struct, new_changeset)
  end

  defp get_initial_value(initial_list, new_list)
       when is_list(initial_list) and is_list(new_list) do
    # For has_many associations: match items by PK, extract only changed fields
    initial_by_id = index_by_primary_key(initial_list)

    new_list
    |> Enum.reduce([], fn new_changeset, acc ->
      add_initial_data_for_updated_item(new_changeset, initial_by_id, acc)
    end)
    |> Enum.reverse()
  end

  defp get_initial_value(value, _new_value), do: value

  defp add_initial_data_for_updated_item(new_changeset, initial_by_id, acc) do
    case get_primary_key_value(new_changeset) do
      {_pk_field, nil} ->
        # New item, skip (not in initial_data)
        acc

      {_pk_field, pk_value} ->
        add_initial_data_if_found(initial_by_id, pk_value, new_changeset, acc)

      pk_map when is_map(pk_map) ->
        # Composite PK
        pk_tuple = pk_map |> Map.values() |> List.to_tuple()
        add_initial_data_if_found(initial_by_id, pk_tuple, new_changeset, acc)

      nil ->
        # No primary key
        acc
    end
  end

  defp add_initial_data_if_found(initial_by_id, pk_value, new_changeset, acc) do
    case Map.get(initial_by_id, pk_value) do
      nil -> acc
      initial_struct -> [extract_changed_fields(initial_struct, new_changeset) | acc]
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
