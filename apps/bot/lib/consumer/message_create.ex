defmodule Bot.Consumer.MessageCreate do
  @moduledoc "Handles the `MESSAGE_CREATE` gateway event."

  @nosedrum_storage_implementation Nosedrum.Storage.ETS

  alias Bot.Invoker.Split, as: CommandInvoker
  alias Nostrum.Struct.Message

  def handle(msg) do
    IO.inspect(msg.content, label: "Handling at message create")
    IO.inspect(@nosedrum_storage_implementation, label: "Storage implementation")
    CommandInvoker.handle_message(msg, @nosedrum_storage_implementation)
    |> IO.inspect(label: "Handle RESULT")
    with "!" <> cmd <- msg.content do
      :ets.lookup(:nosedrum_commands, cmd)
      |> IO.inspect(label: "Result at lookup for command #{cmd} by hand")
    end
  end
end
