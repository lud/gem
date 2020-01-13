defmodule Gem.Adapter.Repository.CubDB do
  @moduledoc """
  This module implements a simple adapter for CubDB.

  Entities are stored with `{type :: atom(), id :: any()}` as keys.

  Persistence events are emitted as `{{event :: atom(), type :: atom()}, {k, v}}`
  """
  use TODO
  @behaviour Gem.Repository
  import Gem.Repository

  @impl true
  @spec load_entities(repository :: atom | pid | {atom, any} | {:via, atom, any}, [
          Gem.Repository.entity_key()
        ]) :: {:ok, %{optional(Gem.Repository.entity_key()) => any}} | {:error, any}
  def load_entities(cub, keys) do
    {:ok, CubDB.get_multi(cub, keys, :NOT_FOUND)}
  end

  @todo "handle timeout"

  def write_changes(cub, changes) do
    # IO.inspect(changes, label: "changes")
    events = Enum.map(changes, &change_to_event/1)
    puts = extract_puts(changes, [])
    delete_keys = extract_delete_keys(changes, [])
    # We use get_and_update_multi with no selection, so we are called
    # with an empty map, but we return data to put and keys to delete
    CubDB.get_and_update_multi(cub, [], fn %{} ->
      {events, puts, delete_keys}
    end)
  end

  defp extract_puts([{:update, entity} | rest], acc),
    do: extract_puts(rest, [entity_to_kv(entity) | acc])

  defp extract_puts([{:insert, entity} | rest], acc),
    do: extract_puts(rest, [entity_to_kv(entity) | acc])

  defp extract_puts([_ | rest], acc),
    do: extract_puts(rest, acc)

  defp extract_puts([], acc),
    do: Map.new(acc)

  defp extract_delete_keys([{:delete, entity} | rest], acc) do
    {key, _} = entity_to_kv(entity)
    extract_delete_keys(rest, [key | acc])
  end

  defp extract_delete_keys([_ | rest], acc),
    do: extract_delete_keys(rest, acc)

  defp extract_delete_keys([], acc),
    do: acc

  # If the entity to persist is already a {key, value} with a {type,
  # id} key, we have nothing to do
  defp entity_to_kv({{_type, _} = _key, _entity} = kv),
    do: kv

  # If we have a struct, we form the {module, primary_key} tuple as
  # the key in {key, entity}
  defp entity_to_kv(%mod{} = entity) do
    case mod.primary_key!(entity) do
      nil ->
        raise "A primary key cannot be nil"

      pk ->
        key = {mod, pk}
        {key, entity}
    end
  end
end
