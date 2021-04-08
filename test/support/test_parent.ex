defmodule AgarTest.ParentSchema do
  use Ecto.Schema

  use Agar,
    whitelist: [
      fields: [:name],
      assocs: [:children]
    ]

  alias AgarTest.ChildSchema

  schema "test_parents" do
    field(:name, :string)

    has_many(:children, ChildSchema)
  end
end
