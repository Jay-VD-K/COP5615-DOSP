-module(sim).
-import(sim, [init/1]).
-export([init/0]).

init() ->
    init(10, 'server@10.20.63.42').

init(UserCount, ServerName) -> 
    net_adm:ping(ServerName),
    S = rpc:call(ServerName, erlang, whereis, [server]),
    io:format("1\n"),
    UserProcesses = registerAndFollow(UserCount, UserCount, S, array:new()),
    io:format("2\n"),
    tweetLoop(UserCount, 10, UserProcesses),
    io:format("3\n"),
    UserProcesses.

registerAndFollow(OCount, UserCount, S, UserProcesses) ->
    if
        UserCount > 0 -> 
            io:format("1 ~p\n", [UserCount]),
            UserProcess = spawn(sim, init, [S]),
            io:format("1- ~p\n", [UserCount]),
            UserProcess! {self(), register, string:concat("user", erlang:integer_to_list(UserCount))},
            io:format("1-- ~p\n", [UserCount]),
            NewUserProcesses = array:set(UserCount, UserProcess ,UserProcesses),
            io:format("1--- ~p\n", [UserCount]),
            follow(OCount, UserCount+1, UserProcess),
            io:format("1---- ~p\n", [UserCount]),
            registerAndFollow(OCount, UserCount - 1, S, NewUserProcesses);
        true -> UserProcesses
    end.

follow(OCount, UserCount, UserProcess) ->
    if
        UserCount =< OCount ->
            UserProcess!  {self(), follow, string:concat("user", erlang:integer_to_list(UserCount))},
            follow(OCount, UserCount + 1, UserProcess);
        true -> false
    end.

tweetLoop(UserCount, Count, UserProcesses) ->
    if 
        Count > 0 ->
            tweet(UserCount, UserProcesses),
            tweetLoop(UserCount, Count -1, UserProcesses);
        true -> false
    end.

tweet(Id, UserProcesses) ->
    if 
        Id > 0 -> 
            UserProcess = array:get(Id, UserProcesses),
            UserProcess !{self, {tweet, "Hi"}},
            tweet(Id - 1, UserProcesses);
        true -> false
    end.
