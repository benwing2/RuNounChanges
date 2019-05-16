#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

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

  def combine_doublets(m):
    first = blib.parse_text(m.group(1))
    rest = blib.parse_text(m.group(2))
    t1 = list(first.filter_templates())[0]
    if getparam(t1, "3") or getparam(t1, "4") or getparam(t1, "alt2") or getparam(t1, "alt3"):
      pagemsg("WARNING: Can't combine %s, first template already has multiple terms" %
          m.group(0))
      return m.group(0)
    next_index = 2
    lang = getparam(t1, "1")
    for t in rest.filter_templates(recursive=False):
      tlang = getparam(t, "1")
      if lang != tlang:
        pagemsg("WARNING: Lang %s in continuation template %s not same as lang %s in first template %s" % (
          tlang, unicode(t), lang, unicode(t1)))
        return m.group(0)
      for param in t.params:
        pname = unicode(param.name).strip()
        pval = unicode(param.value).strip()
        if not pval:
          continue
        if pname == "2":
          t1.add(str(next_index + 1), pval)
        elif pname == "3":
          t1.add("alt%s" % next_index, pval)
        elif pname == "4":
          t1.add("t%s" % next_index, pval)
        elif pname in ["t", "gloss", "tr", "ts", "pos", "lit", "alt", "sc",
            "id", "g"]:
          t1.add("%s%s" % (pname, next_index), pval)
        elif pname in ["t1", "gloss1", "tr1", "ts1", "pos1", "lit1", "alt1", "sc1",
            "id1", "g1"]:
          t1.add("%s%s" % (pname[:-1], next_index), pval)
        elif pname in ["1", "notext", "nocap", "nocat"]:
          pass
        else:
          pagemsg("WARNING: Unrecognized param %s=%s in %s, skipping" %
              (pname, pval, unicode(t)))
          return m.group(0)
      next_index += 1
    for param in ["notext", "nocap", "nocat"]:
      val = getparam(t1, param)
      rmparam(t1, param)
      if val:
        t1.add(param, val)
    newtext = unicode(t1)
    pagemsg("Replaced %s with %s" % (m.group(0), newtext))
    return newtext

  newtext = re.sub(r"(\{\{doublet\|(?:[^{}\n]|\{\{[^{}\n]*\}\})*\}\})((?:(?:, *|,? *and *)\{\{(?:m|l|doublet)\|(?:[^{}\n]|\{\{[^{}\n]*\}\})*\}\})+)", combine_doublets, text)
  if newtext != text:
    notes.append("combine adjacent doublets")
  text = newtext

  return text, notes

parser = blib.create_argparser("Combine adjacent doublets")
parser.add_argument('--pagefile', help="File containing pages to search.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

assert args.pagefile

lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
for index, page in blib.iter_items(lines, start, end):
  blib.do_edit(pywikibot.Page(site, page), index, process_page,
      save=args.save, verbose=args.verbose)
