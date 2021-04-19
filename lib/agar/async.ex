defmodule Agar.Async do
  import Agar.Query
  import Ecto.Query

  alias Agar.Whitelist

  def aggregate(columns, schema, queryable, repo) do
    query = Agar.aggregate(columns, schema, queryable, %{concurrent: true})

    configs =
      if Keyword.keyword?(columns) do
        columns
      else
        Whitelist.parse(schema, columns)
      end

    Task.async(fn ->
      query
      |> repo.all()
      |> Flow.from_enumerable()
      |> Flow.map(fn row ->
        row_query =
          configs
          |> Keyword.get(:fields, [])
          |> Enum.reduce(query, fn
            {assoc_name, fields}, row_query_acc ->
              row_query_with_join = join(row_query_acc, :left, [s], assoc(s, ^assoc_name))

              fields
              |> List.wrap()
              |> Enum.reduce(row_query_with_join, fn field, row_query_with_join_acc ->
                row
                |> Map.fetch!("#{assoc_name}_#{field}")
                |> case do
                  nil ->
                    where(row_query_with_join_acc, [..., j], is_nil(field(j, ^field)))

                  row_val ->
                    where(row_query_with_join_acc, [..., j], field(j, ^field) == ^row_val)
                end
              end)

            field, row_query_acc ->
              row
              |> Map.fetch!(to_string(field))
              |> case do
                nil ->
                  where(row_query_acc, [s], is_nil(field(s, ^field)))

                row_val ->
                  where(row_query_acc, [s], field(s, ^field) == ^row_val)
              end
          end)

        row_data = repo.one(row_query)

        configs
        |> Keyword.get(:assocs, [])
        |> Enum.flat_map(fn {assoc_name, fields} ->
          Enum.flat_map(fields, fn {field, agg} ->
            [{assoc_name, field, agg}]
          end)
        end)
        |> Flow.from_enumerable()
        |> Flow.reduce(fn -> row_data end, fn {assoc_name, field, agg}, row_acc ->
          field_data =
            add_join_for_type(
              :assocs,
              row_query,
              schema,
              assoc_name,
              field,
              agg,
              Keyword.get(configs, :fields, [:id])
            )
            |> select_merge([..., j], %{^"#{assoc_name}_#{field}_#{agg}" => j.agg})
            |> group_by([..., j], j.agg)
            |> repo.one

          Map.merge(row_acc, field_data)
        end)
        |> Enum.into(%{})
      end)
      |> Enum.to_list()
    end)
  end
end
