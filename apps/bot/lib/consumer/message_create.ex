defmodule Bot.Consumer.MessageCreate do
  @moduledoc "Handles the `MESSAGE_CREATE` gateway event."

  @nosedrum_storage_implementation Nosedrum.Storage.ETS

  alias Bot.Invoker.Split, as: CommandInvoker
  alias Nostrum.Struct.Message

  def handle(msg) do
    CommandInvoker.handle_message(msg, @nosedrum_storage_implementation)
    with "!" <> cmd <- msg.content do
      :ets.lookup(:nosedrum_commands, cmd)
    end
  end
end
