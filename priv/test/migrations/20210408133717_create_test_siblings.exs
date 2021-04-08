defmodule AgarTest.Repo.Migrations.CreateTestSiblings do
  use Ecto.Migration

  def change do
    create table(:test_siblings) do
      add(:string_field, :string)

      add(:parent_schema_id, references(:test_parents, on_delete: :delete_all))
    end
  end
end
