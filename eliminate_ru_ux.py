#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Convert ru-ux to ux|ru or uxi|ru (depending on whether inline= is present).
# In the process, convert sub= to subst=. Don't convert if one of the
# special-purpose params noadj=, noshto=, adj= or shto= is present (the
# latter two are obsolete).

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []
  for t in parsed.filter_templates():
    if str(t.name) == "ru-ux":
      origt = str(t)
      if t.has("noadj") or t.has("noshto"):
        pagemsg("WARNING: Can't convert %s, has noadj= or noshto=" % origt)
      elif t.has("adj") or t.has("shto"):
        pagemsg("WARNING: Can't convert %s, has adj= or shto=" % origt)
      else:
        tname = "ux"
        new_params = []
        for param in t.params:
          pname = str(param.name)
          pval = str(param.value)
          if pname == "inline":
            if pval and pval not in ["0", "n", "no", "false"]:
              tname = "uxi"
          elif re.search(r"^[0-9]+$", pname):
            # move numbered params up by one
            new_params.append((str(1 + int(pname)), param.value))
          elif pname == "sub":
            new_params.append(("subst", param.value))
          else:
            new_params.append((pname, param.value))
        del t.params[:]
        t.name = tname
        t.add("1", "ru")
        for pname, pval in new_params:
          t.add(pname, pval)
        notes.append("Replace {{ru-ux}} with {{%s|ru}}" % tname)
      newt = str(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))

  return parsed, notes

parser = blib.create_argparser(u"Convert {{ru-ux}} to {{ux|ru}} or {{uxi|ru}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.references("Template:ru-ux", start, end):
  blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
