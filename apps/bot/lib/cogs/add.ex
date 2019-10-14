defmodule Bot.Cogs.Add do

  alias Bot.{
    Helpers,
    PartySearchParticipants,
    VoiceMembers,
    Cogs.Room,
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
    Sends party message
  """
  @behaviour Nosedrum.Command

  @channel_name "команды"
  @command "add"


  @impl true
  def usage,
      do: [
        "!#{@command} @zae @BlackSail @AnotherFriend",
      ]

  @impl true
  def description,
      do: """
      ```
      Добавляет в список разрешенных пользователей или ролей существующей личной комнаты упомянутых людей

      #{Enum.reduce(usage, "Примеры использования:", fn text, acc -> acc <> "\n" <> text end)}

        Работает только в канале #{@channel_name}
      ```
      """

  def success_message(%Invite{ channel: %{ name: name }, code: code } = invite, msg) do
    """
    <@#{msg.author.id}>, твои друзья были успешно внесены в список разрешенных комнаты **#{name}**!
    Перейти: https://discord.gg/#{code}

    Комната будет удалена в полночь, если будет пустовать.

    Береги ее и люби.
    """
  end

  @impl true
  def predicates, do: [&CustomPredicates.guild_only/1, &CustomPredicates.is_commands_channel?/1]

  def command, do: @command
  def channel_name, do: @channel_name

  @impl true
  def command(%Message{ guild_id: guild_id, channel_id: reply_channel_id, author: %{ username: username, discriminator: discriminator } } = msg, args) do
    with {:ok, %{ id: everyone_role_id }} <- Converters.to_role("@everyone", guild_id),
         {:ok, %Channel{} = personal_channel} <- Room.get_personal_channel(guild_id, username <> "#" <> discriminator) do
      create_invite_task = Task.async(fn -> Api.create_channel_invite!(personal_channel.id, max_age: 1200) end)
      Room.get_members_overwrites_from_args(guild_id, args) ++ Room.get_roles_overwrites_from_args(guild_id, args)
      |> Enum.each(fn %{id: overwrite_id, type: type, allow: allow} ->
        Task.start(fn ->
          {:ok} = Api.edit_channel_permissions(personal_channel.id, overwrite_id, %{ type: type, allow: allow })
          |> IO.inspect(label: "EDITED CHANNEL PERMISSIONS")
        end)
      end)
      Helpers.reply_and_delete_message(reply_channel_id, "<@#{msg.author.id}>, йоу, комната отредактирована, делаю инвайт...", 5000)
      invite = Task.await(create_invite_task)
      Helpers.reply_and_delete_message(reply_channel_id, success_message(invite, msg), 15000)
    else
      err ->
        IO.inspect(err, label: "ADD COMMAND: Cannot get channels for guild #{guild_id}")
        case err do
          {:error, :no_channel} -> Helpers.reply_and_delete_message(reply_channel_id, "<@#{msg.author.id}>, личный канал отсутствует, начните с его создания: !#{Room.command}", 15000)
          _ -> Helpers.reply_and_delete_message(reply_channel_id, "<@#{msg.author.id}>, не получилось отредактировать канал. Обратитесь к админам")
        end
    end
  end
end
