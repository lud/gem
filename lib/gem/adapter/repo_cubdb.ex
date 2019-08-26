defmodule Gem.Adapter.Repository.CubDB do
  def load_entities(keys, cub) do
    case CubDB.get_multi(cub, keys, :NOT_FOUND) do
      list when is_list(list) -> {:ok, list}
      other -> {:error, {:no_reason, other}}
    end
  end

  @todo "handle timeout"

  def write_changes(changes, cub) do
    events = Enum.map(changes, &change_to_event/1)
    puts = extract_puts(changes, [])
    delete_keys = extract_delete_keys(changes, [])
    # We use get_and_update_multi with no selection, so we are called
    # with an empty map, but we return data to put and keys to delete
    CubDB.get_and_update_multi(cub, [], fn %{} ->
      {{:ok, events}, puts, delete_keys}
    end)
  end

  defp change_to_event({:update, {k, v}}),
    do: {:updated, {k, v}}

  # CubDB has no concept of insert so we return an :updated event
  defp change_to_event({:insert, {k, v}}),
    do: {:inserted, {k, v}}

  defp change_to_event({:delete, {k, v}}),
    do: {:deleted, {k, v}}

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
