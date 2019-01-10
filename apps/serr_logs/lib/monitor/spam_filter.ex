defmodule SerrLogs.Monitor.SpamFilter do
  @moduledoc false

  use ExActor.GenServer
  require Logger
  alias Timex

  defstart start_link(),
    gen_server_opts: [name: :SpamFilter] do
    initial_state([])
  end

  defcall spam_filter(msg), state: state do
    wait_seconds = Application.get_env(:serr_logs, :spam_seconds)

    filter_msg =
      Enum.find(state, nil, fn {str, _} ->
        Logger.debug("Jaro distance #{str} with #{msg} = #{String.jaro_distance(msg, str)}")
        String.jaro_distance(msg, str) >= 0.9
      end)

    Logger.debug("Filterd spam msg: #{inspect(filter_msg)}")

    case filter_msg do
      nil ->
        set_and_reply([{msg, Timex.now()} | state], true)

      {tmp, time} ->
        diff_sec = Timex.diff(Timex.now(), time, :seconds)

        Logger.debug("Differen secs: #{diff_sec} / #{wait_seconds}")

        if diff_sec < wait_seconds do
          Logger.info(
            "Msg: #{msg} blocked by spam, diff: #{diff_sec} / #{wait_seconds}\n#{inspect(tmp)}"
          )

          reply({false, diff_sec})
        else
          state
          |> Enum.filter(&(&1 != filter_msg))
          |> set_and_reply(true)
        end
    end
  end

  defcall get_spam_data, state: state do
    reply(state)
  end

  defcall get_count_filtered, state: state do
    reply(Enum.count(state))
  end
end
