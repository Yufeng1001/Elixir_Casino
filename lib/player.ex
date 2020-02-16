defmodule Player do
  @moduledoc """
  This is a Player Client module
  This should work with a manager module and a casino module
  """

  @doc """
  This Player Client allows player to join an established casino process.
  After game joined, player can place bet on small, big, odd, even, single number and three numbers
  Player can perform below action:
  player_pid = Player.join_game(casino_pid :: pid())
  send(player_pid, {:signup, amount :: pos_integer()})
  send(player_pid, {:bet, bet, bet_amount :: pos_integer()})
    Example of bet could be {2,4,6}, {1}, :odd, : small
  send(player_pid, {:signoff})
  """

  @spec join_game(pid()) :: pid()
  # Player init
  def join_game(casino_pid) do
    spawn_link fn() -> receive_loop(casino_pid) end
  end


  @spec join_game(pid()) :: term()
  # Player loop to receive player request and casino message
  defp receive_loop(casino_pid) do
    receive do
        {:signup, amount} ->
          msg = {:signup, self(), amount}
          reply = GenServer.call(casino_pid, {:player_action, msg})
          IO.puts("#{reply}")
          receive_loop(casino_pid)

        {:signoff} ->
          msg = {:signoff, self()}
          reply = GenServer.call(casino_pid, {:player_action, msg})
          IO.puts("#{reply}")
          receive_loop(casino_pid)

        {:bet, type, amount} ->
          if valid_type?(type) do
            msg = {:bet, self(), type, amount}
            reply = GenServer.call(casino_pid, {:player_action, msg})
            IO.puts("#{reply}")
            receive_loop(casino_pid)
          else
            IO.puts("Not a valid bet!")
            receive_loop(casino_pid)
          end

        {:reply, {:result, reply}} ->
          IO.puts("#{reply}")
          receive_loop(casino_pid)

        {:reply, {:closed, reply}} ->
          IO.puts("#{reply}")


      # {:show_balance}} ->
      #   # TODO: to show the current balance of the player

      # {:recharge, amount} ->
      #   # TODO: to deposite for the player

      end

  end


  @spec valid_type?(term()) :: boolean()
  # Check if the bet type is valid
  defp valid_type?(type) do
    case type do
      type when type == :odd or type == :even ->
        true
      type when type == :small or type == :big ->
        true
      {n} ->
        is_integer(n) and n >= 1 and n <= 6
      {a, b, c} ->
        is_integer(a) and is_integer(b) and is_integer(c) and
        a >= 1 and a <= 6 and
        b >= 1 and b <= 6 and
        c >= 1 and c <= 6
      _ ->
        false
    end
  end


end
