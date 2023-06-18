#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname


def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "cs-imperfective form of":
      # Fetch all params.
      params = []
      for param in t.params:
        pname = str(param.name)
        if pname.strip() != "lang":
          params.append((pname, param.value, param.showkey))
      # Erase all params.
      del t.params[:]
      t.add("1", "cs")
      # Put remaining parameters in order.
      for name, value, showkey in params:
        if re.search("^[0-9]+$", name):
          t.add(str(int(name) + 1), value, showkey=showkey, preserve_spacing=False)
        else:
          t.add(name, value, showkey=showkey, preserve_spacing=False)
      blib.set_template_name(t, "imperfective form of")
      notes.append("rename {{cs-imperfective form of}} to {{imperfective form of|cs}}")

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Rename {{cs-imperfective form of}} to {{imperfective form of|cs}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in ["cs-imperfective form of"]:
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
