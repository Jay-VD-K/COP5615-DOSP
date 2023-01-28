-module(tweeter_server).
-export([initServer/0]).

initServer() ->
  register(server, self()),
  initServer(maps:new()).

initServer(LoggedInUsers) -> 
  receive
    {UserProcessId, {register, Handle}} -> 
      NewLoggedInUsers = registerUser(UserProcessId, Handle, LoggedInUsers);
    {UserProcessId,{login, Handle}} -> 
      NewLoggedInUsers = loginUser(UserProcessId, Handle, LoggedInUsers);
    {UserProcessId, {tweet, Message}} ->
      NewLoggedInUsers = LoggedInUsers,
      tweet(UserProcessId, Message, LoggedInUsers);
    {UserProcessId, {getAllTweets}} -> 
      NewLoggedInUsers = LoggedInUsers,
      getAllTweets(UserProcessId, LoggedInUsers);
    {UserProcessId, {follow, Handle}} ->
        NewLoggedInUsers = LoggedInUsers,
        followUser(UserProcessId, Handle, LoggedInUsers);
    {UserProcessId, {retweet, Id}} -> 
      NewLoggedInUsers = LoggedInUsers,
      retweet(UserProcessId, Id, LoggedInUsers)
  end,
  initServer(NewLoggedInUsers).

registerUser(UserProcessId, Handle, LoggedInUsers) ->
  io:format("registering user ~p \n", [Handle]),
  pgInsert("INSERT INTO tweeters (handle) VALUES ($1) RETURNING *", [Handle]),
  loginUser(UserProcessId, Handle, LoggedInUsers).

loginUser(UserProcessId, Handle, LoggedInUsers) ->
  _Rows = pgSelect("SELECT * FROM tweeters WHERE handle = $1", [Handle]),
  NewLoggedInUsers = maps:put(UserProcessId, Handle ,LoggedInUsers),
  NewLoggedInUsers.

tweet(UserProcessId, Message, LoggedInUsers) -> 
    Handle = maps:get(UserProcessId, LoggedInUsers),
    pgInsert("INSERT INTO tweets(by, tweet) VALUES ($1, $2) RETURNING *", [Handle, Message]),
    notifyLoggedInUsers(LoggedInUsers, Message, Handle).

getAllTweets(UserProcessId, LoggedInUsers) ->
    Handle = maps:get(UserProcessId, LoggedInUsers),
    Followers = pgSelect("SELECT ee FROM followers WHERE er = $1", [Handle]),
    Rows = pgSelect("SELECT * FROM tweets WHERE by in $1", [Followers]),
    Rows.

followUser(UserProcessId, Handle, LoggedInUsers) -> 
    ER = maps:get(UserProcessId, LoggedInUsers),
    pgInsert("INSERT INTO followers(ee, er) VALUES ($1, $2) RETURNING *", [Handle, ER]).

retweet(UserProcessId, Id, LoggedInUsers) ->
  TweetRow = pgSelect("SELECT tweet from tweets WHERE id = $1", [Id]),
  Tweet = erlang:bitstring_to_list(erlang:element(1, TweetRow)),
  tweet(UserProcessId, Tweet, LoggedInUsers).

notifyLoggedInUsers(LoggedInUsers, Message, Tweeter) ->
    Followers = pgSelect("SELECT er from followers WHERE ee = $1", [Tweeter]),
    io:format("Folowers: ~p \n LoggedInUsers: ~p", [Followers, LoggedInUsers]),
    maps:fold(
      fun(UserProcessId, Handle, _) -> 
        io:format("UPI: ~p \n H: ~p", [UserProcessId, Handle]),
        ListContains = lists:member({erlang:list_to_bitstring(Handle)}, Followers),
        if
          ListContains ->
            UserProcessId! {self(), liveFeed, Message},
            io:format("Sent live notification to ~p (~p)", [Handle, UserProcessId]);
          true -> false
        end
	    end, ok, LoggedInUsers).

pgSelect(Query, Params) ->
  {ok, C} = epgsql:connect(#{ host => "localhost", username => "postgres", password => "postgres", database => "tweeter_db", port => 5432, timeout => 4000}),
  {ok, _Columns, Rows} = epgsql:equery(C, Query, Params),
  ok = epgsql:close(C),
  Rows.

pgInsert(Query, Params) ->
  {ok, C} = epgsql:connect(#{ host => "localhost", username => "postgres", password => "postgres", database => "tweeter_db", port => 5432, timeout => 4000}),
  {ok, _Count, _Coulumns, _Rows} = epgsql:equery(C, Query, Params),
  ok = epgsql:close(C).
