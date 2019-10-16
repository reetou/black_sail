defmodule Bot.Cogs.Admin.Reinit do

  alias Bot.Cogs.{
    Register,
    Party,
    Admin,
    Room,
  }
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
  require Logger

  @moduledoc """
    Пересоздает канал с нуля
  """
  @behaviour Nosedrum.Command
  @command "admin remove_all_roles"

  @impl true
  def usage,
      do: [
        "!#{@command}",
      ]

  @impl true
  def description,
      do: """
      ```
      Удаляет все роли на сервере, на которые есть права
      Удаляет все каналы на сервере, кроме текущего и канала логов
      Пересоздает нужные комнаты и переназначает права для ролей: @everyone, Войс мут и других

      #{Enum.reduce(usage, "Примеры использования:", fn text, acc -> acc <> "\n" <> text end)}
      ```
      """

  def success_message(msg) do
    """
    <@#{msg.author.id}>, реинициация канала прошла успешно
    """
  end

  @impl true
  def predicates,
      do: [
        &CustomPredicates.guild_only/1,
        CustomPredicates.has_permission(:administrator),
        CustomPredicates.bot_has_permission(:administrator),
        &CustomPredicates.is_zae/1,
      ]

  def command, do: @command

  @impl true
  def command(%Message{ guild_id: guild_id, channel_id: channel_id} = msg, args) do
    Admin.RemoveAllChannels.command(msg, args)
    Admin.RemoveAllRoles.command(msg, args)
    Helpers.reply_and_delete_message(channel_id, "<@#{msg.author.id}>, начинаю пересоздавать все комнаты...", 300000)
    reinit(msg)
  end

  def reinit(%{ guild_id: guild_id } = msg) do


    Bot.Infractions.create_restricted_roles(guild_id)

    applying_restricted_roles = Task.async(fn ->
      with {:ok, channels} <- Api.get_guild_channels(guild_id) do
        Logger.info("Applying restricted roles\' permissions for channels...")
        Helpers.apply_permissions_for_infraction_roles(channels, guild_id)
      else
        err ->
          Logger.error("Cannot apply restricted roles permissions")
          err
          |> IO.inspect(label: "Cannot get channels for guild #{guild_id}")
      end
    end)

    modifying_everyone_role = Task.async(fn ->
      {:ok, role} = Converters.to_role("@everyone", guild_id)
      opts = [
        permissions: Nostrum.Permission.to_bitset([
          :attach_files,
          :send_messages,
          :read_message_history,
          :use_external_emojis,
          :view_channel,
          :add_reactions,
          :speak,
          :connect,
        ]),
      ]
      Logger.info("Modifying roles for guild #{guild_id}")
      Api.modify_guild_role(guild_id, role.id, opts)
    end)

    Logger.info("Ensure that logs channel exists in guild #{guild_id}")
    create_logs_channel = Task.async(fn ->
      {:ok, %{ id: role_id }} = Converters.to_role("@everyone", guild_id)
      overwrites = [
        %{
          id: role_id,
          type: "role",
          deny: Permission.to_bit(:view_channel)
        },
      ]
      Helpers.create_channel_if_not_exists(Helpers.logs_channel, guild_id, 0, overwrites)
    end)

    create_chat_channel = Task.async(fn ->
      Logger.info("Recreating chat_channel channel if not exists")
      with {:ok, %{ id: channel_id }} <- Helpers.create_channel_if_not_exists(Helpers.chat_channel, guild_id, 0) do
        Helpers.set_channel_rate_limit_per_user(channel_id, 5)
      else
        err ->
          Logger.error("Cannot recreate channel for chat_channel, #{err}")
          err
      end
    end)

    create_commands_channel = Task.async(fn ->
      Logger.info("Recreating create_commands_channel if not exists")
      with {:ok, %{ id: channel_id }} <- Helpers.create_channel_if_not_exists(Helpers.commands_channel, guild_id, 0) do
        Helpers.set_channel_rate_limit_per_user(channel_id, 5)
      else
        err ->
          Logger.error("Cannot recreate channel for commands_channel, #{err}")
          err
      end
    end)

    create_admin_contact_channel = Task.async(fn ->
      Logger.info("Recreating contact admin channel if not exists")
      with {:ok, %{ id: channel_id }} <- Helpers.create_channel_if_not_exists(Helpers.contact_admin_channel, guild_id, 0) do
        Helpers.set_channel_rate_limit_per_user(channel_id, 180)
      else
        err ->
          Logger.error("Cannot recreate channel for contact_admin_channel, #{err}")
          err
      end
    end)

    create_party_channel = Task.async(fn ->
      Logger.info("Recreate channel for party command in guild #{guild_id}")
      with {:ok, %{ id: channel_id }} <- Party.recreate_channel(guild_id) do
        Task.start(fn ->
          Helpers.set_channel_rate_limit_per_user(channel_id)
        end)
      else
        err ->
          Logger.error("Cannot recreate channel for Party, #{err}")
          err
      end

      Logger.info("Recreate channel for register command in guild #{guild_id}")
      with {:ok, %{ id: channel_id }} <- Register.recreate_channel(guild_id) do
        Task.start(fn ->
          Helpers.set_channel_rate_limit_per_user(channel_id, 30)
        end)
      else
        err ->
          Logger.error("Cannot recreate channel for Register, #{err}")
          err
      end

      Logger.info("Recreating rules channel in guild #{guild_id}")
      Helpers.ensure_rules_message_exists(guild_id)

      Logger.info("Recreating roles for guild #{guild_id}")
      Register.recreate_roles(guild_id)
    end)

    Task.await(applying_restricted_roles)
    Task.await(modifying_everyone_role)
    Task.await(create_logs_channel)
    Task.await(create_commands_channel)
    Task.await(create_party_channel)
    Bot.Infractions.set_restricted_roles_positions(guild_id)
    Bot.Infractions.send_to_log(success_message(msg), guild_id)

  end
end
