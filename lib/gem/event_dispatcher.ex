defmodule Gem.EventDispatcher do
  @type event ::
          {event_name :: atom, data :: any}
          | {:external, module :: atom, fun :: atom, args :: list}
  @callback transform_event({any(), any()}, context :: any()) :: event | list(event)
  @callback dispatch({topic :: any(), data :: any()}) :: :ok
end
