defmodule Bot.Consumer.MessageCreate do
  @moduledoc "Handles the `MESSAGE_CREATE` gateway event."

  @nosedrum_storage_implementation Nosedrum.Storage.ETS

  alias Nosedrum.Invoker.Split, as: CommandInvoker
  alias Nostrum.Struct.Message

  def handle(msg) do
    IO.inspect(msg.content, label: "Handling at message create")
    CommandInvoker.handle_message(msg, @nosedrum_storage_implementation)
  end
end
