defmodule Bot.Consumer do
  @moduledoc """
    Consumes events and reacts to them
  """

  use Nostrum.Consumer
  alias Nostrum.Struct.{
    Message,
    User,
  }
  alias Bot.Consumer.{
    MessageCreate,
    Ready,
    VoiceStateUpdate,
    GuildMemberAdd,
    GuildMemberRemove,
  }
  alias Nostrum.Cache.Me
  import Nostrum.Api

  def start_link do
    Consumer.start_link(__MODULE__, max_restarts: 0)
  end

  @impl true
  def handle_event({:MESSAGE_CREATE, %{ content: "!" <> command } = msg, _ws_state}) do
    unless msg.author.bot do
      IO.inspect(command, label: "Will handle command #{command}")
      MessageCreate.handle(msg)
    else
      with %User{} = me <- Me.get,
           true <- me.id == msg.author.id do
        IO.inspect(command, label: "Will handle command #{command} FROM MYSELF")
        MessageCreate.handle(msg)
      end
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
  def handle_event({:GUILD_MEMBER_ADD, { guild_id, _member } = data, _ws_state}) do
    GuildMemberAdd.handle(data)
  end

  @impl true
  def handle_event({:GUILD_MEMBER_REMOVE, { guild_id, _member } = data, _ws_state}) do
    GuildMemberRemove.handle(data)
  end

  def handle_event(_other) do
  end

end
