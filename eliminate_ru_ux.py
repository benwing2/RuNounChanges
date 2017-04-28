#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Convert ru-ux to ux|ru or uxi|ru (depending on whether inline= is present).
# In the process, convert sub= to subst=. Don't convert if one of the
# special-purpose params noadj=, noshto=, adj= or shto= is present (the
# latter two are obsolete).

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru
import runounlib as runoun

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    if unicode(t.name) == "ru-ux":
      origt = unicode(t)
      if t.has("noadj") or t.has("noshto"):
        pagemsg("WARNING: Can't convert %s, has noadj= or noshto=" % origt)
      elif t.has("adj") or t.has("shto"):
        pagemsg("WARNING: Can't convert %s, has adj= or shto=" % origt)
      else:
        tname = "ux"
        new_params = []
        for param in t.params:
          pname = unicode(param.name)
          pval = unicode(param.value)
          if pname == "inline":
            if pval and pval not in ["0", "n", "no"]:
              tname = "uxi"
          elif re.search(r"^[0-9]+$", pname):
            # move numbered params up by one
            new_params.append((str(1 + int(pname)), param.value))
          elif pname == "sub":
            new_params.append(("subst", param.value))
          else:
            new_params.append((pname, param.value))
        del t.params[:]
        t.add(tname)
        t.add("ru")
        for pname, pval in new_params:
          t.add(pname, pval)
      newt = unicode(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))

  new_text = unicode(parsed)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, new_text))
    assert notes
    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Convert {{ru-ux}} to {{ux|ru}} or {{uxi|ru}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.references("Template:ru-ux", start, end):
  process_page(i, page, args.save, args.verbose)
