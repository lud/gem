# Gem : Game Entities Machine

**TODO: Add description**


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `gem` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gem, "~> 0.1.0"}
  ]
end
```

### Install Gem in your supervision tree

This is pretty straightforward, just initialize a Gem with some
configuration :

```elixir
defmodule MyApp.Application do
  
  use Application
  
  def start(_type, _args) do
    children = [
      # ...
      {Gem.Adapter.EventDispatcher.Registry, MyApp.Gem.Dispatcher},
      {Gem, name: MyApp.Gem, 
            register: true,
            repository: {Gem.Adapter.Repository.Ecto, MyApp.Repo},
            dispatcher: {Gem.Adapter.EventDispatcher.Registry, MyApp.Gem.Dispatcher}
      }
      # ...
    ]
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
```

This example sets up a single Gem for the application. Any number of
gems can be set, but you have to be careful then because if they use
the same repository, they could update entities concurrently and you
would lose data.

#### Options

Gem requires the following options:

  * `:name` - The name for local process registration.
  * `:repository` - The repository adapter to load and save
  the entities managed by Gem. It is a tuple with two elements:
    * A module implementing the `Gem.Repository` behaviour,
    * The identifier of the repository for the adapter. The identifier
      can be an atom, a pid, or anything else as it depends on the
      adapter.

The following options are … optional:

  * `:register` - Wether the process should register its `:name`. When
    using multiple Gems you may want to use pids instead of names.
    Defaults to `true`.
  * `:dispatcher` The dispatcher adapter to broadcast Gem events. As
    for `repositiory` it is a tuple with two elements:
    * A module implementing the `Gem.EventDispatcher` behaviour,
    * An identifier for the dispatcher: a pid or an atom ; or anything
      else if you use a custom dispatcher.

When using `Gem.Adapter.EventDispatcher.Registry` as a dispatcher, you
will have to start the adapter process with the given name. You can
also use an existing `Registry` as the following specs are equivalent:

```elixir
{Gem.Adapter.EventDispatcher.Registry, MyApp.Gem.Dispatcher}
# Same as:
{Registry,
  name: MyApp.Gem.Dispatcher,
  keys: :duplicate,
  partitions: System.schedulers_online()}
