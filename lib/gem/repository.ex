defmodule Gem.Repository do
  @moduledoc """
  This modules defines a behaviour to load and persist entities from
  a repository.
  """

  @callback load_entities(repository :: any(), [Gem.entity_key()]) ::
              {:ok, list} | {:error, any}
  @callback write_changes(repository :: any(), [Gem.change_event()]) ::
              {:ok, [Gem.write_event()]} | {:error, any()}

  defmacro not_found_constant do
    quote(do: :NOT_FOUND)
  end

  @spec change_to_event(Gem.change_event()) :: Gem.write_event()
  def change_to_event({change_name, {{type, _} = k, v}})
      when change_name in [:update, :delete, :insert],
      do: {{change_event_name(change_name), type}, {k, v}}

  def change_to_event({change_name, %mod{} = s})
      when change_name in [:update, :delete, :insert],
      do: {{change_event_name(change_name), mod}, s}

  defp change_event_name(:update), do: :updated
  defp change_event_name(:delete), do: :deleted
  defp change_event_name(:insert), do: :inserted
end
