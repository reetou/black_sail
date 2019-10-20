defmodule BotTest.Cogs.Room do
  use ExUnit.Case
  alias Nostrum.Cache.{
    GuildCache,
    Me,
    }
  alias Nostrum.Struct.Message
  alias Nostrum.{Permission, Api}
  alias Bot.{
    Helpers,
    Cogs,
    Consumer,
    }
  require Logger
  alias Nosedrum.Converters

  setup_all do
    Process.sleep(3000)
    guild_id = 632727434680205322
    user_id = 634121779035635761
    other_members_ids = [167286153286909952]
    {:ok, member} = Api.get_guild_member(guild_id, user_id)
    channel_name_for_member = Cogs.Room.channel_name_for_user(member.user.username <> "#" <> member.user.discriminator)
    {:ok, chan} = Helpers.create_channel_if_not_exists(Helpers.commands_channel, guild_id)
#    Helpers.delete_channel_if_exists(channel_name_for_member, guild_id)
    Process.sleep(1500)
    Memento.transaction(fn ->
      Memento.Query.write(%Bot.VoiceMembers{
        user_id: user_id,
        guild_id: guild_id,
        channel_id: chan.id,
      })
    end)
    %{
      user_id: user_id,
      msg: %Message{
        channel_id: chan.id,
        guild_id: guild_id,
        author: member.user,
        content: "!" <> Cogs.Room.command
      },
      guild_id: guild_id,
      member: member,
      other_members_ids: other_members_ids,
      channel_name_for_member: channel_name_for_member,
    }
  end

  test "Should create one and remove others", context do
    {:ok, chan} = Cogs.Room.command(context.msg, [])
    Process.sleep(400)
    assert chan.name == context.channel_name_for_member
    Process.sleep(4000)
    channels =
      Api.get_guild_channels!(context.guild_id)
      |> Enum.filter(fn ch -> ch.name == context.channel_name_for_member end)
    assert length(channels) == 1
  end

  test "Room owner should exclusively have permissions to mute, move members, connect and speak", context do
    %{
      channel_name_for_member: chan_name,
      guild_id: guild_id,
      user_id: user_id,
    } = context
    {:ok, chan} = Converters.to_channel(chan_name, guild_id)
    expected_perms = [
      :connect,
      :speak,
      :mute_members,
      :deafen_members,
      :move_members,
    ]
    result =
      chan.permission_overwrites
      |> Enum.filter(fn overwrite -> overwrite.id == user_id end)
      |> Enum.map(fn overwrite ->
        Permission.from_bitset(overwrite.allow)
      end)
      |> List.first
      |> Enum.sort
      |> Keyword.equal?(Enum.sort(expected_perms))
    assert result == true
  end

  test "Add command should return error when no arguments provided", context do
    result = Cogs.Add.command(context.msg, [])
    Process.sleep(400)
    assert result == {:error, :not_enough_arguments}
  end

  test "Add command for member should add permissions to provided members and return ok status", %{
    channel_name_for_member: chan_name,
    guild_id: guild_id,
    user_id: user_id,
  } = context do
    Process.sleep(4000)
    result = Cogs.Add.command(context.msg, Enum.map(context.other_members_ids, fn id -> "<@#{id}>" end))
    Process.sleep(1500)
    assert result == {:ok}
    {:ok, chan} = Converters.to_channel(chan_name, guild_id)
    expected_perms = [:connect, :speak, :view_channel]
    result =
      chan.permission_overwrites
      |> Enum.filter(fn overwrite -> overwrite.id in context.other_members_ids end)
      |> Enum.map(fn overwrite ->
        Permission.from_bitset(overwrite.allow)
      end)
      |> List.first
      |> Enum.sort
      |> Keyword.equal?(Enum.sort(expected_perms))
    assert result == true
  end

  test "Remove command should return error when no arguments provided", context do
    result = Cogs.Remove.command(context.msg, [])
    Process.sleep(400)
    assert result == {:error, :not_enough_arguments}
  end

  test "Remove command for member should remove provided members permissions and return ok status", %{
    channel_name_for_member: chan_name,
    guild_id: guild_id,
    user_id: user_id,
  } = context do
    Process.sleep(4000)
    result = Cogs.Remove.command(context.msg, Enum.map(context.other_members_ids, fn id -> "<@#{id}>" end))
    Process.sleep(1500)
    assert result == {:ok}
    {:ok, chan} = Converters.to_channel(chan_name, guild_id)
    expected_perms = [:connect, :speak, :view_channel]
    result =
      chan.permission_overwrites
      |> Enum.all?(fn overwrite -> overwrite.id not in context.other_members_ids end)
    assert result == true
  end

  test "Kick command should return error when no arguments provided", context do
    result = Cogs.Kick.command(context.msg, [])
    Process.sleep(400)
    assert result == {:error, :not_enough_arguments}
  end

  test "Kick command for member should return error when not in own voice channel", %{
         channel_name_for_member: chan_name,
         guild_id: guild_id,
         user_id: user_id,
       } = context do
    {:ok, chan} = Converters.to_channel(chan_name, guild_id)
    Api.update_voice_state(guild_id, nil)
    Process.sleep(2000)
    result = Cogs.Kick.command(context.msg, Enum.map(context.other_members_ids, fn id -> "<@#{id}>" end))
    |> IO.inspect(label: "Result at kick cmd")
    assert result == {:error, :not_in_own_channel}
  end

  test "Kick command for member should add deny permissions to members and return ok status", %{
    channel_name_for_member: chan_name,
    guild_id: guild_id,
    user_id: user_id,
  } = context do
    {:ok, chan} = Converters.to_channel(chan_name, guild_id)
    Api.update_voice_state(context.guild_id, chan.id)
    Process.sleep(1500)
    result = Cogs.Kick.command(context.msg, Enum.map(context.other_members_ids, fn id -> "<@#{id}>" end))
    Process.sleep(1500)
    {:ok, updated_chan} = Converters.to_channel(chan_name, guild_id)
    assert result == {:ok}
    expected_perms = [:connect, :speak, :view_channel]
    result =
      updated_chan.permission_overwrites
      |> Enum.filter(fn overwrite -> overwrite.id in context.other_members_ids end)
      |> Enum.map(fn overwrite ->
        Permission.from_bitset(overwrite.deny)
      end)
      |> List.first
      |> Enum.sort
      |> Keyword.equal?(Enum.sort(expected_perms))
    assert result == true
  end

end
