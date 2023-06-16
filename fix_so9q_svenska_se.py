#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Convert:
# {{R:SAOL}} → {{R:svenska.se|saol}}
# {{R:SO}} → {{R:svenska.se|so}}
# {{R:SAOB online}} → {{R:svenska.se|saob}}

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []
  for t in parsed.filter_templates():
    tn = tname(t)
    param1 = None
    if tn == "R:SAOL":
      param1 = "saol"
    elif tn == "R:SO":
      param1 = "so"
    elif tn == "R:SAOB online":
      param1 = "saob"
    if param1:
      origt = str(t)
      rmparam(t, "2")
      # Fetch all params.
      params = []
      for param in t.params:
        pname = str(param.name)
        if re.search("^[0-9]+$", pname.strip()):
          params.append((str(1 + int(pname.strip())), param.value, param.showkey))
        else:
          params.append((pname, param.value, param.showkey))
      # Erase all params.
      del t.params[:]
      t.add("1", param1)
      # Put back params in order.
      for name, value, showkey in params:
        t.add(name, value, showkey=showkey, preserve_spacing=False)
      blib.set_template_name(t, "R:svenska.se")
      notes.append("replace {{%s}} with {{R:svenska.se|%s}}" % (tn, param1))
      newt = str(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))

  return parsed, notes

parser = blib.create_argparser(u"Convert {{R:SAOL}}, {{R:SO}}, {{R:SAOB online}} to {{R:svenska.se}}",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:R:SAOL", "Template:R:SO", "Template:R:SAOB online"])
