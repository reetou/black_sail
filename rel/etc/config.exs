# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Do not print debug messages in production
config :logger, level: :debug


# Configures the endpoint
config :backend, BackendWeb.Endpoint,
       http: [:inet6, port: System.get_env("PORT") || 4000],
       url: [host: "thankful-misguided-diamondbackrattlesnake.gigalixirapp.com", port: 80],
       secret_key_base: System.get_env("SECRET_KEY_BASE"),
       render_errors: [view: BackendWeb.ErrorView, accepts: ~w(html json)],
       pubsub: [name: Backend.PubSub, adapter: Phoenix.PubSub.PG2],
       server: true


config :nostrum,
       token: System.get_env("BOT_TOKEN"),
       num_shards: :auto

config :nosedrum,
       prefix: "!"


config :bot, Bot.Scheduler,
       timezone: "Europe/Moscow",
       global: true,
       jobs: [
         # Every minute
         {"* * * * *", {Bot.Infractions, :clear_expired_infractions, []}},
         {"@daily", {Bot.Cogs.Room, :remove_personal_channels, []}},
         {"@daily", {Bot.Cogs.Admin.Stats, :stats_for_servers, []}},
       ]


config :mnesia, dir: '.mnesia/#{Mix.env}/#{node()}'

config :phoenix, :json_library, Jason

config :bot,
       faceit_api_key: System.get_env("FACEIT_API_KEY"),
       redis_host: System.get_env("REDIS_HOST"),
       redis_port: System.get_env("REDIS_PORT"),
       redis_password: System.get_env("REDIS_PASSWORD"),
       mongo_username: System.get_env("MONGO_USERNAME"),
       mongo_password: System.get_env("MONGO_PASSWORD"),
       mongo_host: System.get_env("MONGO_HOST"),
       mongo_database: System.get_env("MONGO_DATABASE"),
       stats_server_url: System.get_env("STATS_SERVER_URL")

config :gen_tcp_accept_and_close, port: 4000
config :gen_tcp_accept_and_close, ip: {0, 0, 0, 0}
