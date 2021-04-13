defmodule AgarTest do
  use ExUnit.Case

  import Ecto.Query

  alias AgarTest.{Repo, ParentSchema, ChildSchema, SiblingSchema}

  doctest Agar

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "aggregate/1 with fields option" do
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

  describe "aggregate/1 on query" do
    setup do
      %ParentSchema{
        name: "hi"
      }
      |> Repo.insert!()

      :ok
    end

    test "includes given field in results when record is included in query" do
      assert [%{"name" => "hi"}] =
               ParentSchema
               |> where(name: "hi")
               |> ParentSchema.aggregate(fields: [:name])
               |> Repo.all()
    end

    test "returns empty list when no record is included in query" do
      assert [] =
               ParentSchema
               |> where(name: "not hi")
               |> ParentSchema.aggregate(fields: [:name])
               |> Repo.all()
    end
  end

  describe "aggregate/1 with association sum" do
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

  describe "aggregate/1 with 1-1 association field" do
    setup do
      parent =
        %ParentSchema{}
        |> Repo.insert!()

      %SiblingSchema{string_field: "what", parent_schema: parent}
      |> Repo.insert!()

      :ok
    end

    test "includes field in results" do
      assert [%{"sibling_string_field" => "what"}] =
               ParentSchema.aggregate(fields: [sibling: :string_field])
               |> Repo.all()
    end
  end

  describe "aggregate/1 with 1-1 association field and association sum" do
    setup do
      parent =
        %ParentSchema{name: "hi"}
        |> Repo.insert!()

      other_parent =
        %ParentSchema{name: "hi"}
        |> Repo.insert!()

      %SiblingSchema{string_field: "what", parent_schema: parent}
      |> Repo.insert!()

      %ChildSchema{number_field: 1, parent_schema: parent}
      |> Repo.insert!()

      %ChildSchema{number_field: 2, parent_schema: other_parent}
      |> Repo.insert!()

      :ok
    end

    test "includes field in results" do
      assert [
               %{"sibling_string_field" => "what", "children_number_field_sum" => 1},
               %{"sibling_string_field" => nil, "children_number_field_sum" => 0}
             ] =
               ParentSchema.aggregate(
                 fields: [sibling: [:string_field]],
                 assocs: [children: [number_field: :sum]]
               )
               |> Repo.all()
    end
  end

  describe "aggregate/1 with association field sum when there are no associated records" do
    setup do
      %ParentSchema{}
      |> Repo.insert!()

      :ok
    end

    test "includes sum in results" do
      assert [%{"children_number_field_sum" => 0}] =
               ParentSchema.aggregate(assocs: [children: [number_field: [:sum]]])
               |> Repo.all()
    end
  end

  describe "aggregate/1 with association field with custom function" do
    setup do
      parent =
        %ParentSchema{
          name: "hi"
        }
        |> Repo.insert!()

      [
        %ChildSchema{string_field: "one", parent_schema: parent},
        %ChildSchema{string_field: "two", parent_schema: parent}
      ]
      |> Enum.each(&Repo.insert!(&1))

      :ok
    end

    test "includes aggregate in results" do
      assert [%{"children_string_field_array" => ["one", "two"]}] =
               ParentSchema.aggregate(assocs: [children: [string_field: [:array]]])
               |> Repo.all()
    end
  end

  describe "aggregate field with non-array function" do
    test "does not raise" do
      assert [] =
               ParentSchema.aggregate(assocs: [children: [string_field: :array]])
               |> Repo.all()
    end
  end

  describe "aggregate/1 with association field with non-array function" do
    test "does not raise" do
      assert [] =
               ParentSchema.aggregate(assocs: [children: [string_field: :array]])
               |> Repo.all()
    end
  end

  describe "aggregate with child field" do
    setup do
      parent =
        %ParentSchema{
          name: "hi"
        }
        |> Repo.insert!()

      [
        %ChildSchema{string_field: "one", parent_schema: parent},
        %ChildSchema{string_field: "two", parent_schema: parent}
      ]
      |> Enum.each(&Repo.insert!(&1))

      :ok
    end

    test "groups by child field" do
      assert [
               %{"name" => "hi", "children_string_field" => "one"},
               %{"name" => "hi", "children_string_field" => "two"}
             ] =
               ParentSchema.aggregate(fields: [:name, children: :string_field])
               |> Repo.all()
               |> Enum.sort_by(&Map.fetch!(&1, "children_string_field"))
    end
  end

  describe "aggregate with parent grouping and child aggregate" do
    setup do
      parent =
        %ParentSchema{
          name: "hi"
        }
        |> Repo.insert!()

      other_parent =
        %ParentSchema{
          name: "hi"
        }
        |> Repo.insert!()

      [
        %ChildSchema{number_field: 1, parent_schema: parent},
        %ChildSchema{number_field: 2, parent_schema: other_parent}
      ]
      |> Enum.each(&Repo.insert!(&1))

      :ok
    end

    test "aggregate respects grouping" do
      assert [
               %{"name" => "hi", "children_number_field_sum" => 3}
             ] =
               ParentSchema.aggregate(
                 fields: [:name],
                 assocs: [children: [number_field: :sum]]
               )
               |> Repo.all()
               |> Enum.sort_by(&Map.fetch!(&1, "children_number_field_sum"))
    end
  end
end
