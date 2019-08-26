defmodule Gem.Command.Fetch do
  @behaviour Gem.Command

  defstruct entity_spec: nil

  def new(entity_spec),
    do: %__MODULE__{entity_spec: entity_spec}

  def key_spec(%__MODULE__{entity_spec: entity_spec}),
    do: entity_spec

  def check(_, _), do: :ok

  def run(%__MODULE__{}, entities) do
    {:reply, {:ok, entities}}
  end
end
