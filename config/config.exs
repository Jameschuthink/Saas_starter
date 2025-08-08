# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :saas_template, :scopes,
  user: [
    default: true,
    module: SaasTemplate.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: SaasTemplate.AccountsFixtures,
    test_login_helper: :register_and_log_in_user
  ]

config :saas_template,
  ecto_repos: [SaasTemplate.Repo],
  generators: [timestamp_type: :utc_datetime],
  app_name: "Sketchy Storage",
  socials: [
    twitter_handle: "@social_handle",
    instagram_handle: "@social_handle",
    linkedin_handle: "@social_handle",
    bluesky_handle: "@social_handle"
  ],
  rate_limit: %{
    limit_per_time_period: 1000,
    time_period_minutes: 1
  }

# Configures the endpoint
config :saas_template, SaasTemplateWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: SaasTemplateWeb.ErrorHTML, json: SaasTemplateWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SaasTemplate.PubSub,
  live_view: [signing_salt: "WjF7P0jb"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :saas_template, SaasTemplate.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  saas_template: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  saas_template: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configures FunWithFlags
config :fun_with_flags, :cache,
  enabled: true,
  ttl: 900

config :fun_with_flags, :persistence,
  adapter: FunWithFlags.Store.Persistent.Ecto,
  repo: SaasTemplate.Repo,
  ecto_table_name: "feature_flags",
  ecto_primary_key_type: :binary_id

config :fun_with_flags, :cache_bust_notifications, enabled: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
