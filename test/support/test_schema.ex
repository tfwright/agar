defmodule AgarTest.TestSchema do
  use Ecto.Schema

  use Agar,
    whitelist: [
      fields: [:number_field]
    ]

  schema "test_schemas" do
    field(:number_field, :integer)

    timestamps()
  end
end
