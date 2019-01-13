defmodule SerrLogs do
  @moduledoc false

  use Application
  require Logger

  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(SerrLogs.CookieStore, []),
      worker(SerrLogs.Scheduler, []),
      worker(SerrLogs.Monitor.SpamFilter, []),
      supervisor(SerrLogs.Monitor.LogSupervisor, [])
    ]

    # Nostrum.Api.create_message(524_222_775_284_727_808, "Serr к вашим услугам :yum:")

    Logger.debug("Starting Log application")
    Supervisor.start_link(children, strategy: :one_for_one, name: SerrLogs.Supervisor)
  end

  defmacro trace_start do
    quote do
      Logger.debug("start call pid: #{inspect(self())}")
    end
  end
end

defmodule SerrLogs.Scheduler do
  @moduledoc false

  use Quantum.Scheduler,
    otp_app: :serr_logs
end
