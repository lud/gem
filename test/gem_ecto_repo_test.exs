defmodule Gem.EctoRepoTest do
  use ExUnit.Case
  alias Gem.EctoRepoTest.Repo

  @gem __MODULE__.Gem

  setup_all do
    with {:ok, _} <- Repo.start_link(),
         {:ok, gem} <-
           Gem.start_link(
             name: @gem,
             register: false,
             repository: {Gem.Adapter.Repository.Ecto, Repo}
           ) do
      {:ok, %{gem: gem}}
    end
  end

  defmodule Thing do
    use Ecto.Schema
    import Ecto.Changeset

    schema "things" do
      field(:name, :string, null: false)
      field(:nick, :string)
      timestamps()
    end

    def changeset(thing, attrs) do
      thing
      |> cast(attrs, [:name, :nick])
      |> validate_required([:name])
    end
  end

  # Of course we would not use a command to create an entity, but it is useful
  # to fully test the repo adapter.
  defmodule Command.CreateThing do
    use Gem.Command
    defstruct attrs: nil

    def new(attrs) when is_map(attrs) do
      %__MODULE__{attrs: attrs}
    end

    def key_spec(_) do
      nil
    end

    def run(%{attrs: attrs}, nil) do
      {:ok, insert: Thing.changeset(%Thing{}, attrs)}
    end
  end

  defmodule Command.ChangeNick do
    use Gem.Command
    defstruct nick: nil, id: nil

    def new(id, nick) when is_integer(id) and is_binary(nick) do
      %__MODULE__{id: id, nick: nick}
    end

    def key_spec(%{id: id}),
      do: {Thing, id}

    def run(%{nick: nick}, %Thing{} = thing) do
      # return the old nick
      {:ok, thing.nick, update: Thing.changeset(thing, %{nick: nick})}
    end
  end

  test "can insert a %Thing{}", %{gem: gem} do
    assert :ok = Gem.run(gem, Command.CreateThing.new(%{name: "blob"}))
  end

  test "can update a %Thing{}", %{gem: gem} do
    assert {:ok, %Thing{id: id}} = Repo.insert(%Thing{name: "Jean"})
    assert {:ok, _} = Gem.run(gem, Command.ChangeNick.new(id, "aaaa"))
    assert {:ok, "aaaa"} = Gem.run(gem, Command.ChangeNick.new(id, "bbbb"))
    assert match?({:ok, %Thing{nick: "bbbb"}}, Gem.fetch_entity(gem, {Thing, id}))
  end
end
