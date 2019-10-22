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
    "elo" => Cogs.Elo,
    "register" => Cogs.Register,
    "update" => Cogs.Update,
    "room" => Cogs.Room,
    "add" => Cogs.Add,
    "kick" => Cogs.Kick,
    "remove" => Cogs.Remove,
    ## Role configuration
    "rooms" => %{
      ## Удалить пустые личные комнаты
      "purge" => Cogs.Rooms.Purge,
    },
    "admin" => %{
      ## Удалить пустые личные комнаты
      "remove_all_channels" => Cogs.Admin.RemoveAllChannels,
      "remove_all_roles" => Cogs.Admin.RemoveAllRoles,
      "reinit" => Cogs.Admin.Reinit,
      "stats" => Cogs.Admin.Stats,
    },
  }

  @aliases %{
    "h" => Map.fetch!(@commands, "help"),

    "фвв" => Map.fetch!(@commands, "add"),
    "ADD" => Map.fetch!(@commands, "add"),
    "добавить" => Map.fetch!(@commands, "add"),

    "куьщму" => Map.fetch!(@commands, "remove"),
    "REMOVE" => Map.fetch!(@commands, "remove"),
    "delete" => Map.fetch!(@commands, "remove"),
    "удалить" => Map.fetch!(@commands, "remove"),
    "удали" => Map.fetch!(@commands, "remove"),

    "кик" => Map.fetch!(@commands, "kick"),
    "кикни" => Map.fetch!(@commands, "kick"),
    "кикнуть" => Map.fetch!(@commands, "kick"),
    "лшсл" => Map.fetch!(@commands, "kick"),
    "ЛШСЛ" => Map.fetch!(@commands, "kick"),
    "KICK" => Map.fetch!(@commands, "kick"),
    "ban" => Map.fetch!(@commands, "kick"),
    "BAN" => Map.fetch!(@commands, "kick"),
    "бан" => Map.fetch!(@commands, "kick"),

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

    "эло" => Map.fetch!(@commands, "elo"),
    "ело" => Map.fetch!(@commands, "elo"),
    "ило" => Map.fetch!(@commands, "elo"),
    "ELO" => Map.fetch!(@commands, "elo"),
    "ЭЛО" => Map.fetch!(@commands, "elo"),
    "ЕЛО" => Map.fetch!(@commands, "elo"),
    "ИЛО" => Map.fetch!(@commands, "elo"),
    "eIo" => Map.fetch!(@commands, "elo"),
    "eio" => Map.fetch!(@commands, "elo"),

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
    :ok = Api.update_status(:online, "Elixir Docs | !help", 3)
    Bot.Cogs.Admin.Stats.stats_for_servers
  end

  defp load_commands do
    [@commands, @aliases]
    |> Stream.concat()
    |> Enum.each(fn {name, cog} ->
      CommandStorage.add_command({name}, cog)
    end)
  end
end
