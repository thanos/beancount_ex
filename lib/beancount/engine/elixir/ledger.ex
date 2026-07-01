defmodule Beancount.Engine.Elixir.Ledger do
  @moduledoc false

  alias Beancount.CostSpec

  alias Beancount.Directives.{
    Balance,
    Close,
    Include,
    Open,
    Option,
    Pad,
    Transaction
  }

  alias Beancount.Engine.Elixir.{
    BalanceCheck,
    Inventory,
    Options,
    PadResolver,
    PostingAmount,
    Tolerance
  }

  alias Beancount.Directives.Posting

  defstruct options: Options.new(),
            opens: %{},
            closes: %{},
            closed: MapSet.new(),
            inventory: Inventory.new(),
            pending_pads: %{},
            balance_assertions: %{},
            parent_balance_accounts: MapSet.new(),
            include_base: nil,
            errors: []

  @type t :: %__MODULE__{}

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{include_base: Keyword.get(opts, :include_base)}
  end

  @spec process(t(), [Beancount.Directive.t()]) :: t()
  def process(%__MODULE__{} = ledger, directives) do
    ledger = index_accounts(ledger, directives)

    directives
    |> Enum.with_index()
    |> Enum.sort_by(&directive_sort_key/1)
    |> Enum.reduce(ledger, fn {directive, _index}, ledger ->
      apply_directive(directive, ledger)
    end)
  end

  defp directive_sort_key({directive, index}) do
    case directive do
      %{date: %Date{} = date} -> {1, date, index}
      _ -> {0, Date.new!(1900, 1, 1), index}
    end
  end

  defp index_accounts(ledger, directives) do
    Enum.reduce(directives, ledger, fn
      %Open{} = open, ledger -> index_open(ledger, open)
      %Close{} = close, ledger -> index_close(ledger, close)
      _, ledger -> ledger
    end)
  end

  defp index_open(ledger, %Open{} = open) do
    if Map.has_key?(ledger.opens, open.account) do
      add_error(ledger, "Duplicate open directive for #{open.account}")
    else
      %{ledger | opens: Map.put(ledger.opens, open.account, open)}
    end
  end

  defp index_close(ledger, %Close{} = close) do
    cond do
      Map.has_key?(ledger.closes, close.account) ->
        add_error(ledger, "Duplicate close for account #{close.account}")

      not Map.has_key?(ledger.opens, close.account) ->
        add_error(ledger, "Unopened account #{close.account} closed")

      true ->
        %{
          ledger
          | closes: Map.put(ledger.closes, close.account, close),
            closed: MapSet.put(ledger.closed, close.account)
        }
    end
  end

  @spec errors(t()) :: [map()]
  def errors(%__MODULE__{errors: errors}), do: Enum.reverse(errors)

  @spec inventory(t()) :: Inventory.t()
  def inventory(%__MODULE__{inventory: inventory}), do: inventory

  defp apply_directive(%Option{} = option, ledger) do
    {options, errors} = Options.apply(ledger.options, option)

    ledger = %{ledger | options: options}
    Enum.reduce(errors, ledger, fn %{message: message}, ledger -> add_error(ledger, message) end)
  end

  defp apply_directive(%Include{path: path}, ledger) do
    case resolve_include(path, ledger.include_base) do
      :ok -> ledger
      {:error, message} -> add_error(ledger, message)
    end
  end

  defp apply_directive(%Open{}, ledger), do: ledger
  defp apply_directive(%Close{}, ledger), do: ledger

  defp apply_directive(%Pad{} = pad, ledger) do
    %{ledger | pending_pads: Map.put(ledger.pending_pads, pad.account, pad)}
  end

  defp apply_directive(%Balance{} = balance, ledger) do
    ledger =
      case Map.get(ledger.pending_pads, balance.account) do
        nil ->
          ledger

        pad ->
          ledger
          |> apply_pending_pad(pad, balance)
          |> then(&%{&1 | pending_pads: Map.delete(&1.pending_pads, balance.account)})
      end

    ledger =
      if parent_account?(balance.account) do
        %{
          ledger
          | parent_balance_accounts: MapSet.put(ledger.parent_balance_accounts, balance.account)
        }
      else
        ledger
      end

    errors =
      BalanceCheck.check(
        balance,
        ledger.inventory,
        ledger.options,
        ledger.balance_assertions,
        ledger.parent_balance_accounts,
        ledger.opens
      )

    ledger = %{
      ledger
      | balance_assertions:
          Map.put(ledger.balance_assertions, balance_key(balance), balance.amount)
    }

    Enum.reduce(errors, ledger, &add_error(&2, &1.message))
  end

  defp apply_directive(%Transaction{} = transaction, ledger) do
    ledger
    |> validate_transaction(transaction)
    |> apply_transaction(transaction)
  end

  defp apply_directive(_other, ledger), do: ledger

  defp apply_pending_pad(
         ledger,
         %Pad{account: account} = pad,
         %Balance{account: account} = balance
       ) do
    {:ok, inventory, pad_txn} = PadResolver.resolve_pad(pad, balance, ledger.inventory)
    ledger = %{ledger | inventory: inventory}
    apply_optional_pad_transaction(ledger, balance, pad_txn)
  end

  @dialyzer {:nowarn_function, apply_optional_pad_transaction: 3}
  defp apply_optional_pad_transaction(ledger, _balance, nil), do: ledger

  defp apply_optional_pad_transaction(ledger, balance, txn) do
    apply_transaction(ledger, %{txn | date: balance.date})
  end

  defp validate_transaction(ledger, %Transaction{date: date, postings: postings}) do
    postings = PostingAmount.expand_postings(postings)

    ledger
    |> validate_posting_accounts(postings, date)
    |> validate_posting_units(postings)
    |> validate_transaction_balance(postings)
  end

  defp validate_posting_units(ledger, postings) do
    Enum.reduce(postings, ledger, fn posting, ledger ->
      case posting do
        %Posting{amount: %Decimal{}, currency: nil} ->
          add_error(ledger, "Could not resolve units currency")

        _ ->
          ledger
      end
    end)
  end

  defp validate_posting_accounts(ledger, postings, date) do
    Enum.reduce(postings, ledger, fn posting, ledger ->
      if posting_material?(posting) do
        validate_posting_account(ledger, posting, date)
      else
        ledger
      end
    end)
  end

  defp validate_posting_account(ledger, %Posting{account: account}, date) do
    cond do
      not account_open_at?(ledger, account, date) ->
        add_error(ledger, "Invalid reference to unknown account '#{account}'")

      account_closed_at?(ledger, account, date) ->
        add_error(ledger, "Account #{account} used after close")

      true ->
        ledger
    end
  end

  defp account_open_at?(ledger, account, date) do
    case Map.get(ledger.opens, account) do
      %Open{date: open_date} -> Date.compare(open_date, date) != :gt
      _ -> false
    end
  end

  defp account_closed_at?(ledger, account, date) do
    case Map.get(ledger.closes, account) do
      %Close{date: close_date} -> Date.compare(close_date, date) != :gt
      _ -> false
    end
  end

  defp validate_transaction_balance(ledger, postings) do
    if skip_transaction_balance?(ledger, postings) do
      ledger
    else
      validate_totals_balanced(ledger, postings)
    end
  end

  defp validate_totals_balanced(ledger, postings) do
    totals = PostingAmount.transaction_totals(postings)
    amounts = tolerance_amounts(postings)

    Enum.reduce(totals, ledger, fn {currency, total}, ledger ->
      apply_balance_tolerance(ledger, currency, total, amounts)
    end)
  end

  defp apply_balance_tolerance(ledger, currency, total, amounts) do
    tolerance = Tolerance.infer(ledger.options, currency, amounts)

    if Decimal.abs(total) |> Decimal.lte?(tolerance) do
      ledger
    else
      add_error(
        ledger,
        "Transaction does not balance: (#{Decimal.to_string(total, :normal)} #{currency})"
      )
    end
  end

  defp skip_transaction_balance?(ledger, postings) do
    Enum.any?(postings, fn
      %Posting{amount: %Decimal{} = amount, cost: %CostSpec{}, account: account} ->
        Decimal.negative?(amount) and strict_booking_account?(ledger, account)

      _ ->
        false
    end)
  end

  defp strict_booking_account?(ledger, account) do
    case Map.get(ledger.opens, account) do
      %Open{booking: booking} when is_binary(booking) ->
        String.upcase(booking) == "STRICT"

      _ ->
        false
    end
  end

  defp tolerance_amounts(postings) do
    postings
    |> PostingAmount.expand_postings()
    |> Enum.flat_map(&posting_tolerance_amounts/1)
  end

  defp posting_tolerance_amounts(%Posting{amount: %Decimal{} = amount, currency: currency})
       when is_binary(currency),
       do: [amount]

  defp posting_tolerance_amounts(%Posting{
         amount: %Decimal{} = amount,
         price: %{amount: price_amount, type: :unit}
       }) do
    [amount, price_amount]
  end

  defp posting_tolerance_amounts(%Posting{amount: %Decimal{} = amount}), do: [amount]
  defp posting_tolerance_amounts(_), do: []

  defp apply_transaction(ledger, %Transaction{postings: postings}) do
    postings = PostingAmount.expand_postings(postings)
    starting_inventory = ledger.inventory

    case apply_postings(starting_inventory, ledger, postings) do
      {:ok, inventory} ->
        %{ledger | inventory: inventory}

      {:error, messages} ->
        Enum.reduce(messages, %{ledger | inventory: starting_inventory}, &add_error(&2, &1))
    end
  end

  defp apply_postings(inventory, ledger, postings) do
    Enum.reduce_while(postings, {:ok, inventory, []}, fn posting, {:ok, inv, _errors} ->
      case apply_posting_to_inventory(inv, ledger, posting) do
        {:ok, new_inv} -> {:cont, {:ok, new_inv, []}}
        {:error, message} -> {:halt, {:error, [message]}}
      end
    end)
    |> case do
      {:ok, inventory, _} -> {:ok, inventory}
      {:error, messages} -> {:error, messages}
    end
  end

  defp apply_posting_to_inventory(inventory, ledger, %Posting{account: account} = posting) do
    booking =
      case Map.get(ledger.opens, account) do
        %Open{booking: booking} -> booking
        _ -> nil
      end

    Inventory.apply_posting(inventory, account, posting, booking)
  end

  defp posting_material?(%Posting{amount: nil, currency: nil}), do: false

  defp posting_material?(%Posting{amount: %Decimal{} = amount, currency: nil}),
    do: not Decimal.equal?(amount, 0)

  defp posting_material?(_), do: true

  defp parent_account?(account) do
    not String.contains?(account, ":")
  end

  defp balance_key(%Balance{account: account, currency: currency, date: date}),
    do: {account, currency, date}

  defp resolve_include(path, base) do
    candidates =
      case base do
        nil -> [path]
        base -> [path, Path.join(Path.dirname(base), path)]
      end

    if Enum.any?(candidates, &File.exists?/1) do
      :ok
    else
      {:error, "File glob \"#{path}\" does not match any files"}
    end
  end

  defp add_error(ledger, message) when is_binary(message) do
    %{ledger | errors: [%{line: nil, message: message} | ledger.errors]}
  end

  defp add_error(ledger, %{message: message}) do
    add_error(ledger, message)
  end
end
