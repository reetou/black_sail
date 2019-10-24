import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with webpack to recompile .js and .css sources.

config :nostrum,
       token: System.get_env("BOT_TOKEN"),
       num_shards: :auto

config :nosedrum,
       prefix: System.get_env("BOT_PREFIX") || "!"

config :mnesia,
       dir: '.mnesia/#{Mix.env}/#{node()}'

config :bot,
       faceit_api_key: System.get_env("FACEIT_API_KEY"),
       redis_host: System.get_env("REDIS_HOST"),
       redis_port: System.get_env("REDIS_PORT"),
       redis_password: System.get_env("REDIS_PASSWORD"),
       mongo_username: System.get_env("MONGO_USERNAME"),
       mongo_password: System.get_env("MONGO_PASSWORD"),
       mongo_host: System.get_env("MONGO_HOST"),
       mongo_database: System.get_env("MONGO_DATABASE"),
       stats_server_url: "http://localhost:7801"

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
