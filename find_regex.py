#!/usr/bin/env python
#coding: utf-8

#    find_regex.py is free software: you can redistribute it and/or modify
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

# Find pages that need definitions among a set list (e.g. most frequent words).

import blib, re, codecs, sys
import pywikibot

import blib
from blib import getparam, rmparam, msg, site

def process_text_on_page(index, pagetitle, text, regex, invert, verbose,
    include_text, all_matches, include_non_mainspace, lang_only):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if verbose:
    pagemsg("Processing")

  if not include_non_mainspace and ":" in pagetitle:
    if verbose:
      pagemsg("WARNING: Colon in page title, skipping page")
    return

  if not lang_only:
    text_to_search = text
  else:
    text_to_search = None
    foundlang = False
    sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

    for j in xrange(2, len(sections), 2):
      if sections[j-1] == "==%s==\n" % lang_only:
        if foundlang:
          pagemsg("WARNING: Found multiple %s sections, skipping page" % lang_only)
          return
        foundlang = True
        text_to_search = sections[j]
        break

  if text_to_search:
    if all_matches:
      for m in re.finditer(regex, text_to_search, re.M):
        pagemsg("Found match for regex: %s" % m.group(0))
    else:
      m = re.search(regex, text_to_search, re.M)
      if not text_to_search.endswith("\n"):
        text_to_search += "\n"
      if m:
        if not invert:
          pagemsg("Found match for regex: %s" % m.group(0))
          if include_text:
            pagemsg("-------- begin text ---------\n%s-------- end text --------" % text_to_search)
      elif invert:
        pagemsg("Didn't find match for regex: %s" % regex)
        if include_text:
          pagemsg("-------- begin text ---------\n%s-------- end text --------" % text_to_search)

def search_pages(args, regex, invert, input_from_diff, start, end, lang_only):

  def do_process_text_on_page(index, title, text):
    process_text_on_page(index, title, text, regex, invert, args.verbose,
        args.text, args.all, args.include_non_mainspace, lang_only)

  if input_from_diff:
    lines = codecs.open(input_from_diff, "r", "utf-8")
    pagename_and_text = blib.yield_text_from_diff(lines, verbose)
    for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
        get_name=lambda x:x[0]):
      do_process_text_on_page(index, pagename, text)
    return

  blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page, stdin=True)

if __name__ == "__main__":
  parser = blib.create_argparser("Search on pages", include_pagefile=True,
    include_stdin=True)
  parser.add_argument("-e", "--regex", help="Regular expression to search for.",
      required=True)
  parser.add_argument("--not", dest="not_", help="Only output if regex not found.",
      action="store_true")
  parser.add_argument('--input-from-diff', help="Use the specified file as input, a previous output of a job run with --diff.")
  parser.add_argument('--all', help="Include all matches.", action="store_true")
  parser.add_argument('--text', help="Include surrounding text.", action="store_true")
  parser.add_argument('--include-non-mainspace', help="Don't skip non-mainspace pages. Defaults to true if --namespaces is given.", action='store_true')
  parser.add_argument('--lang-only', help="Only search the specified language section.")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  if args.not_ and args.all:
    raise ValueError("Can't combine --not with --all")
  regex = args.regex.decode("utf-8")
  input_from_diff = args.input_from_diff and args.input_from_diff.decode("utf-8")
  lang_only = args.lang_only and args.lang_only.decode("utf-8")
  search_pages(args, regex, args.not_, input_from_diff, start, end, lang_only)
