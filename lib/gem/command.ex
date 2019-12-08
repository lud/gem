defmodule Gem.Command do
  @moduledoc """
  This module describes the behaviour for a Gem command.
  """
  require Logger
  use TODO

  # key_spec must return a data structure for {entity_module, id}
  # tuples. It can be a single tuple, a list of tuples, a map of
  # %{any=>tuple}, or other combinations of lists/maps

  @callback key_spec(command :: struct) :: {atom, any} | %{} | list
  @callback check(command :: struct, entities :: {atom, any} | %{} | list) ::
              :ok | {:error, any}
  @callback run(command :: struct, entities :: {atom, any} | %{} | list) ::
              :ok
              | {:ok, changes_and_events :: list()}
              | {:ok, reply :: any(), changes_and_events :: list(tuple())}
              | {:error, any()}

  @todo """
    A lock_spec @callback, with a default to call key_spec(), to be
    able to lock keys without loading them from the database.

    This requires
      quote do
        def lock_spec(command) do
          key_spec(command)
        end
        defoverridable lock_spec: 1
      end

    But then key_spec must exist for this code to compile so it
    also requires a defaut key_spec:

    quote do
      def key_spec(_) do
        raise "The key_spec/1 function must be defined ..."
      end
    end
  """

  @todo """
    Provide helpers
    automatically import Command, only: [reply, add_event, update, insert, delete] and then
    def run(_,_) do
      reply(my_reply)
      |> add_event(:update, entity)
      |> update(entity)
      |> update_all(entities)
      |> reply(other_reply_i_changed_my_mind)
    end

    Events should be a nested list and we'd use flat_map to call transform events
    so `|> add_event(evt)` could simply append to the list :
      new_events = [events, evt]
    But flat_map flattens the result, not the input !

  """

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__.Helpers),
        only: [reply: 1, reply: 2, insert: 1, insert: 2, update: 1, update: 2]

      def check(_, _) do
        :ok
      end

      defoverridable check: 2
    end
  end

  @todo "validate that all keys are 2-tupes {atom, any}"

  @spec list_keys(map()) :: [{atom, any}]
  def list_keys(command) do
    %mod{} = command
    spec = mod.key_spec(command)
    flatten_keys_spec(spec, [])
  end

  defp flatten_keys_spec(nil, acc),
    do: acc

  defp flatten_keys_spec({type, id}, acc),
    do: [{type, id} | acc]

  def fullfill_spec(command, entities_map) do
    %mod{} = command
    spec = mod.key_spec(command)
    do_fullfill_spec(spec, entities_map)
  end

  defp do_fullfill_spec(nil, _entities_map),
    do: nil

  defp do_fullfill_spec({_type, _id} = key, entities_map),
    do: Map.fetch!(entities_map, key)

  def run(%mod{} = command, entities_map) do
    Logger.debug("Running command #{mod}")
    fulfilled = fullfill_spec(command, entities_map)

    case mod.check(command, fulfilled) do
      :ok ->
        command
        |> mod.run(fulfilled)
        |> normalize_run_result

      {:error, _} = err ->
        err
    end
  end

  @todo "Provide a helper to check that all entities were found"

  # If the command returns :ok, the exectution is fine (first :ok) and
  # the reply will be :ok (second one), no changes nor events.
  defp normalize_run_result(:ok),
    do: {:ok, {:ok, []}}

  # If the command returns an :ok-tuple, the reply will :ok and the
  # data is the changes and events
  defp normalize_run_result({:ok, changes_and_events}) when is_list(changes_and_events),
    do: {:ok, {:ok, changes_and_events}}

  # If the command returns an explicit reply, we let it as-is. It is
  # ok to return {:ok, reply, []} for no changes
  defp normalize_run_result({:ok, reply, changes_and_events}) when is_list(changes_and_events),
    do: {:ok, {reply, changes_and_events}}

  defp normalize_run_result({:error, _} = err),
    do: err

  defp normalize_run_result(resp),
    do: raise("Bad return from command run: #{inspect(resp)}")
end
