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
    PopTag,
    PushTag,
    Transaction
  }

  alias Beancount.Engine.Elixir.{
    BalanceCheck,
    DirectiveSort,
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
    {directives, ledger} = expand_includes(directives, ledger)
    directives = apply_tag_scopes(directives)
    ledger = index_accounts(ledger, directives)
    ordered = DirectiveSort.order(directives)

    Enum.reduce(ordered, ledger, fn directive, ledger ->
      apply_directive(directive, ledger)
    end)
  end

  # Beancount applies pushtag/poptag scopes at parse time, in file order. We bake
  # the active tags into each transaction here (before the date sort) so scoping
  # follows authored order rather than chronological order.
  defp apply_tag_scopes(directives) do
    {tagged, _stack} =
      Enum.map_reduce(directives, [], fn
        %PushTag{tag: tag}, stack ->
          {%PushTag{tag: tag}, [tag | stack]}

        %PopTag{tag: tag}, stack ->
          {%PopTag{tag: tag}, List.delete(stack, tag)}

        %Transaction{tags: tags} = txn, stack ->
          {%{txn | tags: Enum.uniq(tags ++ Enum.reverse(stack))}, stack}

        other, stack ->
          {other, stack}
      end)

    tagged
  end

  defp expand_includes(directives, ledger) do
    seen =
      case ledger.include_base do
        nil -> MapSet.new()
        base -> MapSet.new([Path.expand(base)])
      end

    {expanded, errors} = do_expand(directives, ledger.include_base, seen)
    {expanded, Enum.reduce(errors, ledger, &add_error(&2, &1))}
  end

  defp do_expand(directives, base, seen) do
    Enum.reduce(directives, {[], []}, fn
      %Include{path: path}, {acc, errs} ->
        {child_dirs, child_errs} = load_include(path, base, seen)
        {acc ++ child_dirs, errs ++ child_errs}

      other, {acc, errs} ->
        {acc ++ [other], errs}
    end)
  end

  defp load_include(path, base, seen) do
    case resolve_include_path(path, base) do
      {:ok, resolved} ->
        expand_resolved_include(path, resolved, seen)

      :error ->
        {[], ["File glob \"#{path}\" does not match any files"]}
    end
  end

  defp expand_resolved_include(path, resolved, seen) do
    absolute = Path.expand(resolved)

    if MapSet.member?(seen, absolute) do
      {[], ["Include cycle detected for #{path}"]}
    else
      read_and_expand_include(path, resolved, MapSet.put(seen, absolute))
    end
  end

  defp read_and_expand_include(path, resolved, seen) do
    with {:ok, text} <- File.read(resolved),
         {:ok, child} <- Beancount.Parser.parse_text(text) do
      do_expand(child, resolved, seen)
    else
      {:error, %{message: message}} ->
        {[], ["Include #{path}: #{message}"]}

      {:error, reason} ->
        {[], ["Cannot read include #{path}: #{inspect(reason)}"]}
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
    amounts = tolerance_amounts(postings, ledger.options.infer_tolerance_from_cost)

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

  defp tolerance_amounts(postings, infer_from_cost) do
    expanded = PostingAmount.expand_postings(postings)
    base = Enum.flat_map(expanded, &posting_tolerance_amounts/1)

    if infer_from_cost do
      base ++ Enum.flat_map(expanded, &cost_tolerance_amounts/1)
    else
      base
    end
  end

  defp cost_tolerance_amounts(%Posting{cost: %CostSpec{per_amount: %Decimal{} = per}}), do: [per]

  defp cost_tolerance_amounts(%Posting{cost: %CostSpec{total_amount: %Decimal{} = total}}),
    do: [total]

  defp cost_tolerance_amounts(_), do: []

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

  defp resolve_include_path(path, base) do
    candidates =
      case base do
        nil -> [path]
        base -> [path, Path.join(Path.dirname(base), path)]
      end

    case Enum.find(candidates, &File.exists?/1) do
      nil -> :error
      resolved -> {:ok, resolved}
    end
  end

  defp add_error(ledger, message) when is_binary(message) do
    %{ledger | errors: [%{line: nil, message: message} | ledger.errors]}
  end

  defp add_error(ledger, %{message: message}) do
    add_error(ledger, message)
  end
end
