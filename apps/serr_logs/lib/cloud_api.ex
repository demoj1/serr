defmodule SerrLogs.CloudApi do
  @moduledoc false

  require Logger
  require SerrLogs
  alias CookieJar.HTTPoison, as: HTTPoison
  alias Timex

  @spec ping(String.t()) :: :error | :ok
  def ping(prefix \\ "pre-test") do
    SerrLogs.trace_start()
    {:ok, jar} = SerrLogs.CookieStore.get(prefix)

    url =
      "https://#{prefix}-cloud.sbis.ru/cloud.html#ws-nc=cloudAccord=CloudWorkAnalysis;AnalyzeMenuBro=514"

    result =
      HTTPoison.get(
        jar,
        url,
        [
          origin: "https://#{prefix}-cloud.sbis.ru",
          "Content-Type": "application/json; utf-8"
        ],
        []
      )

    case result do
      {:ok, response} ->
        case response.status_code do
          401 -> :error
          _ -> :ok
        end

      {:error, _} ->
        :error
    end
  end

  @spec auth(String.t(), String.t(), String.t()) :: String.t()
  def auth(prefix \\ "pre-test", user \\ "Viewer", password \\ "Viewer1234") do
    SerrLogs.trace_start()
    {:ok, jar} = SerrLogs.CookieStore.get(prefix)

    auth_url = "https://#{prefix}-cloud.sbis.ru/auth/service/sbis-rpc-service300.dll"

    body = %{
      jsonrpc: "2.0",
      protocol: "5",
      method: "САП.Authenticate",
      params: %{
        data: %{
          d: [user, password, false, nil, false, true, false],
          s: [
            %{n: "login", t: "Строка"},
            %{n: "password", t: "Строка"},
            %{n: "license_extended", t: "Логическое"},
            %{n: "license_session_id", t: "Строка"},
            %{n: "stranger", t: "Логическое"},
            %{n: "from_browser", t: "Логическое"},
            %{n: "get_last_url", t: "Логическое"}
          ],
          _type: "record"
        }
      },
      id: "1"
    }

    {:ok, response} =
      HTTPoison.post(
        jar,
        auth_url,
        Poison.encode!(body),
        [
          origin: "https://#{prefix}-cloud.sbis.ru",
          "Content-Type": "application/json; utf-8"
        ],
        []
      )

    %{"result" => %{"d" => [[_ | [id]] | _]}} = Poison.decode!(response.body)

    id
  end

  @spec get_log_msg_for_time(
          any,
          String.t() | nil,
          list(String.t()) | nil,
          String.t(),
          list(integer)
        ) :: any
  def get_log_msg_for_time(
        last_query_time \\ Timex.shift(Timex.now(), minutes: -15),
        service \\ nil,
        methods \\ nil,
        prefix \\ "pre-test",
        levels \\ [1, 3, 4]
      ) do
    SerrLogs.trace_start()
    {:ok, jar} = SerrLogs.CookieStore.get(prefix)
    url = "https://#{prefix}-cloud.sbis.ru/view_log/service/sbis-rpc-service300.dl"

    to_date = Timex.now()
    from_date = last_query_time

    to_date = Timex.format!(to_date, "%Y-%m-%d %H:%M:%S.%f%:z", :strftime)
    from_date = Timex.format!(from_date, "%Y-%m-%d %H:%M:%S.%f%:z", :strftime)

    filter =
      case {service, methods} do
        {service, nil} when not is_nil(service) ->
          %{
            _type: "record",
            d: [
              to_date,
              from_date,
              service || "",
              levels,
              5000,
              true
            ],
            s: [
              %{n: "ВремяДо", t: "Строка"},
              %{n: "ВремяОт", t: "Строка"},
              %{n: "Группа", t: "Строка"},
              %{
                n: "Тип",
                t: %{n: "Массив", t: "Число целое"}
              },
              %{n: "ЧислоЗаписей", t: "Число целое"},
              %{n: "ResolveIP", t: "Логическое"}
            ]
          }

        {nil, method} when not is_nil(method) ->
          %{
            _type: "record",
            d: [
              to_date,
              from_date,
              Enum.join(methods, ", "),
              levels,
              5000,
              true
            ],
            s: [
              %{n: "ВремяДо", t: "Строка"},
              %{n: "ВремяОт", t: "Строка"},
              %{n: "Метод", t: "Строка"},
              %{
                n: "Тип",
                t: %{n: "Массив", t: "Число целое"}
              },
              %{n: "ЧислоЗаписей", t: "Число целое"},
              %{n: "ResolveIP", t: "Логическое"}
            ]
          }

        {nil, nil} ->
          nil

        _ ->
          Logger.warn("Unexpected filter arguments")
      end

    body = %{
      id: "1",
      jsonrpc: "2.0",
      method: "ЖурналСообщений.Список",
      params: %{
        ДопПоля: [],
        Навигация: %{
          _type: "record",
          d: [true, 5000, 0],
          s: [
            %{n: "ЕстьЕще", t: "Логическое"},
            %{n: "РазмерСтраницы", t: "Число целое"},
            %{n: "Страница", t: "Число целое"}
          ]
        },
        Сортировка: nil,
        Фильтр: filter
      },
      protocol: "5"
    }

    response =
      HTTPoison.post!(
        jar,
        url,
        Poison.encode!(body),
        [
          origin: "https://#{prefix}-cloud.sbis.ru",
          "Content-Type": "application/json; utf-8"
        ],
        []
      )

    %{"result" => %{"d" => result}} = Poison.decode!(response.body)

    result
    |> Enum.map(&parse_log_msg!(&1))
  end

  @spec get_stats_last_10_min(String.t(), String.t()) :: any
  def get_stats_last_10_min(service \\ "gis diagnostic ps", prefix \\ "pre-test") do
    SerrLogs.trace_start()
    {:ok, jar} = SerrLogs.CookieStore.get(prefix)
    url = "https://#{prefix}-cloud.sbis.ru/stats-cloud-interface/service/"

    IO.puts(inspect(service))

    local_time = Timex.local()
    to_year = rem(local_time.year, 100)
    to_month = local_time.month
    to_day = local_time.day
    to_hours = local_time.hour
    to_minutes = local_time.minute

    # Последние 10 минут
    last_ten_minutes = Timex.shift(local_time, seconds: -60 * 10)
    from_year = rem(last_ten_minutes.year, 100)
    from_month = last_ten_minutes.month
    from_day = last_ten_minutes.day
    from_hours = last_ten_minutes.hour
    from_minutes = last_ten_minutes.minute

    IO.puts("From #{inspect(local_time)}")
    IO.puts("From #{inspect(last_ten_minutes)}")

    body = %{
      jsonrpc: "2.0",
      protocol: "5",
      method: "СтатистикаОблака.ОбработатьЗапрос_2",
      params: %{
        Фильтр: %{
          d: [
            %{
              d: [
                "1",
                %{
                  d: [
                    %{
                      d: [["ten_minute"], "1"],
                      s: [
                        %{
                          n: "Filter",
                          t: %{
                            n: "Массив",
                            t: "Строка"
                          }
                        },
                        %{n: "Position", t: "Число целое"}
                      ],
                      _type: "record"
                    },
                    %{
                      d: [[service]],
                      s: [
                        %{
                          n: "Filter",
                          t: %{
                            n: "Массив",
                            t: "Строка"
                          }
                        }
                      ],
                      _type: "record"
                    }
                  ],
                  s: [%{n: "time", t: "Запись"}, %{n: "WEB-Сервис_Сервис", t: "Запись"}],
                  _type: "record"
                },
                %{
                  d: [
                    %{
                      d: [true],
                      s: [%{n: "Top", t: "Логическое"}],
                      _type: "record"
                    },
                    %{d: [], s: [], _type: "record"},
                    %{d: [], s: [], _type: "record"}
                  ],
                  s: [
                    %{n: "Количество ошибок", t: "Запись"},
                    %{n: "Количество критических ошибок", t: "Запись"},
                    %{n: "Количество предупреждений", t: "Запись"}
                  ],
                  _type: "record"
                },
                "Вызовы",
                "Таблица",
                "#{from_hours}:#{from_minutes}",
                "#{to_hours}:#{to_minutes}",
                "#{from_day}.#{from_month}.#{from_year}",
                "#{to_day}.#{to_month}.#{to_year}"
              ],
              s: [
                %{n: "Версия", t: "Число целое"},
                %{n: "Вертикальная детализация", t: "Запись"},
                %{n: "Характеристики для анализа", t: "Запись"},
                %{n: "Куб", t: "Строка"},
                %{n: "Отображение", t: "Строка"},
                %{n: "ВремяНачала", t: "Строка"},
                %{n: "ВремяКонца", t: "Строка"},
                %{n: "ДатаНачала", t: "Строка"},
                %{n: "ДатаКонца", t: "Строка"}
              ],
              _type: "record"
            }
          ],
          s: [%{n: "Фильтр", t: "Запись"}],
          _type: "record"
        },
        Сортировка: nil,
        Навигация: %{
          d: [true, "30", "0"],
          s: [
            %{n: "ЕстьЕще", t: "Логическое"},
            %{n: "РазмерСтраницы", t: "Число целое"},
            %{n: "Страница", t: "Число целое"}
          ],
          _type: "record"
        },
        ДопПоля: []
      },
      id: "1"
    }

    {:ok, response} =
      HTTPoison.post(
        jar,
        url,
        Poison.encode!(body),
        [
          origin: "https://#{prefix}-cloud.sbis.ru",
          "Content-Type": "application/json; utf-8"
        ],
        []
      )

    IO.puts(inspect(response.body))

    %{"result" => %{"d" => res}} = Poison.decode!(response.body)

    res
    |> Enum.map(fn [date, _, _, _, _, warning, critical_error, error] ->
      %{
        date: date,
        warning: warning,
        critical_error: critical_error,
        error: error
      }
    end)
  end

  @spec get_build_status(String.t()) :: :empty | [map]
  def get_build_status(prefix \\ "pre-test") do
    SerrLogs.trace_start()
    {:ok, jar} = SerrLogs.CookieStore.get(prefix)
    url = "https://#{prefix}-cloud.sbis.ru/update/service/"

    body = %{
      "id" => 1,
      "jsonrpc" => "2.0",
      "method" => "Update.List",
      "params" => %{
        "ДопПоля" => [],
        "Навигация" => %{
          "_type" => "record",
          "d" => [true, 20, 0],
          "s" => [
            %{"n" => "ЕстьЕще", "t" => "Логическое"},
            %{
              "n" => "РазмерСтраницы",
              "t" => "Число целое"
            },
            %{"n" => "Страница", "t" => "Число целое"}
          ]
        },
        "Сортировка" => nil,
        "Фильтр" => %{
          "_type" => "record",
          "d" => ["С узлами и листьями", "С разворотом", 1, false],
          "s" => [
            %{"n" => "ВидДерева", "t" => "Строка"},
            %{"n" => "Разворот", "t" => "Строка"},
            %{"n" => "Режим", "t" => "Число целое"},
            %{"n" => "ТолькоОшибки", "t" => "Логическое"}
          ]
        }
      },
      "protocol" => 5
    }

    response =
      HTTPoison.post(
        jar,
        url,
        Poison.encode!(body),
        [
          origin: "https://#{prefix}-cloud.sbis.ru",
          "Content-Type": "application/json; utf-8"
        ],
        []
      )

    case response do
      {:ok, response} ->
        case Poison.decode!(response.body) do
          %{"result" => %{"d" => res}} ->
            res
            |> Enum.map(&parse_update_msg(&1))
            |> Enum.filter(&(&1 != :error))

          _ ->
            :empty
        end

      _ ->
        :empty
    end
  end

  @spec parse_update_msg([any]) :: :error | map
  defp parse_update_msg(raw_msg) do
    case raw_msg do
      [
        id,
        begin_time,
        _,
        _,
        _,
        _,
        _,
        _,
        _,
        _,
        _,
        from_ver,
        to_ver,
        _,
        _,
        _,
        _,
        _,
        _,
        _,
        name
        | _
      ]
      when begin_time != nil ->
        %{
          id: id,
          begin_time: begin_time,
          from_ver: from_ver,
          to_ver: to_ver,
          name: name
        }

      _ ->
        :error
    end
  end

  @spec parse_log_msg!([any]) :: map
  defp parse_log_msg!(raw_msg) do
    [_, time, _, error_type, error_msg, method, _, _, service | _] = raw_msg

    %{
      time: time,
      error_msg: error_msg,
      method: method,
      service: service,
      error_type: parse_error_type(error_type)
    }
  end

  @spec parse_error_type(integer) :: String.t()
  defp parse_error_type(1), do: "error"
  defp parse_error_type(3), do: "warning"
  defp parse_error_type(4), do: "critical_error"
  defp parse_error_type(_), do: "undefined"
end
