defmodule Bot.Infractions.Hopper do
  import Bot.Infractions
  alias Bot.Infractions
  alias Nostrum.Struct.Guild
  alias Nostrum.Struct.Guild.Member
  alias Nostrum.Api
  alias Nosedrum.Converters

  @prefix "hoppers"
  @expire_seconds 15
  @role_name "Войс мут"
  @infraction_length_seconds 120

  def role_name, do: @role_name

  def list_name_for_user(user_id, guild_id) do
    # infractions:hoppers:999999999:123123123123
    infractions_prefix <> ":" <> @prefix <> ":" <> "#{guild_id}" <> ":" <> "#{user_id}"
  end

  def hopper_channels(user_id, guild_id) do
    {:ok, channels} = Redix.command(:redix, ["SMEMBERS", list_name_for_user(user_id, guild_id)])
  end

  def reason(user_id, guild_id) do
    {:ok, channels} = hopper_channels(user_id, guild_id)
    channelsNames = channels
    |> Enum.reduce("", fn channel_id, acc ->
      case Converters.to_channel(channel_id, guild_id) do
        {:ok, %{ name: name }} -> acc <> "\n" <> name
        _ -> acc
      end
    end)
    %{ name: name } = Nostrum.Cache.GuildCache.get!(guild_id)
    """
Привет. Ты получил **войсмут** на сервере **#{name}**, потому что слишком часто прыгал по каналам. Если таким образом ты искал себе пати, то лучше пользуйся каналом **поиск**

Войсмут спадет через #{@infraction_length_seconds / 60} минут. Если ты получил войсмут по ошибке, напиши в **админ-чат** на сервере и не забудь написать, что тебе выдали войсмут по ошибке.

Имей в виду, что в админ-чате очень высокий слоумод, поэтому напиши все одним сообщением.

**В ЛС боту писать _НЕ_ нужно.**

Последние голосовые каналы, в которые ты заходил за последние #{(@expire_seconds * length(channels)) / 60} мин.:
#{channelsNames}
"""
  end

  def write_history(user_id, channel_id, guild_id) do
    key = list_name_for_user(user_id, guild_id)
    {:ok, _added} = Redix.command(:redix, ["SADD", key, channel_id])
    {:ok, _} = Redix.command(:redix, ["EXPIRE", key, @expire_seconds])
    {:ok, chans} = hopper_channels(user_id, guild_id)
    handle(user_id, guild_id, length(chans))
  end

  defp handle(user_id, guild_id, size) do
    with size when size > 2 <- size,
         {:ok, %Member{} = member} <- Converters.to_member("<@#{user_id}>", guild_id),
         guild <- Nostrum.Cache.GuildCache.get!(guild_id),
         permissions <- Member.guild_permissions(member, guild) do
      unless :manage_channels in permissions or member.user.bot do
        restrict(user_id, guild_id)
      end
    end
  end

  defp restrict(user_id, guild_id) do
    with {:ok, role} <- Converters.to_role(@role_name, guild_id) do
      {:ok} = %Infractions{
        guild_id: Integer.to_string(guild_id),
        user_id: Integer.to_string(user_id),
        role_id: Integer.to_string(role.id),
        clear_at: DateTime.utc_now()
                  |> DateTime.add(@infraction_length_seconds, :second)
                  |> DateTime.to_unix(),
        reason: "Слишком много переходов подряд",
        type: role_infraction,
      }
        |> apply()
      Api.modify_guild_member(guild_id, user_id, %{ channel_id: nil })
      Task.start(fn ->
        {:ok, channels} = hopper_channels(user_id, guild_id)
        channelsNames = channels
                        |> Enum.reduce("", fn channel_id, acc ->
          case Converters.to_channel(channel_id, guild_id) do
            {:ok, %{ name: name }} -> acc <> "\n" <> name
            _ -> acc
          end
        end)
        Infractions.send_to_log("""
**Кузнечик алерт!**
<@#{user_id}> получил предварительный войсмут на #{@infraction_length_seconds / 60} минут за прыжки по войс каналам

Прыгал по этим каналам последние #{(@expire_seconds * length(channels)) / 60} мин.:

```
#{channelsNames}
```
""", guild_id)
      end)
      {:ok, dm_channel} = Api.create_dm(user_id)
      {:ok, _message} = Api.create_message(dm_channel.id, reason(user_id, guild_id))
    end
  end

end
