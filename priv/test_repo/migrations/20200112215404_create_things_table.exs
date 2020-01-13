defmodule Gem.EctoRepoTest.Repo.Migrations.CreateThingsTable do
  use Ecto.Migration

  def change do
    create table(:things) do
      add(:name, :string, null: false)
      add(:nick, :string)
      timestamps()
    end
  end
end
