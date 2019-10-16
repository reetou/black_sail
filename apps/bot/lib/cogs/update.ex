defmodule Bot.Cogs.Update do
  @moduledoc """
    Sends party message
  """
  @behaviour Nosedrum.Command

  @stats_channel "статистика"
  @command "update"

  alias Bot.{
    Helpers,
    PartySearchParticipants,
    Cogs.Register,
    }
  alias Bot.Predicates, as: CustomPredicates
  alias Nosedrum.{
    Predicates,
    Converters,
    }
  alias Nostrum.Api
  alias Nostrum.Struct.{
    Embed,
    Guild,
    Channel,
    Invite,
    }
  alias Nostrum.Cache.GuildCache
  alias Guild.Member
  import Embed

  @impl true
  def usage,
      do: [
        "!#{@command}",
      ]

  @impl true
  def description,
      do: """
      ```
        Обновляет данные FaceIT по вашему никнейму, указанному при регистрации (см. !#{Register.command})

        ВАЖНО: Для использования этой команды вам сначала нужно зарегистрировать свой никнейм в нашей базе, введите !help для получения дополнительной информации

#{Enum.reduce(usage, "Примеры использования:", fn text, acc -> acc <> "\n" <> text end)}

        Работает только в канале #{@stats_channel}

      ```
      """

  @impl true
  def predicates, do: [&CustomPredicates.guild_only/1, &CustomPredicates.is_stats_channel?/1]

  def command, do: @command

  @impl true
  def command(%{ guild_id: guild_id, author: %{ id: user_id }, id: msg_id, channel_id: channel_id } = msg, _args) do
    reply = Api.create_message!(channel_id, "Обновляю данные...")
    Bot.FaceIT.update_user(user_id, channel_id, guild_id)
    Api.delete_message(channel_id, reply.id)
  end

end
