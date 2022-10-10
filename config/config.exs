use Mix.Config

config :agar,
  ecto_repos: [AgarTest.Repo],
  repo: AgarTest.Repo,
  audience_module: SpurTest.AppUser,
  custom_aggregations: [
    array: "ARRAY_AGG(?)"
  ]

config :agar, AgarTest.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: System.get_env("POSTGRES_DB", "spur_agar_repo"),
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  poolsize: 10,
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "priv/test"
