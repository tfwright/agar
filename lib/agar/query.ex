defmodule Agar.Query do
  import Ecto.Query

  def add_join_for_type(:assocs, q, schema, relation_name, field, agg, grouping_fields) do
    assoc_query =
      from(schema)
      |> join(:left, [s], assoc(s, ^relation_name))
      |> add_subquery_select(field, agg)
      |> add_subquery_conditions(grouping_fields, schema)

    join(q, :left_lateral, [], subquery(assoc_query))
  end

  def add_subquery_select(q, field, nil),
    do: select(q, [..., table], %{f: field(table, ^field)})

  def add_subquery_select(q, field, :count) do
    select(q, [..., table], %{agg: coalesce(count(field(table, ^field)), 0)})
  end

  def add_subquery_select(q, field, :sum) do
    select(q, [..., table], %{agg: coalesce(sum(field(table, ^field)), 0)})
  end

  def add_subquery_select(q, field, :avg) do
    select(q, [..., table], %{agg: coalesce(avg(field(table, ^field)), 0)})
  end

  def add_subquery_select(q, field, custom_function) do
    aggregate_fragment =
      Application.get_env(:agar, :custom_aggregations)
      |> Keyword.fetch!(custom_function)

    escaped_q = Macro.escape(q)

    Code.eval_quoted(
      quote do
        select(unquote(escaped_q), [..., table], %{
          agg: fragment(unquote(aggregate_fragment), field(table, unquote(field)))
        })
      end
    )
    |> elem(0)
  end

  def add_subquery_conditions(q, fields, schema) do
    binding = binding_name(schema)

    Enum.reduce(fields, q, fn
      {relation_name, fields}, subquery_acc ->
        subquery_with_join = join(subquery_acc, :left, [s], assoc(s, ^relation_name))

        fields
        |> List.wrap()
        |> Enum.reduce(subquery_with_join, fn field, subquery_with_join_acc ->
          escaped_query = Macro.escape(subquery_with_join_acc)

          Code.eval_quoted(
            quote do
              where(
                unquote(escaped_query),
                [..., j],
                parent_as(unquote(relation_name)).unquote(field) == j.unquote(field) or
                  (is_nil(parent_as(unquote(relation_name)).unquote(field)) and
                     is_nil(j.unquote(field)))
              )
            end
          )
          |> elem(0)
        end)

      field, subquery_acc ->
        escaped_query = Macro.escape(subquery_acc)

        Code.eval_quoted(
          quote do
            where(
              unquote(escaped_query),
              [s],
              parent_as(unquote(binding)).unquote(field) == field(s, ^unquote(field)) or
                (is_nil(parent_as(unquote(binding)).unquote(field)) and
                   is_nil(field(s, ^unquote(field))))
            )
          end
        )
        |> elem(0)
    end)
  end

  def binding_name(schema), do: String.to_atom("__agar_" <> schema.__schema__(:source))
end
