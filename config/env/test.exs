use Mix.Config

config :agar,
  ecto_repos: [AgarTest.Repo],
  repo: AgarTest.Repo,
  audience_module: SpurTest.AppUser

config :agar, AgarTest.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "spur_agar_repo",
  hostname: System.get_env("DB_HOST") || "localhost",
  poolsize: 10,
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "priv/test"
