#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    newarg1 = None
    if tn == "de-conj":
      generate_template = re.sub(r"^\{\{de-conj(?=[|}])", "{{User:Benwing2/de-generate-verb-props", str(t))
      result = expand_text(generate_template)
      if not result:
        continue
      forms = blib.split_generate_args(result)
      pagemsg("For %s, class=%s" % (str(t), forms["class"]))

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert German verb headwords to use new {{de-verb}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_refs=["Template:de-conj"], edit=True, stdin=True)
