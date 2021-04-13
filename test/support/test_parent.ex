defmodule AgarTest.ParentSchema do
  use Ecto.Schema

  use Agar,
    whitelist: [
      fields: [:name],
      assocs: [:children]
    ]

  import Ecto.Query

  alias AgarTest.{ChildSchema, SiblingSchema}

  schema "test_parents" do
    field(:name, :string)

    has_many(:children, ChildSchema)

    has_one(:sibling, SiblingSchema)
  end

  def children_with_string_field_one do
    ChildSchema |> where(string_field: "one")
  end
end
