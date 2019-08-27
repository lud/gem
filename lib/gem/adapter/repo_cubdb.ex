defmodule Gem.Adapter.Repository.CubDB do
  @moduledoc """
  This module implements a simple adapter for CubDB.

  Entities are stored with `{type :: atom(), id :: any()}` as keys.

  Persistence events are emitted as `{{event :: atom(), type :: atom()}, {k, v}}`
  """
  @behaviour Gem.Repository
  def load_entities(cub, keys) do
    {:ok, CubDB.get_multi(cub, keys, :NOT_FOUND)}
  end

  @todo "handle timeout"

  def write_changes(cub, changes) do
    events = Enum.map(changes, &change_to_event/1)
    puts = extract_puts(changes, [])
    delete_keys = extract_delete_keys(changes, [])
    # We use get_and_update_multi with no selection, so we are called
    # with an empty map, but we return data to put and keys to delete
    CubDB.get_and_update_multi(cub, [], fn %{} ->
      {events, puts, delete_keys}
    end)
  end

  defp change_to_event({:update, {{type, _} = k, v}}),
    do: {{:updated, type}, {k, v}}

  # CubDB has no concept of insert so we return an :updated event
  defp change_to_event({:insert, {{type, _} = k, v}}),
    do: {{:inserted, type}, {k, v}}

  defp change_to_event({:delete, {{type, _} = k, v}}),
    do: {{:deleted, type}, {k, v}}

  defp extract_puts([{:update, kv} | rest], acc),
    do: extract_puts(rest, [kv | acc])

  defp extract_puts([{:insert, kv} | rest], acc),
    do: extract_puts(rest, [kv | acc])

  defp extract_puts([_ | rest], acc),
    do: extract_puts(rest, acc)

  defp extract_puts([], acc),
    do: Map.new(acc)

  defp extract_delete_keys([{:delete, {k, _}} | rest], acc),
    do: extract_delete_keys(rest, [k | acc])

  defp extract_delete_keys([_ | rest], acc),
    do: extract_delete_keys(rest, acc)

  defp extract_delete_keys([], acc),
    do: acc
end
