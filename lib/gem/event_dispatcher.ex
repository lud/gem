defmodule Gem.EventDispatcher do
  @type event ::
          {event_name :: atom, data :: any}
          | {:external, module :: atom, fun :: atom, args :: list}
  @callback transform_event(any) :: event | list(event)
end
