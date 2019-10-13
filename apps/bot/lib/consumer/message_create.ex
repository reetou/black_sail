defmodule Bot.Consumer.MessageCreate do
  @moduledoc "Handles the `MESSAGE_CREATE` gateway event."

  @nosedrum_storage_implementation Nosedrum.Storage.ETS

  alias Nosedrum.Invoker.Split, as: CommandInvoker
  alias Nostrum.Struct.Message

  def handle(msg) do
    IO.inspect(msg.content, label: "Handling at message create")
    IO.inspect(@nosedrum_storage_implementation, label: "Storage implementation")
    CommandInvoker.handle_message(msg, @nosedrum_storage_implementation)
    |> IO.inspect(label: "Handle RESULT")
    raw_command = "!" <> msg.content
    :ets.lookup(:nosedrum_commands, raw_command)
    |> IO.inspect("Result at lookup for command #{raw_command} by hand")
  end
end
