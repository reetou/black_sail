defmodule Bot.Cogs.Register do
  @moduledoc """
    Sends party message
  """
  @behaviour Nosedrum.Command

  @stats_channel "статистика"
  @command "register"

  alias Bot.{
    Helpers,
    PartySearchParticipants,
    }
  alias Bot.Predicates, as: CustomPredicates
  alias Nosedrum.{
    Predicates,
    Converters,
    }
  alias Nostrum.Api
  alias Nostrum.Struct.{
    Embed,
    Guild,
    Channel,
    Invite,
    }
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Permission
  alias Guild.Member
  import Embed

  @impl true
  def usage,
      do: [
        "!#{@command} ваш_никнейм_на_FaceIT",
      ]

  def usage_text, do: """
  ```
  #{Enum.reduce(usage, "Примеры использования:", fn text, acc -> acc <> "\n" <> text end)}
  ```
"""

  @impl true
  def description,
      do: """
      ```
        Вносит ваш никнейм на FaceIT в базу бота, чтобы вы могли обновлять информацию о вашей статистике на FaceIT!

#{Enum.reduce(usage, "Примеры использования:", fn text, acc -> acc <> "\n" <> text end)}

        Работает только в канале #{@stats_channel}

      ```
      """

  @impl true
  def predicates, do: [&CustomPredicates.guild_only/1, &CustomPredicates.is_stats_channel?/1]

  def command, do: @command
  def stats_channel, do: @stats_channel
  def kdr_roles, do: %{
    "KDR 1" => [min: 1, max: 1.9, index: 1],
    "KDR 2" => [min: 2, max: 2.9, index: 2],
    "KDR 3" => [min: 3, max: 3.9, index: 3],
    "KDR 4" => [min: 4, max: 4.9, index: 4],
    "KDR 5" => [min: 5, max: 5.9, index: 5],
    "KDR 6" => [min: 6, max: 999, index: 6],
  }
  def win_rate_roles, do: %{
    "Винрейт 40%" => [range: 40..49 ],
    "Винрейт 50%" => [range: 50..59 ],
    "Винрейт 60%" => [range: 60..69 ],
    "Винрейт 70%" => [range: 70..79 ],
    "Винрейт 80%" => [range: 80..89 ],
    "Винрейт 90%" => [range: 90..99 ],
    "Винрейт 95%" => [range: 95..100 ],
  }

  def recreate_roles(guild_id) do
    [kdr_roles, win_rate_roles]
    |> Stream.concat()
    |> Enum.each(fn { role_name, _role_data } -> Helpers.create_role_if_not_exists(role_name, guild_id) end)
  end

  def kdr_role_name(kdr) do
    kdr_roles
    |> Enum.find(
         fn {role_name, role_data} ->
           {:min, min} = List.keyfind(role_data, :min, 0)
           {:max, max} = List.keyfind(role_data, :max, 0)
           {value, _} = Float.parse(kdr)
           value >= min and value <= max
         end
       )
  end

  def win_rate_role_name(win_rate) do
    win_rate_roles
    |> Enum.find(
         fn {role_name, role_data} ->
           {:range, range} = List.keyfind(role_data, :range, 0)
           {value, _} = Integer.parse(win_rate)
           value in range
         end
       )
  end

  def assign_role_for_win_rate(win_rate, guild_id, user_id) when guild_id != nil and user_id != nil do
    with {role_name, _} <- win_rate_role_name(win_rate),
         {:ok, %{ id: role_id }} <- Converters.to_role(role_name, guild_id) do
      {:ok} = Api.add_guild_member_role(guild_id, user_id, role_id)
    end
  end

  def assign_role_for_kdr(kdr, guild_id, user_id) when guild_id != nil and user_id != nil do
    with {role_name, _} <- kdr_role_name(kdr),
         {:ok, %{ id: role_id }} <- Converters.to_role(role_name, guild_id) do
      {:ok} = Api.add_guild_member_role(guild_id, user_id, role_id)
    end
  end

  def recreate_channel(guild_id) do
    {:ok, role} = Converters.to_role("@everyone", guild_id)
    Helpers.create_channel_if_not_exists(@stats_channel, guild_id, 0, Helpers.special_channel_permission_overwrites(role.id))
  end

  @impl true
  def command(%{ guild_id: guild_id, author: %{ id: user_id }, channel_id: channel_id, id: msg_id } = msg, args) do
    nickname = get_nickname_from_message(msg.content)
    unless nickname == nil do
      reply = Api.create_message!(channel_id, "Ищу игрока с никнеймом `#{nickname}`...")
      Task.start(fn ->
        Bot.FaceIT.register_user(nickname, user_id, channel_id, guild_id)
        Api.delete_message(channel_id, reply.id)
      end)
    else
      Task.start(fn ->
        reply = Api.create_message!(channel_id, "<@#{msg.author.id}>#{usage_text}")
        Process.sleep(4000)
        Api.delete_message(channel_id, reply.id)
      end)
    end
  end

  def get_nickname_from_message(content) do
    case content do
      "!#{@command} " <> nickname -> nickname
      _ -> nil
    end
  end

end
