defmodule Bot.Cogs.KDR do
  alias Bot.Cogs.Party
  alias Bot.Helpers
  alias Bot.Predicates, as: CustomPredicates
  require Logger

  @command "kdr"
  @user_limit Party.user_limit
  @search_channel Party.search_channel

  def usage,
      do: [
        "!#{@command} ваш_комментарий",
        "!#{@command} кдр_целым_числом",
        "!#{@command} кдр_целым_числом ваш_комментарий",
      ]

  def description,
      do: """
      ```
      Отправляет сообщение с поиском пати с кдр не менее указанного значения. Если значения нет, то кдр будет высчитан на основе вашей роли
      **Вы не можете искать пати с кдр выше чем ваше собственное.**

      После или вместо значения кдр можно указать комментарий.

      Если вы находитесь не в голосовом чате, бот создаст для вас канал на #{@user_limit} человек.

      Команда: !#{@command} Предпочитаю играть с любителями народных песен

      Выведет Embed-сообщение:

      Поиск Competitive FaceIT
      @username KDA 2

      Коммент: Предпочитаю играть с любителями народных песен

      Установлено ограничение на вход по KDR: тут_будет_ваш_кдр

      #{Enum.reduce(usage, "Примеры использования:", fn text, acc -> acc <> "\n" <> text end)}

        Работает только в канале #{@search_channel}
      ```
      """

  def predicates, do: [&CustomPredicates.guild_only/1, &CustomPredicates.is_party_search_channel?/1]

  def command, do: @command
  def search_channel, do: @search_channel

  def command(msg, args) when is_list(args) and length(args) == 0 do
    IO.inspect(msg.member.roles, label: "Roles for kdr command")
    kdr_role = Party.get_kdr_role_name(msg.member.roles, msg.guild_id)
    unless kdr_role == nil do
      with {:ok, voice_channel_id} when voice_channel_id != nil <- Party.ensure_user_in_voice_channel(msg) do
        Party.send_message(msg, voice_channel_id, kdr_role != nil)
      end
    else
      response = "<@#{msg.author.id}>, не удалось получить данные о вашем KDR. У вас точно есть роль KDR?"
      Helpers.reply_and_delete_message(msg.channel_id, response)
    end
  end

  defp get_maximum_allowed_index(msg, index) do
    kdr_role = Party.get_kdr_role_name(msg.member.roles, msg.guild_id)
    Party.get_role_index(kdr_role, index)
  end

  def command(msg, args) do
    {:ok, voice_channel_id} = Party.ensure_user_in_voice_channel(msg)
    unless voice_channel_id == nil do
      with {valid_index, _} <- Integer.parse(List.first(args)) do
        case index_from_message(msg, args) do
          :error -> Helpers.reply_and_delete_message(msg.channel_id, "<@#{msg.author.id}>, Не удалось распознать желаемое ограничение кдр")
          {index, updated_msg} ->
            kdr_role = Party.get_kdr_role_name(msg.member.roles, msg.guild_id)
            sanitized_index = get_maximum_allowed_index(msg, index)
            Logger.debug("Index from command is #{index}, sanitized it to #{sanitized_index}")
            Party.send_message(updated_msg, voice_channel_id, kdr_role != nil, sanitized_index)
        end
      else
        _ ->
          kdr_role = Party.get_kdr_role_name(msg.member.roles, msg.guild_id)
          Logger.debug("Index cannot be parsed directly from command, let Party.send_message handle it")
          Party.send_message(msg, voice_channel_id, kdr_role != nil)
      end
    else
      Helpers.reply_and_delete_message(msg.channel_id, "<@#{msg.author.id}>, Вы должны находиться в голосовом канале")
    end
  end

  def index_from_message(msg, args) when length(args) > 1 do
    possible_index = List.first(args)
    Logger.debug("Possible index at KDR command: #{possible_index}")
    case Integer.parse(possible_index) do
      {value, _} ->
        index_size = byte_size(possible_index)
        command_size = byte_size("!#{@command}")
        size = byte_size(msg.content) - command_size - index_size
        Logger.debug("Comparing content and getting comment: #{msg.content}")
        <<cmd :: binary-size(command_size)>> <> " " <> <<index :: binary-size(index_size)>> <> " " <> comment_without_index = msg.content
        Logger.debug("Comment without index at KDR command: #{comment_without_index}")
        updated_msg =
          msg
          |> Map.put(:content, "!kdr " <> comment_without_index)
        {value, updated_msg}
      err -> err
    end
  end

  def index_from_message(msg, args) when length(args) == 1 do
    possible_index = List.first(args)
    Logger.debug("Possible index at KDR command: #{possible_index}")
    size = byte_size(msg.content) - byte_size(" ") - byte_size(possible_index)
    index_size = byte_size(possible_index)
    <<command_without_index :: binary-size(size) >> <> " " <> <<index_or_comment :: binary-size(index_size)>> = msg.content
    case Integer.parse(possible_index) do
      {value, _} ->
        Logger.debug("No comment provided, passing #{command_without_index} to party command")
        updated_msg = msg |> Map.put(:content, command_without_index)
        {value, updated_msg}
      err ->
        index = get_maximum_allowed_index(msg, nil)
        updated_msg = Map.put(msg, :content, command_without_index <> " " <> Integer.to_string(index) <> " " <> index_or_comment)
        |> IO.inspect(label: "Updated message")
        Logger.debug("Not a valid integer, so implying that this is a comment without explicitly declared kdr")
        index_from_message(updated_msg, List.wrap(Integer.to_string(index)) ++ args)
    end
  end

end
