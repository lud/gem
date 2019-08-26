defmodule Gem do
  alias Gem.Command
  require Logger

  def start_link(opts) when is_list(opts) do
    opts =
      opts
      |> validate_opt(:name)
      |> validate_opt(:repository)
      |> validate_opt(:dispatcher)
      |> Keyword.put_new(:dispatcher, nil)

    mutex_meta =
      opts
      |> Keyword.take([:name, :repository, :dispatcher])
      |> Map.new()

    mutex_opts =
      opts
      |> Keyword.take([:name, :cleanup_interval])
      |> Keyword.put(:meta, mutex_meta)

    # We can explicitely ask for no registration
    mutex_opts =
      if false === Keyword.get(opts, :register) do
        IO.warn("not registering #{mutex_opts[:name]}")
        Keyword.drop(mutex_opts, [:name])
      else
        mutex_opts
      end

    Mutex.start_link(mutex_opts)
  end

  defp validate_opt(opts, :name) do
    case Keyword.fetch(opts, :name) do
      {:ok, name} when is_atom(name) ->
        opts

      {:ok, name} ->
        raise("Invalid name: #{inspect(name)}")

      :error ->
        raise """
        Option :name is required. 
          Pass register: false to disable name registration.
        """
    end
  end

  defp validate_opt(opts, :repository) do
    case Keyword.fetch(opts, :repository) do
      {:ok, {module, _context}} when is_atom(module) ->
        if Code.ensure_compiled?(module) do
          opts
        else
          raise """
          Option :repository is not valid, module #{module} cannot be found.
          """
        end

      {:ok, v} ->
        raise("Invalid repository: #{inspect(v)}")

      :error ->
        raise "Option :repository is required"
    end
  end

  defp validate_opt(opts, :dispatcher) do
    case Keyword.fetch(opts, :dispatcher) do
      {:ok, {module, _context}} when is_atom(module) ->
        if Code.ensure_compiled?(module) do
          opts
        else
          raise """
          Option :dispatcher is not valid, module #{module} cannot be found.
          """
        end

      {:ok, v} ->
        raise("Invalid dispatcher: #{inspect(v)}")

      # Dispatcher is not required
      _otherwise ->
        opts
    end
  end

  # We use the fetch command only to get the keys and return the
  # entities. The mutex is not used so the entity(ies) can be outdated
  def fetch_entity(gem, key_spec) do
    dummy = Gem.Command.Fetch.new(key_spec)
    entity_keys = Command.list_keys(dummy)
    %{repository: repo} = Mutex.get_meta(gem)

    with {:ok, entities_map} <- load_entities(entity_keys, repo) do
      {:ok, Command.fullfill_spec(dummy, entities_map)}
    end
  end

  @alias :fetch_entity
  def fetch_entities(gem, key_spec),
    do: fetch_entity(gem, key_spec)

  def run(gem, command, lock_timeout \\ 5000) do
    entity_keys = Command.list_keys(command)

    under_fun = fn lock ->
      do_run(lock.meta, entity_keys, command)
    end

    run_result =
      case entity_keys do
        # If no entity is to be locked, we still need to fetch the
        # metadata from the mutex.
        [] ->
          meta = Mutex.get_meta(gem)
          do_run(meta, [], command)

        [key | []] ->
          Mutex.under(gem, key, lock_timeout, under_fun)

        keys ->
          Mutex.under_all(gem, keys, under_fun)
      end

    run_result
  end

  @todo "Add option to require all entities found"

  defp do_run(%{name: gem, repository: repo, dispatcher: disp}, entity_keys, command) do
    with {:ok, entities_map} <- load_entities(entity_keys, repo),
         {:ok, {reply, changes_and_events}} <- Command.run(command, entities_map),
         {:ok, events} <- write_changes(changes_and_events, repo),
         IO.inspect(events, label: :events),
         :ok <- dispatch_events(events, gem, disp) do
      # If everything is fine, just return the command reply
      reply
    else
      {:error, _} = err -> err
      # Handling Ecto multi errors
      {:error, _, _, _} = err -> err
    end
  end

  defp load_entities(keylist, {mod, arg}) do
    with {:ok, entities} <- mod.load_entities(keylist, arg) do
      map =
        Enum.zip(keylist, entities)
        |> Map.new()

      {:ok, map}
    end
  end

  defp write_changes([], _),
    do: {:ok, []}

  # When writing changes, we create some events for each operation. If
  # the list contains events, we will also return them.
  # We will keep the order of the events, but the new events created
  # for each repository operation will first in list.
  defp write_changes(changes_and_events, {mod, arg}) do
    {writes_evts, other_evts} =
      changes_and_events
      |> Enum.split_with(&is_write_event/1)

    result = mod.write_changes(writes_evts, arg)

    case result do
      :ok -> {:ok, other_evts}
      {:ok, events} when is_list(events) -> {:ok, other_evts ++ events}
      {:ok, events} -> raise "Events must be a list, got: #{inspect(events)}"
      {:error, _} = err -> err
    end
  end

  defp is_write_event({k, v}) when k in [:update, :delete, :insert],
    do: true

  defp is_write_event(_),
    do: false

  defp dispatch_events(events, gem, nil) do
    Logger.warn("Ignored events: #{inspect(events)}")
    :ok
  end

  defp dispatch_events(events, gem, {mod, arg} = disp) do
    events
    |> Enum.map(&mod.transform_event(&1, arg))
    |> :lists.flatten()
    |> Enum.each(&send_event(&1, gem, disp))
  end

  # ignoring transformed events as nil or :ok as it is mostly the
  # result of empty transforms, or explicit nil returns, or result
  # from IO.puts or Logger calls
  defp send_event(nil, _, _),
    do: :ok

  defp send_event(:ok, _, _),
    do: :ok

  defp send_event({:external, module, fun, args}, _gem, _disp),
    do: apply(module, fun, args)

  defp send_event({:run_command, %_mod{} = command}, gem, _disp),
    do: send_event({:run_command, 0, command}, gem, _disp)

  defp send_event({:run_command, timeout, %_mod{} = command}, gem, _disp) do
    timer_args = [timeout, Gem, :run, [gem, command]]

    send_event({:external, :timer, :apply_after, timer_args}, gem, _disp)
  end

  defp send_event(event, gem, {mod, arg}) do
    mod.dispatch(event, gem, arg)
  end
end
