defmodule BotTest do
  use ExUnit.Case
  alias Nostrum.Cache.{
    GuildCache,
    Me,
  }
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
    %{ user_id: 634121779035635761, guild_id: 632727434680205322 }
  end

  describe "Greet" do
    test "Greet user", context do
      {:ok, message} = Helpers.greet_user(context.user_id, context.guild_id)
      assert String.starts_with?(message.content, "<@#{context.user_id}>")
    end
  end

  describe "Assign roles by elo" do

    test "Assign role for elo", context do
      elo = "3000"
      {role_name, opts} = Cogs.Register.elo_role_name(elo)
      assert role_name != nil
      Cogs.Register.assign_role_for_elo(elo, context.guild_id, context.user_id)
      Process.sleep(400)
      {:ok, member} = Api.get_guild_member(context.guild_id, context.user_id)
      {:ok, role} = Converters.to_role(role_name, context.guild_id)
      assert role.name == role_name
      assert role.id in member.roles
    end

    test "Should remove all other elo roles except current", context do
      elo = "800"
      {role_name, opts} = Cogs.Register.elo_role_name(elo)
      assert role_name != nil
      Cogs.Register.assign_role_for_elo(elo, context.guild_id, context.user_id)
      Process.sleep(400)
      {:ok, member} = Api.get_guild_member(context.guild_id, context.user_id)
      other_roles_ids =
        Cogs.Register.other_elo_role_names_except(role_name)
        |> Enum.map(fn name ->
          {:ok, other_role} = Converters.to_role(name, context.guild_id)
          assert other_role.id not in member.roles
        end)
      {:ok, role} = Converters.to_role(role_name, context.guild_id)
      assert role.name == role_name
      assert role.id in member.roles
    end

  end
end
