defmodule SerrLint do
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(SerrLint.Scheduler, []),
      worker(SerrLint.ProjectMonitor, [])
    ]

    Logger.debug("Starting Lint application")
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

defmodule SerrLint.Scheduler do
  @moduledoc false

  use Quantum.Scheduler,
    otp_app: :serr_lint
end
