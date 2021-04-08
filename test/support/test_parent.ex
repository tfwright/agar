defmodule AgarTest.ParentSchema do
  use Ecto.Schema

  use Agar,
    whitelist: [
      fields: [:name],
      assocs: [:children]
    ]

  alias AgarTest.{ChildSchema, SiblingSchema}

  schema "test_parents" do
    field(:name, :string)

    has_many(:children, ChildSchema)

    has_one(:sibling, SiblingSchema)
  end
end
