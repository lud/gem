defmodule Gem.MixProject do
  use Mix.Project

  def project do
    [
      app: :gem,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:cubdb, "~> 0.12.0", only: [:test]}
    ]
  end
end
