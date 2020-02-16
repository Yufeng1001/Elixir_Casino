This is a Casino game which supports Sic Bo. 

Manager can open the casino for player to play or close the casino to finish the game.
Player can join the game and bet, or signoff from the game.


  Manager can perform below action:
    {manager_pid, casino_pid} = Manager.open_casino()
    send(manager_pid, :close)
  
  Player can perform below action:
    player_pid = Player.join_game(casino_pid :: pid())
    send(player_pid, {:signup, amount :: pos_integer()})
    send(player_pid, {:bet, bet, bet_amount :: pos_integer()})
      Example of bet could be {2,4,6}, {1}, :odd, : small
    send(player_pid, {:signoff})
