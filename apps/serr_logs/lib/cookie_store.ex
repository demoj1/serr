defmodule SerrLogs.CookieStore do
  require Logger
  use ExActor.GenServer, export: :CookieStore

  defstart start_link do
    domains = Application.get_env(:serr_logs, :observers)

    res =
      domains
      |> Enum.reduce(%{}, fn {k, _}, acc -> Map.put(acc, k, CookieJar.new()) end)

    initial_state(res)
  end

  defcall get(domain), state: state do
    case Map.fetch(state, domain) do
      {:ok, jar} ->
        reply(jar)

      :error ->
        Logger.warn("Domain #{inspect(domain)} not found in state #{inspect(state)}")
        reply(:error)
    end
  end
end
