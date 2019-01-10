defmodule SerrLint.EslintAPI do
  @moduledoc false

  require Logger

  @eslint_path Application.get_env(:serr_lint, :eslint_path)
  @eslint_rc Application.get_env(:serr_lint, :eslint_rc)

  def lint_file(file_path) do
    System.cmd(@eslint_path, ["-c", @eslint_rc, file_path, "-f", "json"])
  end
end
