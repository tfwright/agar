defmodule Agar do
  import Ecto.Query

  defmacro __using__(opts) do
    whitelist = Keyword.get(opts, :whitelist, [])

    quote do
      Module.register_attribute(__MODULE__, :agar_columns_by_key, accumulate: true)

      for {:fields, fields} <- unquote(whitelist), field <- fields do
        Module.put_attribute(__MODULE__, :agar_columns_by_key, {field, [field: field]})
      end

      for {:assocs, assocs} <- unquote(whitelist),
          {assoc, fields} <- assocs,
          field <- fields do
        Module.put_attribute(
          __MODULE__,
          :agar_columns_by_key,
          {:"#{assoc}_#{field}", [assoc: assoc, field: field]}
        )
      end

      for {:scopes, scopes} <- unquote(whitelist),
          {scope, fields} <- scopes,
          field <- fields do
        Module.put_attribute(
          __MODULE__,
          :agar_columns_by_key,
          {:"#{scope}_#{field}", [scope: scope, field: field]}
        )
      end

      def __agar_columns__(), do: @agar_columns_by_key

      def __agar_columns__(key) when is_binary(key),
        do: String.to_existing_atom(key) |> __agar_columns__()

      def __agar_columns__(key) when is_atom(key) do
        case Keyword.get(@agar_columns_by_key, key) do
          nil -> raise Agar.InvalidColumnKey, ~s(no config found for '#{key}')
          column -> column
        end
      end

      @doc """
      MySchema.aggregate(
        fields: [:name],
        assocs: [other_schema: [field: [:sum]]],
        scopes: [my_schema_func: [field: [:count]]]
      )

      Also accepts a 1D list of key-aggregations:

      MySchema.aggregate(["name", "sum_other_schema_field"])
      """
      def aggregate(queryable \\ __MODULE__, columns) do
        Agar.__aggregate__(columns, __MODULE__, queryable)
      end
    end
  end

  def __aggregate__(columns, schema, queryable) do
    columns
    |> Keyword.keyword?()
    |> case do
      true ->
        columns

      false ->
        Enum.reduce(columns, [], fn key, acc ->
          config =
            if String.starts_with?(key, ["sum", "count", "avg"]) do
              [agg, key] =
                String.split(key, "_", parts: 2)
                |> Enum.map(&String.to_existing_atom/1)

              case schema.__agar_columns__(key) do
                [scope: name, field: field] -> [scopes: [{name, [{field, [agg]}]}]]
                [assoc: name, field: field] -> [assocs: [{name, [{field, [agg]}]}]]
              end
            else
              [fields: [String.to_existing_atom(key)]]
            end

          Keyword.merge(acc, config, &recursively_merge_column_configs/3)
        end)
    end
    |> Enum.reduce(
      base_query(schema, queryable),
      fn {type, configs}, base_query ->
        Enum.reduce(configs, base_query, fn config, query_acc ->
          merge_column_for_type(type, config, query_acc, schema)
        end)
      end
    )
  end

  defp merge_column_for_type(:fields, {assoc_name, fields}, base_query, _schema) do
    query_with_join = join(base_query, :left, [s], assoc(s, ^assoc_name))

    fields
    |> List.wrap()
    |> Enum.reduce(query_with_join, fn field, query_acc ->
      query_acc
      |> select_merge([..., j], %{^"#{assoc_name}_#{field}" => field(j, ^field)})
      |> group_by([..., j], field(j, ^field))
    end)
  end

  defp merge_column_for_type(:fields, field, base_query, _schema) do
    base_query
    |> select_merge([s], %{^to_string(field) => field(s, ^field)})
    |> group_by([s], field(s, ^field))
  end

  defp merge_column_for_type(type, {relation_name, fields}, base_query, schema) do
    fields
    |> List.wrap()
    |> Enum.reduce(
      base_query,
      &merge_relation_field(schema, relation_name, type, &1, &2)
    )
  end

  defp merge_relation_field(schema, relation_name, type, {field, aggs}, query_acc) do
    aggs
    |> List.wrap()
    |> Enum.reduce(query_acc, fn agg, agg_query_acc ->
      add_join_for_type(type, agg_query_acc, schema, relation_name, field, agg)
      |> select_merge([..., j], %{^"#{relation_name}_#{field}_#{agg}" => j.agg})
    end)
  end

  defp merge_relation_field(schema, relation_name, type, field, query_acc) do
    add_join_for_type(type, query_acc, schema, relation_name, field)
    |> select_merge([..., j], %{^"#{relation_name}_#{field}" => j.f})
  end

  defp add_join_for_type(type, q, s, r, f, a \\ nil)

  defp add_join_for_type(:assocs, q, schema, relation_name, field, agg) do
    assoc_query =
      assoc_query(relation_name, schema)
      |> add_subquery_select(field, agg)

    join(q, :left_lateral, [], subquery(assoc_query))
  end

  defp add_join_for_type(:scopes, q, schema, relation_name, field, agg) do
    scope_query =
      from(apply(schema, relation_name, []), as: :queryable)
      |> add_subquery_select(field, agg)

    join(q, :left_lateral, [], subquery(scope_query))
  end

  defp base_query(schema, queryable) do
    binding = String.to_atom(schema.__schema__(:source))

    escaped_query = Macro.escape(queryable)

    Code.eval_quoted(
      quote do
        from(s in unquote(escaped_query), as: unquote(binding))
      end
    )
    |> elem(0)
    |> select([s], %{})
  end

  def assoc_query(name, schema) do
    binding = String.to_atom(schema.__schema__(:source))

    base_query =
      schema
      |> join(:inner, [s], assoc(s, ^name), as: :queryable)

    escaped_query = Macro.escape(base_query)

    Code.eval_quoted(
      quote do
        where(unquote(escaped_query), [s], parent_as(unquote(binding)).id == s.id)
      end
    )
    |> elem(0)
  end

  defp add_subquery_select(q, field, nil),
    do: select(q, [queryable: table], %{f: field(table, ^field)})

  defp add_subquery_select(q, field, :count) do
    select(q, [queryable: table], %{agg: coalesce(count(field(table, ^field)), 0)})
  end

  defp add_subquery_select(q, field, :sum) do
    select(q, [queryable: table], %{agg: coalesce(sum(field(table, ^field)), 0)})
  end

  defp add_subquery_select(q, field, :avg) do
    select(q, [queryable: table], %{agg: coalesce(avg(field(table, ^field)), 0)})
  end

  defp add_subquery_select(q, field, custom_function) do
    aggregate_fragment =
      Application.get_env(:agar, :custom_aggregations)
      |> Keyword.fetch!(custom_function)

    escaped_q = Macro.escape(q)

    Code.eval_quoted(
      quote do
        select(unquote(escaped_q), [queryable: table], %{
          agg: fragment(unquote(aggregate_fragment), field(table, unquote(field)))
        })
      end
    )
    |> elem(0)
  end

  defp recursively_merge_column_configs(k, v1, v2) when is_list(v1) and is_list(v2) do
    case Enum.all?(v1, &is_atom/1) do
      true -> v1 ++ v2
      false -> Keyword.merge(v1, v2, &recursively_merge_column_configs/3)
    end
  end
end

defmodule Agar.InvalidColumnKey do
  defexception message: "No column found for key"
end

defmodule Agar.InvalidColumnConfig do
  defexception message: "Invalid column config"
end
