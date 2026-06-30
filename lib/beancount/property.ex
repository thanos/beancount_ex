if Code.ensure_loaded?(StreamData) do
  defmodule Beancount.Property do
    @moduledoc """
    StreamData generators and helpers for property-based testing.

    These generators produce *valid, balanced* Beancount data so that
    properties such as "every generated ledger passes `bean-check`" and
    "rendering is deterministic" can be expressed.

    This module is only compiled when `StreamData` is available (the `:test`
    and `:dev` environments).

    ## Future oracle comparison

    `compare/2` is a placeholder for the v0.3 strategy of validating a native
    engine against the Beancount oracle on identical inputs.
    """

    import StreamData, except: [date: 0]

    @roots ~w(Assets Liabilities Equity Income Expenses)
    @leaves ~w(Bank Cash Savings Checking Salary Food Rent Fees Misc Travel)
    @currencies ~w(USD EUR GBP CAD CHF JPY)

    @doc "Generate a valid account name such as `Assets:Bank`."
    @spec account() :: StreamData.t(String.t())
    def account do
      bind(member_of(@roots), fn root ->
        bind(member_of(@leaves), fn leaf -> constant(root <> ":" <> leaf) end)
      end)
    end

    @doc "Generate a commodity/currency code."
    @spec currency() :: StreamData.t(String.t())
    def currency, do: member_of(@currencies)

    @doc "Generate a `Date` within a bounded range for determinism."
    @spec date() :: StreamData.t(Date.t())
    def date do
      map(integer(0..3650), fn offset -> Date.add(~D[2020-01-01], offset) end)
    end

    @doc "Generate a positive integer `Decimal` amount."
    @spec amount() :: StreamData.t(Decimal.t())
    def amount, do: map(integer(1..1_000_000), &Decimal.new/1)

    @doc "Generate a small metadata map with string values."
    @spec metadata() :: StreamData.t(map())
    def metadata do
      keys = member_of(~w(note ref category source import id type memo tag)a)
      values = string(:alphanumeric, min_length: 1, max_length: 12)

      map_of(keys, values, max_length: 2)
    end

    @doc """
    Generate a balanced `Beancount.Directives.Transaction`.

    The generated postings always sum to zero in a single currency, so the
    transaction is guaranteed to balance.
    """
    @spec balanced_transaction() :: StreamData.t(Beancount.Directives.Transaction.t())
    def balanced_transaction do
      bind(transaction_inputs(), fn {date, currency, amounts, accounts} ->
        constant(build_transaction(date, currency, amounts, accounts))
      end)
    end

    defp transaction_inputs do
      bind(amounts_with_currency(), fn {currency, amounts} ->
        accounts_and_date(currency, amounts)
      end)
    end

    defp amounts_with_currency do
      bind(currency(), fn currency ->
        amounts = list_of(integer(1..100_000), min_length: 1, max_length: 4)
        bind(amounts, fn generated -> constant({currency, generated}) end)
      end)
    end

    defp accounts_and_date(currency, amounts) do
      accounts = list_of(account(), length: length(amounts) + 1)

      bind(accounts, fn generated ->
        bind(date(), fn date -> constant({date, currency, amounts, generated}) end)
      end)
    end

    defp build_transaction(date, currency, amounts, accounts) do
      total = Enum.sum(amounts)
      {leg_accounts, [balancing_account]} = Enum.split(accounts, length(amounts))

      legs =
        leg_accounts
        |> Enum.zip(amounts)
        |> Enum.map(fn {acct, amt} -> Beancount.posting(acct, Decimal.new(amt), currency) end)

      balancing = Beancount.posting(balancing_account, Decimal.new(-total), currency)

      Beancount.transaction(date, "*", "Payee", "Narration", [balancing | legs])
    end

    @doc """
    Generate a complete, valid ledger: `open` directives for every account
    used, followed by a balanced transaction.
    """
    @spec ledger() :: StreamData.t([Beancount.Directive.t()])
    def ledger do
      bind(balanced_transaction(), fn txn ->
        accounts = txn.postings |> Enum.map(& &1.account) |> Enum.uniq()
        currencies = txn.postings |> Enum.map(& &1.currency) |> Enum.uniq()
        open_date = Date.add(txn.date, -1)
        opens = Enum.map(accounts, &Beancount.open(open_date, &1, currencies))
        constant(opens ++ [txn])
      end)
    end

    @doc """
    Placeholder for oracle/native engine comparison (v0.3).

    Given two engines, this will eventually assert that they produce equivalent
    normalized results for identical input. For now it documents the intended
    contract and returns `:not_implemented`.
    """
    @spec compare(module(), module()) :: :not_implemented
    def compare(_oracle, _native), do: :not_implemented
  end
end
