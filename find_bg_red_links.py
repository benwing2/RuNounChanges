#!/usr/bin/env python
# -*- coding: utf-8 -*-

#    find_bg_red_links.py is free software: you can redistribute it and/or modify
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
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lemmas = set()
msg("Reading Bulgarian lemmas")
for i, page in blib.cat_articles("Bulgarian lemmas", start, end):
  lemmas.add(unicode(page.title()))

lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
words = lines

for i, line in blib.iter_items(words, start, end):
  pagename, freq = line.split("\t")
  m = re.search(u"[^-Ѐ-џҊ-ԧꚀ-ꚗ]", pagename)
  def fmsg(txt):
    msg("Page %s [[%s]]: %s (freq %s)" % (i, pagename, txt, freq))
  if m:
    fmsg("skipped due to non-Cyrillic characters")
  else:
    for pagenm, pagetype in [(pagename, ""),
        (pagename.capitalize(), " (capitalized)"),
        (pagename.upper(), " (uppercased)")]:
      if pagenm in lemmas:
        fmsg("exists%s" % pagetype)
        break
      else:
        page = pywikibot.Page(site, pagenm)
        if page.exists():
          text = unicode(page.text)
          if re.search("#redirect", text, re.I):
            fmsg("exists%s as redirect" % pagetype)
          elif re.search(r"\{\{superlative of\|bg\|", text):
            fmsg("exists%s as superlative" % pagetype)
          elif "==Bulgarian==" in text:
            fmsg("exists%s as non-lemma" % pagetype)
          else:
            fmsg("exists%s only in some other language" % pagetype)
          break
    else:
      fmsg("does not exist")
