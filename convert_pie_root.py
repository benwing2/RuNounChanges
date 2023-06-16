#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "PIE root":
      if not getparam(t, "2"):
        pagemsg("WARNING: Something wrong, no 2=: %s" % str(t))
        continue
      blib.set_template_name(t, "root")
      newparams = []
      for param in t.params:
        pn = pname(param)
        if re.search("^[0-9]+$", pn) and int(pn) >= 2:
          if pn == "2":
            newparams.append(("2", "ine-pro"))
          pv = str(param.value)
          if not pv.startswith("*"):
            pv = "*" + pv
          if not pv.endswith("-"):
            pv = pv + "-"
          newparams.append((str(int(pn) + 1), pv))
        else:
          newparams.append((str(param.name), str(param.value)))
      del t.params[:]
      for name, value in newparams:
        t.add(name, value, preserve_spacing=False)
      notes.append("convert {{%s}} to {{root|...|ine-pro}}" % tn)

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{PIE root}} to {{root|...|ine-pro}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:PIE root"], edit=True, stdin=True)
