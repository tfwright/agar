defmodule AgarTest.Repo.Migrations.CreateTestChildren do
  use Ecto.Migration

  def change do
    create table(:test_children) do
      add(:number_field, :integer)

      add(:parent_schema_id, references(:test_parents, on_delete: :delete_all))
    end
  end
end
