defmodule SerrLint.GitlabAPI do
  @moduledoc false

  require Logger
  alias HTTPoison
  import URI

  @token Application.get_env(:serr_lint, :token)
  @gitlab_path Application.get_env(:serr_lint, :gitlab_url)

  def get_target_mrs(project_id) do
    url =
      "http://#{@gitlab_path}/api/v4/projects/#{project_id}/merge_requests?state=opened&labels=Target"

    Logger.debug("Get target mrs from #{url}")

    response = HTTPoison.get!(url, [], follow_redirect: true)

    Poison.decode!(response.body)
    |> Enum.filter(fn %{"labels" => labels} ->
      "Target" in labels
    end)
    |> Enum.map(fn %{"title" => title, "iid" => id} ->
      %{title: title, mr_id: id, project_id: project_id}
    end)
  end

  def update_mr_label(project_id, mr_id, labels) do
    url = "https://#{@gitlab_path}/api/v4/projects/#{project_id}/merge_requests/#{mr_id}"

    body = %{
      id: project_id,
      merge_request_iid: mr_id,
      labels: labels
    }

    response =
      HTTPoison.put!(
        url,
        Poison.encode!(body),
        [
          {"Content-Type", "application/json"},
          {"Connection", "Keep-Alive"},
          {"Private-Token", @token}
        ]
      )

    Logger.debug(inspect(response))
    response
  end

  def get_last_diff_id(project_id, mr_id) do
    url = "https://#{@gitlab_path}/api/v4/projects/#{project_id}/merge_requests/#{mr_id}/versions"

    body = HTTPoison.get!(url, [{"Private-Token", @token}]).body

    Logger.debug("Get last diff body: #{body}")

    body
    |> Poison.decode!()
    |> Enum.max_by(fn %{"id" => id} -> id end)
    |> Map.take(["id", "head_commit_sha", "base_commit_sha", "start_commit_sha"])
  end

  def get_all_diff_file(project_id, mr_id, diff_id) do
    url =
      "https://#{@gitlab_path}/api/v4/projects/#{project_id}/merge_requests/#{mr_id}/versions/#{
        diff_id
      }"

    body = HTTPoison.get!(url, [{"Private-Token", @token}]).body

    Logger.debug("Get all diff body: #{body}")

    body
    |> Poison.decode!()
    |> Map.get("diffs", [])
    |> Enum.filter(fn %{"deleted_file" => deleted_file} -> not deleted_file end)
    |> Enum.map(fn %{"new_path" => new_path} -> new_path end)
    |> Enum.filter(&String.ends_with?(&1, [".next"]))
  end

  def load_raw_file(project_id, file_path, ref) do
    file_path_encode = encode_www_form(file_path)

    url =
      "https://#{@gitlab_path}/api/v4/projects/#{project_id}/repository/files/#{file_path_encode}/raw?ref=#{
        ref
      }"

    body = HTTPoison.get!(url, [{"Private-Token", @token}]).body

    Logger.debug("Raw file body: #{String.slice(body, 0..100)}")
    body
  end

  def open_discussion(project_id, mr_id, opts) do
    opts_encode = URI.encode_query(opts)

    Logger.debug(opts_encode)

    url =
      "https://#{@gitlab_path}/api/v4/projects/#{project_id}/merge_requests/#{mr_id}/discussions"

    body =
      HTTPoison.post!(url, opts_encode, [
        {"Private-Token", @token},
        {"Content-Type", "application/x-www-form-urlencoded"}
      ])

    body
  end
end
