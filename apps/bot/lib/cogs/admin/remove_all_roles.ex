defmodule Bot.Cogs.Admin.RemoveAllRoles do

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
  require Logger

  @moduledoc """
    Удаляет пустые личные комнаты на сервере
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

      #{Enum.reduce(usage, "Примеры использования:", fn text, acc -> acc <> "\n" <> text end)}
      ```
      """

  def success_message(roles, msg) do
    """
    <@#{msg.author.id}>, все роли, на удаление которых бот имеет права, удалены.

    Список:

    #{Enum.reduce(roles, "", fn i, acc -> acc <> i.name <> "\n" end)}
    """
  end

  @impl true
  def predicates,
      do: [
        &CustomPredicates.guild_only/1,
        CustomPredicates.has_permission(:administrator),
        CustomPredicates.bot_has_permission(:administrator)
      ]

  def command, do: @command

  @impl true
  def command(%Message{ guild_id: guild_id, channel_id: channel_id} = msg, args) do
    with {:ok, %{roles: roles}} <- GuildCache.get(guild_id) do
      Helpers.reply_and_delete_message(channel_id, "<@#{msg.author.id}>, начинаю удалять все роли...", 120000)
      reason = "Requested by #{msg.author.username}"
      response =
        roles
        |> Enum.map(
             fn {id, role} ->
               with {:ok} <- Api.delete_guild_role(guild_id, role.id, reason) do
                 role
               else
                 err ->
                   case err do
                     {
                       :error,
                       %Nostrum.Error.ApiError{
                         response: %{
                           code: 50013,
                           message: "Missing Permissions"
                         },
                         status_code: 403
                       }
                     } ->
                       Helpers.reply_and_delete_message(channel_id, "Нет прав на изменение роли #{role.name}. Возможно, нет прав или эта роль выше роли бота")
                       role
                     _ ->
                       IO.inspect(err, label: "Delete role error")
                       unless role.name == "@everyone", do:
                         Logger.error("Cannot delete role #{role.name}")
                       nil
                   end
               end
             end
           )
        |> Enum.filter(fn ch -> ch != nil end)
        |> success_message(msg)
      Bot.Infractions.send_to_log(response, guild_id)
    else
      err ->
        err |> IO.inspect(label: "Error at clear rooms")
        Helpers.reply_and_delete_message(
          channel_id,
          "<@#{msg.author.id}>, не удалось удалить все роли.",
          300000
        )
    end
  end
end
