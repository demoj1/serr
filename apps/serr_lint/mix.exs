defmodule SerrLint.MixProject do
  use Mix.Project

  def project do
    [
      app: :serr_lint,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {SerrLint, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exactor, "~> 2.2.4", warn_missing: false},
      {:httpoison, "~> 0.13"},
      {:poison, "~> 3.1"},
      {:quantum, "~> 2.3"},
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:dogma, "~> 0.1", only: :dev},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false},
      {:observer_cli, "~> 1.4"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true},
    ]
  end
end
