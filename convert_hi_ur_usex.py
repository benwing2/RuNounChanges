#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Convert {{hi-usex}}/{{hi-x}} and {{ur-x}} to {{uxa}} (auto-inline), or sometimes {{ux}} or {{uxi}}.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, pagetext):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []
  parsed = blib.parse_text(pagetext)
  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    if tn in ["hi-x", "hi-usex", "ur-x"]:
      lang = tn == "ur-x" and "ur" or "hi"
      #numbered_params = []
      #numbered_params.append(lang)
      #param1 = getp("1")
      #param2 = getp("2")
      #numbered_params.append(param1)
      named_params = []
      #if param2:
      #  numbered_params.append(param2)
      newname = "uxa"
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn == "1":
          pn = "2"
        elif pn == "2":
          pn = "3"
        elif pn == "noinline":
          if pv.lower() in ["1", "y", "yes", "true", "t", "on"]:
            newname = "ux"
          elif pv.lower() in ["0", "n", "no", "false", "f", "off"]:
            newname = "uxi"
          continue
        named_params.append((pn, pv))
      origt = str(t)
      del t.params[:]
      t.add("1", lang)
      for k, v in named_params:
        t.add(k, v, preserve_spacing=False)
      blib.set_template_name(t, newname)
      newt = str(t)
      if origt != newt:
        pagemsg("Replace %s with %s" % (origt, newt))
        notes.append("convert {{%s}} to {{%s|%s}}" % (tn, newname, lang))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{hi-x}}/{{hi-usex}} and {{ur-x}} to {{uxa}}/{{ux}}/{{uxi}}",
                               include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
                           default_refs=["Template:hi-usex", "Template:ur-x"])
