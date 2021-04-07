{:ok, _pid} = AgarTest.Repo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(AgarTest.Repo, :manual)

ExUnit.start()
