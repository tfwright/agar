defmodule AgarTest.SiblingSchema do
  use Ecto.Schema

  use Agar,
    whitelist: [
      fields: [:string_field]
    ]

  alias AgarTest.ParentSchema

  schema "test_siblings" do
    field(:string_field, :string)

    belongs_to(:parent_schema, ParentSchema)
  end
end
