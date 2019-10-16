defmodule Bot.Cogs.Rooms.Purge do

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
  @command "rooms purge"

  @impl true
  def usage,
      do: [
        "!#{@command}",
      ]

  @impl true
  def description,
      do: """
      ```
      Удаляет пустые личные комнаты

      #{Enum.reduce(usage, "Примеры использования:", fn text, acc -> acc <> "\n" <> text end)}
      ```
      """

  @impl true
  def predicates,
      do: [
        &CustomPredicates.guild_only/1,
        CustomPredicates.has_permission(:manage_channels),
        CustomPredicates.bot_has_permission(:manage_channels)
      ]

  def command, do: @command

  @impl true
  def command(%Message{ guild_id: guild_id, channel_id: channel_id } = msg, args) do
    with {:ok, %{ channels: channels }} <- GuildCache.get(guild_id) do
      Room.remove_guild_personal_channels(guild_id, channels)
      Helpers.reply_and_delete_message(channel_id, "<@#{msg.author.id}>, команда успешно выполнена", 10000)
    else
      err ->
        err |> IO.inspect(label: "Error at clear rooms")
        Helpers.reply_and_delete_message(
          channel_id,
          "<@#{msg.author.id}>, не удалось очистить пустые личные комнаты, попробуйте позднее или обратитесь к админам",
          60000
        )
    end
  end
end
