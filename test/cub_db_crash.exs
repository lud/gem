defmodule CubDbCrashTest do
  use ExUnit.Case

  @db_dir "test/db/#{__MODULE__}"
  @db_name Module.concat(__MODULE__, Repo)
  @mutex Module.concat(__MODULE__, Mutex)

  setup_all do
    File.mkdir_p!(@db_dir)

    db_opts = [auto_compact: true, auto_file_sync: false]
    gen_opts = [name: @db_name]

    start_supervised(%{
      id: __MODULE__.DB,
      start: {CubDB, :start_link, [@db_dir, db_opts, gen_opts]}
    })

    start_supervised(%{
      id: @mutex,
      start: {Mutex, :start_link, [[name: @mutex]]}
    })

    :ok
  end

  defmodule Account do
    defstruct id: nil, balance: 0
  end

  defp put_account(%Account{id: id} = account) do
    CubDB.get_and_update_multi(@db_name, [], fn %{} ->
      {account, [{{Account, id}, account}], []}
    end)
  end

  defp get_account(id) do
    [account] = CubDB.get_multi(@db_name, [{Account, id}], :NOT_FOUND)
    {:ok, account}
  end

  defp withdrawal(account_id, amount) do
    Mutex.under(@mutex, {Account, account_id}, fn ->
      {:ok, account} = get_account(account_id)

      if account.balance < amount do
        {:error, :not_enough_money}
      else
        account = Map.update!(account, :balance, &(&1 - amount))
        put_account(account)
        :ok
      end
    end)
  end

  defp deposit(account_id, amount) do
    Mutex.under(@mutex, {Account, account_id}, fn ->
      {:ok, account} = get_account(account_id)
      account = Map.update!(account, :balance, &(&1 + amount))
      put_account(account)
      :ok
    end)
  end

  @account_id 1234

  test "Massive concurrency" do
    account = %Account{id: @account_id, balance: 0}
    put_account(account)

    IO.puts("Launching commands")
    iterations = 10_000
    withdrawal = exec_command_n({:withdrawal, fn -> withdrawal(@account_id, 12) end}, iterations)
    deposit_1 = exec_command_n({:deposit, fn -> deposit(@account_id, 4) end}, iterations)
    deposit_2 = exec_command_n({:deposit, fn -> deposit(@account_id, 4) end}, iterations)
    deposit_3 = exec_command_n({:deposit, fn -> deposit(@account_id, 4) end}, iterations)

    IO.puts("Awaiting commands")
    Task.await(withdrawal, :infinity)
    Task.await(deposit_1, :infinity)
    Task.await(deposit_2, :infinity)
    Task.await(deposit_3, :infinity)

    case get_account(@account_id) do
      {:ok, %Account{balance: balance}} ->
        assert(balance == 0)

      other ->
        raise "Unexpeced result"
    end
  end

  defp exec_command_n(command, iterations) do
    Task.async(fn ->
      # Process.sleep(100)
      exec_retry_n(command, iterations)
    end)
  end

  defp exec_retry_n(command, 0),
    do: :ok

  defp exec_retry_n({name, fun} = command, iterations) when iterations > 0 do
    case fun.() do
      :ok ->
        # IO.puts("Command succeeded: #{name}")

        exec_retry_n(command, iterations - 1)

      {:error, reason} ->
        # IO.puts("error running command #{name}\n  reason: #{inspect(reason)}")
        Process.sleep(50)
        exec_retry_n(command, iterations)
    end
  end
end
