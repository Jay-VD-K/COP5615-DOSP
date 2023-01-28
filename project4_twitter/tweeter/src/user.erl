-module(user).
-export([init/1]).

init(S) ->
    receive
        {_SimProcessId, {tweet, Message}} -> S! {self(), {tweet, Message}};
        {_SimProcessId, {register, Handle}} -> S! {self(), {register, Handle}};
        {_SimProcessId, {follow, Handle}} -> S! {self(), {follow, Handle}}
    end,
    init(S).