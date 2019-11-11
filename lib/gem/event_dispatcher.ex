defmodule Gem.EventDispatcher do
  @moduledoc """
  This modules defines a behaviour to load and persist entities from
  a repository.
  """
  @type event ::
          {event_name :: atom, data :: any}
          | {:external, module :: atom, fun :: atom, args :: list}
  @type events :: list(__MODULE__.event())
  @callback transform_event({any(), any()}, context :: any()) :: event | list(event)
  @callback dispatch(
              dispatcher :: pid() | atom() | any(),
              gem :: atom(),
              {topic :: any(), data :: any()}
            ) ::
              :ok
  @callback subscribe(dispatcher :: pid() | atom() | any(), gem :: atom(), topic :: any()) :: :ok
end
