defmodule Bot.Cogs.Admin.RemoveAllChannels do

  alias Bot.Cogs.Room
  alias Bot.{
    Helpers,
    PartySearchParticipants,
    VoiceMembers,
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

  @moduledoc """
    Удаляет пустые личные комнаты на сервере
  """
  @behaviour Nosedrum.Command
  @command "admin remove_all_channels"

  @impl true
  def usage,
      do: [
        "!#{@command}",
      ]

  @impl true
  def description,
      do: """
      ```
      Удаляет все каналы на сервере

      #{Enum.reduce(usage, "Примеры использования:", fn text, acc -> acc <> "\n" <> text end)}
      ```
      """

  def success_message(channels, msg) do
    """
    <@#{msg.author.id}>, все каналы, кроме текущего и канала для логов, на удаление которых бот имеет права, удалены.

    Список:

    #{Enum.reduce(channels, "", fn ch, acc -> acc <> ch.name <> "\n" end)}
    """
  end

  @impl true
  def predicates, do: [&CustomPredicates.guild_only/1, CustomPredicates.has_permission(:administrator)]

  def command, do: @command

  @impl true
  def command(%Message{ guild_id: guild_id, channel_id: channel_id } = msg, args) do
    with {:ok, %{ channels: channels }} <- GuildCache.get(guild_id) do
      Helpers.reply_and_delete_message(channel_id, "<@#{msg.author.id}>, начинаю удалять все каналы...", 120000)
      response = channels
      |> Enum.filter(fn {id, channel} ->
        id != channel_id and channel.name != Helpers.logs_channel
      end)
      |> Enum.map(fn {id, channel} ->
        with {:ok, deleted_channel} <- Api.delete_channel(channel.id, "Requested by #{msg.author.username}") do
          deleted_channel
        else
          _ -> nil
        end
      end)
      |> Enum.filter(fn ch -> ch != nil end)
      |> success_message(msg)
      Bot.Infractions.send_to_log(response, guild_id)
    else
      err ->
        err |> IO.inspect(label: "Error at clear rooms")
        Helpers.reply_and_delete_message(
          channel_id,
          "<@#{msg.author.id}>, не удалось удалить все каналы.",
          300000
        )
    end
  end
end
