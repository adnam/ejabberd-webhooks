#!/bin/bash

EJABBERD_SRC=~/src/ejabberd/src/
MODULE=mod_motion
rm -f ${MODULE}.beam
erlc -I ${EJABBERD_SRC} -pa ${EJABBERD_SRC} -I ${EJABBERD_SRC}web/ `dirname $0`/src/${MODULE}.erl
    ln -f -s -t /usr/lib/ejabberd/ebin/ `pwd -P`/${MODULE}.beam
ejabberdctl restart

