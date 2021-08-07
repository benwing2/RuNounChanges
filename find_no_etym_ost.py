#!/usr/bin/env python
#coding: utf-8

#    find_no_etym_ost.py is free software: you can redistribute it and/or modify
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

# Try to construct etymologies of nouns in -ость from adjectives.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site

import rulib

def process_page(index, page, save, verbose, nouns):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  if not re.search(u"[иы]й$", pagetitle):
    pagemsg(u"Skipping adjective not in -ый or -ий")
    return

  noun = re.sub(u"[иы]й$", u"ость", pagetitle)
  if noun not in nouns:
    return

  text = unicode(page.text)
  parsed = blib.parse(page)

  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == u"ru-adj-alt-ё":
      pagemsg(u"Skipping alt-ё adjective")
      return

  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == "ru-adj":
      heads = blib.fetch_param_chain(t, "1", "head", pagetitle)
      if len(heads) > 1:
        pagemsg("Skipping adjective with multiple heads: %s" % ",".join(heads))
        return
      tr = getparam(t, "tr")

      nounsection = blib.find_lang_section(noun, "Russian", pagemsg, errandpagemsg)
      if not nounsection:
        pagemsg("Couldn't find Russian section for %s" % noun)
        continue
      if "==Etymology" in nounsection:
        pagemsg("Noun %s already has etymology" % noun)
        continue
      if tr:
        msg(u"%s %s+tr1=%s+-ость no-etym" % (noun, heads[0], tr))
      else:
        msg(u"%s %s+-ость no-etym" % (noun, heads[0]))

parser = blib.create_argparser(u"Find etymologies for nouns in -ость")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

nouns = []
for i, page in blib.cat_articles("Russian nouns"):
  nouns.append(page.title())

for category in ["Russian adjectives"]:
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose, nouns)
