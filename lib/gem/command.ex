defmodule Gem.Command do
  # key_spec must return a data structure for {entity_module, id}
  # tuples. It can be a single tuple, a list of tuples, a map of any
  # => tuple, or other combinations of lists/maps

  @callback key_spec(command :: map) :: {Atom.t(), any} | %{} | list
  @callback check(command :: map, entities :: {Atom.t(), any} | %{} | list) :: :ok | {:error, any}
  @callback run(command :: map, entities :: {Atom.t(), any} | %{} | list) ::
              :ok
              | {:ok, changes_and_events :: List.t()}
              | {:ok, reply :: any(), changes_and_events :: List.t()}
              | {:error, any()}

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      def check(_, _) do
        :ok
      end

      defoverridable check: 2
    end
  end

  @todo "validate that all keys are 2-tupes {atom, any}"

  def list_keys(command) do
    %mod{} = command
    spec = mod.key_spec(command)
    flatten_keys_spec(spec, [])
  end

  defp flatten_keys_spec({type, id}, acc),
    do: [{type, id} | acc]

  def fullfill_spec(command, entities_map) do
    %mod{} = command
    spec = mod.key_spec(command)
    do_fullfill_spec(spec, entities_map)
  end

  defp do_fullfill_spec({type, id} = key, entities_map) do
    Map.fetch!(entities_map, key)
  end

  def run(command, entities_map) do
    fulfilled = fullfill_spec(command, entities_map)

    %mod{} = command

    case mod.check(command, fulfilled) do
      :ok ->
        command
        |> mod.run(fulfilled)
        |> normalize_run_result

      {:error, _} = err ->
        err
    end
  end

  # If the command returns :ok, the exectution is fine (first :ok) and
  # the reply will be :ok (second one), no changes nor events.
  defp normalize_run_result(:ok),
    do: {:ok, {:ok, []}}

  # If the command returns an :ok-tuple, the reply will :ok and the
  # data is the changes and events
  defp normalize_run_result({:ok, changes_and_events}),
    do: {:ok, {:ok, changes_and_events}}

  # If the command returns an explicit reply, we let it as-is. It is
  # ok to return {:ok, reply, []} for no changes
  defp normalize_run_result({:ok, reply, changes_and_events}),
    do: {:ok, {reply, changes_and_events}}

  defp normalize_run_result({:error, _} = err),
    do: err
end
