defmodule Bot.Helpers do

  alias Nostrum.{
    Api,
    Struct.User,
    Struct.Embed,
    Permission,
  }
  import Embed
  alias Nosedrum.{Converters}
  alias Bot.Cogs.{Party, Register}

  @errors_channel "errors"
  @logs_channel "logs"
  @rules_channel "правила"
  @game_channel_prefix "Канал пати"
  @rules_title "Правила очень простые:"
  @commands_channel "команды"
  @rules_text """
1. Не быть мудаком
2. Не оскорблять других людей и их родителей
3. Не спамить и не рекламировать
4. Не присваивать чужое
5. Не обходить наказания
"""
  @special_channels [Party.search_channel, Register.stats_channel, @logs_channel, @errors_channel, @rules_channel]

  def errors_channel, do: @errors_channel

  def logs_channel, do: @logs_channel

  def game_channel_prefix, do: @game_channel_prefix

  def commands_channel, do: @commands_channel

  def voice_channel_type, do: 2

  def allow_speak_and_connect(type) when is_atom(type), do: %{
    type: Atom.to_string(type),
    allow: Permission.to_bitset([:connect, :speak])
  }

  def deny_speak_and_connect(type) when is_atom(type), do: %{
    type: Atom.to_string(type),
    deny: Permission.to_bitset([:connect, :speak])
  }

  def allow_manage_voice_channel(type) when is_atom(type), do: %{
    type: Atom.to_string(type),
    allow: Permission.to_bitset([:connect, :speak, :mute_members, :deafen_members, :move_members])
  }

  def restricted_roles do
    [
      {
        Bot.Infractions.Hopper.role_name,
        %{
          type: "role",
          deny: Permission.to_bitset([:connect, :speak])
        }
      }
    ]
  end

  def special_channel_permission_overwrites(role_id) do
    [
      %{ id: role_id, type: "role", deny: Permission.to_bitset([:attach_files, :embed_links, :send_tts_messages, :mention_everyone]) },
    ]
  end

  def create_channel_if_not_exists(channel_name, guild_id, type \\ 0, permission_overwrites \\ []) do
    case Converters.to_channel(channel_name, guild_id) do
      {:error, _} ->
        Api.create_guild_channel(guild_id, name: channel_name, type: type, permission_overwrites: permission_overwrites)
        |> IO.inspect(label: "Created channel")
      {:ok, %{ id: id }} -> Api.modify_channel(id, permission_overwrites: permission_overwrites, type: type, name: channel_name)
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
      Api.delete_message!(reply.channel_id, reply.id)
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
            |> put_footer("Последний перезапуск бота: ")
    Api.create_message(channel.id, content: @rules_title, embed: embed)
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
        err -> err |> IO.inspect(label: "Cannot edit permissions for role #{role_name}")
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
end
