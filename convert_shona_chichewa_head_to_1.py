#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

templates = {
  "ny-noun": "ny-noun/new",
  "ny-proper noun": "ny-proper noun/new",
  "ny-verb": "ny-verb/new",
  "sn-noun": "sn-noun/new",
}

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn in templates:
      head = getparam(t, "head") or getparam(t, "h")
      rmparam(t, "head")
      rmparam(t, "h")
      # Fetch all params.
      params = []
      for param in t.params:
        pname = str(param.name)
        params.append((pname, param.value, param.showkey))
      # Erase all params.
      del t.params[:]
      t.add("1", head)
      # Put remaining parameters in order.
      for name, value, showkey in params:
        if re.search("^[0-9]+$", name):
          t.add(str(int(name) + 1), value, showkey=showkey, preserve_spacing=False)
        else:
          t.add(name, value, showkey=showkey, preserve_spacing=False)
      notes.append("move head/h= to 1= in {{%s}}" % tn)
      blib.set_template_name(t, templates[tn])
      notes.append("rename {{%s}} to {{%s}}" % (tn, templates[tn]))

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Move head/h= to 1= and rename Chichewa/Shona templates", include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
    default_refs=["Template:%s" % template for template in templates],
)
