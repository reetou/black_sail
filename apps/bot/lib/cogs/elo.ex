defmodule Bot.Cogs.Elo do
  alias Bot.Cogs.Party
  alias Bot.Cogs.Register
  alias Bot.Helpers
  alias Bot.Predicates, as: CustomPredicates
  require Logger

  @command "elo"
  @user_limit Party.user_limit
  @search_channel Party.search_channel

  def usage,
      do: [
        "!#{@command} ваш_комментарий",
        "!#{@command} эло_целым_числом",
        "!#{@command} эло_целым_числом  ваш_комментарий",
      ]

  def description,
      do: """
      ```
      Отправляет сообщение с поиском пати с эло не менее указанного значения. Если значения нет, то кдр будет высчитан на основе вашей роли
      **Вы не можете искать пати с эло выше чем ваше собственное.**

      После или вместо значения эло можно указать комментарий.

      Если вы находитесь не в голосовом чате, бот создаст для вас канал на #{@user_limit} человек.

      Команда: !#{@command} Предпочитаю играть с любителями народных песен

      Выведет Embed-сообщение:

      Поиск Competitive FaceIT
      @username KDA 2

      Коммент: Предпочитаю играть с любителями народных песен

      Установлено ограничение на вход по ELO: тут_будет_ваш_эло

      #{Enum.reduce(usage, "Примеры использования:", fn text, acc -> acc <> "\n" <> text end)}

        Работает только в канале #{@search_channel}
      ```
      """

  def predicates, do: [&CustomPredicates.guild_only/1, &CustomPredicates.is_party_search_channel?/1]

  def command, do: @command
  def search_channel, do: @search_channel

  def command(msg, args) when is_list(args) and length(args) == 0 do
    IO.inspect(msg.member.roles, label: "Roles for ELO command")
    elo_role = Party.get_elo_role_name(msg.member.roles, msg.guild_id)
    unless elo_role == nil do
      with {:ok, voice_channel_id} when voice_channel_id != nil <- Party.ensure_user_in_voice_channel(msg) do
        Party.send_message(msg, voice_channel_id, elo_role != nil)
      else
        _ -> {:error, :no_voice_channel}
      end
    else
      response = "<@#{msg.author.id}>, не удалось получить данные о вашем ELO. У вас точно есть роль ELO?"
      Helpers.reply_and_delete_message(msg.channel_id, response, 20000)
      {:error, response}
    end
  end

  defp get_maximum_allowed_index(msg, index) do
    elo_role = Party.get_elo_role_name(msg.member.roles, msg.guild_id)
    Party.get_role_index(elo_role, index)
    |> IO.inspect(label: "Index from sanitized #{msg.content}")
  end

  def command(msg, args) do
    {:ok, voice_channel_id} = Party.ensure_user_in_voice_channel(msg)
    unless voice_channel_id == nil do
      with {valid_index, _} <- Integer.parse(List.first(args)) do
        case elo_from_message(msg, args) do
          :error -> Helpers.reply_and_delete_message(msg.channel_id, "<@#{msg.author.id}>, Не удалось распознать желаемое ограничение эло")
          {index, updated_msg} ->
            elo_role = Party.get_elo_role_name(msg.member.roles, msg.guild_id)
            sanitized_index = get_maximum_allowed_index(msg, index)
            Logger.debug("Index from command is #{index}, sanitized it to #{sanitized_index}")
            Logger.debug("Updated message with comment: #{updated_msg.content}")
            Party.send_message(updated_msg, voice_channel_id, elo_role != nil, sanitized_index)
        end
      else
        _ ->
          elo_role = Party.get_elo_role_name(msg.member.roles, msg.guild_id)
          Logger.debug("Index cannot be parsed directly from command, let Party.send_message handle it")
          Party.send_message(msg, voice_channel_id, elo_role != nil)
      end
    else
      Helpers.reply_and_delete_message(msg.channel_id, "<@#{msg.author.id}>, Вы должны находиться в голосовом канале")
    end
  end

  def elo_from_message(msg, args) when length(args) > 1 do
    possible_value = List.first(args)
    Logger.debug("Possible index at ELO command: #{possible_value}")
    case Integer.parse(possible_value) do
      {value, _} ->
        index_size = byte_size(possible_value)
        command_size = byte_size("!#{@command}")
        size = byte_size(msg.content) - command_size - index_size
        Logger.debug("Comparing content and getting comment: #{msg.content}")
        <<cmd :: binary-size(command_size)>> <> " " <> <<index :: binary-size(index_size)>> <> " " <> comment_without_index = msg.content
        Logger.debug("Comment without index at ELO command: #{comment_without_index}")
        updated_msg =
          msg
          |> Map.put(:content, "!" <> command <> " " <> comment_without_index)
        {role_name, opts} = Register.elo_role(value)
        {:index, index} = List.keyfind(opts, :index, 0)
        {index, updated_msg}
      err -> err
    end
  end

  def elo_from_message(msg, args) when length(args) == 1 do
    possible_stats_value = List.first(args)
    Logger.debug("Possible index at ELO command: #{possible_stats_value}")
    size = byte_size(msg.content) - byte_size(" ") - byte_size(possible_stats_value)
    index_size = byte_size(possible_stats_value)
    <<command_without_index :: binary-size(size) >> <> " " <> <<index_or_comment :: binary-size(index_size)>> = msg.content
    case Integer.parse(possible_stats_value) do
      {value, _} ->
        Logger.debug("No comment provided, passing #{command_without_index} to party command")
        updated_msg = msg |> Map.put(:content, command_without_index)
        {role_name, opts} = Register.elo_role(value)
        {:index, index} = List.keyfind(opts, :index, 0)
        {index, updated_msg}
      err ->
        index = get_maximum_allowed_index(msg, nil)
        updated_msg = Map.put(msg, :content, command_without_index <> " " <> Integer.to_string(index) <> " " <> index_or_comment)
        |> IO.inspect(label: "Updated message")
        Logger.debug("Not a valid integer, so implying that this is a comment without explicitly declared ELO")
        elo_from_message(updated_msg, List.wrap(Integer.to_string(index)) ++ args)
    end
  end

end
