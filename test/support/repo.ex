defmodule AgarTest.Repo do
  use Ecto.Repo,
    otp_app: :agar,
    adapter: Ecto.Adapters.Postgres
end
