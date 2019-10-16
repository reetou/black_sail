defmodule Bot.Predicates do
  @moduledoc "Implements various predicates used by commands."

  alias Bot.{
    Helpers,
    Cogs.Party,
    Cogs.Register,
    VoiceMembers,
  }
  alias Nostrum.Permission
  alias Nostrum.Struct.Message
  alias Nostrum.Struct.Guild.Member
  alias Nostrum.Struct.User
  alias Nostrum.Api
  alias Nostrum.Cache.GuildCache
  alias Nosedrum.Converters

  @all_permissions Permission.all()

  def is_party_search_channel?(msg) do
    check_expected_channel(msg, Party.search_channel)
  end

  def is_stats_channel?(msg) do
    check_expected_channel(msg, Register.stats_channel)
  end

  def is_commands_channel?(msg) do
    check_expected_channel(msg, Helpers.commands_channel)
  end

  def in_own_voice_channel(%{ channel_id: channel_id } = msg) when channel_id == nil do
    {:error, "Нужно находиться в голосовом канале на сервере, чтобы использовать эту команду"}
  end

  def in_own_voice_channel(msg) do
    with {:ok, channel} <- Helpers.get_user_current_personal_or_party_voice_channel(msg.author.id, msg.guild_id) do
      :passthrough
    else
      _err ->
        reason = "<@#{msg.author.id}>, эту команду можно использовать только находясь в канале, который создан вами. Покиньте голосовой канал и введите команду заново"
        {:error, reason}
    end
  end

  def guild_only(%Message{guild_id: nil}), do: {:error, "Эту команду можно использовать только на сервере"}
  def guild_only(_), do: :passthrough


  def has_permission(permission) when permission in @all_permissions do
    fn msg ->
      with {:is_on_guild, true} <- {:is_on_guild, msg.guild_id != nil},
           {:ok, guild} <- GuildCache.get(msg.guild_id),
           {:member, member} when member != nil <-
             {:member, Map.get(guild.members, msg.author.id)},
           {:has_permission, true} <-
             {:has_permission, permission in Member.guild_permissions(member, guild)} do
        :passthrough
      else
        {:error, _reason} ->
          {:error, "❌ Не удалось проверить права на сервере"}

        {:has_permission, false} ->
          permission_string =
            permission
            |> Atom.to_string()
            |> String.upcase()

          {:error, "🚫 Вы должны иметь право `#{permission_string}` для использования этой команды"}

        {:is_on_guild, false} ->
          {:error, "🚫 Эта команда не может быть использована в ЛС"}

        {:member, nil} ->
          {:error, "❌ Не удалось проверить ваши права на сервере"}
      end
    end
  end

  def bot_has_permission(permission) when permission in @all_permissions do
    fn msg ->
      with {:is_on_guild, true} <- {:is_on_guild, msg.guild_id != nil},
           {:ok, guild} <- GuildCache.get(msg.guild_id),
           {:me, bot_user} when bot_user != nil <-
             {:me, Nostrum.Cache.Me.get},
           {:member, member} when member != nil <-
             {:member, Map.get(guild.members, bot_user.id)},
           {:has_permission, true} <-
             {:has_permission, permission in Member.guild_permissions(member, guild)} do
        :passthrough
      else
        {:error, _reason} ->
          {:error, "❌ Не удалось проверить права бота на сервере"}

        {:has_permission, false} ->
          permission_string =
            permission
            |> Atom.to_string()
            |> String.upcase()

          {:error, "🚫 Бот должен иметь право `#{permission_string}` для использования этой команды"}

        {:is_on_guild, false} ->
          {:error, "🚫 Эта команда не может быть использована в ЛС"}

        {:member, nil} ->
          {:error, "❌ Не удалось проверить права бота на сервере"}
      end
    end
  end

  def is_zae(msg) do
    unless msg.author.id == 167286153286909952 do
      {:error, "Этой командой вам пользоваться нельзя"}
    else
      :passthrough
    end
  end

  defp check_expected_channel(%{ channel_id: channel_id, guild_id: guild_id, id: msg_id } = msg, expected_channel) do
    case Converters.to_channel("#{channel_id}", guild_id) do
      {:ok, %{ name: name }} when name == expected_channel -> {:ok, msg}
      _ ->
        with {:ok, %{ id: expected_channel_id }} <- Converters.to_channel(expected_channel, guild_id) do
          {:error, "<@#{msg.author.id}>, эта команда доступна только в канале <##{expected_channel_id}>"}
        else _err ->
          {:error, "<@#{msg.author.id}>, эта команда недоступна в этом канале"}
        end
    end
  end
end
