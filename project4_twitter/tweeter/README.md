tweeter

`rebar3 shell --name user1@10.20.63.42 --setcookie aditya` in one shell
`tweeter_server:initServer().`

In User  shell(s) 
`rebar3 shell --name user1@10.20.63.42 --setcookie aditya`
`net_adm:ping('server@10.20.63.42').`
`S = rpc:call('server@10.20.63.42', erlang, whereis, [server]).`
`S! {self(), {login, "user 1"}}.`

To login/register
`S! {self(), {register/login , "haddle"}}`

To tweet
`S! {self(), {tweet , "xyz"}}`