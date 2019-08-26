defmodule Gem.Adapter.EventDispatcher.Registry do
  @behaviour Gem.EventDispatcher

  @todo """
  define __using__ so we copy all the dispatch code into the using
  module, but we can override the transform_event function.
  """

  def start_link(name) do
    Registry.start_link(
      keys: :duplicate,
      name: name,
      partitions: System.schedulers_online()
    )
  end

  def transform_event(x, _),
    do: x

  def dispatch({key, event}, gem, name) do
    IO.puts("dispatching to #{inspect(key)}")

    Registry.dispatch(name, key, fn entries ->
      for {pid, private} <- entries do
        send(pid, {key, event, private})
      end
    end)
  end

  def subscribe(name, gem, key, private \\ []) do
    IO.puts("subscribed to #{inspect(key)}")
    Registry.register(name, key, private)
  end
end
