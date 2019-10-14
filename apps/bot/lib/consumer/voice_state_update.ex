defmodule Bot.Consumer.VoiceStateUpdate do
  alias Bot.Infractions.{
    Hopper,
  }

  def handle(%Bot.VoiceMembers{ channel_id: channel_id, user_id: user_id, guild_id: guild_id } = data) when channel_id != nil do
    case Bot.VoiceMembers.user_entered_channel(data) do
      {:ok, x} when x != nil -> Bot.PartySearchParticipants.handle_voice_update(x.channel_id, x.guild_id)
      _ -> IO.inspect("Channel that user has entered is unknown")
    end
    Hopper.write_history(user_id, channel_id, guild_id)
  end

  def handle(%Bot.VoiceMembers{ channel_id: nil } = data) do
    case Bot.VoiceMembers.user_left_channel(data) do
      {:ok, x} when x != nil -> Bot.PartySearchParticipants.handle_voice_update(x.channel_id, x.guild_id)
      _ -> IO.inspect("Channel that user has left is unknown")
    end
  end

  def handle(data) do
    data
    |> IO.inspect(label: "Got data without struct")
  end

end
