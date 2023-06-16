#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

pos_mapper = {
  "n": "noun",
  "v": "verb",
  "adj": "adjective",
  "adv": "adverb"
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
    if tn == "hu-suffix":
      if getparam(t, "pos2"):
        pagemsg("Has pos2: %s" % str(t))
        continue
      if (getparam(t, "3") or getparam(t, "4") or getparam(t, "5") or getparam(t, "6")) and not getparam(t, "nocat"):
        pagemsg("Has more than one suffix and not nocat=: %s" % str(t))
        continue
      for i in range(1, 11):
        trnum = getparam(t, "tr%s" % i)
        if trnum:
          notes.append("move tr%s to t%s in {{hu-suffix}}" % (i, i))
          t.add("t%s" % i, trnum, before="tr%s" % i)
          rmparam(t, "tr%s" % i)
      for i in range(1, 11):
        tnum = getparam(t, "t%s" % i)
        if tnum and re.search(" (marker|suffix|ending|vowel|plural)$", tnum):
          notes.append("move t%s to pos%s in {{hu-suffix}}" % (i, i))
          t.add("pos%s" % i, tnum, before="t%s" % i)
          rmparam(t, "t%s" % i)
      for i in range(2, 11):
        suf = getparam(t, str(i))
        if suf and not suf.startswith("-"):
          suf = "-" + suf
          t.add(str(i), suf)
      base = getparam(t, "1")
      if not base or not getparam(t, "nocat") and (base.startswith("-") or base.endswith("-")):
        base = "^" + base
        t.add("1", base, before="2")
      pos = getparam(t, "pos")
      if pos in pos_mapper:
        t.add("pos", pos_mapper[pos])
      # Fetch all params.
      params = []
      for param in t.params:
        pname = str(param.name)
        params.append((pname, param.value, param.showkey))
      # Erase all params.
      del t.params[:]
      t.add("1", "hu")
      # Put remaining parameters in order.
      for name, value, showkey in params:
        if re.search("^[0-9]+$", name):
          t.add(str(int(name) + 1), value, showkey=showkey, preserve_spacing=False)
        else:
          t.add(name, value, showkey=showkey, preserve_spacing=False)
      blib.set_template_name(t, "affix")
      notes.append("convert {{hu-suffix}} to {{affix}}")
    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Clean up {{hu-suffix}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in ["hu-suffix"]:
  msg("Processing references to Template:%s" % template)
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
