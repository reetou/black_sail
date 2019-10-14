defmodule Bot.Consumer do
  @moduledoc """
    Consumes events and reacts to them
  """

  use Nostrum.Consumer
  alias Nostrum.Struct.Message
  alias Bot.Consumer.{
    MessageCreate,
    Ready,
    VoiceStateUpdate,
    GuildMemberAdd,
  }
  import Nostrum.Api

  def start_link do
    Consumer.start_link(__MODULE__, max_restarts: 0)
  end

  @impl true
  def handle_event({:MESSAGE_CREATE, %{ content: "!" <> command } = msg, _ws_state}) do
    unless msg.author.bot do
      IO.inspect(command, label: "Will handle command #{command}")
      MessageCreate.handle(msg)
    end
  end
  @impl true
  def handle_event({:MESSAGE_CREATE, %{ content: "" <> _content } = msg, _ws_state}) do
    unless msg.author.bot do
      Bot.Helpers.delete_casual_message_from_special_channel(msg)
    end
  end

  @impl true
  def handle_event({:READY, data, _ws_state}) do
    Ready.handle(data)
  end

  @impl true
  def handle_event({:VOICE_STATE_UPDATE, %{ channel_id: channel_id, user_id: user_id, guild_id: guild_id }, _ws_state}) do
    %Bot.VoiceMembers{ channel_id: channel_id, user_id: user_id, guild_id: guild_id }
    |> VoiceStateUpdate.handle
  end

  @impl true
  def handle_event({:GUILD_MEMBER_ADD, %{ guild_id: guild_id, new_member: new_member } = data, _ws_state}) when guild_id != nil and is_map(new_member) do
    GuildMemberAdd.handle(data)
  end

  def handle_event(_other) do
  end

end
