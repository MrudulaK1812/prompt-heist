/// Where a player lands after rejoining, based on their restored state.
String routeForPlayerState(String state) => switch (state) {
  'PLAYING' || 'LOCKED_100' => '/player/battle', // locked is a battle state
  'RESULT_PENDING' => '/player/timeup',
  'COMPLETE' => '/player/result',
  _ => '/player/lobby', // LOBBY
};
