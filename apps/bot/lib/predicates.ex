defmodule Bot.Predicates do
  @moduledoc "Implements various predicates used by commands."

  alias Bot.{
    Helpers,
    Cogs.Party,
    Cogs.Register,
  }
  alias Nostrum.Struct.Message
  alias Nostrum.Struct.User
  alias Nostrum.Api
  alias Nosedrum.Converters

  def is_party_search_channel?(msg) do
    check_expected_channel(msg, Party.search_channel)
  end

  def is_stats_channel?(msg) do
    check_expected_channel(msg, Register.stats_channel)
  end

  def is_commands_channel?(msg) do
    check_expected_channel(msg, Helpers.commands_channel)
  end

  def guild_only(%Message{guild_id: nil}), do: {:error, "Эту команду можно использовать только на сервере"}
  def guild_only(_), do: :passthrough

  defp check_expected_channel(%{ channel_id: channel_id, guild_id: guild_id, id: msg_id } = msg, expected_channel) do
    case Converters.to_channel("#{channel_id}", guild_id) do
      {:ok, %{ name: name }} when name == expected_channel -> {:ok, msg}
      _ ->
        with {:ok, %{ id: expected_channel_id }} <- Converters.to_channel(expected_channel, guild_id) do
          {:error, "<@#{msg.author.id}>, эта команда доступна только в канале <##{expected_channel_id}>"}
        else _err ->
          {:error, "<@#{msg.author.id}>, эта команда недоступна в этом канале"}
        end
    end
  end
end
