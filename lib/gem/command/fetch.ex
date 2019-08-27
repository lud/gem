defmodule Gem.Command.Fetch do
  @moduledoc """
  This command allows to fetch entities within the commands queue,
  whereas Gem.fetch_entity will direclty return the entities from
  the repository.

  If concurrent processes are sending commands to the same gem, it is
  possible that pending commands will update the entities after the
  fetch command returns. Therefore this command does not offer much
  compared to Gem.fetch_entity.

  The main interest is to fetch entities after sending one or many
  other commands so we have the guarantee that those other commands
  ran before we fetch the current entity state.

  Also this command act as helper function for Gem.fetch_entity.
  """
  @behaviour Gem.Command

  defstruct entity_spec: nil

  def new(entity_spec),
    do: %__MODULE__{entity_spec: entity_spec}

  def key_spec(%__MODULE__{entity_spec: entity_spec}),
    do: entity_spec

  def check(_, _), do: :ok

  def run(%__MODULE__{}, entities) do
    {:ok, entities, []}
  end
end
