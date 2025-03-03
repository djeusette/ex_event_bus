defmodule ExEventBus.Worker do
  @moduledoc """
  This Oban worker handles the ExEventBus events
  """

  use Oban.Worker,
    queue: :ex_event_bus,
    tags: ["ex_event_bus"]

  use ExEventBus.Event

  @impl Oban.Worker
  def perform(%Oban.Job{} = job) do
    with {:ok, event} when is_event(event) <- build_event(job) do
      get_event_handler(job).handle_event(event)
    end
  end

  defp build_event(%Oban.Job{
         attempt: attempt,
         max_attempts: max_attempts,
         inserted_at: inserted_at,
         args: %{
           "event" => event_mod,
           "aggregate" => aggregate,
           "changes" => changes,
           "metadata" => metadata,
           "event_handler" => _event_handler_mod
         }
       }) do
    event =
      event_mod
      |> String.to_existing_atom()
      |> struct(%{
        aggregate: aggregate,
        changes: changes,
        metadata:
          Map.merge(metadata || %{}, %{
            "attempt" => attempt,
            "max_attempts" => max_attempts,
            "inserted_at" => inserted_at
          })
      })

    {:ok, event}
  end

  defp build_event(_args), do: {:error, :invalid_args}

  defp get_event_handler(%Oban.Job{args: %{"event_handler" => event_handler_mod}}),
    do: String.to_existing_atom(event_handler_mod)
end
