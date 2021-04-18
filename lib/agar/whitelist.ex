defmodule Agar.Whitelist do
  def parse(module, columns) do
    Enum.reduce(columns, [], fn key, acc ->
      parse_key(key)
      |> key_to_config(module)
      |> Keyword.merge(acc, &recursively_merge_column_configs/3)
    end)
  end

  defp configs_by_whitelisted_keys(module) do
    module.__schema__(:associations)
    |> Enum.flat_map(fn assoc_name ->
      with %{queryable: assoc_mod} <- module.__schema__(:association, assoc_name),
           true <- Kernel.function_exported?(assoc_mod, :__agar_fields__, 0),
           fields <- apply(assoc_mod, :__agar_fields__, []) do
        Enum.map(fields, &to_whitelist_key_pair(assoc_name, &1))
      else
        _ -> []
      end
    end)
    |> Enum.concat(apply(module, :__agar_fields__, []) |> Enum.map(&to_whitelist_key_pair/1))
    |> Enum.into(%{})
  end

  defp recursively_merge_column_configs(_k, v1, v2) when is_list(v1) and is_list(v2) do
    if Enum.all?(v1, &is_atom/1) do
      v1 ++ v2
    else
      Keyword.merge(v1, v2, &recursively_merge_column_configs/3)
    end
  end

  defp to_whitelist_key_pair(assoc_name, field),
    do: {"#{assoc_name}_#{field}", {assoc_name, field}}

  defp to_whitelist_key_pair(field), do: {to_string(field), field}

  defp parse_key(key) do
    if String.starts_with?(
         key,
         Enum.concat(
           [:sum, :count, :avg],
           Application.get_env(:agar, :custom_aggregations, []) |> Keyword.keys()
         )
         |> Enum.map(&to_string/1)
       ) do
      String.split(key, "_", parts: 2)
    else
      [nil, key]
    end
  end

  defp key_to_config([agg, key], module) do
    configs_by_whitelisted_keys(module)
    |> Map.get(key)
    |> case do
      nil ->
        raise Agar.InvalidColumnKey, ~s(no config found for '#{key}')

      {assoc_name, field} ->
        [assocs: [{assoc_name, [{field, [String.to_existing_atom(agg)]}]}]]

      key ->
        [fields: [key]]
    end
  end
end
