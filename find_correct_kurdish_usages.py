#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname

arabic_charset = u"؀-ۿݐ-ݿࢠ-ࣿﭐ-﷽ﹰ-ﻼ"

def process_text_on_page(index, pagename, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  templates_seen = {}
  templates_changed = {}

  def process_param(pagetitle, index, parsed, t, tlang, param, trparam):
    if type(param) is list:
      pagemsg("WARNING: Skipping param %s referencing page title: %s" % (param, unicode(t)))
      return
    if args.find:
      pagemsg("Found %s" % unicode(t))
      return
    pval = getparam(t, param)
    if not pval or pval == "-":
      pagemsg("Leaving as ku: %s" % unicode(t))
      return
    origt = unicode(t)
    if re.search("[%s]" % arabic_charset, getparam(t, param)):
      if getparam(t, "1") != "ku":
        pagemsg("WARNING: 1=%s not ku, don't know how to change language: %s" % (getparam(t, "1"), unicode(t)))
        return
      t.add("1", "ckb")
      pagemsg("Replaced %s with %s" % (origt, unicode(t)))
      return ["convert {{%s|ku}} to lang ckb based on Arabic script in param" % tname(t)]
    if getparam(t, "1") != "ku":
      pagemsg("WARNING: 1=%s not ku, don't know how to change language: %s" % (getparam(t, "1"), unicode(t)))
      return
    t.add("1", "kmr")
    pagemsg("Replaced %s with %s" % (origt, unicode(t)))
    return ["convert {{%s|ku}} to lang kmr based on Latin script in param" % tname(t)]

  return blib.process_one_page_links(pagename, index, text, process_param,
      ['ku'], templates_seen, templates_changed, split_templates=None)

parser = blib.create_argparser("Find or correct usages of language code 'ku'", include_pagefile=True,
    include_stdin=True)
parser.add_argument("--find", action="store_true", help="Find usages only")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
