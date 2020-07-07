#!/usr/bin/env python
#coding: utf-8

#    find_red_links.py is free software: you can redistribute it and/or modify
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

# Find redlinks (non-existent pages).

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

parser = blib.create_argparser(u"Find red links")
parser.add_argument("--pagefile", help="File containing pages to check")
parser.add_argument("--lang", help="Language of terms")
parser.add_argument("--field", help="Field containing terms", type=int, default=1)
parser.add_argument("--output-orig", help="Output original lines", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lemmas = set()
msg("Reading %s lemmas" % args.lang)
for i, page in blib.cat_articles("%s lemmas" % args.lang, start, end):
  lemmas.add(unicode(page.title()))

words_freq = {}

lines = [re.split(r"\s", x.strip()) for x in codecs.open(args.pagefile, "r", "utf-8")]
lines = [(x[args.field - 1], x) for x in lines]

for i, (pagename, origline) in blib.iter_items(lines, start, end):
  m = re.search(u"[^-'Ѐ-џҊ-ԧꚀ-ꚗ]", pagename)
  if m:
    outtext = "skipped due to non-Cyrillic characters"
  else:
    for pagenm, pagetype in [(pagename, ""),
        (pagename.capitalize(), " (capitalized)"),
        (pagename.upper(), " (uppercased)")]:
      if pagenm in lemmas:
        outtext = "exists%s" % pagetype
        break
      else:
        page = pywikibot.Page(site, pagenm)
        if page.exists():
          text = unicode(page.text)
          if re.search("#redirect", text, re.I):
            outtext = "exists%s as redirect" % pagetype
          elif re.search(r"\{\{superlative of", text):
            outtext = "exists%s as superlative" % pagetype
          elif "==%s==" % args.lang in text:
            outtext = "exists%s as non-lemma" % pagetype
          else:
            outtext = "exists%s only in some other language" % pagetype
          break
    else:
      outtext = "does not exist"
  if args.output_orig:
    msg("| %s || %s || %s" % (i, " || ".join(origline), outtext))
    msg("|-")
  else:
    msg("Page %s [[%s]]: %s" % (i, pagename, outtext))
