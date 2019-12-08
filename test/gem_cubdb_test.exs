defmodule Gem.CubDBTest do
  use ExUnit.Case
  doctest Gem

  @db_dir "test/db/#{__MODULE__}"
  @db_name Module.concat(__MODULE__, Repo)
  @dispatcher_name Module.concat(__MODULE__, Dispatcher)
  @gem Module.concat(__MODULE__, Gem)

  setup_all do
    File.mkdir_p!(@db_dir)

    db_opts = [auto_compact: true, auto_file_sync: false]
    gen_opts = [name: @db_name]

    start_supervised(%{
      id: __MODULE__.DB,
      start: {CubDB, :start_link, [@db_dir, db_opts, gen_opts]}
    })

    start_supervised({Gem.Adapter.EventDispatcher.Registry, @dispatcher_name})

    CubHelpers.clear_db(@db_name)
    :ok
  end

  defmodule Command.CreatePerson do
    use Gem.Command
    defstruct attrs: nil

    def new(attrs) do
      %__MODULE__{attrs: attrs}
    end

    def key_spec(%{attrs: %{name: name}}) do
      {:person, name}
    end

    def run(%{attrs: attrs}, :NOT_FOUND) do
      %{name: name} = attrs
      {:ok, [insert: {{:person, name}, attrs}]}
    end
  end

  test "can start a database and create entities" do
    assert {:ok, gem} =
             Gem.start_link(
               name: @gem,
               register: false,
               repository: {Gem.Adapter.Repository.CubDB, @db_name},
               dispatcher: {Gem.Adapter.EventDispatcher.Registry, @dispatcher_name}
             )

    # register is set to false
    assert nil === Process.whereis(@gem)

    event_key = {:inserted, :person}
    # We register self as a listener for the event
    Gem.Adapter.EventDispatcher.Registry.subscribe(@dispatcher_name, event_key)
    Gem.Adapter.EventDispatcher.Registry.subscribe(@dispatcher_name, event_key, :added_metadata)

    assert {:ok, :NOT_FOUND} = Gem.fetch_entity(gem, {:person, "Alice"})
    alice = %{name: "Alice", age: 22}
    assert :ok = Gem.run(gem, Command.CreatePerson.new(alice))

    # We should receive the event
    assert_receive {@gem, ^event_key, {{:person, "Alice"}, ^alice}}
    assert_receive {@gem, ^event_key, {{:person, "Alice"}, ^alice}, :added_metadata}

    assert {:ok, alice} === Gem.fetch_entity(gem, {:person, "Alice"})
  end

  IO.warn("todo test that shows that fetch_entity is out of sync but not fetch_sync")
end
