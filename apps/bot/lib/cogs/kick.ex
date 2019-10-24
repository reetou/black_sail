defmodule Bot.Cogs.Kick do

  alias Bot.{
    Helpers,
    PartySearchParticipants,
    VoiceMembers,
    Cogs.Room,
    Cogs.Remove,
    Cogs.Party
  }
  alias Nosedrum.{
    Predicates,
    Converters,
  }
  alias Bot.Predicates, as: CustomPredicates
  alias Nostrum.Api
  alias Nostrum.Snowflake
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
  require Logger
  import Embed

  @moduledoc """
    Sends party message
  """
  @behaviour Nosedrum.Command

  @channel_name "команды"
  @command "kick"


  @impl true
  def usage,
      do: [
        "!#{@command} @zae @BlackSail @AnotherFriend",
      ]

  @impl true
  def description,
      do: """
      ```
      Кикает указанных людей из личного канала или канала пати и запрещает им заходить в него
      Если указанные пользователи находятся в этом голосовом канале, выкидывает их из войса.

      **Как разбанить:**

      Если пользователь был кикнут из пати комнаты, комната пати должна быть пересоздана (нужно выйти из нее и ввести команду на создание пати)

      Если пользователь был кикнут из личной комнаты, воспользуйся командой !#{Remove.command}

      #{Enum.reduce(usage, "Примеры использования:", fn text, acc -> acc <> "\n" <> text end)}

        Работает только в канале #{@channel_name}
        **Для использования нужно находиться в личном канале или канале своей пати**
      ```
      """

  def success_message(%Channel{ name: name } = channel, msg) do
    """
    <@#{msg.author.id}>, указанные тобой пользователи были кикнуты из канала **#{name}**
    Они не смогут зайти в него, пока комната не пересоздастся или пока ты не разбанишь их.

    **Как разбанить:**

    Если пользователь был кикнут из пати комнаты, комната пати должна быть пересоздана (нужно выйти из нее и ввести команду на создание пати)

    Если пользователь был кикнут из личной комнаты, воспользуйся командой !#{Remove.command}

    Комната будет удалена в полночь, если будет пустовать, **в этом случае кики тоже обнулятся**.

    Не сердись на ребят.
    """
  end

  @impl true
  def predicates, do: [&CustomPredicates.guild_only/1, &CustomPredicates.is_commands_channel?/1, &CustomPredicates.in_own_voice_channel/1]

  def command, do: @command
  def channel_name, do: @channel_name

  def command(msg, args) when length(args) == 0 do
    Helpers.reply_and_delete_message(msg.channel_id, "<@#{msg.author.id}>, эта команда должна быть вызвана с аргументами. Пример: #{List.first(usage)}", 15000)
    {:error, :not_enough_arguments}
  end

  @impl true
  def command(
        %Message{
          guild_id: guild_id,
          channel_id: reply_channel_id,
          author: %{
            username: username,
            discriminator: discriminator
          }
        } = msg,
        args
      ) do
    with {:ok, %{id: everyone_role_id}} <- Converters.to_role("@everyone", guild_id),
         {:ok, %Channel{} = channel_to_kick_from} <- Helpers.get_user_current_personal_or_party_voice_channel(msg.author.id, guild_id) do
      case Helpers.get_user_current_personal_or_party_voice_channel(msg.author.id, guild_id) do
        {:ok, %Channel{} = channel_to_kick_from} ->
          Room.get_overwrites_ids_from_args(guild_id, args, :member, :deny)
          |> Enum.each(
               fn %{id: overwrite_id, type: type, deny: deny} ->
                 Task.start(
                   fn ->
                     {:ok} =
                       Api.edit_channel_permissions(
                         channel_to_kick_from.id,
                         overwrite_id,
                         %{type: type, deny: deny}
                       )
                       |> IO.inspect(label: "EDITED CHANNEL PERMISSIONS")
                     if type == "member" and Bot.VoiceMembers.get_channel_id_by_user_id(
                       overwrite_id
                     ) == channel_to_kick_from.id do
                       Logger.debug("Kicking user from channel because he is there")
                       Api.modify_guild_member(guild_id, overwrite_id, %{channel_id: nil})
                     else
                       Logger.debug(
                         "Type: #{type} and probably not in that voice channel: #{
                           Bot.VoiceMembers.get_channel_id_by_user_id(overwrite_id)
                         }"
                       )
                     end
                   end
                 )
               end
             )
          Helpers.reply_and_delete_message(reply_channel_id, success_message(channel_to_kick_from, msg), 60000)
          {:ok}
        err -> err
      end
    else
      err ->
        IO.inspect(err, label: "ADD COMMAND: Cannot get channels for guild #{guild_id}")
        case err do
          {:error, :not_in_own_channel} = res ->
            response = "<@#{msg.author.id}>, для использования команды нужно находиться в личном голосовом канале"
            Helpers.reply_and_delete_message(reply_channel_id, response, 15000)
            res
          {:error, :no_channel} = res ->
            response = "<@#{msg.author.id}>, личный канал отсутствует, начните с его создания: !#{Room.command}"
            Helpers.reply_and_delete_message(reply_channel_id, response, 15000)
            res
          err ->
            response = "<@#{msg.author.id}>, не получилось отредактировать канал. Обратитесь к админам"
            Helpers.reply_and_delete_message(reply_channel_id, response)
            {:error, :unknown_error}
        end
    end
  end

  def get_restrictions_overwrites_from_args(guild_id, args) do
    args
    |> Enum.map(fn possible_user_mention ->
      with {:ok, member} <- Converters.to_member(possible_user_mention, guild_id) do
        %{
          id: member.user.id,
          type: "member",
          deny: Permission.to_bitset([:connect, :speak, :view_channel])
        }
      else
        _err -> nil
      end
    end)
    |> Enum.filter(fn o -> o != nil end)
  end

  defp get_channel_to_kick_from(user_id, guild_id, text_channel_id) do
    case Helpers.get_user_current_personal_or_party_voice_channel(user_id, guild_id) do
      {:ok, channel} = res -> res
      {:error, :not_in_own_channel} = res ->
        response = "<@#{user_id}>, Вы находитесь не в личном и не в канале вашей пати, потому не можете кикать"
        Helpers.reply_and_delete_message(text_channel_id, response)
        res
      z ->
        z
        |> IO.inspect(label: "In ensure")
    end
  end
end
