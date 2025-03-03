defmodule EventBus.MixProject do
  use Mix.Project

  def project do
    [
      app: :event_bus,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:con_cache, "~> 1.1"},
      {:oban, "~> 2.19"},
      {:postgrex, ">= 0.0.0"}
    ]
  end

  defp aliases do
    [
      "test.reset": ["ecto.drop --quiet", "test.setup"],
      "test.setup": ["ecto.create --quiet", "ecto.migrate --quiet"]
    ]
  end
end
