defmodule SerrLint.EslintAPI do
  @moduledoc false

  require Logger

  # Путь к eslint-у, указывается в переменной окружения ESLINT_PATH
  @eslint_path Application.get_env(:serr_lint, :eslint_path)

  # Путь к eslintrc файлу, указывается в переменной окружения ESLINT_RC_PATH
  @eslint_rc Application.get_env(:serr_lint, :eslint_rc)

  @doc """
  Выполнить проверку файла.

  ### Параметры
  * `file_path` - Путь к файлу, который нужно проверить.

  ### Возвращает
  Список словарей вида:
  * `message` - Сообщение проверки.
  * `line` -  Строка в которой сработало предупреждение.
  * `ruleId` - ID правила.
  * `severity` - Уровень (предупреждение, ошибка и т.д).
  * `column` - Колонка в которой сработало предупреждение.
  """
  @spec lint_file(String.t) :: list(%{
    message: String.t,
    line: integer,
    ruleId: String.t,
    severity: String.t,
    column: integer
  })
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
