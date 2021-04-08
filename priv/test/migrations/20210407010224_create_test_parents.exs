defmodule AgarTest.Repo.Migrations.CreateTestParents do
  use Ecto.Migration

  def change do
    create table(:test_parents) do
      add(:name, :string)
    end
  end
end
