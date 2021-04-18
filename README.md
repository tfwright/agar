# Agar

Dynamically build aggregate queries in Ecto from simple configs that can easily be encoded as URL params.

## Usage

```
MySchema.aggregate(
  fields: [:name, :email, some_assoc: :id],
  assocs: [other_assocs: [numeric_field: [:sum, :avg]]],
)
=> [%{"name" => "hi", "email" => "email@example.com", "other_assoc_numeric_field_avg" => 3, "other_assoc_numeric_field_sum" => 10}]
```

or: `MySchema.aggregate(["name", "email", "some_assoc_id", "sum_other_assocs_numeric_field", "avg_other_assocs_numeric_field"])`

In the former version, you can use any association and any field defined on the schemas. In the latter, only associations that themselves use Agar and fields specified in the whitelist option will be permitted, as shown below. Other values will cause an error.

```
defmodule MySchema do
  use Agar, whitelist: [:name, :email]

  #...

  belongs_to :some_assoc, AssocSchema
  has_many :other_assocs, OtherAssocSchema
end

defmodule AssocSschema do
  use Agar, whitelist: [:id]
end

defmodule OtherAssocSchema do
  use Agar, whitelist: [:numeric_field]
end
```


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `agar` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:agar, "~> 0.1.0"}
  ]
end
```

## Development

* Prepare test database: `MIX_ENV=test mix do ecto.create, mix ecto.migrate`
