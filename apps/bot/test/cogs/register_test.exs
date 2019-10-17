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
      nickname: "zaeee",
      new_nickname: "kr0Cky",
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

    test "Register should replace old nickname with new", context do
      {:ok, channel} = Converters.to_channel(Cogs.Register.stats_channel, context.guild_id)
      msg = %Message{
        channel_id: channel.id,
        guild_id: context.guild_id,
        author: %{
          id: context.user_id,
        },
        content: "!" <> Cogs.Register.command <> " " <> context.new_nickname
      }
      result = Cogs.Register.command(msg, [context.new_nickname])
      assert result == {:ok, context.new_nickname}
      elo_roles =
        Cogs.Register.other_elo_role_names_except("not_Existing")
        |> Enum.map(fn name ->
          case Converters.to_role(name, context.guild_id) do
            {:ok, role} -> role.id
            _ -> nil
          end
        end)
        |> Enum.filter(fn x -> x != nil end)
      IO.inspect(elo_roles, label: "ELO ROLES")
      Process.sleep(500)
      {:ok, member} = Api.get_guild_member(context.guild_id, context.user_id)
      IO.inspect(member.roles, label: "MEMBER ROLES")
      has_elo_role =
        member.roles
        |> Enum.any?(fn id -> id in elo_roles end)
      assert has_elo_role == true
    end
  end
end
