defmodule AgarTest do
  use ExUnit.Case

  alias AgarTest.{Repo, ParentSchema, ChildSchema}

  doctest Agar

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "aggregate with fields option" do
    setup do
      %ParentSchema{
        name: "hi"
      }
      |> Repo.insert!()

      :ok
    end

    test "includes given field in results" do
      assert [%{"name" => "hi"}] = ParentSchema.aggregate(fields: [:name]) |> Repo.all()
    end
  end

  describe "aggregate with association sum" do
    setup do
      parent =
        %ParentSchema{
          name: "hi"
        }
        |> Repo.insert!()

      [
        %ChildSchema{number_field: 2, parent_schema: parent},
        %ChildSchema{number_field: 8, parent_schema: parent}
      ]
      |> Enum.each(&Repo.insert!(&1))

      :ok
    end

    test "includes sum in results" do
      assert [%{"children_number_field_sum" => 10}] =
               ParentSchema.aggregate(assocs: [children: [number_field: [:sum]]])
               |> Repo.all()
    end
  end
end
