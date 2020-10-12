#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  parsed = blib.parse_text(text)
  head = None
  for t in parsed.filter_templates():
    tn = tname(t)
    newhead = None
    if tn == "head" and getparam(t, "1") == "ang" or tn in [
      "ang-noun", "ang-noun-form", "ang-verb", "ang-verb-form",
      "ang-adj", "ang-adj-form", "ang-adv", "ang-con",
      "ang-prep", "ang-prefix", "ang-proper noun", "ang-suffix"]:
      newhead = getparam(t, "head") or pagetitle
    if newhead:
      if head:
        pagemsg("WARNING: Saw head=%s and newhead=%s, skipping" % (head, newhead))
        pagemsg("------- begin text --------")
        msg(text.rstrip('\n'))
        msg("------- end text --------")
        return
      head = newhead
  if u"ƿ" not in head:
    pagemsg("WARNING: Something wrong, didn't see wynn in head: %s" % head)
  saw_altspell = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "alternative spelling of":
      if saw_altspell:
        pagemsg("WARNING: Saw multiple {{alternative spelling of}}, skipping: %s and %s" % (
          unicode(saw_altspell), unicode(t)))
        pagemsg("------- begin text --------")
        msg(text.rstrip('\n'))
        msg("------- end text --------")
        return
      saw_altspell = unicode(t)
      if getparam(t, "1") != "ang":
        pagemsg("WARNING: {{alternative spelling of}} without language 'ang', skipping: %s" % unicode(t))
        pagemsg("------- begin text --------")
        msg(text.rstrip('\n'))
        msg("------- end text --------")
        return
      param2 = getparam(t, "2")
      should_param2 = blib.remove_links(head).replace(u"ƿ", "w")
      if param2 != should_param2:
        origt = unicode(t)
        t.add("2", should_param2)
        pagemsg("Replacing %s with %s" % (origt, unicode(t)))
  text = re.sub("\n\n+", "\n\n", unicode(parsed))
  pagemsg("------- begin text --------")
  msg(text.rstrip('\n'))
  msg("------- end text --------")
  return

parser = blib.create_argparser("Fix Old English adjective headwords to new format")
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = codecs.open(args.direcfile, "r", "utf-8")

pagename_and_text = blib.yield_text_from_find_regex(lines, args.verbose)
for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
    get_name=lambda x:x[0]):
  process_page(index, pagename, text)
