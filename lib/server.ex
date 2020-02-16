defmodule Casino do
  @moduledoc """
  This is a Caino Server module
  This should work with a manager module and a player module
  """

  @doc """
  This Casino Server allows manager to open and close a casino process.
  After casino process is created by a manager, players can join to play.
  The game is Sic Bo and player can bet on small, big, odd, even, single number and three numbers
  The game is performed periodically and player can place bet any time.
  Casino will inform player who has bet placed when the result is generated.
  """

  use GenServer

  require Integer

  defstruct [:manager_pid,
             :opening_status,
             earning_status: 0
             # result_history: []
           ]


  @spec init(any()) :: {:ok, {%Casino{}, []}}
  def init(_arg) do
    {:ok, {%Casino{}, []}}
  end

  @spec handle_cast({:manager_action, tuple()}, {%Casino{}, list()}) :: {:noreply, {%Casino{}, list()}}
  # Handle manager request
  # For open request, start the periodic Sic Bo result geneating
  # For close request, change the casino status to closed and wait for the current round to finish
  def handle_cast({:manager_action, action}, {casino, players}) do
    case action do
      {:open, manager_pid} ->
        loop_pid = self()
        spawn fn -> start_a_new_round(loop_pid) end
        send(manager_pid, {:reply, {:open}})
        {:noreply, {%{casino | manager_pid: manager_pid, opening_status: :open}, []}}

      {:close} ->
        IO.puts("Casino: Casino is closing!")
        {:noreply, {%{casino | opening_status: :closed}, players}}
    end
  end

  @spec handle_info({:timeout, tuple()}, {%Casino{}, list()}) :: {:noreply, {%Casino{}, list()}}
  # Handle timeout
  # Triggered by timer process
  # Received result and calculate win/lose for each player and casino
  # If casino is still open, start a new round
  # If casino is closed, cleanup all players and inform manager the earning
  def handle_info({:timeout, result}, {casino, players}) do
    {new_players_list, new_earning_status} =
      calculate_result(result, players, casino.earning_status)
    case casino.opening_status do
      :open ->
        loop_pid = self()
        spawn fn -> start_a_new_round(loop_pid) end
        {:noreply, {%{casino | earning_status: new_earning_status}, new_players_list}}

      :closed ->
        cleanup(players)
        send(casino.manager_pid, {:reply, {:closed, casino.earning_status}})
        {:noreply, {%Casino{}, []}}
    end
  end

  @spec handle_call({:player_action, tuple()}, pid(), {%Casino{}, list()}) ::
  {:reply, String.t(), {%Casino{}, list()}}
  # Handle player request
  # Triggered by timer process
  # Received result and calculate win/lose for each player and casino
  def handle_call({:player_action, action}, _from, {casino, players}) do
    case action do
      # Signup for the player. Add player to the player list
      # Check if player existed
      {:signup, player_pid, amount} ->
        if find_player(player_pid, players) do
          {:reply, "You have already joined.", {casino, players}}

        else
          new_players_list = [%{player_pid: player_pid, balance: amount, bet: {}} | players]
          {:reply, "Welcome Player! #{amount} is deposit.", {casino, new_players_list}}
        end

        # Signoff for the player. Remove player from the player list
        # Check if player existed
      {:signoff, player_pid} ->
        player = find_player(player_pid, players)
        if player do
          new_players_list = Enum.filter(players, &(&1.player_pid != player_pid))
          {:reply, "Bye Player! #{player.balance} is withdrawn", {casino, new_players_list}}

        else
          {:reply, "Player Unknown!", {casino, players}}
        end

        # Place bet for the player. Add bet to player
        # Check if player existed
        # Check if player has sufficient Balance
        # Check if player already has a bet
        # Check if the current bet is the same as previous bet
      {:bet, player_pid, type, amount} ->
        player = find_player(player_pid, players)
        if player do
          new_balance = player.balance - amount
          case player.bet do
            _ when new_balance < 0 ->
              {:reply, "No Enough Balance! #{player.balance} remaining in you account.", {casino, players}}

            {} when new_balance >= 0 ->
              # TODO: check if it is valid bet type
              new_players_list = place_bet(player, type, amount, players)
              {:reply, "Bet Accepted! #{amount} is bet.", {casino, new_players_list}}

            {existing_bet, existing_amount} when existing_bet == type and new_balance >= 0 ->
              new_players_list = place_bet(player, type, amount, players)
              {:reply, "Increase bet amount! #{existing_amount + amount} in total is bet.", {casino, new_players_list}}

            {_current_bet, _current_bet_amount} ->
              # TODO: To accept multiple different bet for a player
              {:reply, "Already have a bet.", {casino, players}}
          end

        else
          {:reply, "Player Unknown!", {casino, players}}
        end

      _ ->
        {:reply, "Wrong Action!", {casino, players}}
    end
  end

  @spec terminate(any(), any()) :: :ok
  def terminate(_reason, _state) do
    nil
  end



