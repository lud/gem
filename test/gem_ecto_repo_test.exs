defmodule Gem.EctoRepoTest do
  use ExUnit.Case
  alias Gem.EctoRepoTest.Repo

  setup_all do
    case Repo.start_link() do
      {:ok, _pid} -> :ok
      other -> other
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
      %{name: name} = attrs

      {:ok, insert: Thing.changeset(%Thing{}, attrs)}
    end
  end

  test "can insert a %Thing{}" do
    assert {:ok, gem} =
             Gem.start_link(
               name: @gem,
               register: false,
               repository: {Gem.Adapter.Repository.Ecto, Repo}
             )

    assert {:ok, _} = Gem.run(gem, Command.CreateThing.new(%{name: "blob"}))
  end

  test "can update a %Thing{}" do
    assert false
  end
end
