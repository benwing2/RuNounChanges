#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Convert Japanese headwords from old-style to new-style. We look at
# ja-noun, ja-adj, ja-verb and ja-pos.
#
# 1. If the first parameter is one of 'r', 'h', 'ka', 'k', 's', 'ky' or 'kk',
#    remove it and move the other numbered parameters down one.
# 2. Convert hira= and kata= to numbered parameters -- make them the first
#    empty numbered param.
# 3. If rom= is present and the page isn't in
#    [[:Category:Japanese terms with romaji needing attention]], remove rom=.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose, romaji_to_keep):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname in ["ja-noun", "ja-adj", "ja-verb", "ja-pos"]:
      origt = unicode(t)

      # Remove old script code
      p1 = getparam(t, "1")
      if p1 in ["r", "h", "ka", "k", "s", "ky", "kk"]:
        pagemsg("Removing 1=%s: %s" % (p1, unicode(t)))
        notes.append("remove 1=%s from %s" % (p1, tname))
        rmparam(t, "1")
        for param in t.params:
          pname = unicode(param.name)
          if re.search(r"^[0-9]+$", pname):
            param.name = str(int(pname) - 1)
            param.showkey = False

      # Convert hira= and/or kata= to numbered param. The complexity is
      # from ensuring that the numbered params always go before the
      # non-numbered ones.
      if t.has("hira") or t.has("kata"):
        # Fetch the numbered and non-numbered params, skipping blank
        # numbered ones and converting hira and kata to numbered
        numbered_params = []
        non_numbered_params = []
        for param in t.params:
          pname = unicode(param.name)
          if re.search(r"^[0-9]+$", pname):
            val = unicode(param.value)
            if val:
              numbered_params.append(val)
          elif pname not in ["hira", "kata"]:
            non_numbered_params.append((pname, param.value))
        hira = getparam(t, "hira")
        if hira:
          numbered_params.append(hira)
          pagemsg("Moving hira=%s to %s=: %s" % (hira, len(numbered_params),
            unicode(t)))
          notes.append("move hira= to %s= in %s" % (len(numbered_params),
            tname))
        kata = getparam(t, "kata")
        if kata:
          numbered_params.append(kata)
          pagemsg("Moving kata=%s to %s=: %s" % (kata, len(numbered_params),
            unicode(t)))
          notes.append("move kata= to %s= in %s" % (len(numbered_params),
            tname))
        del t.params[:]
        # Put back numbered params, then non-numbered params.
        for i, param in enumerate(numbered_params):
          t.add(str(i+1), param)
        for name, value in non_numbered_params:
          t.add(name, value)

      # Remove rom= if not in list of pages to keep rom=
      if t.has("rom"):
        if pagetitle in romaji_to_keep:
          pagemsg("Keeping rom=%s because in romaji_to_keep: %s" % (
            getparam(t, "rom"), unicode(t)))
        else:
          pagemsg("Removing rom=%s: %s" % (getparam(t, "rom"), unicode(t)))
          rmparam(t, "rom")
          notes.append("remove rom= from %s" % tname)

      newt = unicode(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))

  new_text = unicode(parsed)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, new_text))
    assert notes
    comment = "; ".join(blib.group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Convert Japanese headwords from old-style to new-style")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

romaji_to_keep = set()
for i, page in blib.cat_articles("Japanese terms with romaji needing attention"):
  pagetitle = unicode(page.title())
  romaji_to_keep.add(pagetitle)

for ref in ["ja-noun", "ja-adj", "ja-verb", "ja-pos"]:
  msg("Processing references to Template:%s" % ref)
  for i, page in blib.references("Template:%s" % ref, start, end):
    process_page(i, page, args.save, args.verbose, romaji_to_keep)
