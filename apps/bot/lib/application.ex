defmodule Bot.Application do
  @moduledoc """
  The entry point for bot.
  Starts the required processes, including the gateway consumer supervisor.
  """
  require Logger
  use Application
  import Application

  @impl true
  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = [
      Bot.Scheduler,
#      worker(Bot.Periodic, []),
      {Redix,
        host: Application.fetch_env!(:bot, :redis_host),
        port: String.to_integer(Application.fetch_env!(:bot, :redis_port)),
        password: Application.fetch_env!(:bot, :redis_password),
        name: :redix
      },
      worker(Mongo, [
        [
          name: :mongo,
          url: "mongodb+srv://#{fetch_env!(:bot, :mongo_username)}:#{fetch_env!(:bot, :mongo_password)}@#{fetch_env!(:bot, :mongo_host)}/#{fetch_env!(:bot, :mongo_database)}?retryWrites=true&w=majority",
          pool_size: 3,
        ]
      ]),
      Nosedrum.Storage.ETS,
      # Supervises Discord Gateway event consumers.
      Bot.ConsumerSupervisor,
    ]
    Memento.Table.create(Bot.VoiceMembers)
    Memento.Table.create(Bot.PartySearchParticipants)
    options = [strategy: :rest_for_one, name: Bot.Supervisor]
    Supervisor.start_link(children, options)
  end

end
