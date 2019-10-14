defmodule Bot.Cogs.Room do

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
<@#{msg.author.id}>, для тебя и твоих друзей (если ты их указал) была создана комната **#{name}**!
Перейти: https://discord.gg/#{code}

Комната будет удалена в полночь, если будет пустовать.

Береги ее и люби.
"""
  end

  @impl true
  def predicates, do: [&CustomPredicates.guild_only/1, &CustomPredicates.is_commands_channel?/1]

  def command, do: @command
  def channel_name, do: @channel_name
  def category_name, do: @category_name

  @impl true
  def command(%Message{ guild_id: guild_id, channel_id: channel_id, author: %{ username: username, discriminator: discriminator } } = msg, args) do
    with {:ok, channels} <- Api.get_guild_channels(guild_id),
         {:ok, %{ id: everyone_role_id }} <- Converters.to_role("@everyone", guild_id) do
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
        create_invite_task = Task.async(fn -> Api.create_channel_invite!(created_channel.id, max_age: 3600) end)
        Task.start(fn ->
          delete_old_user_channels(guild_id, msg.author.id, [created_channel.id])
        end)
        Helpers.reply_and_delete_message(msg.channel_id, "<@#{msg.author.id}>, йоу, комната создана, делаю инвайт...", 5000)
        invite = Task.await(create_invite_task)
        Helpers.reply_and_delete_message(msg.channel_id, success_message(invite, msg), 15000)
    else
      err ->
        IO.inspect(err, label: "Cannot get channels for guild #{guild_id}")
        Helpers.reply_and_delete_message(channel_id, "Не получилось создать канал. Обратитесь к админам")
    end
  end

  def get_members_overwrites_from_args(guild_id, args) do
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

  def get_roles_overwrites_from_args(guild_id, args) do
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

  defp delete_old_user_channels(guild_id, user_id, exceptions \\ []) do
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
    |> Enum.filter(fn %{id: id} -> id not in exceptions end)
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

  def remove_guild_personal_channels(guild_id, channels) do
    Task.start(fn ->
      Bot.Infractions.send_to_log("Очищаю пустые каналы в категории **#{@category_name}**...", guild_id)
    end)
    channels
    |> Enum.map(fn {id, %{name: name}} -> name end)
    |> IO.inspect(label: "Channels in guild #{guild_id}")
    parent = channels
             |> Enum.map(fn t -> elem(t, 1) end)
             |> Enum.filter(fn %{type: type} -> type == 4 end)
             |> Enum.find(fn %{name: name} -> name == @category_name end)
    case parent do
      %Channel{} ->
        deleted_channels =
          channels
          |> Enum.map(fn t -> elem(t, 1) end)
          |> Enum.filter(fn ch -> ch.parent_id == parent.id end)
          |> Enum.filter(fn ch -> VoiceMembers.is_voice_channel_empty?(ch.id, guild_id) end)
          |> Enum.map(
               fn ch ->
                 case Api.delete_channel(ch.id, "Deleting empty duplicate") do
                   {:ok, _} -> ch.name
                   res -> res
                          |> IO.inspect(label: "Result")
                          nil
                 end
               end
             )
          |> Enum.filter(fn ch -> ch !== nil end)
          |> IO.inspect(label: "Deleted channels")
        unless length(deleted_channels) == 0 do
          Task.start(
            fn ->
              deleted_channels_names = Enum.reduce(
                deleted_channels,
                "\n",
                fn name, acc -> acc <> "\n" <> name end
              )
              Bot.Infractions.send_to_log(
                """
                Удалены пустые каналы в категории **#{@category_name}**:
                ```
                #{deleted_channels_names}
                ```
                """,
                guild_id
              )
            end
          )
        else
          Task.start(fn ->
            Bot.Infractions.send_to_log("В категории **#{@category_name}** нет пустых каналов. Ничего не удалено.", guild_id)
          end)
        end
      result ->
        result
        |> IO.inspect(label: "Cannot find parent")
    end
  end

  def remove_personal_channels do
    GuildCache.all
    |> Enum.map(fn %{id: id, channels: channels} -> remove_guild_personal_channels(id, channels) end)
  end

  def get_personal_channel(guild_id, username_with_discriminator) do
    IO.puts("Looking for #{username_with_discriminator}\'s personal channel")
    case Nostrum.Cache.GuildCache.get(guild_id) do
      {:ok, %{ channels: channels }} ->
        channel = channels
        |> Enum.map(fn t -> elem(t, 1) end)
        |> Enum.find(fn %{ name: name } -> name == channel_name_for_user(username_with_discriminator) end)
        unless channel == nil do
          {:ok, channel}
        else
          {:error, :no_channel}
        end
      {:error, reason} ->
        reason
        |> IO.inspect(label: "Cannot get guild from cache")
        {:error, reason}
    end
  end
end
