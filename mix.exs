defmodule Gem.MixProject do
  use Mix.Project

  def project do
    [
      app: :gem,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # The main page in the docs
      docs: [extras: ["README.md"], main: "readme", extra_section: "GUIDES"],
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mutex, "~> 1.1.2"},
      {:cubdb, "~> 0.13.0", only: [:test, :dev]},
      # {:dialyxir, "~> 1.0.0-rc.6", only: [:test, :dev], runtime: false},
      {:todo, "~> 1.3", only: [:test, :dev], runtime: false},
      # {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      # {:ex_doc, "> 0.0.0", only: :dev, runtime: false}
      {:ecto_sql, "~> 3.0", only: [:test, :dev]},
      {:postgrex, ">= 0.0.0", only: [:test, :dev]}
    ]
  end

  defp aliases do
    [
      lint: ["dialyzer", "credo --all --strict"],
      test: ["ecto.migrate", "test"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/ecto"]
  defp elixirc_paths(_), do: ["lib"]
end
