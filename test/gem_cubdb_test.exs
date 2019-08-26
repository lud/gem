defmodule Gem.CubDBTest do
  use ExUnit.Case
  doctest Gem

  @db1_dir "test/db/cub1"
  @db1_name Module.concat(__MODULE__, Repo1)
  @dispatcher1_name Module.concat(__MODULE__, Dispatcher1)

  setup_all do
    File.mkdir_p!(@db1_dir)

    db_opts = [auto_compact: true, auto_file_sync: false]
    gen_opts = [name: @db1_name]
    {:ok, _} = CubDB.start_link(@db1_dir, db_opts, gen_opts)

    {:ok, _} = Gem.Adapter.EventDispatcher.Registry.start_link(@dispatcher1_name)
    :ok
  end

  def clear_db(db) do
    {:ok, keys} =
      CubDB.select(db,
        pipe: [
          map: fn {k, _} -> k end
        ]
      )

    CubDB.delete_multi(db, keys)
    CubDB.file_sync(db)
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
    clear_db(@db1_name)

    assert {:ok, gem} =
             Gem.start_link(
               name: MyGem,
               register: false,
               repository: {Gem.Adapter.Repository.CubDB, @db1_name},
               dispatcher: {Gem.Adapter.EventDispatcher.Registry, @dispatcher1_name}
             )

    # register is set to false
    assert nil === Process.whereis(MyGem)

    event = {:inserted, :person}
    # We register self as a listener for the event
    Gem.Adapter.EventDispatcher.Registry.subscribe(@dispatcher1_name, gem, event, :HELLO)

    assert {:ok, :NOT_FOUND} = Gem.fetch_entity(gem, {:person, "Alice"})
    alice = %{name: "Alice", age: 22}
    assert :ok = Gem.run(gem, Command.CreatePerson.new(alice))

    # We should receive the event
    assert_receive {^event, {{:person, "Alice"}, ^alice}, :HELLO}

    assert {:ok, alice} === Gem.fetch_entity(gem, {:person, "Alice"})
  end
end
