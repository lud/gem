defmodule Gem.Repository do
  @moduledoc """
  This modules defines a behaviour to load and persist entities from
  a repository.
  """
  @callback load_entities(repository :: any(), [{t :: atom, id :: any}]) ::
              {:ok, any} | {:error, any}
  @callback write_changes(repository :: any(), Keyword.t()) ::
              {:ok, Gem.EventDispatcher.events()} | {:error, any()}
end
