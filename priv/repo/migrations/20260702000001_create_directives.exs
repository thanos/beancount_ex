defmodule Beancount.Repo.Migrations.CreateDirectives do
  use Ecto.Migration

  def change do
    create table(:beancount_opens) do
      add :date, :date, null: false
      add :account, :string, null: false
      add :currencies, {:array, :string}
      add :booking, :string
      add :metadata, :map
      add :file_order, :integer
      timestamps()
    end

    create index(:beancount_opens, [:account])
    create index(:beancount_opens, [:date])

    create table(:beancount_closes) do
      add :date, :date, null: false
      add :account, :string, null: false
      add :metadata, :map
      add :file_order, :integer
      timestamps()
    end

    create index(:beancount_closes, [:account])

    create table(:beancount_commodities) do
      add :date, :date, null: false
      add :currency, :string, null: false
      add :metadata, :map
      add :file_order, :integer
      timestamps()
    end

    create table(:beancount_transactions) do
      add :date, :date, null: false
      add :flag, :string
      add :payee, :string
      add :narration, :string
      add :tags, {:array, :string}
      add :links, {:array, :string}
      add :metadata, :map
      add :postings, :map
      add :file_order, :integer
      timestamps()
    end

    create index(:beancount_transactions, [:date])

    create table(:beancount_balances) do
      add :date, :date, null: false
      add :account, :string, null: false
      add :amount, :decimal
      add :currency, :string
      add :tolerance, :decimal
      add :metadata, :map
      add :file_order, :integer
      timestamps()
    end

    create index(:beancount_balances, [:account])
    create index(:beancount_balances, [:date])

    create table(:beancount_prices) do
      add :date, :date, null: false
      add :commodity, :string, null: false
      add :amount, :decimal
      add :currency, :string
      add :metadata, :map
      add :file_order, :integer
      timestamps()
    end

    create index(:beancount_prices, [:commodity])

    create table(:beancount_notes) do
      add :date, :date, null: false
      add :account, :string, null: false
      add :comment, :string
      add :metadata, :map
      add :file_order, :integer
      timestamps()
    end

    create table(:beancount_documents) do
      add :date, :date, null: false
      add :account, :string, null: false
      add :path, :string
      add :metadata, :map
      add :file_order, :integer
      timestamps()
    end

    create table(:beancount_events) do
      add :date, :date, null: false
      add :type, :string
      add :description, :string
      add :metadata, :map
      add :file_order, :integer
      timestamps()
    end

    create table(:beancount_customs) do
      add :date, :date, null: false
      add :type, :string
      add :values, :map
      add :metadata, :map
      add :file_order, :integer
      timestamps()
    end

    create table(:beancount_pads) do
      add :date, :date, null: false
      add :account, :string, null: false
      add :source_account, :string, null: false
      add :metadata, :map
      add :file_order, :integer
      timestamps()
    end

    create table(:beancount_includes) do
      add :path, :string, null: false
      add :file_order, :integer
      timestamps()
    end

    create table(:beancount_options) do
      add :name, :string, null: false
      add :value, :string
      add :file_order, :integer
      timestamps()
    end

    create table(:beancount_plugins) do
      add :module, :string, null: false
      add :config, :string
      add :file_order, :integer
      timestamps()
    end

    create table(:beancount_push_tags) do
      add :tag, :string, null: false
      add :file_order, :integer
      timestamps()
    end

    create table(:beancount_pop_tags) do
      add :tag, :string, null: false
      add :file_order, :integer
      timestamps()
    end

    create table(:beancount_queries) do
      add :date, :date, null: false
      add :name, :string
      add :bql, :string
      add :metadata, :map
      add :file_order, :integer
      timestamps()
    end
  end
end
