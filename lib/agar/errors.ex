defmodule Agar.InvalidColumnKey do
  defexception message: "No column found for key"
end

defmodule Agar.InvalidColumnConfig do
  defexception message: "Invalid column config"
end
