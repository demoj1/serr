defmodule SerrLint.EslintAPI do
  @moduledoc false

  require Logger

  @eslint_path Application.get_env(:serr_lint, :eslint_path)
  @eslint_rc Application.get_env(:serr_lint, :eslint_rc)

  def lint_file(file_path) do
   {res, _} = System.cmd(@eslint_path, ["-c", @eslint_rc, file_path, "-f", "json"])

    res
    |> Poison.decode!()
    |> Enum.map(&Map.pop(&1, "messages"))
    |> Enum.at(0, [])
    |> Tuple.to_list()
    |> Enum.at(0, [])
    |> Enum.map(&Map.take(&1, ["message", "line", "ruleId", "severity", "column"]))
  end
end
