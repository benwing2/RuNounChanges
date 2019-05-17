#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("WARNING: Script no longer applies and would need fixing up")
  return

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = unicode(t)
    tname = unicode(t.name)
    if tname.startswith("ru-conj-") and tname != "ru-conj-verb-see":
      m = re.search("^ru-conj-(.*)$", tname)
      t.name = "ru-conj"
      conjtype = m.group(1)
      varargno = None
      variant = None
      if conjtype in ["3oa", "4a", "4b", "4c", "6a", "6c", "11a", "16a", "16b", u"irreg-дать", u"irreg-клясть", u"irreg-быть"]:
        varargno = 3
      elif conjtype in ["5a", "5b", "5c", "6b", "9a", "9b", "11b", "14a", "14b", "14c"]:
        varargno = 4
      elif conjtype in ["7b"]:
        varargno = 5
      elif conjtype in ["7a"]:
        varargno = 6
      if varargno:
        variant = getparam(t, str(varargno))
        if re.search("^[abc]", variant):
          variant = "/" + variant
        if getparam(t, str(varargno + 1)) or getparam(t, str(varargno + 2)) or getparam(t, str(varargno + 3)):
          t.add(str(varargno), "")
        else:
          rmparam(t, str(varargno))
        conjtype = conjtype + variant
      notes.append("ru-conj-* -> ru-conj, moving params up by one%s" %
          (variant and " (and move variant spec)" or ""))
      seenval = False
      for i in xrange(20, 0, -1):
        val = getparam(t, str(i))
        if val:
          seenval = True
        if seenval:
          t.add(str(i + 1), val)
      t.add("1", conjtype)
      blib.sort_params(t)
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

parser = blib.create_argparser(u"Convert ru-conj-* to ru-conj and move variant")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.cat_articles("Russian verbs", start, end):
  process_page(i, page, args.save, args.verbose)
