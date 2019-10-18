defmodule BotTest.Cogs.Party do
  use ExUnit.Case
  alias Nostrum.Cache.{
    GuildCache,
    Me,
    }
  alias Nostrum.Struct.Message
  alias Nostrum.{Snowflake, Api}
  alias Bot.{
    Helpers,
    Cogs,
    Consumer,
    }
  require Logger
  alias Nosedrum.Converters

  def remove_elo_roles_from_member_roles(%{ guild_id: guild_id, user_id: user_id } = context) do
    {:ok, member} = Api.get_guild_member(context.guild_id, context.user_id)
    elo_roles_ids =
      Cogs.Register.elo_roles
      |> Enum.map(fn {name, opts} ->
        case Converters.to_role(name, context.guild_id) do
          {:ok, role} -> role.id
          _ -> nil
        end
      end)
      |> Enum.filter(fn role_id -> role_id != nil end)
    roles_without_elo =
      member.roles
      |> Enum.filter(fn id -> id not in elo_roles_ids end)
    {:ok} = Api.modify_guild_member(guild_id, user_id, %{ roles: roles_without_elo })
    context
  end

  def command_without_arguments(context) do
    {:ok, search_chan} = Converters.to_channel(Cogs.Party.search_channel, context.guild_id)
    msg = %Message{
      channel_id: search_chan.id,
      guild_id: context.guild_id,
      author: context.member.user,
      content: "!" <> Cogs.Party.command
    }
    Map.put(context, :msg, msg)
  end

  def command_with_only_comment(context) do
    {:ok, search_chan} = Converters.to_channel(Cogs.Party.search_channel, context.guild_id)
    msg = %Message{
      channel_id: search_chan.id,
      guild_id: context.guild_id,
      author: context.member.user,
      content: "!" <> Cogs.Party.command <> " " <> "sadas sdasd sad asasds sad"
    }
    Map.put(context, :msg, msg)
  end

  def delete_all_channels_with_name(name, guild_id) do
    Api.get_guild_channels!(guild_id)
    |> Enum.filter(fn c -> c.name == name end)
    |> Enum.each(fn c -> Api.delete_channel!(c.id, "Tests cleanup") end)
  end

  def remove_party_voice_channel_for_member(context) do
    {:ok, member} = Api.get_guild_member(context.guild_id, context.user_id)
    channel_name_for_member = Cogs.Party.get_channel_name_for_member(member.user.username <> "#" <> member.user.discriminator)
    delete_all_channels_with_name(channel_name_for_member, context.guild_id)
    context
  end

  def create_voice_channel(context) do
    username = context.member.user.username <> "#" <> context.member.user.discriminator
    Cogs.Party.create_voice_channel_for_member(context.guild_id, username, context.user_id)
    Process.sleep(3000)
    context
  end

  setup_all context do
    Process.sleep(3000)
    guild_id = 632727434680205322
    user_id = 634121779035635761
    {:ok, member} = Api.get_guild_member(guild_id, user_id)
    Helpers.create_channel_if_not_exists(Cogs.Party.search_channel, guild_id)
    channel_name_for_member = Cogs.Party.get_channel_name_for_member(member.user.username <> "#" <> member.user.discriminator)
    Nostrum.Api.update_voice_state(guild_id, nil)
    channel_name_for_member = Cogs.Party.get_channel_name_for_member(member.user.username <> "#" <> member.user.discriminator)
    delete_all_channels_with_name(channel_name_for_member, guild_id)
    Process.sleep(1500)
    %{
      user_id: user_id,
      guild_id: guild_id,
      wanted_elo: "800",
      higher_elo: "3500",
      member: member,
      channel_name_for_member: channel_name_for_member,
    }
  end

  describe "When not in voice channel" do

    setup [:remove_elo_roles_from_member_roles, :remove_party_voice_channel_for_member, :command_without_arguments]

    test "Create party voice channel for user", context do
      Process.sleep(2000)
      result = Cogs.Party.command(context.msg, [])
      Process.sleep(2000)
      assert result == {:ok, :created_voice_channel}
    end

  end

  describe "When in voice channel" do

    setup [:remove_elo_roles_from_member_roles, :command_without_arguments, :create_voice_channel]

    test "Create message for party when bot joined voice channel", context do
      {:ok, channel} = Converters.to_channel(context.channel_name_for_member, context.guild_id)
      Api.update_voice_state(context.guild_id, channel.id)
      Process.sleep(500)
      result = Cogs.Party.command(context.msg, [])
      assert result == {:ok, :free_enter}
    end

    test "Create message for party without restrictions even when has elo role", context do
      {:ok, channel} = Converters.to_channel(context.channel_name_for_member, context.guild_id)
      Api.update_voice_state(context.guild_id, channel.id)
      Process.sleep(1000)
      {:ok, role} = Cogs.Register.assign_role_for_elo("1200", context.guild_id, context.user_id)
      Process.sleep(1000)
      {:ok, member} = Api.get_guild_member(context.guild_id, context.user_id)
      assert role.id in member.roles
      result = Cogs.Party.command(context.msg, [])
      assert result == {:ok, :free_enter}
    end
  end

end
