defmodule BotTest.Cogs.Register do
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

  setup_all do
    Process.sleep(5000)
  end

  setup do
    %{
      user_id: 634121779035635761,
      guild_id: 632727434680205322,
      nickname: "zaeee"
    }
  end

  describe "Register command" do
    test "Register without arguments", context do
      {:ok, channel} = Converters.to_channel(Cogs.Register.stats_channel, context.guild_id)
      msg = %Message{
        channel_id: channel.id,
        guild_id: context.guild_id,
        author: %{
          id: context.user_id,
        },
        content: "!" <> Cogs.Register.command
      }
      result = Cogs.Register.command(msg, [])
      assert result == :not_enough_arguments
    end

    test "Register with nickname", context do
      {:ok, channel} = Converters.to_channel(Cogs.Register.stats_channel, context.guild_id)
      msg = %Message{
        channel_id: channel.id,
        guild_id: context.guild_id,
        author: %{
          id: context.user_id,
        },
        content: "!" <> Cogs.Register.command <> " " <> context.nickname
      }
      result = Cogs.Register.command(msg, [context.nickname])
      assert result == {:ok, context.nickname}
    end
  end
end
