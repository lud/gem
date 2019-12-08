ExUnit.start()

defmodule CubHelpers do
  def clear_db(db) do
    keys = list_keys(db)

    CubDB.delete_multi(db, keys)
    CubDB.file_sync(db)
  end

  def list_keys(db) do
    {:ok, keys} =
      CubDB.select(db,
        pipe: [
          map: fn {k, _} -> k end
        ]
      )

    keys
  end
end
