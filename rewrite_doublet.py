#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

# WARNING: Not idempotent.

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  text = unicode(page.text)

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  if blib.page_should_be_ignored(pagetitle):
    pagemsg("WARNING: Page should be ignored")
    return None, None

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)

    if tn == "doublet":
      params = []
      for param in t.params:
        pname = unicode(param.name).strip()
        pval = unicode(param.value).strip()
        showkey = param.showkey
        if not pval:
          continue
        if pname == "3":
          pname = "alt1"
          showkey = True
        elif pname == "4":
          pname = "t1"
          showkey = True
        elif pname in ["t", "gloss", "tr", "ts", "pos", "lit", "alt", "sc",
            "id", "g"]:
          pname = pname + "1"
        elif pname in ["1", "2", "notext", "nocap", "nocat"]:
          pass
        else:
          pagemsg("WARNING: Unrecognized param %s=%s in %s, skipping" %
              (pname, pval, origt))
          break
        params.append((pname, pval, showkey))
      else: # No break
        # Erase all params.
        del t.params[:]
        # Put back new params.
        for pname, pval, showkey in params:
          t.add(pname, pval, showkey=showkey, preserve_spacing=False)
        if origt != unicode(t):
          pagemsg("Replaced %s with %s" % (origt, unicode(t)))
          notes.append("restructure {{doublet}} for new syntax")

  return unicode(parsed), notes

parser = blib.create_argparser("Rewrite 'doublet' to use multiple-term syntax")
parser.add_argument('--pagefile', help="File containing pages to search.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.pagefile:
  lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
  for index, page in blib.iter_items(lines, start, end):
    blib.do_edit(pywikibot.Page(site, page), index, process_page,
        save=args.save, verbose=args.verbose)
else:
  for i, page in blib.references("Template:doublet", start, end):
    blib.do_edit(page, i, process_page, save=args.save,
        verbose=args.verbose)
