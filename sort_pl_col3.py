#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Polish", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  col3_splits = re.split(r"^((?:\{\{col3\|pl\|[^{}\n]*\}\}\n)+)", secbody, 0, re.M)
  for k in range(1, len(col3_splits), 2):
    col3_split = col3_splits[k].rstrip("\n").split("\n")
    decorated_lines = []
    must_continue = False
    for line in col3_split:
      m = re.search(r"\|title=([^{}|\n]*)[|}]", line)
      if not m:
        pagemsg("WARNING: Saw {{col3|pl}} line but couldn't extract part of speech from title=: %s" % line)
        must_continue = True
        break
      decorated_lines.append((m.group(1), line))
    if must_continue:
      continue
    new_col3_splits = "\n".join(line for _, line in sorted(decorated_lines)) + "\n"
    if new_col3_splits != col3_splits[k]:
      notes.append("sort {{col3|pl}} lines by title (part of speech)")
      def quote_nl(text):
        return text.replace("\n", r"\n")
      pagemsg("Replaced <%s> with <%s>" % (quote_nl(col3_splits[k]), quote_nl(new_col3_splits)))
      col3_splits[k] = new_col3_splits
  secbody = "".join(col3_splits)

  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)

  return text, notes

parser = blib.create_argparser("Sort {{col3|pl}} lines by title (part of speech)", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_cats=["Polish lemmas"])
