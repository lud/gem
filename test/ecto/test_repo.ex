defmodule Gem.EctoRepoTest.Repo do
  use Ecto.Repo, otp_app: :gem, adapter: Ecto.Adapters.Postgres
end
