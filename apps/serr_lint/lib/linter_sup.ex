defmodule SerrLint.ProjectMonitor do
  @moduledoc false

  require Logger
  use ExActor.GenServer, export: :MonitorLint
  alias SerrLint.ProjectLinter

  defstart start_link do
    config = Application.get_env(:serr_lint, :observers)

    state =
      Enum.reduce(config, %{}, fn {name, setting}, acc ->
        Logger.debug("Start lint project for #{inspect(name)} with settings #{inspect(setting)}")

        {:ok, pid} = ProjectLinter.start_link(name, setting)
        Map.put(acc, name, pid)
      end)

    initial_state(state)
  end

  defcast send(name, msg), state: state do
    Logger.debug("Cast to lint project: #{name} msg: #{inspect(msg)}")
    project_linter = Map.get(state, name)
    Logger.debug("Project linter find #{inspect(project_linter)}")

    GenServer.cast(project_linter, msg)
    new_state(state)
  end

  defcall fetch(name, msg), state: state do
    Logger.debug("Call to lint project: #{name} msg: #{inspect(msg)}")
    project_linter = Map.get(state, name)
    Logger.debug("Project linter find #{inspect(project_linter)}")

    res = GenServer.cast(project_linter, msg)
    reply(res)
  end
end

defmodule SerrLint.ProjectLinter do
  @moduledoc false

  alias Crontab.CronExpression.Parser
  alias Quantum.Job
  alias SerrLint.GitlabAPI
  alias SerrLint.ProjectMonitor
  alias SerrLint.Scheduler

  require Logger
  use ExActor.GenServer

  defstart start_link(name, opts),
    gen_server_opts: [name: String.to_atom("#{name}Linter")] do
    pooling_minutes = Application.get_env(:serr_lint, :pooling_minutes)
    token = Application.get_env(:serr_lint, :token)

    opts = Map.put(opts, :token, token)

    initial_schedule(name, pooling_minutes)
    initial_state(opts)
  end

  defcast pool(), state: state do
    mrs = GitlabAPI.get_target_mrs(state.id, state.target_label)

    Enum.each(mrs, fn %{mr_id: mr_id} ->
      GitlabAPI.update_mr_label(state.id, mr_id, "Checking...")

      try do
        %{
          "head_commit_sha"  => head_sha,
          "base_commit_sha"  => base_sha,
          "start_commit_sha" => start_sha,
          "id"               => diff_id
        } = GitlabAPI.get_last_diff_id(state.id, mr_id)

        diff_files = GitlabAPI.get_all_diff_file(state.id, mr_id, diff_id)

        Enum.each(diff_files, fn file ->
          file_body = GitlabAPI.load_raw_file(state.id, file, head_sha)
          lint_file(file_body, file, mr_id, head_sha, base_sha, start_sha)
        end)
      rescue
        e ->
          IO.puts(:stderr, e.message)
          GitlabAPI.update_mr_label(state.id, mr_id, "Error")
      after
        GitlabAPI.update_mr_label(state.id, mr_id, "Finish")
      end
    end)

    new_state(state)
  end

  defcast lint_result(mr_id, file_path, mr_id, head, base, start, lint_res), state: state do
    Logger.debug("Cast lint result: #{inspect(lint_res)}")

    Enum.each(lint_res, fn msg ->
      open_discussion(msg, state.id, mr_id, file_path, head, base, start)
    end)

    new_state(state)
  end

  defp lint_file(file_body, file_path, mr_id, head, base, start) do
    tmp_dir = "/tmp/#{head}/"

    File.mkdir_p(tmp_dir)
    sys_file_path = "#{tmp_dir}#{random_string(50)}.next"

    File.open!(sys_file_path, [:write], fn file ->
      IO.binwrite(file, file_body)

      lint_res = SerrLint.EslintAPI.lint_file(sys_file_path)
      GenServer.cast(
        self(),
        {
          :lint_result,
          mr_id,
          file_path,
          mr_id,
          head,
          base,
          start,
          lint_res
        }
      )
    end)

    File.rm(sys_file_path)
  end

  @doc """
  Сгенерировать случайную строку, указанной длины.
  """
  @spec random_string(integer) :: String.t
  defp random_string(length) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
    |> binary_part(0, length)
  end

  defp open_discussion(
    msg,
    project_id,
    mr_id,
    file,
    head_sha,
    base_sha,
    start_sha
  ) do
    %{
      "severity" => level,
      "message"  => message,
      "ruleId"   => rule_id,
      "column"   => column,
      "line"     => line
    } = msg

    Logger.debug("Open disccusion: #{inspect(msg)}")

    circle =
      case level do
        1 -> ":large_blue_circle:"
        2 -> ":red_circle:"
      end

    GitlabAPI.open_discussion(project_id, mr_id, %{
      "body" => """
      # #{circle} #{message}
      * ID правила: #{rule_id}
      * Строка: #{line}
      * Столбец: #{column}
      """,
      "position[base_sha]"      => base_sha,
      "position[start_sha]"     => start_sha,
      "position[head_sha]"      => head_sha,
      "position[new_path]"      => file,
      "position[new_line]"      => line,
      "position[position_type]" => "text"
    })
  end

  defp initial_schedule(name, pooling_minutes) do
    job_name = String.to_atom("Beat_linter_#{name}")
    Logger.debug("Delete job: #{inspect(Scheduler.delete_job(job_name))}")

    Scheduler.new_job()
    |> Job.set_name(job_name)
    |> Job.set_schedule(Parser.parse!("*/#{pooling_minutes}"))
    |> Job.set_task(fn ->
      ProjectMonitor.send(name, :pool)
    end)
    |> Scheduler.add_job()

    job_name
  end
end
