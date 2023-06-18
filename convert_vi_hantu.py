#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

def one_char(t):
  return len(t) == 1 or len(t) == 2 and 0xD800 <= ord(t[0]) <= 0xDBFF

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  global args

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "vi-hantu":
      if not one_char(pagetitle):
        pagemsg("WARNING: Length of page title is %s > 1, skipping" % len(pagetitle))
        continue
      if getparam(t, "pos"):
        pagemsg("WARNING: Saw pos=, skipping: %s" % str(t))
        continue
      chu = getparam(t, "chu")
      if chu and chu != "Nom":
        pagemsg("WARNING: Saw chu=%s not 'Nom', skipping: %s" % (chu, str(t)))
        continue
      if chu == "Nom":
        newparam = "nom"
      else:
        newparam = "reading"
      reading = blib.remove_links(getparam(t, "1"))
      if not reading:
        pagemsg("WARNING: Empty reading, skipping: %s" % str(t))
        continue
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "rs", "chu"]:
          pagemsg("WARNING: Unrecognized parameter %s=%s, skipping: %s" % (pn, str(param.value), str(t)))
          must_continue = True
          break
      if must_continue:
        continue
      t.add(newparam, reading, before="1")
      rmparam(t, "1")
      blib.set_template_name(t, "vi-readings")
      notes.append("{{vi-hantu}} -> {{vi-readings}}")

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{vi-hantu}} to {{vi-readings}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_refs=["Template:vi-hantu"], edit=True, stdin=True)
