defmodule ExEventBus.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_event_bus,
      version: "0.2.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      description: description(),
      package: package(),
      name: "ExEventBus",
      source_url: "https://github.com/djeusette/ex_event_bus"
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp description,
    do: "ExEventBus provides an event bus that uses the outbox pattern.  Behind the scenes, 
it relies on Oban and ConCache."

  defp package,
    do: [
      name: "ex_event_bus",
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/djeusette/ex_event_bus"}
    ]

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
      {:postgrex, ">= 0.0.0"},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      "test.reset": ["ecto.drop --quiet", "test.setup"],
      "test.setup": ["ecto.create --quiet", "ecto.migrate --quiet"]
    ]
  end
end
