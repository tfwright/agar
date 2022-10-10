defmodule Mix.Tasks.Benchmark do
  @moduledoc """
  Run benchmarks
  """
  use Mix.Task

  alias AgarTest.{Repo, ParentSchema, ChildSchema, SiblingSchema}

  @shortdoc "Add extensions to database"
  def run(_) do
    Mix.Task.run("app.start")

    {:ok, _pid} = Repo.start_link()

    Ecto.Adapters.SQL.Sandbox.mode(AgarTest.Repo, :manual)

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    Enum.each(0..5000, fn _ ->
      %ParentSchema{
        name: "hi",
        children: [%ChildSchema{number_field: 2}, %ChildSchema{number_field: 8}]
      }
      |> Repo.insert()
    end)

    Benchee.run(%{
      "simple select" => fn -> Repo.all(ParentSchema) end,
      "aggregrate one field" => fn -> ParentSchema.aggregate(fields: [:name]) |> Repo.all(timeout: :infinity) end,
      "with sum" => fn ->
        ParentSchema.aggregate(fields: [:name], assocs: [children: [number_field: :sum]])
        |> Repo.all(timeout: :infinity)
      end,
      "with sum and array" => fn ->
        ParentSchema.aggregate(fields: [:name], assocs: [children: [number_field: :sum, string_field: :array]])
        |> Repo.all(timeout: :infinity)
      end
    })
  end
end
