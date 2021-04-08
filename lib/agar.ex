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
      def aggregate(columns) do
        Agar.__aggregate__(columns, __MODULE__)
      end
    end
  end

  def __aggregate__(columns, schema) do
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
      source_query(schema),
      fn {type, configs}, base_query ->
        merge_column_types(type, configs, base_query, schema)
      end
    )
  end

  defp merge_column_types(type, configs, base_query, schema) do
    Enum.reduce(configs, base_query, fn config, query_acc ->
      merge_column_for_type(type, config, query_acc, schema)
    end)
  end

  defp merge_column_for_type(:fields, field, base_query, _schema),
    do: select_merge(base_query, [s], %{^to_string(field) => field(s, ^field)})

  defp merge_column_for_type(type, {name, fields}, base_query, schema)
       when type in [:scopes, :assocs] do
    Enum.reduce(fields, base_query, fn
      {field, aggs}, query_acc ->
        Enum.reduce(aggs, query_acc, fn agg, agg_query_acc ->
          add_join_for_type(type, agg_query_acc, name, field, agg, schema)
          |> select_merge([..., j], %{^"#{name}_#{field}_#{agg}" => coalesce(j.agg, 0)})
        end)

      _, _ ->
        raise Agar.InvalidColumnConfig, ~s(missing aggregation)
    end)
  end

  defp add_join_for_type(:assocs, q, name, field, agg, schema) do
    assoc_query =
      assoc_query(name, schema)
      |> add_subquery_select(field, agg)

    join(q, :left_lateral, [], subquery(assoc_query))
  end

  defp add_join_for_type(:scopes, q, name, field, agg, schema) do
    scope_query =
      from(apply(schema, name, []), as: :queryable)
      |> add_subquery_select(field, agg)

    join(q, :left_lateral, [], subquery(scope_query))
  end

  defp source_query(schema) do
    binding = String.to_atom(schema.__schema__(:source))

    Code.eval_quoted(
      quote do
        from(s in unquote(schema), as: unquote(binding))
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

  defp add_subquery_select(q, field, :count) do
    select(q, [queryable: table], %{agg: count(field(table, ^field))})
  end

  defp add_subquery_select(q, field, :sum) do
    select(q, [queryable: table], %{agg: sum(field(table, ^field))})
  end

  defp add_subquery_select(q, field, :avg) do
    select(q, [queryable: table], %{agg: avg(field(table, ^field))})
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
