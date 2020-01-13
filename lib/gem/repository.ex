defmodule Gem.Repository do
  @moduledoc """
  This modules defines a behaviour to load and persist entities from
  a repository.
  """
  @type entity_key :: {t :: atom, id :: any}

  @callback load_entities(repository :: any(), [entity_key]) ::
              {:ok, %{optional(entity_key) => any}} | {:error, any}
  @callback write_changes(repository :: any(), Keyword.t()) ::
              {:ok, Gem.EventDispatcher.events()} | {:error, any()}

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
