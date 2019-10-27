#!/usr/bin/env python
#coding: utf-8

#    rewrite.py is free software: you can redistribute it and/or modify
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

import blib, re, codecs
import pywikibot
from arabiclib import reorder_shadda

def process_page(page, index, refrom, reto, pagetitle_sub, comment, lang_only,
    warn_on_no_replacement, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    blib.msg("Page %s %s: %s" % (index, pagetitle, txt))
  if verbose:
    blib.msg("Processing %s" % pagetitle)
  #blib.msg("From: [[%s]], To: [[%s]]" % (refrom, reto))
  text = unicode(page.text)
  origtext = text
  text = reorder_shadda(text)
  zipped_fromto = zip(refrom, reto)
  def replace_text(text):
    for fromval, toval in zipped_fromto:
      if pagetitle_sub:
        fromval = fromval.replace(pagetitle_sub, re.escape(pagetitle))
        toval = toval.replace(pagetitle_sub, pagetitle)
      text = re.sub(fromval, toval, text, 0, re.M)
    return text
  if not lang_only:
    text = replace_text(text)
  else:
    sec_to_replace = None
    foundlang = False
    sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

    for j in xrange(2, len(sections), 2):
      if sections[j-1] == "==%s==\n" % lang_only:
        if foundlang:
          pagemsg("WARNING: Found multiple %s sections, skipping page" % lang_only)
          if warn_on_no_replacement:
            pagemsg("WARNING: No replacements made")
          return
        foundlang = True
        sec_to_replace = j
        break

    if sec_to_replace is None:
      if warn_on_no_replacement:
        pagemsg("WARNING: No replacements made")
      return
    sections[sec_to_replace] = replace_text(sections[sec_to_replace])
    text = "".join(sections)
  if warn_on_no_replacement and text == origtext:
    pagemsg("WARNING: No replacements made")
  return text, comment or "replace %s" % (", ".join("%s -> %s" % (f, t) for f, t in zipped_fromto))

pa = blib.create_argparser("Search and replace on pages", include_pagefile=True)
pa.add_argument("-f", "--from", help="From regex, can be specified multiple times",
    metavar="FROM", dest="from_", required=True, action="append")
pa.add_argument("-t", "--to", help="To regex, can be specified multiple times",
    required=True, action="append")
pa.add_argument("--comment", help="Specify the change comment to use")
pa.add_argument('--pagetitle', help="Value to substitute page title with")
pa.add_argument('--lang-only', help="Only replace in the specified language section")
pa.add_argument('--warn-on-no-replacement', action="store_true",
  help="Warn if no replacements made")
args = pa.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

from_ = [x.decode("utf-8") for x in args.from_]
to = [x.decode("utf-8") for x in args.to]
pagetitle_sub = args.pagetitle and args.pagetitle.decode("utf-8")
comment = args.comment and args.comment.decode("utf-8")
lang_only = args.lang_only and args.lang_only.decode("utf-8")

if len(from_) != len(to):
  raise ValueError("Same number of --from and --to arguments must be specified")

def do_process_page(page, index, parsed):
  return process_page(page, index, from_, to, pagetitle_sub, comment, lang_only,
    args.warn_on_no_replacement, args.verbose)
blib.do_pagefile_cats_refs(args, start, end, do_process_page, edit=True)
