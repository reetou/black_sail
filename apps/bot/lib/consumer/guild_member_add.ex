defmodule Bot.Consumer.GuildMemberAdd do
  alias Nostrum.Cache.{
    GuildCache,
    UserCache,
  }
  alias Bot.Infractions

  def handle(%{ guild_id: guild_id, new_member: %{ user: %{ id: user_id } } } = data) do
    with {:ok, guild} <- GuildCache.get(guild_id),
         {:ok, member} <- UserCache.get(user_id) do
      Infractions.reapply_active_infractions_for_user(user_id, guild_id)
    else
      err -> err |> IO.inspect(label: "Cannot find guild or member on GUILD_MEMBER_ADD")
    end
  end

  def handle(data) do
    data
    |> IO.inspect(label: "Got data without struct")
  end

end
