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
parser.add_argument("--with-freq", help="Words come with frequencies and possibly occur multiple times.", action="store_true")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

lemmas = set()
msg("Reading Russian lemmas")
for i, page in blib.cat_articles("Russian lemmas", start, end):
  lemmas.add(unicode(page.title()))

words_freq = {}

lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
if args.with_freq:
  for line in lines:
    freq, word = re.split(r"\s", line)
    freq = int(freq)
    if word in words_freq:
      words_freq[word] += freq
    else:
      words_freq[word] = freq
  words = [x[0] for x in sorted(words_freq.items(), key=lambda y:-y[1])]
else:
  words = lines

for i, pagename in blib.iter_items(words, start, end):
  m = re.search(u"[^-Ѐ-џҊ-ԧꚀ-ꚗ]", pagename)
  if m:
    msg("Page %s [[%s]]: skipped due to non-Cyrillic characters" % (i, pagename))
  else:
    for pagenm, pagetype in [(pagename, ""),
        (pagename.capitalize(), " (capitalized)"),
        (pagename.upper(), " (uppercased)")]:
      if pagenm in lemmas:
        msg("Page %s [[%s]]: exists%s" % (i, pagename, pagetype))
        break
      else:
        page = pywikibot.Page(site, pagenm)
        if page.exists():
          if re.search("#redirect", unicode(page.text), re.I):
            msg("Page %s [[%s]]: exists%s as redirect" % (i, pagename, pagetype))
          elif re.search(r"\{\{superlative of", unicode(page.text)):
            msg("Page %s [[%s]]: exists%s as superlative" % (i, pagename, pagetype))
          else:
            msg("Page %s [[%s]]: exists%s as non-lemma" % (i, pagename, pagetype))
          break
    else:
      msg("Page %s [[%s]]: does not exist" % (i, pagename))
