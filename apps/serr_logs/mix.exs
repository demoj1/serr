defmodule SerrLogs.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :serr_logs,
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
      mod: {SerrLogs, []},
      extra_applications: [:logger, :nostrum]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:exactor, "~> 2.2.4", warn_missing: false},
      {:httpoison, "~> 0.13"},
      {:poison, "~> 3.1"},
      {:cookie_jar, "~> 1.0"},
      {:timex, "~> 3.1"},
      {:quantum, "~> 2.3"},
      {:distillery, "~> 1.5.5"},
      {:nostrum, git: "https://github.com/dmitrydprog/nostrum.git", tag: "0.2.6"},
      {:dogma, "~> 0.1", only: :dev},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false}
    ]
  end
end
