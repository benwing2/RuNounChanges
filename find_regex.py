#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Find pages that need definitions among a set list (e.g. most frequent words).

import blib, re, sys
import pywikibot

import blib
from blib import getparam, rmparam, msg, site

def process_text_on_page(index, pagetitle, text, regex, invert, verbose,
    include_text, all_matches, lang, from_to):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if verbose:
    pagemsg("Processing")

  if not lang:
    text_to_search = text
  else:
    text_to_search = []
    langs = set(re.split(",(?!= )", lang))
    seen_langs = set()
    sections = re.split("(^==[^=]*==\s*\n)", text, 0, re.M)

    for j in range(2, len(sections), 2):
      m = re.search("^==\s*(.*?)\s*==$", sections[j - 1].strip())
      if m:
        seclang = m.group(1)
        if seclang in langs:
          if seclang in seen_langs:
            pagemsg("WARNING: Found multiple %s sections, skipping page" % seclang)
            return
          seen_langs.add(seclang)
          if len(langs) == 1:
            text_to_search = [sections[j]]
            break
          text_to_search.append(sections[j - 1] + sections[j])
    text_to_search = "".join(text_to_search)

  def output_match(m):
    if from_to:
      pagemsg("Found match for regex: <from> %s <to> %s <end>" % (m.group(0), m.group(0)))
    else:
      pagemsg("Found match for regex: %s" % m.group(0))

  if text_to_search:
    found_match = False
    if regex is None:
      found_match = True
    elif all_matches:
      for m in re.finditer(regex, text_to_search, re.M):
        found_match = True
        output_match(m)
    else:
      m = re.search(regex, text_to_search, re.M)
      if m:
        found_match = True
        if not invert:
          output_match(m)
    if not found_match and invert:
      pagemsg("Didn't find match for regex: %s" % regex)
    if include_text:
      if not text_to_search.endswith("\n"):
        text_to_search += "\n"
      if found_match == (not invert):
        pagemsg("-------- begin text --------\n%s-------- end text --------" % text_to_search)

def search_pages(args, regex, invert, input_from_diff, start, end, lang):

  def do_process_text_on_page(index, title, text):
    process_text_on_page(index, title, text, regex, invert, args.verbose,
        args.text, args.all, lang, args.from_to)

  if input_from_diff:
    lines = open(input_from_diff, "r", encoding="utf-8")
    index_pagename_and_text = blib.yield_text_from_diff(lines, args.verbose)
    for _, (index, pagename, text) in blib.iter_items(index_pagename_and_text, start, end,
        get_name=lambda x:x[1], get_index=lambda x:x[0]):
      do_process_text_on_page(index, pagename, text)
    return

  blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page, stdin=True)

if __name__ == "__main__":
  parser = blib.create_argparser("Search on pages", include_pagefile=True,
    include_stdin=True)
  parser.add_argument("-e", "--regex", help="Regular expression to search for.")
  parser.add_argument("--not", dest="not_", help="Only output if regex not found.",
      action="store_true")
  parser.add_argument('--input-from-diff', help="Use the specified file as input, a previous output of a job run with --diff.")
  parser.add_argument('--all', help="Include all matches.", action="store_true")
  parser.add_argument('--from-to', help="Output in from-to format, for ease in pushing changes.", action="store_true")
  parser.add_argument('--text', help="Include full text of page or language section.", action="store_true")
  parser.add_argument('--lang', help="Only search the specified language section(s) (comma-separated).")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  if not args.regex and not args.text:
    raise ValueError("-e (--regex) must be given unless --text is given")
  if args.not_ and args.all:
    raise ValueError("Can't combine --not with --all")
  search_pages(args, args.regex, args.not_, args.input_from_diff, start, end, args.lang)
