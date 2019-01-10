use Mix.Config

config :serr_lint,
  pooling_minutes: 1,
  token: System.get_env("GITLAB_TOKEN"),
  gitlab_url: System.get_env("GITLAB_URL"),
  #
  eslint_path: System.get_env("ESLINT_PATH"),
  eslint_rc: System.get_env("ESLINT_RC_PATH"),
  #
  observers: %{
    "mercury" => %{
      id: 1502,
      target_label: "Target"
    }
  }
