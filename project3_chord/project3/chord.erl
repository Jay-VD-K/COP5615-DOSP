-module(chord).
-export([startChord/2,chord_node/5,fix_fingers/3,terminate/5,test/0]).

startChord(N_Nodes, N_Requests) ->
  M=round(math:ceil(math:log2(N_Nodes)))+10,
  Hash=[{binary:decode_unsigned(crypto:hash(sha256,integer_to_list(N_Nodes))) rem round(math:pow(2,M)), spawn(chord, chord_node, [0,0,M,0,N_Requests])}],
  Table = createnodes(N_Nodes-1,Hash,M,N_Requests),
  register(man, spawn(chord,terminate, [0,0,0,N_Nodes,Table])),
  ets:new(tab,[named_table,ordered_set,public]),
  lists:foreach(fun(N) -> ets:insert(tab, lists:nth(N,Table)) end, lists:seq(1,N_Nodes)),
  fix_fingers(Table,M,1),
%   io:format("~p",[Table]),
%   io:format("~n~p~n",[ets:first(tab)]),
  lists:foreach(fun(N) -> {_,PID} = lists:nth(N,Table), PID ! {send} end, lists:seq(1,N_Nodes)).

% chord_nodes
chord_node(Table, Count , Max, Sent, N_Requests) ->
  receive
    {updatetable, T} ->
      chord_node(T,Count,Max,Sent,N_Requests);
    {send} ->
      Y=rand:uniform(round(math:pow(2,Max))),
      H=ets:member(tab,Y),
      if
        H =:= false ->
          Z=ets:last(tab),
          if
            Y>Z ->
              P=ets:prev(tab,Y);
            true ->
              P=ets:next(tab,Y)
          end;
        true ->
          P=ets:lookup(tab,Y)
      end,
      if
        Sent>=N_Requests ->
          man ! {nodefinished},
          chord_node(Table,Count,Max,Sent+1,N_Requests);
        true ->
          erlang:send_after(1000,self(),{send}),
          self() ! {findpath, P, 0},
          chord_node(Table,Count,Max,Sent+1,N_Requests)
      end ;

    {stop} ->
      terminated;
    {message, Hops} ->
      man ! {messagefinished, Hops},
      chord_node(Table,Count+1,Max, Sent,N_Requests);

    {findpath, N,Hops} ->
      {Found, P} = closest_node(N,1,math:pow(2,1023),0,Table),
      {_,PID} = lists:nth(P,Table),
      if
        Found =:= found ->
          PID ! {message, Hops+1};
        true ->
          PID ! {findpath, N,Hops+1}
      end,
      chord_node(Table, Count, Max, Sent, N_Requests)
  end.

createnodes(N_Nodes, Table, M, N_Requests) ->
    if
        N_Nodes =:= 1 ->
        Hash=[{binary:decode_unsigned(crypto:hash(sha256,integer_to_list(N_Nodes))) rem round(math:pow(2,M)), spawn(chord, chord_node, [0,0,M,0,N_Requests])}],
        io:format("Nodes Created!~n"),
        lists:append(Table,Hash);
        true ->
        Hash=[{binary:decode_unsigned(crypto:hash(sha256,integer_to_list(N_Nodes))) rem round(math:pow(2,M)), spawn(chord, chord_node, [0,0,M,0,N_Requests])}],
        T=lists:append(Table,Hash),
        createnodes(N_Nodes-1,T,M,N_Requests)
    end.

closest_node(X,I,Diff,Hash,List) ->
  T=round(math:pow(2,1000)),
  if
    I>length(List) ->
      {notfound, Hash};
    true ->
      {D,_} = lists:nth(I,List),
      if
        X =:= D ->
          {found, I};
        I=:= 1, X-D>0->
          closest_node(X,I+1,X-D,I,List);
        I=:= 1 ->
          closest_node(X,I+1,Diff,I,List);
        X-D >0, X-D<Diff ->
          closest_node(X,I+1,X-D,I,List);
        X-D<0, X+T-D<Diff ->
          closest_node(X,I+1,X+T-D,I,List);
        true ->
          closest_node(X,I+1,Diff,Hash,List)
      end
  end.

terminate(Msg, Hops, Fin_Nodes, N_Nodes,Table) ->
  receive
    {messagefinished, Hop} ->
      terminate(Msg+1,Hops+Hop,Fin_Nodes,N_Nodes,Table);
    {nodefinished} ->
    %   io:format("~n~p~n",[N_Nodes-Fin_Nodes]),
      finished,
      if
        Fin_Nodes+1>=N_Nodes ->
          io:format("~nFinished. Requests sent by all nodes. ~nAverage Hops:~p~n",[Hops/Msg]),
          ets:delete(tab),
          lists:foreach(fun(N) -> {_,PID} = lists:nth(N,Table), PID ! {stop} end, lists:seq(1,N_Nodes));
        true ->
          terminate(Msg, Hops, Fin_Nodes+1, N_Nodes,Table)
      end
  end.

fix_fingers(Table, M, I) ->
  {K,PID}=lists:nth(I,Table),
  T=finger_table([],M,K,1),
%   io:format("~n~p~n",[T]),
  PID ! {updatetable,T},
  if
    I>=length(Table) ->
      ok;
    true ->
      fix_fingers(Table,M,I+1)
  end.

finger_table(Table, M, N, I) ->
  H=ets:member(tab,N+round(math:pow(2,I-1)) rem round(math:pow(2,M))),
  K=N+math:pow(2,I-1),
  O=ets:last(tab),
  if
    K>O ->
      F=K-O+ets:first(tab),
      OP=ets:member(tab,F+round(math:pow(2,I-1)) rem round(math:pow(2,M))),
      if
        OP =:= false ->
          T=ets:next(tab,F+round(math:pow(2.0,I-1)) rem round(math:pow(2,M)));
        true ->
          T=ets:lookup(tab,F+round(math:pow(2.0,I-1))rem round(math:pow(2,M)))
      end;
    H =:= false ->
      T=ets:next(tab,N+round(math:pow(2.0,I-1)) rem round(math:pow(2,M)));
    true ->
      T=ets:lookup(tab,N+round(math:pow(2.0,I-1))rem round(math:pow(2,M)))
  end,
  Tabl=lists:append(Table,ets:lookup(tab,T)),
  if
    I =:= M ->
      Tabl;
    true ->
      finger_table(Tabl,M,N,I+1)
  end.

% test message
test() ->

  L1=[{0,"Hello"}],
  L2 = lists:append(L1, [{5,"J"}]),
  L3 = lists:append(L2, [{3,"K"}]),
  lists:sort(L3).
