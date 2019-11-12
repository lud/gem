defmodule MyApp.Bank.Deposit do
  use Gem.Command
  alias MyApp.Data.Account

  defstruct amount: nil, account_id: nil

  def new(account_id, amount) when is_integer(amount) and amount > 0,
    do: %__MODULE__{account_id: account_id, amount: amount}

  def key_spec(%__MODULE__{account_id: account_id}),
    do: {Account, account_id}

  def run(%{amount: amount}, %Account{} = account) do
    account = Map.update!(account, :balance, &(&1 + amount))
    {:ok, update: account}
  end
end
