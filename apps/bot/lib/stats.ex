defmodule Bot.Stats do
  use Timex
  require Logger

  def date_to_start_from do
    DateTime.utc_now
    |> Timex.beginning_of_month
  end

  def beginning_of_year do
    DateTime.utc_now
    |> Timex.beginning_of_year
  end

  def pipeline(guild_id, type) when type == :year do
    current_date = Date.utc_today
    [
      %{
        "$match" => %{
          guild_id: guild_id,
          date: %{
            "$gte" => beginning_of_year
          }
        }
      },
      %{ "$project" => %{
          year: %{ "$year" => "$date" },
          month: %{ "$month" => "$date" },
          user_id: 1,
        }
      },
      %{
        "$group" => %{
          _id: "$month",
          users: %{
            "$addToSet" => "$user_id"
          }
        }
      },
      %{
        "$group" => %{
          _id: "$_id",
          count: %{ "$sum" => %{ "$size" => "$users" } }
        }
      },
      %{
        "$sort" => %{
          "_id.month" => 1,
        }
      },
    ]
  end

  def pipeline(guild_id, type) when type == :month do
    current_date = Date.utc_today
    [
      %{ "$match" => %{ guild_id: guild_id, date: %{ "$gte" => date_to_start_from } } },
      %{
        "$project" => %{
          year: %{
            "$year" => "$date"
          },
          month: %{
            "$month" => "$date"
          },
          day: %{
            "$dayOfMonth" => "$date"
          },
          user_id: 1,
        }
      },
      %{
        "$group" => %{
          _id: %{
            year: "$year",
            month: "$month",
            day: "$day"
          },
          users: %{
            "$addToSet" => "$user_id"
          }
        }
      },
      %{
        "$group" => %{
          _id: "$_id",
          count: %{ "$sum" => %{ "$size" => "$users" } }
        }
      },
      %{
        "$sort" => %{
          "_id.month" => 1,
          "_id.day" => 1,
        }
      },
    ]
  end

  def get_income_outcome_stats(guild_id, type \\ :month) do
    joins = Mongo.aggregate(:mongo, "joins", pipeline(guild_id, type))
           |> Enum.to_list()
           |> IO.inspect(label: "Data main")
           |> stats_to_highcharts_data("Пришло", type)
    leaves = Mongo.aggregate(:mongo, "leaves", pipeline(guild_id, type))
           |> Enum.to_list()
           |> IO.inspect(label: "Data main")
           |> stats_to_highcharts_data("Ушло", type)
    [joins, leaves]
  end

  def parse_data(data, type) when type == :month do
    last_day = Timex.days_in_month(Date.utc_today)
    range =
      1..last_day
      |> Enum.map(fn x -> data_for_day(data, x) end)
      |> IO.inspect(label: "Will filled fields")
  end

  def parse_data(data, type) when type == :year do
    1..String.to_integer(Timex.format!(Date.utc_today, "{M}"))
    |> Enum.map(fn x -> data_for_month(data, x) end)
  end

  def day_value(map) do
    map
    |> Map.get("_id")
    |> Map.get("day")
  end

  def month_value(map) do
    map
    |> Map.get("_id")
  end

  def data_for_day(data, day) do
    data_map =
      data
      |> Enum.filter(fn x -> day_value(x) == day end)
      |> Enum.map(fn x -> Map.put(x, "day", day_value(x)) end)
      |> List.first
    unless data_map == nil, do: Map.get(data_map, "count"), else: 0
  end

  def data_for_month(data, month) do
    data_map =
      data
      |> Enum.filter(fn x -> month_value(x) == month end)
      |> Enum.map(fn x -> Map.put(x, "month", month_value(x)) end)
      |> List.first
    unless data_map == nil, do: Map.get(data_map, "count"), else: 0
  end

  defp stats_to_highcharts_data(raw_data, label, type) when is_list(raw_data) do
    %{
      name: label,
      data: parse_data(raw_data, type)
    }
  end

  def categories(type) when type == :month do
    last_day = Timex.days_in_month(Date.utc_today)
    range = Date.range(Timex.beginning_of_month(Date.utc_today), Date.utc_today)
    |> Enum.map(fn x ->
      Timex.lformat!(x, "{D}", "ru")
    end)
  end

  def categories(type) when type == :year do
    months = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]
    current_date = Date.utc_today
    1..String.to_integer(Timex.format!(Date.utc_today, "{M}"))
    |> Enum.map(fn x ->
      Enum.at(months, x - 1)
    end)
  end

end
