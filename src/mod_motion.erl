%%%------------------------------------------------------------------- 
%%% File    : mod_motion.erl
%%% Author  : Adam Hayward <adam [at] happy [dot] cat>
%%% Purpose : Redirect stanzas to a web service and sends the HTTP 
%%%           response back to sender.
%%% Created : January 2010
%%% Version : 0.1
%%% Purpose : Allows you to handle messages, presence and iqs with
%%%           a web service backend. I called it 'mod_motion' because
%%%           it's the opposite of 'mod_rest' and it sounds better than
%%%           'mod_tser'. mod_rest allows you to post stanzas to 
%%%           ejabberd, while mod_motion posts stanzas received by 
%%%           ejabberd to a restful webservice.
%%% TODO    : Maybe we should define different handlers for 1XX, 4XX & 
%%%           5XX status codes.
%%% Credits : Inspired by Anders Conbere's echo_bot.erl
%%%           http://anders.conbere.org/media/code/echo_bot.erl
%%% 
%%% Copyright (c) 2010, Adam Hayward
%%% All rights reserved.
%%%
%%% Redistribution and use in source and binary forms, with or 
%%% without modification, are permitted provided that the following 
%%% conditions are met:
%%% 
%%% * Redistributions of source code must retain the above copyright 
%%%   notice, this list of conditions and the following disclaimer.
%%% * Redistributions in binary form must reproduce the above copyright 
%%%   notice, this list of conditions and the following disclaimer in the 
%%%   documentation and/or other materials provided with the distribution.
%%% * Neither the name of the author nor the names of its contributors 
%%%   may be used to endorse or promote products derived from this 
%%%   software without specific prior written permission.
%%%
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS 
%%% IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED 
%%% TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
%%% PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
%%% HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
%%% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
%%% LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
%%% DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
%%% THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
%%% (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
%%% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%%%----------------------------------------------------------------------

-module(mod_motion).
-behavior(gen_server).
-behavior(gen_mod).

-export([start_link/2]).

-export([start/2,
         stop/1,
         init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-export([route/3]).

-include("ejabberd.hrl").
-include("jlib.hrl").

-define(PROCNAME,   ejabberd_mod_motion).
-define(BOTNAME,    mod_motion_bot).
-define(BASE_URL,   "http://127.0.0.1:7645/").
-define(USER_AGENT, "ejabberd mod_motion / 0.1").

start_link(Host, Opts) ->
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:start_link({local, Proc}, ?MODULE, [Host, Opts], []).

start(Host, Opts) ->
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    ChildSpec = {Proc,
        {?MODULE, start_link, [Host, Opts]},
        temporary,
        1000,
        worker,
        [?MODULE]},
    supervisor:start_child(ejabberd_sup, ChildSpec).

stop(Host) ->
    Proc = gen_mod:get_module_proc(Host, ?PROCNAME),
    gen_server:call(Proc, stop),
    ?INFO_MSG("MOD_MOTION: Stopping mod_motion", []),
    supervisor:terminate_child(ejabberd_sup, Proc),
    supervisor:delete_child(ejabberd_sup, Proc).

init([Host, Opts]) ->
    HostName = gen_mod:get_opt(host, Opts, "motion.@HOST@"),
    MyHost   = gen_mod:get_opt_host(Host, Opts, HostName),
    ?INFO_MSG("MOD_MOTION: Starting mod_motion on ~p", [MyHost]),
    ejabberd_router:register_route(MyHost, {apply, ?MODULE, route}),
    inets:start(),
    {ok, Host}.

handle_call(stop, _From, Host) ->
    {stop, normal, ok, Host}.

handle_cast(_Msg, Host) ->
    {noreply, Host}.

handle_info(_Msg, Host) ->
    {noreply, Host}.

terminate(_Reason, Host) ->
    ejabberd_router:unregister_route(Host),
    ok.

code_change(_OldVsn, Host, _Extra) ->
    {ok, Host}.

send_presence(From, To, "") ->
    ejabberd_router:route(From, To, {xmlelement, "presence", [], []});

send_presence(From, To, TypeStr) ->
    ejabberd_router:route(From, To, {xmlelement, "presence", [{"type", TypeStr}], []}).

echo(From, To, Body) ->
    send_message(From, To, "chat", Body).

rpc(Url, PostData) ->
    http:request(
        post, 
        {
            ?BASE_URL ++ Url,
            [{"User-Agent", ?USER_AGENT}],
            "application/x-www-form-urlencoded",
            PostData
        }, [], []).

send_message(From, To, TypeStr, BodyStr) ->
    XmlBody = {xmlelement, "message",
           [{"type", TypeStr},
        {"from", jlib:jid_to_string(From)},
        {"to", jlib:jid_to_string(To)}],
           [{xmlelement, "body", [],
         [{xmlcdata, BodyStr}]}]},
    ejabberd_router:route(From, To, XmlBody).

% strip_bom function courtesy of Anders Conbere
strip_bom([239,187,191|C]) -> C;
strip_bom(C) -> C.

post_encode({xmlelement, _Type, _Attrs, _Els} = Packet) -> 
    edoc_lib:escape_uri(lists:flatten(xml:element_to_string(Packet)));
post_encode(List) -> 
    edoc_lib:escape_uri(List).

presence_info({xmlelement, "presence", _, _} = Packet) ->
    Status      = xml:get_subtag_cdata(Packet, "status"),
    Show        = xml:get_subtag_cdata(Packet, "show"),
    Priority    = xml:get_subtag_cdata(Packet, "priority"),
    X           = xml:get_subtag(Packet, "x"),
    case X of
        false ->
            Photo = "";
        _ -> 
            Photo = xml:get_subtag_cdata(X, "photo")
    end,
    [Status, Show, Priority, Photo].

route(From, To, {xmlelement, "presence", _Attrs, _Els} = Packet) ->
    {jid,SenderName,SenderHost,_,_,_,_} = From,
    Jid = SenderName ++ "@" ++ SenderHost,
    [Status, Show, Priority, Photo] = presence_info(Packet),
    PostData = "status=" ++ edoc_lib:escape_uri(Status) 
               ++ "&show=" ++ post_encode(Show) 
               ++ "&priority=" ++ post_encode(Priority) 
               ++ "&photo=" ++ post_encode(Photo)
               ++ "&packet=" ++ post_encode(Packet),
    PresenceType = xml:get_tag_attr_s("type", Packet),
    case PresenceType of
        "subscribe" ->
            send_presence(To, From, "subscribe"),
            rpc("presence/subscribe/" ++ Jid, PostData);

        "subscribed" ->
            send_presence(To, From, "subscribed"),
            send_presence(To, From, ""),
            rpc("presence/subscribed/" ++ Jid, PostData);

        "unsubscribe" ->
            send_presence(To, From, "unsubscribed"),
            send_presence(To, From, "unsubscribe"),
            rpc("presence/unsubscribe/" ++ Jid, PostData);

        "unsubscribed" ->
            send_presence(To, From, "unsubscribed"),
            rpc("presence/unsubscribed/" ++ Jid, PostData);

        "" ->
            send_presence(To, From, ""),
            case Status of
                "" ->
                    rpc("presence/none/" ++ Jid, PostData);
                _ ->
                    rpc("presence/status/" ++ Jid, PostData)
            end;

        "unavailable" ->
            rpc("presence/unavailable/" ++ Jid, PostData);
        
        "probe" ->
            send_presence(To, From, ""),
            rpc("presence/probe/" ++ Jid, PostData);

        _Other ->
            rpc("presence/other/" ++ Jid, PostData)

    end,
    ok;

route(From, To, {xmlelement, "message", _Attrs, _Els} = Packet) ->
    {jid,SenderName,SenderHost,_,_,_,_} = From,
    Jid = SenderName ++ "@" ++ SenderHost,
    case xml:get_subtag_cdata(Packet, "body") of
        "" ->
            ok;
    
        Body ->
            case xml:get_tag_attr_s("type", Packet) of
            "error" ->
                ?ERROR_MSG("Received error message~n~p -> ~p~n~p", [From, To, Packet]);
            
            _ ->
                {jid,SenderName,SenderHost,_,_,_,_} = From,
                PostData = "msg=" ++  edoc_lib:escape_uri(Body),
                {ok, {{_, _Code, _Msg}, _, HtmlBody}} = rpc("message/" ++ Jid, PostData),
                echo(To, From, strip_bom(HtmlBody))
            end
    end,
    ok;

route(From, _To, {xmlelement, "iq", _Attrs, _Els} = Packet) ->
    {jid, SenderName, SenderHost,_,_,_,_} = From,
    Jid = SenderName ++ "@" ++ SenderHost,
    PostData = "packet=" ++ post_encode(Packet),
    {ok, {{_, _Code, _Msg}, _, _HtmlBody}} = rpc("iq/" ++ Jid, PostData),
    ok.

