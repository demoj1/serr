defmodule DomainMonitorTest do
  use ExUnit.Case, async: false

  alias Monitor.LogDomain
  alias Monitor.SpamFilter

  setup do
    Application.put_env(:elixir3, :spam_seconds, 1)

    {:ok, spam_filter_pid} = Monitor.SpamFilter.start_link()
    {:ok, filter: spam_filter_pid}
  end

  test "Инициализация спам фильтра.", state do
    # Инициализация, состоянеие пустое
    spam_data = GenServer.call(state[:filter], :get_spam_data)
    assert spam_data == []
  end

  test "Базовый сценарий, отправляем два раза подряд сообщение", state do
    # Делаем запрос проверки строки
    res = GenServer.call(state[:filter], {:spam_filter, "Hello"})
    # Отправка сообщения разрешена
    assert res

    # Делаем повторный запрос, не прошло нужное кол-во времени.
    res = GenServer.call(state[:filter], {:spam_filter, "Hello"})
    # Отправка запрещена
    assert res = {false, 0}
  end

  test "Базовый сценарий, отправляем два раза сообщение, с необходимым (1с) ожиданием", state do
    # Делаем запрос проверки строки
    res = GenServer.call(state[:filter], {:spam_filter, "Hello"})
    # Отправка сообщения разрешена
    assert res

    # Ждем нужное кол-во времени, отправляем повторно
    Process.sleep(1100)

    # Делаем повторный запрос, прошло нужное кол-во времени.
    res = GenServer.call(state[:filter], {:spam_filter, "Hello"})
    # Отправка разрешена
    assert res
  end

  test "Базовый сценарий, отправляем два похожих сообщения", state do
    # Делаем запрос проверки строки
    res = GenServer.call(state[:filter], {:spam_filter, "Hello"})
    # Отправка сообщения разрешена
    assert res

    # Делаем другой запрос проверки строки
    res = GenServer.call(state[:filter], {:spam_filter, "Hello2"})

    # Отправка сообщения запрещена (сообщения схожи между собой)
    assert res == {false, 0}

    # Делаем запрос проверки строки
    res = GenServer.call(state[:filter], {:spam_filter, "Hello"})
    # Отправка сообщения запрещена
    assert res == {false, 0}

    # Делаем другой запрос проверки строки
    res = GenServer.call(state[:filter], {:spam_filter, "Hello2"})
    # Отправка сообщения запрещена
    assert res == {false, 0}
  end

  test "Базовый сценарий, отправляем два разных сообщения", state do
    # Делаем запрос проверки строки
    res = GenServer.call(state[:filter], {:spam_filter, "Hello"})
    # Отправка сообщения разрешена
    assert res

    # Делаем другой запрос проверки строки
    res = GenServer.call(state[:filter], {:spam_filter, "Holle"})
    # Отправка сообщения разрешена
    assert res
  end

  test "Базовый сценарий, отправляем два одинаковых сообщения, не дождавшись таймаута", state do
    # Делаем запрос проверки строки
    res = GenServer.call(state[:filter], {:spam_filter, "Hello"})
    # Отправка сообщения разрешена
    assert res

    # Ждем 500 мс
    Process.sleep(500)

    # Делаем запрос проверки строки
    res = GenServer.call(state[:filter], {:spam_filter, "Hello"})

    # Отправка сообщения запрещена, не прошло нужное кол-во времени
    assert res = {false, 500}

    # Ждем 500 мс
    Process.sleep(500)

    # Делаем запрос проверки строки
    res = GenServer.call(state[:filter], {:spam_filter, "Hello"})
    # Отправка сообщения разрешена
    assert res
  end
end
