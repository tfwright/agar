defmodule AgarTest do
  use ExUnit.Case

  import Ecto.Query

  alias AgarTest.{Repo, ParentSchema, ChildSchema, SiblingSchema}

  doctest Agar

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "aggregate/1 containing non-whitelisted key" do
    test "raises error" do
      assert_raise Agar.InvalidColumnKey, fn ->
        ParentSchema.aggregate(["what"])
      end
    end
  end

  describe "aggregate/1 with single record" do
    setup do
      %ParentSchema{
        name: "hi"
      }
      |> Repo.insert!()

      :ok
    end

    test "supports field option" do
      assert [%{"name" => "hi"}] = ParentSchema.aggregate(fields: [:name]) |> Repo.all()
    end

    test "includes record when matching query" do
      assert [%{"name" => "hi"}] =
               ParentSchema
               |> where(name: "hi")
               |> ParentSchema.aggregate(fields: [:name])
               |> Repo.all()
    end

    test "returns empty list when not matching query" do
      assert [] =
               ParentSchema
               |> where(name: "not hi")
               |> ParentSchema.aggregate(fields: [:name])
               |> Repo.all()
    end
  end

  describe "aggregate/1 with parent with children" do
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

    test "includes sum of children field when aggregated" do
      assert [%{"children_number_field_sum" => 10}] =
               ParentSchema.aggregate(assocs: [children: [number_field: [:sum]]])
               |> Repo.all()
    end
  end

  describe "aggregate/1 with parent with sibling" do
    setup do
      parent =
        %ParentSchema{}
        |> Repo.insert!()

      %SiblingSchema{string_field: "what", parent_schema: parent}
      |> Repo.insert!()

      :ok
    end

    test "accepts sibling grouping" do
      assert [%{"sibling_string_field" => "what"}] =
               ParentSchema.aggregate(fields: [sibling: :string_field])
               |> Repo.all()
    end
  end

  describe "aggregate/1 with two parents one with sibling and one without" do
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

    test "aggregate on child respects grouping on sibling" do
      assert [
               %{"sibling_string_field" => "what", "children_number_field_sum" => 1},
               %{"sibling_string_field" => nil, "children_number_field_sum" => 2}
             ] =
               ParentSchema.aggregate(
                 fields: [sibling: [:string_field]],
                 assocs: [children: [number_field: :sum]]
               )
               |> Repo.all()
    end
  end

  describe "aggregate/1 with parent without children" do
    setup do
      %ParentSchema{}
      |> Repo.insert!()

      :ok
    end

    test "includes 0 sum in results" do
      assert [%{"children_number_field_sum" => 0}] =
               ParentSchema.aggregate(assocs: [children: [number_field: [:sum]]])
               |> Repo.all()
    end
  end

  describe "aggregate/1 " do
    test "accepts field with non-array function" do
      assert [] =
               ParentSchema.aggregate(assocs: [children: [string_field: :array]])
               |> Repo.all()
    end

    test "accepts association field with non-array function" do
      assert [] =
               ParentSchema.aggregate(assocs: [children: [string_field: :array]])
               |> Repo.all()
    end
  end

  describe "aggregate/1 with parent with two children" do
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

    test "grouping on child field returns two results" do
      assert [
               %{"name" => "hi", "children_string_field" => "one"},
               %{"name" => "hi", "children_string_field" => "two"}
             ] =
               ParentSchema.aggregate(fields: [:name, children: :string_field])
               |> Repo.all()
               |> Enum.sort_by(&Map.fetch!(&1, "children_string_field"))
    end

    test "aggregating on child function returns one result" do
      assert [%{"children_string_field_array" => ["one", "two"]}] =
               ParentSchema.aggregate(assocs: [children: [string_field: [:array]]])
               |> Repo.all()
    end
  end

  describe "aggregate/1 with parents with matching fields and children" do
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

    test "grouping on matching field and aggregating on child field returns single result" do
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

  describe "aggregate/1 with parent with nil field and child" do
    setup do
      parent =
        %ParentSchema{
          name: nil
        }
        |> Repo.insert!()

      %ChildSchema{number_field: 1, parent_schema: parent}
      |> Repo.insert!()

      :ok
    end

    test "aggregating child value works when grouping on nil field" do
      assert [%{"children_number_field_sum" => 1}] =
               ParentSchema.aggregate(fields: [:name], assocs: [children: [number_field: :sum]])
               |> Repo.all()
    end
  end
end
