#!/usr/bin/env python
#coding: utf-8

#    fix_fr_adj.py is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Remove unnecessary fr-adj parameters.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  text = unicode(page.text)

  notes = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = unicode(t)
    name = unicode(t.name)
    if unicode(t.name) == "fr-adj":
      g = getparam(t, "1")
      if g and g != "mf":
        pagemsg("WARNING: Strange value 1=%s: %s" % (g, unicode(t)))
      inv = getparam(t, "inv")
      if inv:
        if inv not in ["y", "yes", "1"]:
          pagemsg("WARNING: Strange value inv=%s: %s" % (inv, unicode(t)))
        if (getparam(t, "1") or getparam(t, "f") or
            getparam(t, "mp") or getparam(t, "fp") or getparam(t, "p")):
          pagemsg("WARNING: Found extraneous params with inv=: %s" %
              unicode(t))
        continue
      if (getparam(t, "f2") or getparam(t, "mp2") or getparam(t, "fp2")
          or getparam(t, "p2")):
        pagemsg("Skipping multiple feminines or plurals: %s" % unicode(t))
        continue
      expected_mp = (pagetitle if re.search("[sx]$", pagetitle)
          else re.sub("al$", "aux", pagetitle) if pagetitle.endswith("al")
          else pagetitle + "s")
      if getparam(t, "mp") == expected_mp:
        rmparam(t, "mp")
        notes.append("remove redundant mp=")
      expected_fem = (pagetitle if pagetitle.endswith("e")
          else pagetitle + "ne" if pagetitle.endswith("en")
          else re.sub("er$", u"ère", pagetitle) if pagetitle.endswith("er")
          else pagetitle + "e")
      if re.search("(el|on|et|eur|eux|if|c)$", pagetitle) and not getparam(t, "f"):
        pagemsg("WARNING: Found suffix -el/-on/-et/-eur/-eux/-if/-c and no f=: %s" % unicode(t))
      new_expected_fem = (pagetitle if pagetitle.endswith("e")
          else pagetitle + "ne" if pagetitle.endswith("en")
          else re.sub("er$", u"ère", pagetitle) if pagetitle.endswith("er")
          else pagetitle + "le" if pagetitle.endswith("el")
          else pagetitle + "ne" if pagetitle.endswith("on")
          else pagetitle + "te" if pagetitle.endswith("et")
          else re.sub("teur$", "trice", pagetitle) if pagetitle.endswith("teur")
          else re.sub("eur$", "euse", pagetitle) if pagetitle.endswith("eur")
          else re.sub("eux$", "euse", pagetitle) if pagetitle.endswith("eux")
          else re.sub("if$", "ive", pagetitle) if pagetitle.endswith("if")
          else re.sub("c$", "que", pagetitle) if pagetitle.endswith("c")
          else pagetitle + "e")
      if getparam(t, "f") == expected_fem:
        rmparam(t, "f")
        notes.append("remove redundant f=")
      fem = getparam(t, "f") or expected_fem
      if not fem.endswith("e"):
        if not getparam(t, "fp"):
          pagemsg("WARNING: Found f=%s not ending with -e and no fp=: %s" %
              (fem, unicode(t)))
        continue
      expected_fp = fem + "s"
      if getparam(t, "fp") == expected_fp:
        rmparam(t, "fp")
        notes.append("remove redundant fp=")
      if getparam(t, "fp") and not getparam(t, "f"):
        pagemsg("WARNING: Found fp=%s and no f=: %s" % (getparam(t, "fp"),
          unicode(t)))
        continue
      if getparam(t, "fp") == fem:
        pagemsg("WARNING: Found fp=%s same as fem=%s: %s" % (getparam(t, "fp"),
          fem, unicode(t)))
        continue
      if pagetitle.endswith("e") and not getparam(t, "f") and not getparam(t, "fp"):
        if g == "mf":
          rmparam(t, "1")
          notes.append("remove redundant 1=mf")
        g = "mf"
      if g == "mf":
        f = getparam(t, "f")
        if f:
          pagemsg("WARNING: Found f=%s and 1=mf: %s" % (f, unicode(t)))
        mp = getparam(t, "mp")
        if mp:
          pagemsg("WARNING: Found mp=%s and 1=mf: %s" % (mp, unicode(t)))
        fp = getparam(t, "fp")
        if fp:
          pagemsg("WARNING: Found fp=%s and 1=mf: %s" % (fp, unicode(t)))
        if f or mp or fp:
          continue
        expected_p = (pagetitle if re.search("[sx]$", pagetitle)
            else re.sub("al$", "aux", pagetitle) if pagetitle.endswith("al")
            else pagetitle + "s")
        if getparam(t, "p") == expected_p:
          rmparam(t, "p")
          notes.append("remove redundant p=")
      elif getparam(t, "p"):
        pagemsg("WARNING: Found unexpected p=%s: %s" % (getparam(t, "p"),
          unicode(t)))
      f = getparam(t, "f")
      if not re.search("[ -]", pagetitle) and (f and f != new_expected_fem or
          getparam(t, "mp") or getparam(t, "fp") or getparam(t, "p")):
        pagemsg("Found explicit feminine or plural in single-word base form: %s"
            % unicode(t))
    newt = unicode(t)
    if origt != newt:
      pagemsg("Replacing %s with %s" % (origt, newt))

  newtext = unicode(parsed)
  if newtext != text:
    assert notes
    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser("Remove extraneous params from {{fr-adj}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for cat in ["French adjectives"]:
  msg("Processing category: %s" % cat)
  for i, page in blib.cat_articles(cat, start, end):
    process_page(i, page, args.save, args.verbose)