################################################################################
### Internal Functions
################################################################################

  @spec cleanup(list()) :: :ok
  # Signoff each player. Send each player the signoff message.
  defp cleanup(players) do
    Enum.each(players,
              &(send(&1.player_pid,
                     {:reply, {:closed, "Bye Player! #{&1.balance} is withdrawn"}})))
  end


  @spec find_player(pid(), list()) :: %{}
  # Find the player by pid
  defp find_player(player_pid, players) do
    Enum.find(players, &(&1.player_pid == player_pid))
  end


  @spec place_bet(%{}, tuple(), pos_integer(), list()) :: list()
  # Place bet for player
  # 1. Find the player by pid
  # 2. Check if balance is enough
  # 3. Check if already has a bet
  defp place_bet(%{player_pid: player_pid}, type, amount, players) do
    Enum.map(players,
             fn x ->
               pid = x.player_pid
               new_balance = x.balance - amount
                 case x.bet do
                   {} when pid == player_pid ->
                     %{x | balance: new_balance, bet: {type, amount}}
                   {existing_bet, existing_amount} when
                     pid == player_pid and existing_bet == type and new_balance >= 0 ->
                     %{x | balance: new_balance, bet: {existing_bet, existing_amount + amount}}
                   _ ->
                     x
                 end
             end)
  end


  @spec start_a_new_round(pid()) :: nil
  # To generate periodic round and inform pid when time reaches
  defp start_a_new_round(casino_pid) do
    receive do
    after
      10000 ->
        result = {:rand.uniform(6), :rand.uniform(6), :rand.uniform(6)}
        send(casino_pid, {:timeout, result})
    end
  end


  @spec calculate_result(tuple(), list(), integer()) :: {list(), integer()}
  # After each round calculate earning for player and casino
  # Inform player who played the result and update earning status for casino
  defp calculate_result({a,b,c} = result, players, casino_earning_status) do
    new_earning_status =
      List.foldl(players, casino_earning_status,
      fn x, acc ->
        case x.bet do
          {current_bet, bet_amount} ->
            case calculate_odds(current_bet, result) do
              0 ->
                acc + bet_amount
              odd ->
                acc - (bet_amount * odd)
            end

          {} ->
            acc
        end
      end)

    reply_result = "#{a} - #{b} - #{c}"

    new_players_list =
      Enum.map(players,
      fn x  ->
        case x.bet do
          {current_bet, bet_amount} ->
            odd = calculate_odds(current_bet, result)
            if odd == 0 do
              send(x.player_pid, {:reply, {:result, "You Lose. Result is #{reply_result}. Current balance is #{x.balance}."}})
              %{x | bet: {}}

            else
              win_amount = bet_amount + (bet_amount * odd)
              new_balance = x.balance + win_amount
              send(x.player_pid, {:reply, {:result, "You Win! You Win #{bet_amount * odd}! Result is #{reply_result}. Current balance is #{new_balance}."}})
              %{x | balance: new_balance, bet: {}}
            end

          {} ->
            x
        end
      end)

    {new_players_list, new_earning_status}
  end


  @spec calculate_odds(tuple(), tuple()) :: integer()
  # Calculate the odd based on the bet and the result
  defp calculate_odds({bet_a, bet_b, bet_c}, {res_a,res_b,res_c}) do
    case Enum.sort([res_a, res_b, res_c]) == Enum.sort([bet_a, bet_b, bet_c]) do
      true ->
        30
      _ ->
      0
    end
  end
  defp calculate_odds({bet_a_number}, {res_a,res_b,res_c}) do
    case Enum.count([res_a, res_b, res_c], &(&1 == bet_a_number)) do
      1 ->
        1
      2 ->
        3
      3 ->
        12
      _ ->
        0
    end
  end
  defp calculate_odds(bet_bigsmall_evenodd, {res_a,res_b,res_c}) do
    res_sum = res_a + res_b + res_c
    case res_a == res_b and res_b == res_c do
      true ->
        0
      false ->
        case bet_bigsmall_evenodd do
          :big when res_sum > 9 ->
            1
          :small when res_sum <= 9 ->
            1
          :even when Integer.is_even(res_sum) ->
            1
          :odd when Integer.is_odd(res_sum) ->
            1
          _combination ->
            0
        end
    end
  end



end
