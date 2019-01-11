defmodule SerrLogs.Monitor.LogSupervisor do
  require Logger
  use Supervisor

  @spec start_link() :: :ignore | {:error, any} | {:ok, pid}
  def start_link() do
    domains = Application.get_env(:serr_logs, :observers) |> Map.keys()
    Supervisor.start_link(__MODULE__, domains, name: __MODULE__)
  end

  @spec init(any) :: none
  def init(_opts) do
    import Supervisor.Spec, warn: false

    settings = Application.get_env(:serr_logs, :observers)

    opts =
      Enum.reduce(settings, %{}, fn {domain, opts}, acc ->
        Map.put(acc, domain, %{
          build_services: opts |> Map.get(:build_services),
          previous: [],
          build_channel: opts |> Map.get(:build_channel)
        })
      end)

    children = [
      worker(SerrLogs.Monitor.Log, []),
      worker(SerrLogs.Monitor.Build, [opts])
    ]

    Supervisor.init(children, strategy: :one_for_one, name: SerrLogs.Monitor.LogSupervisor)
  end
end

defmodule SerrLogs.Monitor.Log do
  @moduledoc false

  require Logger
  use ExActor.GenServer, export: :MonitorLog

  defstart start_link do
    config = Application.get_env(:serr_logs, :observers)

    SerrLogs.Doctor.check_health()

    state =
      Enum.reduce(config, %{}, fn {domain, setting}, acc ->
        {:ok, pid} = SerrLogs.Monitor.LogDomain.start_link(domain, setting)
        Map.put(acc, domain, pid)
      end)

    initial_state(state)
  end

  defcast send(domain, msg), state: state do
    domain_monitor = Map.get(state, domain)

    GenServer.cast(domain_monitor, msg)

    new_state(state)
  end

  defcall fetch(domain, msg), state: state do
    domain_monitor = Map.get(state, domain)

    res = GenServer.call(domain_monitor, msg)
    reply(res)
  end
end

defmodule SerrLogs.Monitor.LogDomain do
  @moduledoc false

  require Logger
  alias Nostrum.Struct.Embed, as: Embed
  alias Nostrum.Struct.Embed.Field, as: Field
  use ExActor.GenServer

  defstart start_link(domain, opts),
    gen_server_opts: [name: String.to_atom("#{domain}Monitor")] do
    %{
      pooling_minutes: pooling_minutes,
      services: services
    } = opts

    initial_schedule(domain, pooling_minutes)

    services =
      services
      |> Enum.map(&Map.put_new(&1, :domain, domain))
      |> Enum.map(&Map.put_new(&1, :last_time, Timex.now()))

    initial_state(services)
  end

  defcast pool(), state: state do
    state
    |> Enum.map(fn service ->
      pool_result = pool_data(service)
      %{discord_channel: discord_channel} = service

      for res <- pool_result do
        Task.async(fn -> send_msg(discord_channel, res) end)
      end

      Map.put(service, :last_result, pool_result)
    end)
    |> Enum.map(&Map.put(&1, :last_time, Timex.now()))
    |> new_state
  end

  defcall result(service), state: state do
    state
    |> Enum.filter(&(&1.service == service))
    |> reply
  end

  defcall result_all, state: state do
    reply(state)
  end

  @spec pool_data(map) :: any
  def pool_data(%{domain: domain, level: level, service: service, last_time: last_time}) do
    SerrLogs.CloudApi.get_log_msg_for_time(
      last_time,
      service,
      domain,
      level
    )
  end

  @spec send_msg(pos_integer, map) :: {:error, any} | {:ok, any}
  def send_msg(discord_channel, %{
        error_msg: error_msg,
        time: time,
        method: method,
        service: service,
        error_type: error_type
      }) do
    error_msg = error_msg |> String.reverse() |> String.slice(0..2000) |> String.reverse()
    date = Timex.parse!(time, "{ISO:Extended}")

    case GenServer.call(:SpamFilter, {:spam_filter, "#{discord_channel}#{error_msg}"}) do
      {false, secs} ->
        Logger.info("Message: #{error_msg} locked on time: #{secs}")
        :ok

      true ->
        Nostrum.Api.create_message(
          discord_channel,
          content: "#{error_to_emoji(error_type)}\n```python\n\n#{error_msg}```",
          embed: %Embed{
            title: String.capitalize(service),
            color: color_error_type(error_type),
            timestamp: date,
            fields: [
              %Field{
                name: "Method",
                value: method,
                inline: true
              }
            ]
          }
        )
    end
  end

  @spec error_to_emoji(String.t()) :: String.t()
  defp error_to_emoji("error"), do: ":rage:"
  defp error_to_emoji("warning"), do: ":warning:"
  defp error_to_emoji(_), do: ""

  @spec color_error_type(any) :: 0x000000 | 0xFF0000 | 0xFF9410
  defp color_error_type("error"), do: 0xFF0000
  defp color_error_type("warning"), do: 0xFF9410
  defp color_error_type(_), do: 0x000000

  @spec initial_schedule(String.t(), pos_integer) :: atom
  def initial_schedule(domain, pooling_minutes) do
    res = SerrLogs.Scheduler.delete_job(String.to_atom("Beat_domain_#{domain}"))

    SerrLogs.Scheduler.new_job()
    |> Quantum.Job.set_name(String.to_atom("Beat_domain_#{domain}"))
    |> Quantum.Job.set_schedule(Crontab.CronExpression.Parser.parse!("*/#{pooling_minutes}"))
    |> Quantum.Job.set_task(fn ->
      SerrLogs.Monitor.Log.send(domain, :pool)
    end)
    |> SerrLogs.Scheduler.add_job()

    String.to_atom("Beat_domain_#{domain}")
  end
end
