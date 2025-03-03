defmodule EventBus.Publisher do
  @moduledoc """
  Publishes events to the event bus.
  """

  use EventBus.Event

  alias EventBus.Worker

  @doc """
  Publishes the events by enqueueing the EventBus.Worker jobs in the Oban queue.
  Takes the oban instance name and the job changesets as input.
  Returns the list of the enqueued Oban.Jobs.
  """
  @spec publish(
          oban_name :: atom,
          job_changesets :: list(Ecto.Changeset.t()),
          opts :: Keyword.t()
        ) ::
          result :: list(Oban.Job.t()) | Ecto.Multi.t()
  def publish(oban_name, job_changesets, opts \\ [])
      when is_atom(oban_name) and is_list(job_changesets) and is_list(opts) do
    insert_jobs(job_changesets, oban_name, opts)
  end

  @doc """
  Creates the job changesets used to publish the given event and its subscribers.
  """
  @spec create_job_changesets(
          subscribers :: list(atom),
          event :: EventBus.Event.t(),
          acc :: list(Ecto.Changeset.t())
        ) ::
          list(Ecto.Changeset.t())
  def create_job_changesets(subscribers, event, acc \\ [])

  def create_job_changesets([first_subscriber | other_subscribers], event, acc) do
    job = create_job_changeset(first_subscriber, event)
    create_job_changesets(other_subscribers, event, [job | acc])
  end

  def create_job_changesets([], _event, acc), do: acc

  defp create_job_changeset(subscriber, event) when is_atom(subscriber) and is_event(event) do
    Worker.new(%{
      event: event.__struct__,
      aggregate: event.aggregate,
      changes: event.changes,
      metadata: event.metadata,
      event_handler: subscriber
    })
  end

  defp insert_jobs([], _oban_name, opts) do
    case Keyword.get(opts, :multi) do
      nil ->
        []

      %Ecto.Multi{} = multi ->
        multi
    end
  end

  defp insert_jobs([_ | _] = changesets, oban_name, opts) do
    case Keyword.get(opts, :multi) do
      nil ->
        Oban.insert_all(oban_name, changesets)

      %Ecto.Multi{} = multi ->
        Oban.insert_all(
          oban_name,
          multi,
          :insert_event_bus_jobs,
          changesets
        )
    end
  end
end
