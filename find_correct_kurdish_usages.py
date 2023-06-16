#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site, tname

arabic_charset = u"؀-ۿݐ-ݿࢠ-ࣿﭐ-﷽ﹰ-ﻼ"

templates_seen = {}
templates_changed = {}

def process_text_on_page(index, pagename, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  def process_param(obj):
    t = obj.template
    if type(obj.param) is list:
      pagemsg("WARNING: Skipping param %s referencing page title: %s" % (obj.param, str(t)))
      return
    if args.find:
      pagemsg("Found %s" % str(t))
      return
    if obj.notforeign:
      pagemsg("WARNING: Skipping template with not-foreign text, needs manual review: %s" % str(t))
      return
    pval = getparam(t, obj.param)
    if not pval or pval == "-":
      pagemsg("Leaving as ku: %s" % str(t))
      return
    origt = str(t)
    lpar = obj.langparam
    if re.search("[%s]" % arabic_charset, getparam(t, obj.param)):
      if getparam(t, lpar) != "ku":
        pagemsg("WARNING: %s=%s not ku, don't know how to change language: %s" % (lpar, getparam(t, lpar), str(t)))
        return
      t.add(lpar, "ckb")
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      return ["convert {{%s|ku}} to lang ckb based on Arabic script in param" % tname(t)]
    if getparam(t, lpar) != "ku":
      pagemsg("WARNING: %s=%s not ku, don't know how to change language: %s" % (lpar, getparam(t, lpar), str(t)))
      return
    t.add(lpar, "kmr")
    pagemsg("Replaced %s with %s" % (origt, str(t)))
    return ["convert {{%s|ku}} to lang kmr based on Latin script in param" % tname(t)]

  return blib.process_one_page_links(index, pagename, text, ['ku'], process_param,
      templates_seen, templates_changed, include_notforeign=True)

parser = blib.create_argparser("Find or correct usages of language code 'ku'", include_pagefile=True,
    include_stdin=True)
parser.add_argument("--find", action="store_true", help="Find usages only")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
blib.output_process_links_template_counts(templates_seen, templates_changed)
