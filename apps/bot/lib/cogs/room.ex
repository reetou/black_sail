defmodule Bot.Cogs.Room do

  alias Bot.{Helpers, PartySearchParticipants}
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
  @command "room"
  @category_name "личные комнаты"


  @impl true
  def usage,
      do: [
        "!#{@command} @zae @BlackSail @AnotherFriend",
      ]

  @impl true
  def description,
      do: """
      ```
      Создает личную комнату на количество человек, упомянутых в команде

      #{Enum.reduce(usage, "Примеры использования:", fn text, acc -> acc <> "\n" <> text end)}

        Работает только в канале #{@channel_name}
      ```
      """

  def success_message(%Invite{ channel: %{ name: name }, code: code } = invite, msg) do
    """
<@#{msg.author.id}>, для тебя и твоих друзей была создана комната **#{name}**!
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
  def command(msg, args) when length(args) == 0 or args == nil do
    Helpers.reply_and_delete_message(msg.channel_id, """
<@#{msg.author.id}>, нельзя быть таким эгоистом и создавать комнату лишь для себя.

Примеры использования:
#{Enum.reduce(usage, "", fn e, acc -> acc <> "\n" <> e end)}
""")
  end

  @impl true
  def command(%Message{ guild_id: guild_id, channel_id: channel_id, author: %{ username: username, discriminator: discriminator } } = msg, args) do
    IO.inspect(args, label: "RECEIVED COMMAND ROOM WITH ARGS")
    with {:ok, channels} <- Api.get_guild_channels(guild_id),
         {:ok} <- delete_old_user_channels(guild_id, msg.author.id),
         {:ok, %{ id: everyone_role_id }} = Converters.to_role("@everyone", guild_id) do
      overwrites = [
        %{
          id: everyone_role_id,
          type: "role",
          deny: Permission.to_bitset([:connect, :speak])
        },
        %{
          id: msg.author.id,
          type: "member",
          allow: Permission.to_bitset([:connect, :speak])
        }
      ] ++ get_members_overwrites_from_args(guild_id, args) ++ get_roles_overwrites_from_args(guild_id, args)
        channel_name = channel_name_for_user(username <> "#" <> discriminator)
        %Channel{id: parent_id} = get_or_create_parent_category(guild_id)
        {:ok, created_channel} = Api.create_guild_channel(
          guild_id,
          [
            name: channel_name,
            type: Helpers.voice_channel_type,
            permission_overwrites: overwrites,
            parent_id: parent_id,
          ]
        )
        invite = Api.create_channel_invite!(created_channel.id, max_age: 3600)
        Helpers.reply_and_delete_message(msg.channel_id, success_message(invite, msg), 15000)
    else
      err ->
        IO.inspect(err, label: "Cannot get channels for guild #{guild_id}")
        Helpers.reply_and_delete_message(channel_id, "Не получилось создать канал. Обратитесь к админам")
    end
  end

  defp get_members_overwrites_from_args(guild_id, args) do
    args
    |> Enum.map(fn possible_user_mention ->
      with {:ok, member} <- Converters.to_member(possible_user_mention, guild_id) do
        %{
          id: member.user.id,
          type: "member",
          allow: Permission.to_bitset([:connect, :speak])
        }
      else
        _err -> nil
      end
    end)
    |> Enum.filter(fn o -> o != nil end)
  end

  defp get_roles_overwrites_from_args(guild_id, args) do
    args
    |> Enum.map(fn possible_role_mention ->
      with {:ok, role} <- Converters.to_role(possible_role_mention, guild_id) do
        %{
          id: role.id,
          type: "role",
          allow: Permission.to_bitset([:connect, :speak])
        }
      else
        _err -> nil
      end
    end)
    |> Enum.filter(fn o -> o != nil end)
  end

  defp delete_old_user_channels(guild_id, user_id) do
    {
      :ok,
      %Member{
        user: %{
          username: username,
          discriminator: discriminator
        }
      } = member
    } = Converters.to_member("<@#{user_id}>", guild_id)
    Api.get_guild_channels!(guild_id)
    |> Enum.filter(fn %{name: name} -> name == channel_name_for_user(username <> "#" <> discriminator) end)
    |> Enum.each(fn %{id: id} -> Api.delete_channel(id, "Deleting duplicate") end)
    {:ok}
  end

  def channel_name_for_user(username_with_discriminator) do
    "Рума #{username_with_discriminator}"
  end

  defp get_or_create_parent_category(guild_id) do
    parent_category = Api.get_guild_channels!(guild_id)
                      |> Enum.find(fn x -> x.name == @category_name end)
    case parent_category do
      %Channel{} = channel -> channel
      err ->
        IO.inspect(err, label: "Unable to find such channel")
        Api.create_guild_channel!(guild_id, name: @category_name, type: 4)
    end
  end
end
