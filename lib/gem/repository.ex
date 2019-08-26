defmodule Gem.Repository do
  @callback load_entities([{t :: atom, id :: any}], context :: any()) ::
              {:ok, any} | {:error, any}
  @callback write_changes(Keyword.t(), context :: any()) :: {:ok, any()} | {:error, any()}
end
