defmodule Gem do
  @moduledoc """
  This module is the main interface to Gem. It allows to start a Gem
  and run commands.
  """
  alias Gem.Command
  alias Gem.Command.Fetch
  use TODO

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

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
        # @todo name is required because we pass it to the event
        #    listeners. If it is acceptable to pass nil to the
        #    listeners then we can allow nameless gems.
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
    dummy = Fetch.new(key_spec)
    entity_keys = Command.list_keys(dummy)
    %{repository: repo} = Mutex.get_meta(gem)

    with {:ok, entities_map} <- load_entities(entity_keys, repo) do
      {:ok, Command.fullfill_spec(dummy, entities_map)}
    end
  end

  def fetch_entities(gem, key_spec),
    do: fetch_entity(gem, key_spec)

  def fetch_sync(gem, key_spec),
    do: Gem.run(gem, Gem.Command.Fetch.new(key_spec))

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
  @todo "Events should be dispatched outside of mutex lock"

  defp do_run(%{name: gem, repository: repo, dispatcher: disp}, entity_keys, command) do
    with {:ok, entities_map} <- load_entities(entity_keys, repo),
         {:ok, {reply, changes_and_events}} <- Command.run(command, entities_map),
         {:ok, write_events, other_events} <- split_events(changes_and_events),
         {:ok, write_result_events} <- write_changes(write_events, repo),
         :ok <- dispatch_events(gem, write_result_events ++ other_events, disp) do
      # If everything is fine, just return the command reply
      reply
    else
      {:error, _} = err -> err
      # Handling Ecto multi errors
      {:error, _, _, _} = err -> err
    end
  end

  defp load_entities(keylist, {mod, arg}) do
    with {:ok, entities} <- mod.load_entities(arg, keylist) do
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
  defp write_changes(write_events, {mod, arg}) do
    case mod.write_changes(arg, write_events) do
      :ok -> {:ok, []}
      {:ok, events} when is_list(events) -> {:ok, events}
      {:error, _} = err -> err
    end
  end

  # Splitting events recursively. We check if the event has a "write"
  # key: :update, :delete or :insert, else if it is a 2-tuple.
  # We discard nil events
  defp split_events(events, acc \\ {[], [], []})

  defp split_events([{k, _} = event | events], {write, other, bad})
       when k in [:update, :delete, :insert],
       do: split_events(events, {[event | write], other, bad})

  defp split_events([{_, _} = event | events], {write, other, bad}),
    do: split_events(events, {write, [event | other], bad})

  defp split_events([nil | events], {write, other, bad}),
    do: split_events(events, {write, other, bad})

  defp split_events([event | events], {write, other, bad}),
    do: split_events(events, {write, other, [event | bad]})

  # When done with all events we can return ok if there is no bad
  # event
  defp split_events([], {write_events, other_events, []}),
    do: {:ok, :lists.reverse(write_events), :lists.reverse(other_events)}

  # ... or return an error otherwise
  defp split_events([], {_, _, bad_events}),
    do: {:error, {:bad_events, :lists.reverse(bad_events)}}

  defp dispatch_events(_gem, _events, nil) do
    :ok
  end

  defp dispatch_events(gem, events, {mod, arg} = disp) do
    events
    |> Enum.map(&mod.transform_event(&1, arg))
    # flatten in case the transform callback returns event lists
    |> :lists.flatten()
    # |> IO.inspect(label: "Transformed events")
    |> Enum.each(&send_event(&1, gem, disp))
  end

  # ignoring transformed events as nil or :ok as it is mostly the
  # result of empty transforms, explicit nil returns or result
  # from IO.puts and Logger calls
  defp send_event(nil, _, _), do: :ok
  defp send_event(:ok, _, _), do: :ok

  @todo ":external is a bad keyword, must use a Gem. prefixed keyword"
  @todo """
    no need to use timer.apply_after by default as it happens in the
    client process.
  """

  defp send_event({:external, module, fun, args}, _gem, _disp),
    do: apply(module, fun, args)

  defp send_event({:run_command, %_mod{} = command}, gem, disp),
    do: send_event({:run_command, 0, command}, gem, disp)

  defp send_event({:run_command, timeout, %_mod{} = command}, gem, disp) do
    timer_args = [timeout, Gem, :run, [gem, command]]

    send_event({:external, :timer, :apply_after, timer_args}, gem, disp)
  end

  defp send_event(event, gem, {mod, arg}) do
    mod.dispatch(arg, gem, event)
  end
end
