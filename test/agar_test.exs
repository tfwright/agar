defmodule AgarTest do
  use ExUnit.Case

  alias AgarTest.{TestSchema, Repo}

  doctest Agar

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "aggregate with fields option" do
    setup do
      %TestSchema{
        number_field: 2
      }
      |> Repo.insert!()

      :ok
    end

    test "includes given field in results" do
      assert [%{"number_field" => 2}] =
               TestSchema.aggregate(fields: [:number_field]) |> Repo.all()
    end
  end
end
