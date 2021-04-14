# Agar

Dynamically build aggregate queries in Ecto from simple configs that can easily be encoded as URL params.

```
MySchema.aggregate(
  fields: [:name, :email, associated_schema: :id],
  assocs: [other_assoc: [numeric_field: [:sum, :avg]]],
)
=> [%{"name" => "hi", "email" => "email@example.com", "other_assoc_numeric_field_avg" => 3, "other_assoc_numeric_field_sum" => 10}]
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
