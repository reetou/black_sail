defmodule Bot.PartySearchParticipants do
  alias Nostrum.{Api}
  alias Bot.Cogs.Party
  alias Nostrum.Struct.{
    Embed,
  }
  require Logger

  use Memento.Table,
      attributes: [
        :message_id,
        :voice_channel_id,
        :guild_id,
        :invite_code,
        :text_channel_id,
        :comment,
        :elo_role,
        :override_index,
      ],
      type: :ordered_set

  def handle_voice_update(channel_id, guild_id) do
    guards = [
      {:==, :voice_channel_id, channel_id},
      {:==, :guild_id, guild_id},
    ]
    IO.inspect(%{ channel_id: channel_id, guild_id: guild_id }, label: "Handle voice update")
    with {:ok, rows} <- Memento.transaction(fn -> Memento.Query.select(Bot.PartySearchParticipants, guards) end),
         x <- length(rows),
         true <- x > 0,
         {:ok, %Bot.PartySearchParticipants{} = data} <- Enum.fetch(rows, 0) do
      update_party_search_message(data)
    end
  end

  def update_party_search_message(%{
    message_id: message_id,
    text_channel_id: text_channel_id,
    voice_channel_id: voice_channel_id,
    invite_code: invite_code,
    guild_id: guild_id,
    comment: comment,
    elo_role: elo_role,
    override_index: override_index,
  } = data) do
    members = Bot.VoiceMembers.get_channel_members(%Bot.VoiceMembers{
      channel_id: voice_channel_id,
      guild_id: guild_id,
    })
    with {:ok, msg} <- Api.get_channel_message(text_channel_id, message_id),
         {:ok, invite} <- Api.get_invite(invite_code),
         msg = Map.put(msg, :guild_id, guild_id),
         msg = Map.put(msg, :content, "!#{Bot.Cogs.Party.command} #{comment}") do
      unless length(members) == 0 do
        Logger.debug("Channel not empty, editing...")
        %Embed{} = updated_embed = Party.create_party_message(msg, invite, elo_role, override_index)
        Api.edit_message!(msg, embed: updated_embed)
      else
        Logger.debug("Deleting empty channel because members are empty")
        delete_party_message_from_history(msg.id)
        Api.edit_message!(msg, embed: Party.create_empty_party_message(msg))
#        Api.delete_message(text_channel_id, message_id)
      end
    else err -> err
                |> IO.inspect(label: "Cannot edit message")
    end
  end

  def write_party_search_message(%Bot.PartySearchParticipants{} = data) do
    {:ok, _} = Memento.transaction(fn ->
      Memento.Query.write(data)
#      Memento.Query.read(Bot.PartySearchParticipants, message_id)
    end)
  end

  def delete_party_messages_for_voice_channel(voice_channel_id, guild_id) do
    Memento.transaction(fn ->
      guards = [
        {:==, :guild_id, guild_id},
        {:==, :voice_channel_id, voice_channel_id}
      ]
      rows = Memento.Query.select(Bot.PartySearchParticipants, guards)
      Enum.each(rows, fn row ->
        Memento.Query.delete(Bot.PartySearchParticipants, row.message_id)
        Task.start(fn ->
          Api.delete_message(row.text_channel_id, row.message_id)
        end)
      end)
    end)
  end

  def delete_party_message_from_history(message_id) do
    Memento.transaction(fn ->
      Memento.Query.delete(Bot.PartySearchParticipants, message_id)
    end)
  end

end
