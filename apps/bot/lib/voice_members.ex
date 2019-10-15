defmodule Bot.VoiceMembers do
  alias Nostrum.{Api}
  alias Nostrum.Struct.Guild.Member
  alias Nostrum.Struct.Guild
  alias Bot.PartySearchParticipants
  require Logger

  use Memento.Table,
      attributes: [:user_id, :channel_id, :guild_id],
      type: :ordered_set

  def user_entered_channel(%Bot.VoiceMembers{} = data) do
    with old_channel_id when old_channel_id != nil <- get_channel_id_by_user_id(data.user_id),
         true <- data.channel_id != old_channel_id,
         :ok <- Memento.transaction(fn -> Memento.Query.delete(Bot.VoiceMembers, data.user_id) end) do
      members = Bot.VoiceMembers.get_channel_members(%Bot.VoiceMembers{channel_id: old_channel_id, guild_id: data.guild_id })
      unless length(members) == 0 do
        Logger.debug("Old channel not empty, updating it.")
        PartySearchParticipants.handle_voice_update(old_channel_id, data.guild_id)
      else
        PartySearchParticipants.delete_party_messages_for_voice_channel(old_channel_id)
      end
    else
      _ -> Logger.debug("Old channel id not equal to new, doing nothing")
    end
    x = Memento.transaction(fn ->
      Memento.Query.write(data)
    end)
    |> IO.inspect(label: "User entered channel")
  end

  def user_left_channel(%Bot.VoiceMembers{ channel_id: nil } = data) do
    Memento.transaction fn ->
      channel_data = Memento.Query.read(Bot.VoiceMembers, data.user_id)
      Memento.Query.delete(Bot.VoiceMembers, data.user_id)
      channel_data
    end
    |> IO.inspect(label: "User left channel")
  end

  def get_channel_members_by_user_id(user_id) do
    case Memento.transaction(fn -> Memento.Query.read(Bot.VoiceMembers, user_id) end) do
      {:ok, %Bot.VoiceMembers{} = data} -> get_channel_members(data)
      e -> []
    end
  end

  def get_channel_id_by_user_id(user_id) do
    case Memento.transaction(fn -> Memento.Query.read(Bot.VoiceMembers, user_id) end) do
      {:ok, %Bot.VoiceMembers{ channel_id: channel_id }} -> channel_id
      _ -> nil
    end
  end

  def get_channel_members(%Bot.VoiceMembers{channel_id: channel_id, guild_id: guild_id}) do
    guards = [
      {:==, :guild_id, guild_id},
      {:==, :channel_id, channel_id},
    ]
    {:ok, x} = Memento.transaction fn ->
      Memento.Query.select(Bot.VoiceMembers, guards)
    end
    guild = Nostrum.Cache.GuildCache.get(guild_id)
    x
    |> Enum.map(fn x ->
      case guild do
        {:ok, %Guild{} = guild} ->
          case Enum.find(guild.members, fn { id, member } -> id == x.user_id end) do
            {id, %Member{} = member} -> member
            _ -> nil
          end
        _ ->
          case Api.get_guild_member(guild_id, x.user_id) do
            {:ok, member} -> member
            _ -> nil
          end
      end
    end)
    |> Enum.filter(fn x -> x != nil end)
  end

  def is_voice_channel_empty?(channel_id, guild_id) do
    case get_channel_members(%Bot.VoiceMembers{ channel_id: channel_id, guild_id: guild_id }) do
      x when is_list(x) and length(x) > 0 -> false
      _ -> true
    end
  end

end
