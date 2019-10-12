import Config

# For production, don't forget to configure the url host
# to something meaningful, Phoenix uses this information
# when generating URLs.
#
# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix phx.digest` task,
# which you should run after static files are built and
# before starting your production server.
#config :backend, BackendWeb.Endpoint,
#  url: [host: "example.com", port: 80],
#  cache_static_manifest: "priv/static/cache_manifest.json"

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
       prefix: System.get_env("BOT_PREFIX") || "!"

config :mnesia,
       dir: '.mnesia/#{Mix.env}/#{node()}'
config :phoenix, :json_library, Jason
