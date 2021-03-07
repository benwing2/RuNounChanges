#!/usr/bin/env python
# -*- coding: utf-8 -*-

import blib
from blib import getparam, rmparam, msg, errmsg, errandmsg, site

import pywikibot, re, sys, codecs, argparse

def process_page(index, page, contents, lang, verbose, comment):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  if verbose:
    pagemsg("For [[%s]]:" % pagename)
    pagemsg("------- begin text --------")
    msg(contents.rstrip('\n'))
    msg("------- end text --------")
  if not page.exists():
    return contents, comment
  else:
    insert_before = 0
    curtext = page.text
    sections = re.split("(^==[^=]*==\n)", curtext, 0, re.M)

    for j in xrange(2, len(sections), 2):
      m = re.search(r"^==\s*(.*?)\s*==\n", sections[j - 1])
      if not m:
        errandpagemsg("WARNING: Saw bad second-level header: %s" % sections[j - 1].strip())
        return
      foundlang = m.group(1)
      if foundlang == lang:
        errandpagemsg("WARNING: Already found %s section" % lang)
        return
      if foundlang > lang:
        insert_before = j - 1
        break
    if insert_before == 0:
      # Add to the end
      newtext = curtext.rstrip("\n") + "\n\n----\n\n" + contents
      return newtext, comment
    sections[insert_before:insert_before] = contents.rstrip("\n") + "\n\n----\n\n"
    return "".join(sections), comment

if __name__ == "__main__":
  parser = blib.create_argparser("Push new entries from generate_entries.py")
  parser.add_argument('--direcfile', help="File containing entries.")
  parser.add_argument('--comment', help="Comment to use.", required="true")
  parser.add_argument('--lang', help="Language of entries.", required="true")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  lines = codecs.open(args.direcfile, "r", "utf-8")

  index_pagename_and_text = blib.yield_text_from_find_regex(lines, args.verbose)
  for _, (index, pagename, text) in blib.iter_items(index_pagename_and_text, start, end,
      get_name=lambda x:x[1], get_index=lambda x:x[0]):
    def do_process_page(page, index, parsed):
      return process_page(index, page, text, args.lang, args.verbose, args.comment.decode("utf-8"))
    blib.do_edit(pywikibot.Page(site, pagename), index, do_process_page,
        save=args.save, verbose=args.verbose, diff=args.diff)
