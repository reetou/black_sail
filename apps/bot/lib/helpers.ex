defmodule Bot.Helpers do

  alias Nostrum.{
    Api,
    Struct.User,
    Struct.Embed,
    Struct.Guild.Member,
    Permission,
  }
  import Embed
  alias Nosedrum.{Converters}
  alias Bot.Cogs.{
    Party,
    Register,
    Room,
    Update,
    Elo,
    Kick,
    Add,
    Remove,
  }
  require Logger

  @errors_channel "errors"
  @logs_channel "logs"
  @rules_channel "правила"
  @game_channel_prefix "Канал пати"
  @rules_title "Правила очень простые:"
  @commands_channel "команды"
  @contact_admin_channel "админ-чат"
  @get_started_channel "с-чего-начать"
  @greetings_channel "приветствия"
  @chat_channel "общий-чат"
  @mee6_role "MEE6"
  @rules_text """
1. Не быть мудаком
2. Не оскорблять других людей и их родителей
3. Не спамить и не рекламировать
4. Не присваивать чужое
5. Не обходить наказания
"""
  @get_started_messages [
  """
Йоу! Чтобы начать искать пати и тусить, начни с прочтения самого последнего сообщения в канале #{"#" <> @rules_channel}, там есть все нужные команды для тебя
Самое первое, что ты захочешь использовать - !#{Party.command} в канале #{"#" <> Party.search_channel}. Вперед!
""",
"""
Қайырлы кеш! Если хочешь поискать пати, заходи сюда: #{"#" <> Party.search_channel}, пообщаться сюда: #{"#" <> @chat_channel}
Все остальное в правилах: #{"#" <> @rules_channel}
""",
"""
**RUSH B DONT STOP**
Поиск пати для игры: #{"#" <> Party.search_channel}, поболтать - сюда: #{"#" <> @chat_channel}
Все остальное в правилах: #{"#" <> @rules_channel}
""",
"""
**AWP PLS**
Поиск пати для игры: #{"#" <> Party.search_channel}
Поболтать: #{"#" <> @chat_channel}
Все остальное в правилах: #{"#" <> @rules_channel}
""",
"""
**рУсСкиЕ ЕстЬ??77**
Найти команду: #{"#" <> Party.search_channel}
Покумекать: #{"#" <> @chat_channel}
Все остальное в правилах: #{"#" <> @rules_channel}
""",
"""
**АЙ СМОУК МИД**
Найти команду: #{"#" <> Party.search_channel}
Поговорить: #{"#" <> @chat_channel}
Все остальное в правилах: #{"#" <> @rules_channel}
""",
  ]
  @onboarding_text """
Так как вы сэкономили время на прочтении правил, посмею украсть оставшиеся секунды на краткий гайд по командам сервера:

!help - показать подробную информацию по всем командам

!room - создает личную комнату, куда только у вас есть доступ. Вы можете мутить участников своей комнаты.

!add - разрешает упомянутым людям заходить в вашу комнату

!remove - забирает право у упомянутых заходить в вашу комнату

!party - отправить сообщение о поиске со свободным входом. Можно добавить комментарий после команды

!elo - отправить сообщение о поиске с ограничением по эло. Можно указать ограничение поменьше, смотрите в !help за подробностями

!register - внести свой ник на FaceIT в базу бота, чтобы накидать вам ролей в зависимости от ваших статов

!update - обновить данные с сайта FaceIT

За подробностями смотрите в !help
"""
  @faq_text """
*Как зарегистрировать свой ник на FaceIT в боте?*

- Перейдите в канал #{"#" <> Register.stats_channel} и введите команду !#{Register.command} ваш_ник_на_FaceIT

Если у вас уже был зарегистрированный ник в боте до этого, он будет заменен новым.

*Как обновить статы и получить роль ELO*

- Перейдите в канал #{"#" <> Register.stats_channel} и введите команду !#{Update.command} ваш_ник_на_FaceIT

*Как найти пати?*

- Перейдите в канал #{"#" <> Party.search_channel} и введите команду !#{Party.command}

*Но я хочу найти пати с эло как у меня!*

- Тогда в канале #{"#" <> Party.search_channel} введи команду !#{Elo.command}

*Чувак залетел в канал и поливает нас всех гадостями и включает музыку!*

- Если это ваш личный канал или канал вашей пати, вы можете использовать команду !#{Kick.command}

*Хочу добавить друга в свою личную комнату*

- Что ж, !#{Add.command}

*Не хочу, чтобы определенный человек заходил ко мне в руму*

- !#{Remove.command}

"""
  @special_channels [Party.search_channel, Register.stats_channel, @logs_channel, @errors_channel, @rules_channel]

  def errors_channel, do: @errors_channel

  def logs_channel, do: @logs_channel

  def game_channel_prefix, do: @game_channel_prefix

  def commands_channel, do: @commands_channel

  def contact_admin_channel, do: @contact_admin_channel

  def get_started_channel, do: @get_started_channel

  def chat_channel, do: @chat_channel

  def voice_channel_type, do: 2

  def greet_user(user_id, guild_id) do
    Logger.debug("Gonna greet user")
    with {:ok, %{ id: reply_channel_id }} <- Converters.to_channel(@chat_channel, guild_id) do
      channels_to_replace = [
        @chat_channel,
        @get_started_channel,
        @commands_channel,
        @contact_admin_channel,
        @rules_channel,
        Party.search_channel,
        Register.stats_channel,
      ]
      greet_message =
        channels_to_replace
        |> Enum.reduce(Enum.random(@get_started_messages), fn name, acc ->
          with {:ok, %{ id: id }} <- Converters.to_channel(name, guild_id) do
            String.replace(acc, "#" <> name, "<#" <> "#{id}>")
          else _ -> acc
          end
        end)
      Api.create_message(reply_channel_id, content: "<@#{user_id}>\n" <> greet_message)
    else
      err ->
        Logger.error("Cannot greet user")
        IO.inspect(err, label: "Greet user error")
    end
  end

  def allow_speak_and_connect(type) when is_atom(type), do: %{
    type: Atom.to_string(type),
    allow: Permission.to_bitset([:connect, :speak])
  }

  def deny_speak_and_connect(type) when is_atom(type), do: %{
    type: Atom.to_string(type),
    deny: Permission.to_bitset([:connect, :speak])
  }

  def channel_name_to_mention(channel_name, guild_id) do
    with {:ok, %{ id: id }} <- Converters.to_role(channel_name, guild_id) do
      "<#" <>"#{id}>"
    else _ -> channel_name
    end
  end

  def allow_manage_voice_channel(type) when is_atom(type), do: %{
    type: Atom.to_string(type),
    allow: Permission.to_bitset([:connect, :speak, :mute_members, :deafen_members, :move_members])
  }

  def restricted_roles_perms, do: %{
    Bot.Infractions.Hopper.role_name => Permission.to_bitset([:attach_files, :send_messages, :add_reactions])
  }

  def restricted_roles do
    [
      {
        Bot.Infractions.Hopper.role_name,
        %{
          type: "role",
          deny: Permission.to_bitset([:connect, :speak, :view_channel])
        }
      }
    ]
  end

  def special_channel_permission_overwrites(role_id) do
    [
      %{ id: role_id, type: "role", deny: Permission.to_bitset([:attach_files, :embed_links, :send_tts_messages, :mention_everyone]) },
    ]
  end

  def infraction_roles_permission_overwrites(guild_id) do
    restricted_roles
    |> Enum.map(fn {name, map} ->
      {:ok, %{ id: id }} = Converters.to_role(name, guild_id)
      Map.put(map, :id, id)
    end)
  end

  def mee6_permissions_overwrites(guild_id) do
    case Converters.to_role(@mee6_role, guild_id) do
      {:ok, role} -> List.wrap(%{ id: role.id, deny: Permission.to_bitset([:send_messages]), type: "role" })
      _ -> []
    end
  end

  def create_channel_if_not_exists(channel_name, guild_id, type \\ 0, permission_overwrites \\ []) do
    overwrites = permission_overwrites ++ mee6_permissions_overwrites(guild_id)
    case Converters.to_channel(channel_name, guild_id) do
      {:error, _} ->
        Api.create_guild_channel(guild_id, name: channel_name, type: type, permission_overwrites: overwrites)
      {:ok, %{ id: id }} -> Api.modify_channel(id, permission_overwrites: overwrites, type: type, name: channel_name)
    end
  end

  def delete_game_channels_without_parent(guild_id) do
    with {:ok, channels} = Api.get_guild_channels(guild_id) do
      channels
      |> Enum.filter(fn ch ->
        case ch.name do
          @game_channel_prefix <> _other -> ch.parent_id == nil
          _ -> false
        end
      end)
      |> Enum.map(fn ch -> Api.delete_channel(ch.id, "Deleting game channel without parent") end)
    else err -> IO.inspect(err, label: "Cannot delete game channels without parent")
    end
  end

  def get_user_avatar_by_user_id(user_id) do
    case Nostrum.Cache.UserCache.get(user_id) do
      {:ok, %User{} = user} -> User.avatar_url(user, "gif")
      _ -> nil
    end
  end

  def reply_and_delete_message(channel_id, text, delete_after \\ 5000) do
    Task.start(fn ->
      reply = Api.create_message!(channel_id, text)
      Process.sleep(delete_after)
      Api.delete_message(reply.channel_id, reply.id)
    end)
  end

  def is_in_voice_channel?(user_id) do
    case Bot.VoiceMembers.get_channel_members_by_user_id(user_id) do
      x when is_list(x) and length(x) > 0 -> true
      _ -> false
    end
  end

  def delete_casual_message_from_special_channel(%{ guild_id: guild_id, channel_id: channel_id } = msg) when guild_id != nil do
    with {:ok, %{ name: name }} when name in @special_channels <- Converters.to_channel("#{channel_id}", guild_id) do
      Api.delete_message(channel_id, msg.id)
    end
  end
  def delete_casual_message_from_special_channel(_msg), do: nil

  def ensure_rules_message_exists(guild_id) do
    with {:ok, channel} <- Converters.to_channel(@rules_channel, guild_id) do
      Api.delete_channel(channel.id, "Recreating rules")
    end
    {:ok, role} = Converters.to_role("@everyone", guild_id)
    opts = [
      name: @rules_channel,
      type: 0,
      permission_overwrites: [
        %{
          type: "role",
          id: role.id,
          deny: Permission.to_bit(:send_messages)
        }
      ]
    ]
    {:ok, channel} = Api.create_guild_channel(guild_id, opts)
    embed = %Embed{}
            |> put_description(@rules_text)
            |> put_color(0x9768d1)
            |> put_timestamp(DateTime.utc_now())
    onboarding_embed = %Embed{}
            |> put_description(@onboarding_text)
            |> put_color(0x43b581)
            |> put_footer("Счастья-здоровья и удачи")
    faq_embed = %Embed{}
            |> put_description(@faq_text)
            |> put_color(0x4e7097)
            |> put_footer("Если еще остались вопросы, пиши в админ чат")
    Api.create_message(channel.id, content: @rules_title, embed: embed)
    Api.create_message(channel.id, content: "**КОМАНДЫ**", embed: onboarding_embed)
    Api.create_message(channel.id, content: "**Частые вопросы**", embed: faq_embed)
  end

  def delete_channel_if_exists(channel_name, guild_id) do
    with {:ok, channel} <- Converters.to_channel(channel_name, guild_id) do
      Api.delete_channel(channel.id)
    end
  end

  def create_role_if_not_exists(role_name, guild_id, opts \\ []) do
    with {:error, _} <- Converters.to_role(role_name, guild_id) do
      IO.inspect(role_name, label: "Creating role")
      Api.create_guild_role(guild_id, [name: role_name] ++ opts)
    end
  end

  def apply_permissions_for_infraction_roles(channels, guild_id) do
    restricted_roles
    |> Enum.each(fn { role_name, permission_info } ->
      with {:ok, role} <- Converters.to_role(role_name, guild_id) do
        channels
        |> Enum.filter(fn %{ name: name } -> name not in @special_channels end)
        |> Enum.each(fn %{ id: id, name: name } ->
          case Api.edit_channel_permissions(id, role.id, permission_info) do
            {:ok} -> IO.inspect(permission_info, label: "Successfully edited permissions for role #{role_name} in channel #{name}")
            {:error, %{ status_code: 404 }} -> IO.puts("Cannot edit channel permissions because it is already deleted")
            err -> err |> IO.inspect(label: "Cannot edit channel permissions: #{id} #{name}")
          end
        end)
      else
        err ->
          Logger.error("Cannot edit permissions for role #{role_name}")
          err
      end
    end)
  end

  def set_channel_rate_limit_per_user(channel_id, rate_limit_seconds \\ 60) do
    Api.request("PATCH", "/channels/#{channel_id}", %{ rate_limit_per_user: rate_limit_seconds })
  end

  def get_guild_roles_by_id!(roles, guild_id) do
    roles
    |> Enum.map(
         fn r ->
           with {:ok, role} <- Converters.to_role("<@&#{r}>", guild_id) do
             role
           else
             err -> nil
           end
         end
       )
    |> Enum.filter(fn x -> x != nil end)
#    |> IO.inspect(label: "Roles from guild by id")
  end

  def get_guild_roles_by_name!(roles, guild_id) do
    roles
    |> Enum.map(
         fn r ->
           with {:ok, role} <- Converters.to_role(r, guild_id) do
             role
           else
             err -> nil
           end
         end
       )
    |> Enum.filter(fn x -> x != nil end)
  end



  def get_user_current_personal_or_party_voice_channel(user_id, guild_id) do
    with channel_id when channel_id != nil <- Bot.VoiceMembers.get_channel_id_by_user_id(user_id),
         {:ok, channel} <- Converters.to_channel("#{channel_id}", guild_id),
         {
           :ok,
           %Member{
             user: %{
               username: username,
               discriminator: discriminator
             }
           }
         } <- Converters.to_member("<@#{user_id}>", guild_id) do
      personal_channel_name = Room.channel_name_for_user(username <> "#" <> discriminator)
      party_channel_name = Party.get_channel_name_for_member(username <> "#" <> discriminator)
      case channel.name do
        x when x == personal_channel_name -> {:ok, channel}
        x when x == party_channel_name -> {:ok, channel}
        _ -> {:error, :not_in_own_channel}
      end
    else
      z -> {:error, :not_in_own_channel}
    end
  end
end
