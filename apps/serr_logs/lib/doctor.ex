defmodule SerrLogs.Doctor do
  require Logger

  @spec check_health() :: [any]
  def check_health() do
    domains = Application.get_env(:serr_logs, :observers)

    for {k, v} <- domains do
      %{:user => user, :password => password} = v
      check_health({k, user, password})
    end
  end

  @spec check_health({String.t(), String.t(), String.t()}) :: any
  def check_health({domain, user, password}) do
    case SerrLogs.CloudApi.ping(domain) do
      :ok ->
        :ok

      :error ->
        Logger.warn("Domain #{domain} error!")
        spawn_link(fn -> SerrLogs.CloudApi.auth(domain, user, password) end)
    end
  end
end
