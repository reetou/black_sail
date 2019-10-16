defmodule Bot.Consumer.GuildMemberAdd do
  alias Nostrum.Cache.{
    GuildCache,
    UserCache,
  }
  alias Bot.Infractions
  require Logger

  def handle({guild_id, %{ user: %{ id: user_id } } = member} = data) do
    Task.start(fn ->
      Bot.Helpers.greet_user(user_id, guild_id)
    end)
    Infractions.reapply_active_infractions_for_user(user_id, guild_id)
  end

  def handle(data) do
    data
    |> IO.inspect(label: "Got data without struct")
  end

end
