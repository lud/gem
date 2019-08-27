defmodule Gem.Adapter.EventDispatcher.Registry do
  @moduledoc """
  This module implements a simple pub-sub mechanism on top of the
  standard Elixir registry module.

  Each subscriber receive events as `{gem :: atom(), key :: any(), event :: any()}`
  """
  @behaviour Gem.EventDispatcher

  require Logger

  @todo """
  define __using__ so we copy all the dispatch code into the using
  module, but we can override the transform_event function.
  """

  def child_spec(name) do
    name
    |> start_opts()
    |> Registry.child_spec()
  end

  def start_link(name) do
    name
    |> start_opts()
    |> Registry.start_link()
  end

  defp start_opts(name) do
    [
      keys: :duplicate,
      name: name,
      partitions: System.schedulers_online()
    ]
  end

  def transform_event(x, _),
    do: x

  def dispatch(registry, gem, {topic, data}) do
    IO.puts("dispatching to #{inspect(topic)}")

    Registry.dispatch(registry, topic, fn entries ->
      for {pid, ^gem} <- entries do
        send(pid, {gem, topic, data})
      end
    end)
  end

  def subscribe(registry, topic, gem) when is_atom(gem) do
    IO.puts("subscribed to #{inspect(topic)}")

    case Registry.register(registry, topic, gem) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
