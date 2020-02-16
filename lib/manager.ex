defmodule Manager do
  @moduledoc """
  This is a Manager Client module
  This should work with a casino module
  """

  @doc """
  This Manager Client allows manager to establish a casino process.
  After casino established, player can join and play casino game.
  Manager can perform below action:
  {manager_pid, casino_pid} = Manager.open_casino()
  send(manager_pid, :close)
  """

  @spec open_casino() :: {pid(), pid()}
  # Request to start a casino process
  def open_casino() do
    {:ok, casino_pid} = GenServer.start_link(Casino, nil)
    manager_pid = spawn_link fn() -> manager_loop(casino_pid) end
    GenServer.cast(casino_pid, {:manager_action, {:open, manager_pid}})
    {manager_pid, casino_pid}
  end

  @spec manager_loop(pid()) :: term()
  # Manager loop to wait for manager request and casino reply
  defp manager_loop(casino_pid) do
    receive do
      {:reply, {:open}} ->
        IO.puts("Manager: Casino open for business!")
        manager_loop(casino_pid)

      {:reply, {:closed, earning_status}} ->
        GenServer.stop(casino_pid)
        IO.puts("Manager: Casino closed! Earning is #{earning_status}")

      :close ->
        GenServer.cast(casino_pid, {:manager_action, {:close}})
        manager_loop(casino_pid)

      _ ->
        manager_loop(casino_pid)
    end
  end

end
