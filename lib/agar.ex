defmodule Agar do
  import Agar.Query
  import Ecto.Query

  alias Agar.Whitelist

  @doc """
  Define the aggregate function on schema.

  `use Agar`

  In order to support composing aggregations from query params, specify
  allowed associations and fields using the `whitelist` option.

  `use Agar, whitelist: [:list, :of, :fields]`
  """
  defmacro __using__(opts) do
    whitelist = Keyword.get(opts, :whitelist, [])

    quote do
      Module.register_attribute(__MODULE__, :agar_fields, accumulate: true)

      for field <- unquote(whitelist) do
        Module.put_attribute(__MODULE__, :agar_fields, field)
      end

      def __agar_fields__, do: @agar_fields

      @doc """
      MySchema.aggregate(
        fields: [:name],
        assocs: [other_schema: [field: [:sum]]],
      )

      Also accepts a 1D list of key-aggregations:

      MySchema.aggregate(["name", "sum_other_schema_field"])
      """
      def aggregate(queryable \\ __MODULE__, columns) do
        Agar.aggregate(columns, __MODULE__, queryable)
      end

      def aggregate_async(queryable \\ __MODULE__, columns, repo) do
        Agar.Async.aggregate(columns, __MODULE__, queryable, repo)
      end
    end
  end

  def aggregate(columns, schema, queryable, opts \\ %{}) do
    configs =
      if Keyword.keyword?(columns) do
        columns
      else
        Whitelist.parse(schema, columns)
      end

    grouping_fields = Keyword.get(configs, :fields, [:id])

    Enum.reduce(
      configs,
      base_query(schema, queryable),
      fn {type, fields}, base_query ->
        Enum.reduce(fields, base_query, fn field, query_acc ->
          merge_column_for_type(type, field, query_acc, schema, grouping_fields, opts)
        end)
      end
    )
  end

  defp merge_column_for_type(
         :fields,
         {assoc_name, fields},
         base_query,
         _schema,
         _grouping_fields,
         _opts
       ) do
    escaped_query = Macro.escape(base_query)

    query_with_join =
      Code.eval_quoted(
        quote do
          join(unquote(escaped_query), :left, [s], assoc(s, unquote(assoc_name)),
            as: unquote(assoc_name)
          )
        end
      )
      |> elem(0)

    fields
    |> List.wrap()
    |> Enum.reduce(query_with_join, fn field, query_acc ->
      query_acc
      |> select_merge([..., j], %{^"#{assoc_name}_#{field}" => field(j, ^field)})
      |> group_by([..., j], field(j, ^field))
    end)
  end

  defp merge_column_for_type(:fields, field, base_query, _schema, _grouping_fields, _opts) do
    base_query
    |> select_merge([s], %{^to_string(field) => field(s, ^field)})
    |> group_by([s], field(s, ^field))
  end

  defp merge_column_for_type(_, _, base_query, _, _, %{concurrent: true}), do: base_query

  defp merge_column_for_type(
         type,
         {relation_name, fields},
         base_query,
         schema,
         grouping_fields,
         _opts
       ) do
    fields
    |> List.wrap()
    |> Enum.reduce(
      base_query,
      &merge_relation_field(schema, relation_name, type, &1, &2, grouping_fields)
    )
  end

  defp merge_relation_field(
         schema,
         relation_name,
         type,
         {field, aggs},
         query_acc,
         grouping_fields
       ) do
    aggs
    |> List.wrap()
    |> Enum.reduce(query_acc, fn agg, agg_query_acc ->
      add_join_for_type(type, agg_query_acc, schema, relation_name, field, agg, grouping_fields)
      |> select_merge([..., j], %{^"#{relation_name}_#{field}_#{agg}" => j.agg})
      |> group_by([..., j], j.agg)
    end)
  end

  defp base_query(schema, queryable) do
    binding = binding_name(schema)

    escaped_query = Macro.escape(queryable)

    Code.eval_quoted(
      quote do
        from(unquote(escaped_query), as: unquote(binding))
      end
    )
    |> elem(0)
    |> select([s], %{})
  end
end
