use Mix.Config

config :gem, ecto_repos: [Gem.EctoRepoTest.Repo]

config :gem, Gem.EctoRepoTest.Repo,
  priv: "priv/test_repo",
  username: "gem_test",
  password: "gem_test",
  database: "gem_test",
  port: 54325,
  pool: Ecto.Adapters.SQL.Sandbox
