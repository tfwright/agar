defmodule AgarTest.ChildSchema do
  use Ecto.Schema

  use Agar,
    whitelist: [
      fields: [:number_field]
    ]

  alias AgarTest.ParentSchema

  schema "test_children" do
    field(:number_field, :integer)
    field(:string_field, :string)

    belongs_to(:parent_schema, ParentSchema)
  end
end
