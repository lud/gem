defmodule Gem.Command.Fun do
  @moduledoc """
  Utility to define a command with a fun.
  """
  @behaviour Gem.Command

  defstruct entity_spec: nil, fun: nil

  def new(entity_spec, fun) when is_function(fun, 1),
    do: %__MODULE__{entity_spec: entity_spec, fun: fun}

  @impl Gem.Command

  def key_spec(%__MODULE__{entity_spec: entity_spec}),
    do: entity_spec

  @impl Gem.Command
  def check(_, _), do: :ok
  @impl Gem.Command

  def run(%__MODULE__{fun: fun}, entities) do
    fun.(entities)
  end
end
