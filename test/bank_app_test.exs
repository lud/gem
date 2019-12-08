defmodule Gem.EventsTest do
  use ExUnit.Case

  @db_dir "test/db/#{__MODULE__}"
  @db_name Module.concat(__MODULE__, Repo)
  @dispatcher_name Module.concat(__MODULE__, Dispatcher)
  @gem Module.concat(__MODULE__, Gem)

  defmodule Account do
    @behaviour Gem.Entity
    defstruct id: nil, balance: 0, max_overdraft: 0

    def new(id) when is_integer(id) do
      %__MODULE__{id: id}
    end

    def primary_key!(%__MODULE__{id: id}),
      do: id
  end

  defmodule Command.CreateAccount do
    use Gem.Command

    defstruct []

    def new() do
      %__MODULE__{}
    end

    defp generate_id() do
      :erlang.system_time(:millisecond)
    end

    def key_spec(_),
      do: nil

    def run(_, nil) do
      account_id = generate_id()
      account = Account.new(account_id)

      insert(account) |> reply({:ok, account_id})
    end
  end

  defmodule Command.Deposit do
    use Gem.Command

    defstruct amount: nil, account_id: nil

    def new(account_id, amount) when is_integer(amount) and amount > 0,
      do: %__MODULE__{account_id: account_id, amount: amount}

    def key_spec(%__MODULE__{account_id: account_id}),
      do: {Account, account_id}

    def run(%{amount: amount}, %Account{} = account) do
      account = Map.update!(account, :balance, &(&1 + amount))
      {:ok, update: account}
      # update(account)
    end
  end

  defmodule Command.Withdrawal do
    use Gem.Command

    defstruct amount: nil, account_id: nil

    def new(account_id, amount) when is_integer(amount) and amount > 0,
      do: %__MODULE__{account_id: account_id, amount: amount}

    def key_spec(%__MODULE__{account_id: account_id}),
      do: {Account, account_id}

    def run(%{amount: amount}, %Account{} = account) do
      %{balance: balance, max_overdraft: overdraft} = account
      new_balance = balance - amount
      minimum_balance = 0 - overdraft

      if new_balance < minimum_balance do
        {:error, :not_enough_money}
      else
        events = [
          {:update, Map.put(account, :balance, new_balance)},
          if(new_balance < 0, do: {:balance_below_zero, account.id})
        ]

        {:ok, events}
      end
    end
  end

  setup_all do
    File.mkdir_p!(@db_dir)

    db_opts = [auto_compact: true, auto_file_sync: false]
    gen_opts = [name: @db_name]

    start_supervised(%{
      id: __MODULE__.DB,
      start: {CubDB, :start_link, [@db_dir, db_opts, gen_opts]}
    })

    start_supervised({Gem.Adapter.EventDispatcher.Registry, @dispatcher_name})

    start_supervised(
      {Gem,
       name: @gem,
       repository: {Gem.Adapter.Repository.CubDB, @db_name},
       dispatcher: {Gem.Adapter.EventDispatcher.Registry, @dispatcher_name}}
    )

    CubHelpers.clear_db(@db_name)

    assert {:ok, account_id} = Gem.run(@gem, Command.CreateAccount.new())
    {:ok, %{account_id: account_id}}
  end

  defp assert_balance_sync(account_id, expected_balance) do
    assert %Account{balance: balance} = Gem.fetch_sync(@gem, {Account, account_id})
    assert balance === expected_balance
  end

  defp fetch_balance(account_id) do
    Gem.fetch_sync(@gem, {Account, account_id}).balance
  end

  defp update_account(account_id, fun) do
    :ok =
      Gem.run(
        @gem,
        Gem.Command.Fun.new({Account, account_id}, fn %Account{} = account ->
          {:ok, update: fun.(account)}
        end)
      )
  end

  test "The bank account exists", %{account_id: account_id} do
    # The bank account we work with is created during the test suite setup.
    # This test ensure that it exists.
    assert match?({:ok, %Account{id: account_id}}, Gem.fetch_entity(@gem, {Account, account_id}))
  end

  test "We can deposit money to an account", %{account_id: account_id} do
    # We send the deposit command and check the balance
    old_balance = fetch_balance(account_id)
    assert :ok = Gem.run(@gem, Command.Deposit.new(account_id, 1000))
    assert fetch_balance(account_id) === old_balance + 1000
  end

  test "We can withdraw money with a maximum overdraft, events are emitted when balance is below zero",
       %{account_id: account_id} do
    # First we will use a fun to arbitrarily fix the balance
    :ok = update_account(account_id, &Map.put(&1, :balance, 100))
    assert_balance_sync(account_id, 100)
    withdraw_com = Command.Withdrawal.new(account_id, 500)
    assert match?({:error, _}, Gem.run(@gem, withdraw_com))

    # Then we will change the overdraft
    :ok = update_account(account_id, &Map.put(&1, :max_overdraft, 1000))

    # We will listen for changes
    this = self()

    listener =
      Task.async(fn ->
        Gem.Adapter.EventDispatcher.Registry.subscribe(@dispatcher_name, {:updated, Account})
        Gem.Adapter.EventDispatcher.Registry.subscribe(@dispatcher_name, :balance_below_zero)
        send(this, :ack_registered)

        account_id =
          receive do
            {@gem, {:updated, Account}, %Account{balance: balance, id: id}} ->
              assert(balance < 0)
              id

            other ->
              assert(false == other)
          after
            1000 -> assert(false)
          end

        assert_receive({@gem, :balance_below_zero, ^account_id})
      end)

    receive do
      :ack_registered -> :ok
    end

    # Now we can withdraw 500
    assert :ok === Gem.run(@gem, withdraw_com)
    assert_balance_sync(account_id, 100 - 500)

    Task.await(listener)
    |> IO.inspect()
  end
end
