defmodule Gem.Command.Helpers do
  def reply(reply),
    do: {:ok, reply, []}

  def reply({:ok, events}, reply),
    do: {:ok, reply, events}

  def reply({:ok, old_reply, _events}, _reply) do
    raise "Reply is already set to #{inspect(old_reply)}"
  end

  def insert(entity),
    do: {:ok, insert: entity}

  def insert({:ok, events}, entity),
    do: {:ok, [events, insert: entity]}

  def insert({:ok, reply, events}, entity),
    do: {:ok, reply, [events, insert: entity]}

  def update(entity),
    do: {:ok, update: entity}

  def update({:ok, events}, entity),
    do: {:ok, [events, update: entity]}

  def update({:ok, reply, events}, entity),
    do: {:ok, reply, [events, update: entity]}
end
