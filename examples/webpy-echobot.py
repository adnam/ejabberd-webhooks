#!/usr/bin/env python
# -*- coding: utf-8 -*-
""" Echobot example for demostrating ejabberd mod_motion
    Copyright 2010 Adam Hayward <adam at happy dot cat>
"""

import os, sys, re
try:
    import web
except ImportError:
    print "Echobot depends on webpy; download it from webpy.org"
    exit()

urls = (
    '/',                    'IndexController',
    '/presence/(.*)/(.*)',  'PresenceController',
    '/message/(.*)',        'MessageController',
    '/iq/(.*)',             'IqController',
    )

class IndexController:
    def GET(self):
        return "Chattly backend rpc server"
    
class PresenceController:
    def GET(self, type, jid):
        return ""
    
    def POST(self, type, jid):
        i = web.input(show="", status="", photo="")
        print i
        return ""

class MessageController:
    def GET(self, jid):
        return ""
    
    def POST(self, jid):
        i = web.input(msg='')
        return i.msg.strip()

class IqController:
    def GET(self, jid):
        return ""
    
    def POST(self, jid):
        return ""
        
def main():
    if len(sys.argv) < 2:
        sys.argv.append('127.0.0.1:8080')
    os.chdir(os.path.dirname(__file__))
    web.config.debug = True
    app = web.application(urls, globals())
    app.run()

if __name__ == '__main__':
    main()

