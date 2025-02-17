defmodule Bot.Cogs.Admin.Stats do

  alias Bot.{
    Helpers,
    PartySearchParticipants,
    VoiceMembers,
    Stats,
  }
  alias Nosedrum.{
    Predicates,
    Converters,
    }
  alias Bot.Predicates, as: CustomPredicates
  alias Nostrum.Api
  alias Nostrum.Struct.{
    Embed,
    Guild,
    Channel,
    Invite,
    Message,
    }
  alias Nostrum.Cache.GuildCache
  alias Guild.Member
  alias Nostrum.Permission
  import Embed
  import Application
  require Logger

  @moduledoc """
    Sends party message
  """
  @behaviour Nosedrum.Command

  @channel_name "сервер"
  @command "room"
  @category_name "личные комнаты"

  def highcharts_settings(type, guild, series) do
    date_format = if type == :month, do: "{0M}.{YYYY}", else: "{YYYY} год"
    %{
      type: "png",
      scale: 3,
      infile: %{
        chart: %{
          type: "areaspline",
          backgroundColor: "transparent",
        },
        legend: %{
          layout: "vertical",
          align: "left",
          verticalAlign: "top",
          x: 50,
          y: 80,
          floating: true,
          borderWidth: 0,
          borderRadius: 10,
          backgroundColor: "#202225",
          plotBackgroundColor: "#333666",
          itemStyle: %{
            color: "#FFF",
          },
        },
        labels: %{
          style: %{
            color: "#E7E8E8",
          },
        },
        title: %{
          text: Timex.lformat!(Date.utc_today, "Данные сервера #{guild.name} за #{date_format}", "ru"),
          style: %{
            color: "#E7E8E8",
          },
        },
        subtitle: %{
          text: "Бот записывает каждый вход/выход пользователя с сервера",
          style: %{
            color: "#E7E8E8",
          },
        },
        xAxis: %{
          title: %{
            text: (if type == :month, do: "День месяца", else: "Месяц"),
            style: %{
              color: "#E7E8E8",
              fontWeight: "bold",
            },
          },
          labels: %{
            style: %{
              color: "#E7E8E8",
            },
          },
          categories: Stats.categories(type),
        },
        yAxis: %{
          title: %{
            text: "Уникальных пользователей",
            style: %{
              color: "#E7E8E8",
              fontWeight: "bold",
            },
          },
        },
        credits: %{ enabled: false },
        colors: ["#43B581", "#F04747"],
        series: series,
      }
    }
  end

  def channel_name, do: @channel_name

  @impl true
  def usage,
      do: [
        "!#{@command} year",
        "!#{@command} month",
        "!#{@command} week",
      ]

  @impl true
  def description,
      do: """
      ```
      Отправляет в чат статистику сервера за последний промежуток времени
      ```
      """


  @impl true
  def predicates, do: [
                    &CustomPredicates.guild_only/1,
                    CustomPredicates.has_permission(:administrator),
  ]

  def command(msg, args) when length(args) > 0 do
    IO.inspect(msg.guild_id, label: "Guild id")
    case List.first(args) do
      "year" -> stats(msg.guild_id, :year, msg.channel_id)
      "month" -> stats(msg.guild_id, :month, msg.channel_id)
      _ -> Helpers.reply_and_delete_message(msg.channel_id, "<@#{msg.author.id}>, неизвестный тип статистики")
    end
  end

  def command(msg, _args) do
    Helpers.reply_and_delete_message(msg.channel_id, "<@#{msg.author.id}>, нужно указать тип статистики: year или month", 20000)
  end

  def stats(guild_id, type, channel_id) do
    series = Stats.get_income_outcome_stats(guild_id, type)
           |> IO.inspect(label: "DATA FORMATTED FOR REQUEST")
    {:ok, guild} = GuildCache.get(guild_id)
    settings = highcharts_settings(type, guild, series)
    encoded = Jason.encode!(settings)
    response = HTTPoison.post!(fetch_env!(:bot, :stats_server_url), encoded, [{"Content-Type", "application/json"}])
    unless channel_id == nil do
      send_stats(%{ body: response.body, name: "stats.png" }, channel_id)
    else
      Bot.Infractions.send_to_log("Не указан канал для отправки статистики", guild_id)
    end
  end

  def send_stats(file, channel_id) when is_map(file) do
    Api.create_message(channel_id, file: file)
  end

  def stats_for_servers do
    Logger.debug("Getting stats for servers...")
    GuildCache.all
    |> Enum.map(fn %{id: guild_id, channels: channels, name: name} ->
      chan_name = Helpers.logs_channel
      Logger.debug("Looking for channel name #{chan_name} in guild #{name}")
      case Enum.find(channels, fn {channel_id, ch} -> ch.name == Helpers.logs_channel end) do
        nil ->
          Logger.debug("No channel #{chan_name} for guild #{name}, id: #{guild_id}, ignoring getting stats for server")
          Bot.Infractions.send_to_log("Не найден канал #{chan_name}, не могу запостить регулярную статистику", guild_id)
        {channel_id, chan} ->
          Logger.debug("Found channel #{chan_name}")
          IO.inspect(guild_id, label: "Guild id")
          IO.inspect(channel_id, label: "CHAN ID")
          stats(guild_id, :month, channel_id)
      end
    end)
  end

end
