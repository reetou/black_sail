defmodule Bot.Infractions do
  alias Nostrum.Api
  alias Nostrum.Cache.{
    GuildCache,
  }
  alias Nosedrum.Converters
  alias Nostrum.Snowflake
  alias Bot.Helpers
  require Logger

  @derive Jason.Encoder
  defstruct [
    guild_id: nil,
    user_id: nil,
    role_id: nil,
    clear_at: nil,
    type: nil,
    reason: nil,
    punisher: nil,
  ]

  @infractions_prefix "infractions"
  @applied_infractions_prefix "#{@infractions_prefix}:applied"

  @role_infraction "role_infr"
  @channel_permission_infraction "chperm_infr"

  def role_infraction, do: @role_infraction
  def infractions_prefix, do: @infractions_prefix

  # 0 - roles
  # 1 - channel permissions

  def apply(%{ guild_id: guild_id }) when guild_id == nil, do: {:error, "No guild id provided"}
  def apply(%{ user_id: user_id }) when user_id == nil, do: {:error, "User id is not provided"}
  def apply(%{ type: type }) when type == nil, do: {:error, "Infraction type is not provided"}
  def apply(%{ role_id: role_id, type: type }) when role_id == nil and type == @role_infraction, do: {:error, "Role id is not provided"}
  def apply(%{ clear_at: clear_at }) when clear_at == nil, do: {:error, "Clear_at timestamp provided"}

  def apply(%__MODULE__{ user_id: user_id, guild_id: guild_id, type: type, role_id: role_id, reason: reason } = data) when type == @role_infraction do
    {:ok, _} = Redix.command(:redix, ["HSET", @applied_infractions_prefix, "#{@role_infraction}" <> "#{guild_id}_#{user_id}", Jason.encode!(data)])
    {:ok} = Api.add_guild_member_role(guild_id, user_id, role_id, reason)
  end

  def is_infraction?(str) do
    with {:ok, decoded} when is_map(decoded) <- Jason.decode(str),
         %{ "clear_at" => _clear_at } <- decoded do
      true
    else
      _err -> false
    end
  end

  def reapply_active_infractions_for_user(user_id, guild_id) when guild_id != nil and user_id != nil do
    {:ok, infractions} = Redix.command(:redix, ["HGETALL", @applied_infractions_prefix])
    infractions
    |> Enum.filter(fn possible_i -> is_infraction?(possible_i) end)
    |> Enum.each(fn i ->
      %{
        "guild_id" => guild_id,
        "user_id" => user_id,
        "role_id" => role_id,
        "clear_at" => clear_at,
        "type" => type,
        "reason" => reason,
        "punisher" => punisher,
      } = Jason.decode!(i)
      unless infraction_expired?(clear_at) do
        %__MODULE__{
          guild_id: guild_id,
          user_id: user_id,
          role_id: role_id,
          clear_at: clear_at,
          type: type,
          reason: reason,
          punisher: punisher,
        }
        |> IO.inspect(label: "Infraction still active for a newcomer, applying it")
        |> apply
      end
    end)
  end

  def clear_expired_infractions do
    {:ok, infractions} = Redix.command(:redix, ["HGETALL", @applied_infractions_prefix])
    infractions
    |> Enum.filter(fn possible_i -> is_infraction?(possible_i) end)
    |> Enum.each(fn i ->
      %{ "clear_at" => clear_at } = infraction = Jason.decode!(i)
      if infraction_expired?(clear_at) do
        IO.inspect(infraction, label: "Infraction expired, clearing it")
        clear(infraction)
      end
    end)
  end

  def infraction_expired?(clear_at) when clear_at == nil, do: true
  def infraction_expired?(clear_at) do
    now = DateTime.utc_now()
    |> DateTime.to_unix()
    now >= clear_at
  end

  def clear(%{
    "type" => type,
    "user_id" => user_id_string,
    "role_id" => role_id,
    "guild_id" => guild_id_string,
    "reason" => reason,
  }) when type == @role_infraction do
    { :ok, guild_id } = Snowflake.cast(guild_id_string)
    { :ok, user_id } = Snowflake.cast(user_id_string)
    with {:ok, guild} <- GuildCache.get(guild_id),
         {:ok, user} <- Converters.to_member("<@#{user_id_string}>", guild_id),
         {:ok, role} <- Converters.to_role("<@&#{role_id}>", guild_id) do
      IO.puts("Removing role")
      {:ok} = Api.remove_guild_member_role(guild_id, user_id, role_id, reason)
      {:ok, 1} = Redix.command(:redix, ["HDEL", @applied_infractions_prefix, "#{@role_infraction}" <> "#{guild_id_string}_#{user_id}"])
      Task.start(fn ->
        {:ok, _message} = send_to_log("Наказание <@&#{role.id}> было снято с <@#{user_id}>", guild_id)
      end)
      Task.start(fn ->
        {:ok, dm_channel} = Api.create_dm(user_id)
        {:ok, _message} = Api.create_message(dm_channel.id, "```Ура! Наказание #{role.name} на сервере #{guild.name} было снято.```")
      end)
    else
      err -> IO.inspect(err, label: "Cannot clear infraction for guild #{guild_id}")
    end
  end

  def send_to_log(message, guild_id) do
    with {:ok, guild} <- GuildCache.get(guild_id),
         {:ok, channel} <- Converters.to_channel(Helpers.logs_channel, guild_id) do
      Api.create_message(channel.id, message)
    end
  end

  def create_restricted_roles(guild_id) do
    Helpers.restricted_roles
    |> Enum.each(fn {name, map} ->
      with {:ok, role} <- Api.create_guild_role(guild_id, [color: 0x24211a, name: name, permissions: Map.fetch!(map, :deny)]) do
      else
        err -> Logger.error("Cannot create role #{name}: #{err}")
      end
    end)
  end

  def set_restricted_roles_positions(guild_id) do
    restricted_roles_names =
      Helpers.restricted_roles
      |> Enum.map(fn {name, map} -> name end)
    roles_to_modify =
      Api.get_guild_roles!(guild_id)
      |> Enum.map(fn role ->
        if role.name in restricted_roles_names do
          Map.put(role, :position, 300)
        end
        nil
      end)
      |> Enum.filter(fn r -> r != nil end)
    Api.modify_guild_role_positions(guild_id, roles_to_modify)
  end

end
