defmodule Bot.Periodic do
  use GenServer
  alias Bot.Helpers

  def start_link do
    GenServer.start_link(__MODULE__, %{ })
  end

  def init(state) do
#    IO.inspect(state, label: "INITIAL state is")
    schedule_work() # Schedule work to be performed at some point
    {:ok, %{ status: :online }}
  end

  def handle_info(:work, state) do
    # Do the work you desire here
#    updated_state = Helpers.blink_rules_post(state)
#    IO.inspect(updated_state, label: "Updated state is")
    schedule_work() # Reschedule once more
    {:noreply, state}
  end

  defp schedule_work() do
    Process.send_after(self(), :work, 10000) # In 10 sec
  end
end
