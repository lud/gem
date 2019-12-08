defmodule Gem.Adapter.EventDispatcher.Registry do
  @moduledoc """
  This module implements a simple pub-sub mechanism on top of the
  standard Elixir registry module.

  Each subscriber receive events as `{gem :: atom(), key :: any(), event :: any()}`
  """
  @behaviour Gem.EventDispatcher
  use TODO
  require Logger

  @todo """
  define __using__ so we copy all the dispatch code into the using
  module, but we can override the transform_event function.
  """

  @no_meta :__NO_META__

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

  def transform_event(x, _) do
    IO.puts("event transform: #{inspect(x)}")
    x
  end

  def dispatch(registry, gem, {topic, data}) do
    IO.puts("dispatching to #{inspect(topic)}")

    Registry.dispatch(registry, topic, fn entries ->
      for {pid, meta} <- entries do
        msg =
          case meta do
            @no_meta -> {gem, topic, data}
            meta -> {gem, topic, data, meta}
          end

        send(pid, msg)
      end
    end)
  end

  @todo """
    Instead of unsubscribe then subscribe we must synchronously check
    if we are subscribed already, and subscribe if not
  """
  def subscribe_new(registry, topic, meta \\ @no_meta) do
    unsubscribe(registry, topic)
    subscribe(registry, topic, meta)
  end

  def subscribe(registry, topic, meta \\ @no_meta) do
    IO.puts("subscribed to #{inspect(topic)}")

    case Registry.register(registry, topic, meta) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def unsubscribe(registry, topic) do
    Registry.unregister(registry, topic)
  end
end
