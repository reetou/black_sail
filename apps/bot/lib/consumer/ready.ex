defmodule Bot.Consumer.Ready do
  @moduledoc "Handles the `READY` event."

  alias Nosedrum.Storage.ETS, as: CommandStorage
  alias Bot.{Cogs, Helpers}
  alias Nostrum.{Api, Permission}
  alias Nosedrum.{Converters}
  alias Cogs.Party
  alias Cogs.Register

  @infraction_group %{
    "detail" => Cogs.Infraction.Detail,
    "reason" => Cogs.Infraction.Reason,
    "list" => Cogs.Infraction.List,
    "user" => Cogs.Infraction.User,
    "expiry" => Cogs.Infraction.Expiry
  }

  @commands %{
    ## Bot meta commands
    "help" => Cogs.Help,
    "party" => Cogs.Party,
    "register" => Cogs.Register,
    "update" => Cogs.Update,
    "room" => Cogs.Room,
    ## Role configuration
    "rooms" => %{
      ## Удалить пустые личные комнаты
      "purge" => Cogs.Room.Purge,
    },
  }

  @aliases %{
    "h" => Map.fetch!(@commands, "help"),
    "h" => Map.fetch!(@commands, "help"),

    "рум" => Map.fetch!(@commands, "room"),
    "кщщь" => Map.fetch!(@commands, "room"),
    "ROOM" => Map.fetch!(@commands, "room"),

    "зфкен" => Map.fetch!(@commands, "party"),
    # Английская эр
    "p" => Map.fetch!(@commands, "party"),
    # Русская эр
    "р" => Map.fetch!(@commands, "party"),
    "пати" => Map.fetch!(@commands, "party"),
    "поиск" => Map.fetch!(@commands, "party"),

    "reg" => Map.fetch!(@commands, "register"),
    "купшыеук" => Map.fetch!(@commands, "register"),
    "куп" => Map.fetch!(@commands, "register"),
    "рег" => Map.fetch!(@commands, "register"),

    "u" => Map.fetch!(@commands, "update"),
    "гзвфеу" => Map.fetch!(@commands, "update"),
    "stats" => Map.fetch!(@commands, "update"),
    "ыефеы" => Map.fetch!(@commands, "update"),
    "статс" => Map.fetch!(@commands, "update"),
  }

  def commands, do: @commands

  @spec handle(map()) :: :ok
  def handle(data) do
    :ok = load_commands()
    IO.puts("⚡ Logged in and ready, seeing `#{length(data.guilds)}` guilds.")
    data.guilds
    |> Enum.map(fn %{ id: guild_id } = guild -> Map.put(guild, :channels, Api.get_guild_channels!(guild_id)) end)
    |> Enum.each(fn %{ id: guild_id } ->

      Task.start(fn ->
        with {:ok, channels} <- Api.get_guild_channels(guild_id) do
          IO.puts("Applying restricted roles\' permissions for channels...")
          Helpers.apply_permissions_for_infraction_roles(channels, guild_id)
        else
          err -> err |> IO.inspect(label: "Cannot get channels for guild #{guild_id}")
        end
      end)

      Task.start(fn ->
        {:ok, role} = Converters.to_role("@everyone", guild_id)
        opts = [
          permissions: Nostrum.Permission.to_bitset([
            :attach_files,
            :send_messages,
            :read_message_history,
            :use_external_emojis,
            :view_channel,
            :add_reactions,
            :speak,
            :connect,
          ]),
        ]
        IO.puts("Modifying roles for guild #{guild_id}")
        Api.modify_guild_role(guild_id, role.id, opts)
      end)

      IO.puts("Ensure that logs channel exists in guild #{guild_id}")
      Task.start(fn ->
        {:ok, %{ id: role_id }} = Converters.to_role("@everyone", guild_id)
        overwrites = [
          %{
            id: role_id,
            type: "role",
            deny: Permission.to_bit(:view_channel)
          },
        ]
        Helpers.create_channel_if_not_exists(Helpers.logs_channel, guild_id, 0, overwrites)
      end)

      Task.start(fn ->
        IO.puts("Recreating commands channel if not exists")
        Helpers.create_channel_if_not_exists(Helpers.commands_channel, guild_id, 0)
      end)

      Task.start(fn ->
        IO.puts("Recreate channel for party command in guild #{guild_id}")
        Party.recreate_channel(guild_id)

        IO.puts("Recreate channel for register command in guild #{guild_id}")
        Register.recreate_channel(guild_id)

        IO.puts("Recreating rules channel in guild #{guild_id}")
        Helpers.ensure_rules_message_exists(guild_id)

        IO.puts("Recreating roles for guild #{guild_id}")
        Register.recreate_roles(guild_id)
      end)

      IO.inspect(guild_id, label: "Deleting guild game channels")
      Task.start(fn -> Helpers.delete_game_channels_without_parent(guild_id) end)
    end)
    :ok = Api.update_status(:online, "Elixir Docs | !help", 3)
  end

  defp load_commands do
    [@commands, @aliases]
    |> Stream.concat()
    |> Enum.each(fn {name, cog} ->
      CommandStorage.add_command({name}, cog)
    end)
  end
end
