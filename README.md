Webhooks for ejabberd
=====================

mod_motion - Post stanzas to a restful web service, forward response to sender

Author: Adam Hayward <adam - at - happy - dot - cat>
Copyright (C) 2010 Adam Hayward, all rights reserved

CONFIGURATION
=============

in /etc/ejabberd/ejabberd.cfg :

    {modules,
     [
      %% ....
      {mod_motion,  []},
      %% ....
     ]}

in mod_motion.erl:

    -define(BASE_URL,   "http://example.com:portnum/").
    
BUILD ERLANG AND GET SOURCE
===========================

    $ sudo apt-get install erlang-base erlang-nox erlang-dev \
        build-essential libssl-dev libexpat1-dev
    $ mkdir -p ~/src/ejabberd
    $ svn co https://svn.process-one.net/ejabberd/trunk ~/src/ejabberd/


BUILD MODULE
============

    $ erlc -I ~/src/ejabberd/src/ \
        -pa ~/src/ejabberd/src/ \
        -I ~/src/ejabberd/src/web/ \
        mod_motion.erl

INSTALL MODULE
==============
    $ sudo ln -s -t /usr/lib/ejabberd/ebin/ `pwd -P`/mod_motion.beam

