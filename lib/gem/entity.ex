defmodule Gem.Entity do
  @callback primary_key!(map()) :: any()
end
