defmodule EventBus.Event do
  @moduledoc """
  Defines macros to define events
  """

  @type t :: %{
          required(:__struct__) => module,
          required(:__event_bus_event__) => true,
          required(:aggregate) => map | nil,
          required(:changes) => map | nil,
          required(:metadata) => map | nil
        }

  defmacro defevent(name) do
    quote bind_quoted: [name: name] do
      defmodule Module.concat(__MODULE__, name) do
        @moduledoc false
        @derive JSON.Encoder
        defstruct [:aggregate, :changes, :metadata, __event_bus_event__: true]
      end
    end
  end

  defmacro defevents(names) when is_list(names) do
    quote do
      for name <- unquote(names) do
        defevent(name)
      end
    end
  end

  @doc """
  Returns true if `term` is an EventBus.Event; otherwise returns `false`.
  Allowed in guard tests.
  ## Examples
      iex> is_event(%MyEvent{})
      true
      iex> is_event(%{})
      false
  """
  defmacro is_event(term) do
    case __CALLER__.context do
      nil ->
        event_without_context?(term)

      :match ->
        invalid_match!(:is_event)

      :guard ->
        event_guard?(term)
    end
  end

  @doc """
  Returns true if `term` is an EventBus.Event of `name`; otherwise returns `false`.
  Allowed in guard tests.
  ## Examples
      iex> is_event(%MyEvent{}, MyEvent)
      true
      iex> is_event(%MyEvent{}, Macro.Env)
      false
  """
  defmacro is_event(term, name) do
    case __CALLER__.context do
      nil ->
        event_without_context?(term, name)

      :match ->
        invalid_match!(:is_event)

      :guard ->
        event_guard?(term, name)
    end
  end

  defp event_without_context?(term) do
    quote do
      case unquote(term) do
        %_{__event_bus_event__: true} -> true
        _ -> false
      end
    end
  end

  defp event_without_context?(term, name) do
    quote do
      case unquote(name) do
        name when is_atom(name) ->
          case unquote(term) do
            %{__struct__: ^name, __event_bus_event__: true} -> true
            _ -> false
          end

        _ ->
          raise ArgumentError
      end
    end
  end

  defp event_guard?(term) do
    quote do
      is_map(unquote(term)) and :erlang.is_map_key(:__struct__, unquote(term)) and
        is_atom(:erlang.map_get(:__struct__, unquote(term))) and
        :erlang.is_map_key(:__event_bus_event__, unquote(term)) and
        :erlang.map_get(:__event_bus_event__, unquote(term)) == true
    end
  end

  defp event_guard?(term, name) do
    quote do
      is_map(unquote(term)) and
        (is_atom(unquote(name)) or :fail) and
        :erlang.is_map_key(:__struct__, unquote(term)) and
        :erlang.map_get(:__struct__, unquote(term)) == unquote(name) and
        :erlang.is_map_key(:__event_bus_event__, unquote(term)) and
        :erlang.map_get(:__event_bus_event__, unquote(term)) == true
    end
  end

  defp invalid_match!(exp) do
    raise ArgumentError,
          "invalid expression in match, #{exp} is not allowed in patterns " <>
            "such as function clauses, case clauses or on the left side of the = operator"
  end

  def build_event(event, data, changes, metadata) when is_struct(data) and is_atom(event) do
    with true <- Code.ensure_loaded?(event),
         true <- function_exported?(event, :__struct__, 0),
         %_{} = event_struct <-
           struct(event, %{aggregate: data, changes: changes, metadata: metadata}),
         true <- is_event(event_struct) do
      event_struct
    else
      _ ->
        raise ArgumentError, "#{inspect(event)} is not a module defining an EventBus.Event"
    end
  end

  def build_events(event, record, changes, metadata, acc \\ [])

  def build_events(event, record, changes, metadata, acc) when is_atom(event) do
    [build_event(event, record, changes, metadata) | acc]
  end

  def build_events([first_event | other_events], record, changes, metadata, acc)
      when is_atom(first_event),
      do:
        build_events(other_events, record, changes, metadata, [
          build_event(first_event, record, changes, metadata) | acc
        ])

  def build_events([], _record, _changes, _metadata, acc), do: Enum.reverse(acc)

  defmacro __using__(_) do
    quote location: :keep do
      import EventBus.Event
    end
  end
end
