defmodule Bot.Cogs.Party do
  require Logger
  @moduledoc """
    Sends party message
  """
  @behaviour Nosedrum.Command

  @search_channel "поиск"
  @user_limit 5
  @text_channel_type 0
  @command "party"
  @category_name "игровые комнаты"
  @topic """
  Для поиска введите команду !party ваш_комментарий. Если вы не в голосовом канале, бот создаст канал и переместит вас туда.
"""

  alias Bot.{
    Helpers,
    PartySearchParticipants,
    Cogs.Register,
  }
  alias Nosedrum.{
    Predicates,
    Converters,
  }
  alias Bot.Predicates, as: CustomPredicates
  alias Nostrum.{
    Api,
    Permission,
    Snowflake,
  }
  alias Nostrum.Struct.{
    Embed,
    Guild,
    Channel,
    Invite,
  }
  alias Nostrum.Cache.GuildCache
  alias Guild.Member
  import Embed

  @impl true
  def usage,
      do: [
        "!#{@command} ваш_комментарий",
      ]

  @impl true
  def description,
      do: """
      ```
      Отправляет сообщение с поиском пати.
      Если вы находитесь не в голосовом чате, бот создаст для вас канал на #{@user_limit} человек.

      Команда: !#{@command} Предпочитаю играть с любителями народных песен

      Выведет Embed-сообщение:

      Поиск Competitive FaceIT
      @username KDA 2

      Коммент: Предпочитаю играть с любителями народных песен

#{Enum.reduce(usage, "Примеры использования:", fn text, acc -> acc <> "\n" <> text end)}

        Работает только в канале #{@search_channel}
      ```
      """

  @impl true
  def predicates, do: [&CustomPredicates.guild_only/1, &CustomPredicates.is_party_search_channel?/1]

  def command, do: @command
  def search_channel, do: @search_channel
  def user_limit, do: @user_limit

  def recreate_channel(guild_id) do
    {:ok, role} = Converters.to_role("@everyone", guild_id)
    Helpers.create_channel_if_not_exists(@search_channel, guild_id, 0, Helpers.special_channel_permission_overwrites(role.id))
  end

  @impl true
  def command(%{ guild_id: guild_id, member: member, channel_id: channel_id } = msg, _args) do
    with {:ok, voice_channel_id} when voice_channel_id != nil <- ensure_user_in_voice_channel(msg) do
      send_message(msg, voice_channel_id)
    end
  end

  def ensure_user_in_voice_channel(%{ guild_id: guild_id, channel_id: channel_id } = msg) do
    with true <- Helpers.is_in_voice_channel?(msg.author.id) do
      case CustomPredicates.in_own_voice_channel(msg) do
        :passthrough ->
          voice_channel_id = Bot.VoiceMembers.get_channel_id_by_user_id(msg.author.id)
          if voice_channel_id == nil do
            response = "Что-то пошло не так. <@#{msg.author.id}>, пожалуйста, введите команду заново"
            Task.start(fn -> Api.create_message!(channel_id, response) end)
          end
          {:ok, voice_channel_id}
        {:error, reason} = result ->
          Helpers.reply_and_delete_message(channel_id, reason, 15000)
          result
      end
    else
      _ ->
        username_with_discriminator = msg.author.username <> "#" <> msg.author.discriminator
        channel_name_for_member = get_channel_name_for_member(username_with_discriminator)
        Task.start(
          fn ->
            delete_empty_voice_channels_with_same_name(channel_name_for_member, guild_id)
          end
        )
        %Channel{} = channel = create_voice_channel_for_member(guild_id, username_with_discriminator, msg.author.id)
        invite = Api.create_channel_invite!(channel.id, max_age: 1200)
        Task.start(
          fn ->
            Api.create_message(
              channel_id,
              content: "<@#{msg.author.id}>",
              embed: message_if_not_in_voice_channel(msg.author.id, invite)
            )
          end
        )
        :ignored
    end
  end

  def send_message(%{ channel_id: channel_id, member: member, guild_id: guild_id } = msg, voice_channel_id, restrict_by_kdr \\ false, override_index \\ nil) do
    {:ok, %{ id: everyone_role_id }} = Converters.to_role("@everyone", guild_id)
    invite_task = Task.async(fn -> Api.create_channel_invite!(voice_channel_id, max_age: 1200) end)
    if restrict_by_kdr == true do
      IO.inspect(member.roles, label: "Roles for member")
    end
    kdr_role = if restrict_by_kdr == true, do: get_kdr_role_name(member.roles, guild_id), else: nil
    unless kdr_role == nil do
      Logger.debug("Restrict by kdr enabled, set permissions depending on kdr role: #{kdr_role}.")
      actual_role_index = get_role_index(kdr_role, override_index)
      {:ok} = Api.edit_channel_permissions(voice_channel_id, everyone_role_id, Helpers.deny_speak_and_connect :role)
      set_permissions_by_index(actual_role_index, voice_channel_id, guild_id, override_index, :allow)
      set_permissions_by_index(actual_role_index, voice_channel_id, guild_id, override_index, :deny)
    else
      Logger.debug("Kdr role is #{if kdr_role == nil, do: "UNKNOWN", else: kdr_role} or restrict by kdr disabled, allowing everyone to connect and speak in channel #{voice_channel_id}")
      Task.start(fn ->
        set_permissions_for_party_voice_channel(voice_channel_id, guild_id)
#        {:ok} = Api.edit_channel_permissions(voice_channel_id, everyone_role_id, Helpers.allow_speak_and_connect :role)
      end)
    end
    invite = Task.await(invite_task)
    reply = Api.create_message!(channel_id, embed: create_party_message(msg, invite, kdr_role, override_index))
    write_party_message_history(%PartySearchParticipants{
      message_id: reply.id,
      voice_channel_id: voice_channel_id,
      guild_id: guild_id,
      invite_code: invite.code,
      text_channel_id: channel_id,
      comment: extract_comment(msg.content),
      kdr_role: kdr_role,
      override_index: override_index,
    })
  end

  def write_party_message_history(%PartySearchParticipants{ voice_channel_id: voice_channel_id, guild_id: guild_id } = data) do
    PartySearchParticipants.delete_party_messages_for_voice_channel(voice_channel_id, guild_id)
    PartySearchParticipants.write_party_search_message(data)
  end

  def create_party_message(msg, invite, kdr_role \\ nil, override_index \\ nil) do
    %{
      guild_id: guild_id,
      author: %{
        id: user_id
      },
    } = msg
    %Invite{
      channel: %{
        id: channel_id
      }
    } = invite
    members = Bot.VoiceMembers.get_channel_members(%Bot.VoiceMembers{channel_id: channel_id, guild_id: guild_id})
    placesLeft = @user_limit - length(members)
    title = if placesLeft != 0, do: "Ищу +#{placesLeft}", else: "Пати собрано"
    embed = %Embed{}
            |> put_title(title)
    embed_description = Enum.reduce(
      members,
      "",
      fn %Member{
           user: %{id: id},
           roles: roles,
         }, acc ->
        acc <> "<@#{id}> " <> party_message_roles(roles, guild_id) <> " \n"
      end
    )
    actual_index = get_role_index(kdr_role, override_index)
    index = if actual_index > override_index, do: override_index, else: actual_index
    comment = extract_comment(msg.content)
    invite_text = "\n\nПерейти: https://discord.gg/"
    embed_description = comment <> "\n" <> embed_description <> invite_text <> invite.code <> get_description_for_kdr(index)
    embed
    |> put_description(embed_description)
  end

  def get_description_for_kdr(index) when index == nil, do: "\n\nСвободный вход"
  def get_description_for_kdr(index) do
    "\n\nУстановлено ограничение на вход по KDR: #{index} и выше"
  end

  defp get_comment(%Embed{} = embed, content) do
    case content do
      "!#{@command} " <> comment ->
        embed
        |> put_description("Коммент: #{comment}")
        |> IO.inspect(label: "Embed with comment")
      _ ->
        IO.inspect(content, label: "Content message for comment")
        embed
    end
  end

  defp extract_comment(content) do
    args = String.split(content)
    Logger.debug("Trimming #{Enum.at(args, 0)}")
    comment = String.trim_leading(content, Enum.at(args, 0))
    with true <- length(args) > 1 do
      "Комментарий: #{comment}\n"
    else
      _ -> ""
    end
  end

  defp get_member_description(user_id) do
    "<@#{user_id}>: Player"
  end

  defp create_voice_channel_for_member(guild_id, username, user_id) do
    %Channel{} = parent_category = get_or_create_parent_category(guild_id)
    %{id: id} = Api.create_guild_channel!(guild_id, [
      name: get_channel_name_for_member(username),
      type: 2,
      user_limit: @user_limit,
      parent_id: parent_category.id,
      permission_overwrites: [
        Map.put(Helpers.allow_manage_voice_channel(:member), :id, user_id)
      ] ++ Helpers.infraction_roles_permission_overwrites(guild_id),
    ])
  end

  defp message_if_not_in_voice_channel(user_id, %Invite{} = invite) do
    %Embed{}
    |> put_description(
         """
         <@#{user_id}>, для вас был создан канал **#{invite.channel.name}**. Перейдите в него и введите команду заново

         Нажмите для перехода: https://discord.gg/#{invite.code}
         """
       )
  end

  defp get_or_create_parent_category(guild_id) do
    parent_category = Api.get_guild_channels!(guild_id)
    |> Enum.find(fn x -> x.name == @category_name end)
    case parent_category do
      %Channel{} = channel ->
        channel
      err ->
        IO.inspect(err, label: "Unable to find such channel")
        Api.create_guild_channel!(guild_id, name: @category_name, type: 4)
    end
  end

  def get_channel_name_for_member(username) do
    "#{Helpers.game_channel_prefix} #{username}"
  end

  def set_permissions_for_party_voice_channel(voice_channel_id, guild_id) do
    Register.kdr_roles
    |> Enum.map(fn role_data ->
      role_data
      |> Tuple.to_list
      |> List.first
    end)
    |> Enum.map(fn name ->
      case Converters.to_role(name, guild_id) do
        {:ok, role} -> role
        _ -> nil
      end
    end)
    |> Enum.filter(fn r -> r != nil end)
    |> Enum.each(fn %{id: id, name: name} ->
      Logger.debug("Delete permissions for role #{name} from channel #{voice_channel_id}")
      Api.delete_channel_permissions(voice_channel_id, id)
    end)
    Task.start(fn ->
      {:ok, %{ id: everyone_role_id }} = Converters.to_role("@everyone", guild_id)
      Api.edit_channel_permissions(voice_channel_id, everyone_role_id, Helpers.allow_speak_and_connect :role)
    end)
  end

  def set_permissions_by_index(current_index, voice_channel_id, guild_id, override_index, type) do
    case override_index do
      nil ->
        Logger.debug("Override is nil. Index is set to #{current_index} for type #{type}")
        set_permissions_for_roles_by_index(current_index, voice_channel_id, guild_id, type)
      _ ->
        if override_index < current_index do
          Logger.debug("Override index is < current index: putting #{override_index} for type #{type}")
          set_permissions_for_roles_by_index(override_index, voice_channel_id, guild_id, type)
        else
          Logger.debug("Putting current index #{current_index} for type #{type}")
          set_permissions_for_roles_by_index(current_index, voice_channel_id, guild_id, type)
        end
    end
  end

  def set_permissions_for_roles_by_index(role_index, voice_channel_id, guild_id, type) when type == :allow do
    Register.kdr_roles
    |> Enum.filter(fn {name, opts} ->
      {:index, index} = List.keyfind(opts, :index, 0)
      index >= role_index
    end)
    |> Enum.map(fn role_data ->
      role_data
      |> Tuple.to_list
      |> List.first
    end)
    |> Enum.map(fn name ->
      case Converters.to_role(name, guild_id) do
        {:ok, role} -> role
        _ -> nil
      end
    end)
    |> Enum.filter(fn r -> r != nil end)
    |> Enum.each(fn %{id: id, name: name} ->
      Logger.debug("Allow speak and connect for role #{name} to channel #{voice_channel_id}")
      Api.edit_channel_permissions(voice_channel_id, id, Helpers.allow_speak_and_connect :role)
    end)
  end

  def set_permissions_for_roles_by_index(role_index, voice_channel_id, guild_id, type) when type == :deny do
    Register.kdr_roles
    |> Enum.filter(fn {name, opts} ->
      {:index, index} = List.keyfind(opts, :index, 0)
      index < role_index
    end)
    |> Enum.map(fn role_data ->
      role_data
      |> Tuple.to_list
      |> List.first
    end)
    |> Enum.map(fn name ->
      case Converters.to_role(name, guild_id) do
        {:ok, role} -> role
        _ -> nil
      end
    end)
    |> Enum.filter(fn r -> r != nil end)
    |> Enum.each(fn %{id: id, name: name} ->
      Logger.debug("Deny speak and connect for role #{name}")
      Api.delete_channel_permissions(voice_channel_id, id)
    end)
  end

  defp party_message_roles(roles, guild_id) do
    roles
    |> Helpers.get_guild_roles_by_id!(guild_id)
    |> Enum.map(fn %{ name: name } -> name end)
    |> Enum.filter(fn name -> is_kdr_role?(name) end)
    |> Enum.reduce("", fn name, acc -> acc <> name <> " "  end)
  end

  defp is_kdr_role?(name) do
    kdr_roles_names = Register.kdr_roles
                      |> Enum.map(&(elem(&1, 0)))
    name in kdr_roles_names
  end

  defp is_kdr_role?(name) when name == nil do
    false
  end

  def get_kdr_role_name(roles, guild_id) when roles == nil, do: nil
  def get_kdr_role_name(roles, guild_id) when is_list(roles) and length(roles) == 0, do: nil
  def get_kdr_role_name(roles, guild_id) do
    role =
      roles
      |> Helpers.get_guild_roles_by_id!(guild_id)
      |> IO.inspect(label: "Got roles by ids")
      |> Enum.filter(fn %{name: name} -> is_kdr_role?(name) end)
      |> Enum.map(fn r ->
        unless r == nil do
          Map.fetch(r, :name)
        else
          nil
        end
      end)
      |> List.first
    case role do
      {:ok, name} -> name
      _ -> nil
    end
  end

  def get_role_index(role_name, override_index \\ nil)
  def get_role_index(role_name, override_index) when role_name == nil, do: nil
  def get_role_index(role_name, override_index) when is_integer(override_index) or override_index == nil do
    index = Register.kdr_roles
    |> Enum.find(fn {name, opts} -> name == role_name end)
    |> elem(1)
    |> List.keyfind(:index, 0)
    |> elem(1)
    unless override_index == nil do
      index_to_return = if override_index < index, do: override_index, else: index
      Logger.debug("Override index is #{override_index}, origin index is #{index}. If origin index is lower than override, should return override: #{index_to_return}")
      index_to_return
    else
      Logger.debug("Override index is nil, returning regular index: #{index}")
      index
    end
  end

  def higher_or_equal_index_roles(role_name, override_index \\ nil) when role_name != nil and is_binary(role_name) do
    role_index = get_role_index(role_name, override_index)
    with true <- role_index != nil do
      Register.kdr_roles
      |> Enum.filter(fn {name, opts} ->
        index = opts
        |> List.keyfind(:index, 0)
        |> elem(1)
        index >= role_index
      end)
      |> Enum.map(&(elem(&1, 0)))
    else
      err ->
        err |> IO.inspect(label: "ERROR")
        []
    end
  end

  def lower_index_roles(role_name, override_index \\ nil) when role_name != nil and is_binary(role_name) do
    role_index = get_role_index(role_name, override_index)
    with true <- role_index != nil do
      Register.kdr_roles
      |> Enum.filter(fn {name, opts} ->
        index = opts
        |> List.keyfind(:index, 0)
        |> elem(1)
        index < role_index
      end)
      |> Enum.map(&(elem(&1, 0)))
    else
      err ->
        err |> IO.inspect(label: "ERROR")
        []
    end
  end

  defp delete_empty_voice_channels_with_same_name(channel_name, guild_id) do
    case GuildCache.get(guild_id) do
      {:ok, guild} ->
        guild.channels
        |> Enum.filter(fn { id, ch } ->
          ch.name == channel_name and ch.type == 2 and Bot.VoiceMembers.is_voice_channel_empty?(id, guild_id)
        end)
        |> Enum.each(fn { id, ch } ->
          Api.delete_channel(ch.id, "Deleting empty duplicate")
        end)
      _ -> nil
    end
  end
end
