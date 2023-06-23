#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib

parser = blib.create_argparser("Login to sysop or no-sysop")
#parser.add_argument('--sysop', help="Login to sysop", action="store_true")
args = parser.parse_args()

#pywikibot.Site().login(sysop=args.sysop)
pywikibot.Site().login()
