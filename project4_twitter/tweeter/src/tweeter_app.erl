%%%-------------------------------------------------------------------
%% @doc tweeter public API
%% @end
%%%-------------------------------------------------------------------

-module(tweeter_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    tweeter_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
