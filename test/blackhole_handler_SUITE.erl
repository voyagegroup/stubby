-module(blackhole_handler_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

init_per_suite(Config) ->
    Url = stubby:start() ++ "/blackhole/",
    [{url, Url} | Config].

end_per_suite(_) ->
    ok = stubby:stop(),
    ok.

all() ->
    [
     request_plain_test,
     request_gzip_test,
     slow_request_awaits_test
    ].

request_plain_test(Config) ->
    Url = ?config(url, Config),
    Body = <<"Hello in plain text">>,
    {ok, {
       {"HTTP/1.1", 204, _},
       _,
       _
      }} = httpc:request(
             post,
             {Url, [], "text/plain", Body},
             [],
             []
            ),
    ?assertEqual({ok, Body}, stubby:get_recent()).

request_gzip_test(Config) ->
    Url = ?config(url, Config),
    Body = <<"Hello in gzipped text">>,
    {ok, {
       {"HTTP/1.1", 204, _},
       _,
       _
      }} = httpc:request(
             post,
             {Url, [{"content-encoding", "gzip"}], "text/plain", zlib:gzip(Body)},
             [],
             []
            ),
    ?assertEqual({ok, Body}, stubby:get_recent()).

slow_request_awaits_test(Config) ->
    Url = ?config(url, Config),
    Reqs = [
            {<<"slow req after 100 ms">>, 100},
            {<<"fast req after 10 ms">>, 10}
           ],
    [
     spawn(fun() ->
                   timer:sleep(Time),
                   httpc:request(
                     post,
                     {Url, [], "text/plain", Body},
                     [],
                     []
                    )
           end)
     || {Body, Time} <- Reqs
    ],
    ?assertEqual([
                  {ok, <<"fast req after 10 ms">>},
                  {ok, <<"slow req after 100 ms">>}
                 ],
                 [
                  stubby:get_recent(),
                  stubby:get_recent()
                 ]).