```

Note that duplicate keys must be used.


## Issuing commands

The Gem library revolves around commands that are sent to you Gem
process run on your entities.

Commands are simple modules that implement the `Gem.Command` behaviour
and define a struct.

A command provides a _key spec_ (through the `key_spec/1` callback) to
load entites, and accept those entities along with the command struct
in the `run/2` callback.

Gem does not much behind the scene, it will just load the entities
thanks to the repository it was passed, and call them to your `run/2`
function.

The only goal of Gem is to ensure that any commands that require a
common entity will be ran sequentially, and that data is properly
persisted between the two commands execution.


### Key specs

Commands `run/2` callback are called with the command struct as the
first argument, and then entities as the second argument. The _key
spec_ describes how the entities are passed.

The most basic key spec is a 2-tuple, `{type, id}`, where `type` is
the entity type (for example the name of an Ecto schema, e.g. `User`)
and `id` is simply the primary key.

So it the `key_spec/1` function returns `{User, 123}`, your `run/2`
function will be called with `%User{id: 123, …}` as its second
argument.

Gem will _fullfill_ the spec by loading those entities from the
repository.

More complex entities are possible through the use of lists and maps.
For example, `%{buyer: {User, 123}, seller: {User: 456}}` as a spec
will have your command called with two Ecto schemas in the same
_shape_: `%{buyer: %User{id: 123, …}, seller: %User{id: 456, …}}`.

It is also possible to simply return `nil` from `key_spec/1`, but if 
no locking is required, it may not be useful to create a command.

TODO add a "Creating entities" section.


If an entity could not be found, the atom `:NOT_FOUND` will be given
instead of the corresponding entity. Gem will not raise if some entity
could not be found, and will still call your `run/2` callback.

Thus, it is the developer responsibility to ensure that all the
required entities have been found.

The `Gem.Command` behaviour defines a `check/2` function that must
accept the same arguments as `run/2` (i.e. the command struct and the
fullfilled entities) but should not perform any action besides
validation. It is a good place to fail early if a required entity is
`:NOT_FOUND`.

TODO example on pattern matching heads for not found in check/2

Note that it is OK to run a command when an entity is not found if the
entity is not _required_. For example, commands for a key/value store
may create the entity on the fly if it does not exist yet.


### Updating data

The `run/2` callback for a command can perform any operations that the
developer want. As long as a command is running, no other command will
run if it shares a common entity with the running command in its key
spec.

A command may then return a single `:ok` to free the entities for
other commands if everything went well, or an `{:error, …}` 2-tuple
otherwise.

Commands are given to then `Gem.run/2` function and its return value
would then be the same `:ok` or `{:error, …}` value.

Although, it is a good practice to provide _pure_ functions as the
command callbacks, and use the update/event system provided by Gem to
persist changes to your data. Update/events are described below.

A command may return `{:ok, events}` or `{:ok, reply, events}` in
which case the return value of `Gem.run/2` would be `:ok` or `{:ok, reply}`.

If your reply is computed dynamically, you may want to return `:"$noreply"` as
the reply, so it will be ignored and the return value of `Gem.run/2` will be 
`:ok`.

If you need to return a reply but no events, just return and empty
list: `{:ok, reply, []}`.


### Events and persistence

Events returned by a command `run/2` callback is a list of tuples with
two elements. The first element of the tuple is the _topic_ and the
second element is the event value. So basically `{:my_event, value}`
is a valid event.

There are a few rules to respect about events:


  * As said before, an event is a tuple of size 2.
  * 2-tuples where the first element is `:update`, `:delete` or
    `:insert` are special events reserved by Gem. They will not be
    dispatched as they are used to persist data to the repository.
    Refer to the the "Update events" section to know more.
  * 2-tuples where the _topic_ is itself a tuple matching `{:updated,
    _}`, `{:deleted, _}` or `{:inserted, _}`, for instance
    `{{:updated, Account}, %Account{}}`, are normal events but
    repository adapters issue those events after perfoming writes,
    you should then respect their data shape if you want to mimic
    those events.

Special events (`:update`, `:delete` or `:insert`) will be handled
before any other event of the list is handled. Order of events within
each group (special or normal) is respected.

Each event returned by the command is passed to the
`transform_event/2` callback of the dispatcher module. The standard
dispatcher (`Gem.Adapter.EventDispatcher.Registry`) will not perform
any changes to your events and return them as they are, but you may
want to provide your own dispatcher to be able to transform events as
you see fit.

If `transform_event/2` returns a list, it is a list of new events. The
results of this thransformation is also flattened. Note that events
returned by `transform_event/2` will not be recursively passed to this
callback. If you need this behaviour, you will have to flatten your
own list and call `transform_event/2` recursively.


#### Update events

Events that are 2-tuples where the first element is either `:insert`,
`:update` or `:delete` will be swallowed by Gem (not dispatched) and
will trigger writes in the given repository adapter ; before any other
event is dispatched.

For example, the following `run/2` callback for a command is _pure_
and returns and event to write data to the database:

```elixir
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
```

If you are new to Elixir, you may need to know that `{:ok, update:
account}` is syntaxic sugar for `{:ok, [{:update, account}]}` where we
can see that the single item in the returned events list is a 2-tuple
with `:update` as its first element.

Repository adapters provided in the Gem distribution will issue events
with `{:updated, type}`, `{:deleted, type}` and `{:inserted, type}`
_topics_ after the corresponding changes are written. For instance:
`{{:updated, Account}, %Account{balance: 1000}}`.

The type of entity is given in the _topic_ of the event, (i.e.
`{:updated, Account}`) because event listeners may listen for only a
subset of your entity types events.

The `nil` event will be silently ignored. You may return events
conditionnally with this simple form:

```elixir
events = [{:update, record}, if(some_condition, do: {:another_event, value})]
```




### Fetching data
TODO


#### Fun commands
TODO
With `Gem.Command.Fun` you can create a command that will load the
entities from your entity spec and pass them to the fun.

TODO a note on exceptions : commands are ran in the calling process