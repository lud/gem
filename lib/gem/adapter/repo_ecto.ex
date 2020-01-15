defmodule Gem.Adapter.Repository.Ecto do
  @moduledoc """
  This module implements a simple adapter for Ecto.

  Entities are stored with their primary key.

  Persistence events are emitted as `{{event :: atom(), schema :: atom()}, {id, v}}`
  """
  use TODO
  @behaviour Gem.Repository
  import Gem.Repository
  alias Ecto.Multi
  alias Ecto.Changeset

  @impl true
  @spec load_entities(repository :: any(), [Gem.Repository.entity_key()]) ::
          {:ok, %{optional(Gem.Repository.entity_key()) => any}} | {:error, any}
  def load_entities(repo, keys) do
    Enum.reduce(keys, {:ok, []}, fn
      # Lift errors @optimize with throw ?
      _, {:error, _} = error ->
        error

      {schema, id}, {:ok, acc} ->
        case repo.get(schema, id) do
          # @optimize with Map.put_new ?
          %^schema{} = entity -> {:ok, [entity | acc]}
          nil -> {:ok, [Gem.Repository.not_found_constant() | acc]}
          {:error, _} = error -> error
        end
    end)
    |> case do
      {:ok, list} -> {:ok, :lists.reverse(list)}
      err -> err
    end
  end

  @impl true
  @spec write_changes(repository :: any(), [Gem.change_event()]) ::
          {:ok, [Gem.write_event()]} | {:error, any()}
  def write_changes(repo, changes) do
    with {:ok, changes} <- check_all_multiable(changes),
         {:ok, multi} <- run_multi_changes(repo, changes) do
      events =
        Enum.map(multi, fn {{__MODULE__, type, _}, entity} -> change_to_event({type, entity}) end)

      {:ok, events}
    end
  end

  defp run_multi_changes(repo, changes) do
    changes
    |> Enum.with_index()
    |> Enum.reduce(Multi.new(), fn
      {{:update, changeset}, index}, multi ->
        Multi.update(multi, {__MODULE__, :update, index}, changeset, returning: true)

      {{:insert, data}, index}, multi ->
        Multi.insert(multi, {__MODULE__, :insert, index}, data, returning: true)

      {{:delete, data}, index}, multi ->
        Multi.delete(multi, {__MODULE__, :delete, index}, data, returning: true)
    end)
    |> repo.transaction()
  end

  # defp get_pk(%Changeset{data: %{__meta__: %{schema: schema}}} = change) do
  #   __schema__ :primary_key
  # end

  defp check_all_multiable(changes) do
    changes
    |> Enum.filter(fn
      {_, %Changeset{}} -> false
      {:insert, %_mod{}} -> false
      {:delete, %_mod{}} -> false
      _ -> true
    end)
    |> case do
      [] -> {:ok, changes}
      not_multiable -> {:error, {:bad_changes, not_multiable}}
    end
  end
end
