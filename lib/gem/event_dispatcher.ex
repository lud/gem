defmodule Gem.EventDispatcher do
  @moduledoc """
  This modules defines a behaviour to load and persist entities from
  a repository.
  """
  @callback transform_event(Gem.event(), context :: any()) :: Gem.event() | list(Gem.event())
  @callback dispatch(
              dispatcher :: pid() | atom() | any(),
              gem :: atom(),
              Gem.event()
            ) ::
              :ok
  @callback subscribe(dispatcher :: pid() | atom() | any(), gem :: atom(), topic :: any()) :: :ok
end
