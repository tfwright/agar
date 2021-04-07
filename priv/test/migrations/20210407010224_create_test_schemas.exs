defmodule AgarTest.Repo.Migrations.CreateTestSchemas do
  use Ecto.Migration

  def change do
    create table(:test_schemas) do
      add(:number_field, :integer)

      timestamps()
    end
  end
end
