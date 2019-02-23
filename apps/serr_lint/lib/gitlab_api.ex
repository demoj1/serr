defmodule SerrLint.GitlabAPI do
  @moduledoc false

  require Logger
  alias HTTPoison
  import URI

  # Токен авторизации на Gitlab.
  @token Application.get_env(:serr_lint, :token)

  # Путь к Gitlab-у.
  @gitlab_path Application.get_env(:serr_lint, :gitlab_url)

  @doc """
  Получить список MR-ов, соотвествующих метки.
  > Более подробно:
  > https://docs.gitlab.com/ee/api/merge_requests.html#list-project-merge-requests

  ### Параметры
  * `project_id` - ID проекта на gitlab.
  * `target_label` - Метка, по которой будет производится фильтрация.

  ### Возвращает
  Список подходящих MR-ов. Каждый MR имеет формат:
  ```elixir
  %{
    title,
    mr_id,
    project_id
  }
  ```
  """
  @spec get_target_mrs(integer, String.t) :: list(%{
    title: String.t,
    mr_id: integer,
    project_id: integer
  })
  def get_target_mrs(project_id, target_label) do
    "http://#{@gitlab_path}/api/v4/projects/#{project_id}/merge_requests?state=opened&labels=#{target_label}"
    |> HTTPoison.get!([], follow_redirect: true)
    |> Map.get(:body)
    |> Poison.decode!()
    |> Enum.map(fn %{"title" => title, "iid" => id} ->
      %{title: title, mr_id: id, project_id: project_id}
    end)
  end

  @doc """
  Обновить текущие метки MRа.
  > Более подробно:
  > https://docs.gitlab.com/ee/api/merge_requests.html#update-mr

  ### Параметры
  * `project_id` - ID проекта на gitlab.
  * `mr_id` - ID merge request-а на gitlab.
  * `labels` - Список меток, которые нужно установить.
  """
  @spec update_mr_label(integer, integer, list(String.t)) :: any
  def update_mr_label(project_id, mr_id, labels) do
    body = %{
      id: project_id,
      merge_request_iid: mr_id,
      labels: labels
    }

    "https://#{@gitlab_path}/api/v4/projects/#{project_id}/merge_requests/#{mr_id}"
    |> HTTPoison.put!(
        Poison.encode!(body),
        [
          {"Content-Type", "application/json"},
          {"Connection", "Keep-Alive"},
          {"Private-Token", @token}
        ]
      )
  end

  @doc """
  Получить ID и доп. информацию о последнем diff-е по ID MR-а.
  > Более подробно
  > https://docs.gitlab.com/ee/api/merge_requests.html#get-mr-diff-versions

  ### Параметры
  * `project_id` - ID проекта на gitlab.
  * `mr_id` - ID merge request-а на gitlab.

  ### Возвращает
  Словарь вида:
  * `id` - ID diff-а.
  * `head_commit_sha` - Хеш HEAD коммита.
  * `base_commit_sha` - Хеш базового коммита.
  * `start_commit_sha` - Стартовый хеш.

  Параметры `head_commit_sha`, `base_commit_sha`, `start_commit_sha` позже потребуется
  для того, что бы открыть дискусию с помощью функции `open_discussion/3`.
  """
  @spec get_last_diff_id(integer, integer) :: %{
    id: integer,
    head_commit_sha: String.t,
    base_commit_sha: String.t,
    start_commit_sha: String.t
  }
  def get_last_diff_id(project_id, mr_id) do
    "https://#{@gitlab_path}/api/v4/projects/#{project_id}/merge_requests/#{mr_id}/versions"
    |> HTTPoison.get!([{"Private-Token", @token}])
    |> Map.get(:body)
    |> Poison.decode!()
    |> Enum.max_by(fn %{"id" => id} -> id end)
    |> Map.take(["id", "head_commit_sha", "base_commit_sha", "start_commit_sha"])
  end

  @doc """
  Получить список измененых файлов в опредленном diff-е.
  Файлы фильтруются по расширениям, на данный момент возвращаются
  файлы, имеющие расширения `.next`, остальные игнорируются.
  > Более подробно
  > https://docs.gitlab.com/ee/api/merge_requests.html#get-a-single-mr-diff-version

  ### Параметры
  * `project_id` - ID проекта на gitlab.
  * `mr_id` - ID merge request-а на gitlab.
  * `diff_id` - ID diff-а, можно получить из метода `get_last_diff_id/2`.

  ### Возвращает
  Список файлов с расширением `.next`.
  """
  @spec get_all_diff_file(integer, integer, integer) :: list(String.t)
  def get_all_diff_file(project_id, mr_id, diff_id) do
    "https://#{@gitlab_path}/api/v4/projects/#{project_id}/merge_requests/#{mr_id}/versions/#{
      diff_id
    }"
    |> HTTPoison.get!([{"Private-Token", @token}])
    |> Map.get(:body)
    |> Poison.decode!()
    |> Map.get("diffs", [])
    |> Enum.filter_map(
      fn %{"deleted_file" => deleted_file} -> not deleted_file end,
      fn %{"new_path" => new_path} -> new_path end
    )
    |> Enum.filter(&String.ends_with?(&1, [".next"]))
  end

  @doc """
  Загрузить код файла.
  Код файла загражуется из проекта с указанием
  конкретного хеша коммита.

  ### Параметры
  * `project_id` - ID проекта на gitlab.
  * `file_path` - Путь файла в проекте.
  * `ref` - Хеш коммита.

  ### Возвращает
  Текст загруженного файла.
  """
  @spec load_raw_file(integer, String.t, String.t) :: String.t
  def load_raw_file(project_id, file_path, ref) do
    file_path_encode = encode_www_form(file_path)

    "https://#{@gitlab_path}/api/v4/projects/#{project_id}/repository/files/#{file_path_encode}/raw?ref=#{
      ref
    }"
    |> HTTPoison.get!([{"Private-Token", @token}])
    |> Map.get(:body)
  end

  @doc """
  Открыть новую дискусю на gitlab-е.

  ### Параметры
  * `project_id` - ID проекта на gitlab.
  * `mr_id` - ID merge request-а на gitlab.
  * `opts` - Опции, необходимые для открытия дискусии.
    Опции представляют из себя словарь с полями:
    * `body` - текст сообщения.
    * `position[base_sha]` - Служебная информация с хешами, требующимися для gitlab-а.
    * `position[start_sha]` - Служебная информация с хешами, требующимися для gitlab-а.
    * `position[head_sha]` - Служебная информация с хешами, требующимися для gitlab-а.
    * `position[new_path]` - Путь до файла.
    * `position[new_line]` - Строка в файле.
    * `position[position_type]` - Обычно соотвествует строке `text`.
  """
  @spec open_discussion(integer, integer, map) :: any
  def open_discussion(project_id, mr_id, opts) do
    opts_encode = URI.encode_query(opts)

    "https://#{@gitlab_path}/api/v4/projects/#{project_id}/merge_requests/#{mr_id}/discussions"
    |> HTTPoison.post!(opts_encode, [
        {"Private-Token", @token},
        {"Content-Type", "application/x-www-form-urlencoded"}
      ])
  end
end
