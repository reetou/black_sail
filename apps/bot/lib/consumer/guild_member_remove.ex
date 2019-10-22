defmodule Bot.Consumer.GuildMemberRemove do
  alias Nostrum.Cache.{
    GuildCache,
    UserCache,
    }
  alias Bot.Helpers
  alias Bot.Infractions
  require Logger

  def handle({guild_id, %{ user: %{ id: user_id } } = member} = data) do
    Task.start(fn ->
      Helpers.write_leave(guild_id, user_id)
    end)
  end

  def handle(data) do
    data
    |> IO.inspect(label: "Got data without struct")
  end

end
