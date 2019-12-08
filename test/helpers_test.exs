defmodule Gem.HelpersTest do
  use ExUnit.Case
  alias Gem.Command.Helpers, as: H

  def flat({:ok, reply, events}),
    do: {:ok, reply, :lists.flatten(events)}

  test "helpers can be called in different order" do
    assert {:ok, :rep, []} = H.reply(:rep)

    assert {:ok, :rep, insert: :ins} = H.reply(:rep) |> H.insert(:ins) |> flat

    # order between reply() and events does not count
    assert H.reply(:rep) |> H.insert(:ins) |> flat === H.insert(:ins) |> H.reply(:rep) |> flat

    # Cannot overwrite reply
    assert_raise RuntimeError, ~r/^Reply is already set/, fn ->
      H.reply(:one) |> H.reply(:two)
    end
  end
end
