#!/usr/bin/env python
#coding: utf-8

#    find_multiword_red_links.py is free software: you can redistribute it and/or modify
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

# Find redlinks (non-existent pages) in multiword lemmas, i.e. individual
# words in multiword lemmas that don't exist as lemmas.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

# For each lemma seen, count of how many times seen
lemma_count = {}
# For each nonexistent lemma seen, message indicating what type of nonexistence
# ('does not exist', 'exists as redirect', 'exists as superlative',
# 'exists as non-lemma').
nonexistent_lemmas = {}
# For each nonexistent lemma seen, list of all pages referencing it.
nonexistent_lemmas_refs = {}
lemmas = set()
msg("Reading Russian lemmas")
for i, page in blib.cat_articles("Russian lemmas", start, end):
  lemmas.add(unicode(page.title()))

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  origtext = page.text
  parsed = blib.parse_text(origtext)

  def check_lemma(lemma):
    if lemma in lemma_count:
      lemma_count[lemma] += 1
      if lemma in nonexistent_lemmas:
        nonexistent_lemmas_refs[lemma].append(pagetitle)
    else:
      lemma_count[lemma] = 1
      if lemma not in lemmas:
        page = pywikibot.Page(site, lemma)
        if page.exists():
          if re.search("#redirect", unicode(page.text), re.I):
            nonexistent_msg = "exists as redirect"
          elif re.search(r"\{\{superlative of", unicode(page.text)):
            nonexistent_msg = "exists as superlative"
          else:
            nonexistent_msg = "exists as non-lemma"
        else:
          nonexistent_msg = "does not exist"
        pagemsg("Referenced lemma %s: %s" % (lemma, nonexistent_msg))
        nonexistent_lemmas[lemma] = nonexistent_msg
        nonexistent_lemmas_refs[lemma] = [pagetitle]

  def process_arg_set(arg_set):
    if not arg_set:
      return
    offset = 0
    if re.search(r"^[a-f]'*$", arg_set[offset]):
      offset = 1
    if len(arg_set) <= offset:
      return
    lemma = arg_set[offset]
    if not lemma:
      return
    lemma = rulib.remove_accents(blib.remove_links(lemma))
    check_lemma(lemma)

  def process_new_style_headword(htemp):
    # Split out the arg sets in the declension and check the
    # lemma of each one, taking care to handle cases where there is no lemma
    # (it would default to the page name).

    highest_numbered_param = 0
    for p in htemp.params:
      pname = unicode(p.name)
      if re.search("^[0-9]+$", pname):
        highest_numbered_param = max(highest_numbered_param, int(pname))

    # Now split based on arg sets.
    arg_set = []
    for i in xrange(1, highest_numbered_param + 2):
      end_arg_set = False
      val = getparam(decl_template, str(i))
      if (i == highest_numbered_param + 1 or elif val in ["or", "_", "-"] or
          re.search("^join:", val)):
        end_arg_set = True

      if end_arg_set:
        process_arg_set(arg_set)
        arg_set = []
      else:
        arg_set.append(val)

  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == "ru-decl-noun-see":
      pagemsg("WARNING: Skipping ru-decl-noun-see, can't handle yet: %s" % unicode(t))
    elif tname in ["ru-noun+", "ru-proper noun+"]:
      pagemsg("Found %s" % unicode(t))
      process_new_style_headword(t)
    elif tname in ["ru-noun", "ru-proper noun"]:
      pagemsg("WARNING: Skipping ru-noun or ru-proper noun, can't handle yet: %s" % unicode(t))

parser = blib.create_argparser(u"Find red links in multiword lemmas")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for pos in ["nouns", "proper nouns"]:
  tracking_page = "Template:tracking/ru-headword/space-in-headword/" + pos
  msg("PROCESSING REFERENCES TO: %s" % tracking_page)
  for index, page in blib.references(tracking_page, start, end):
    process_page(index, page)

for lemma, nonexistent_msg in sorted(nonexistent_lemmas.items(), key=lambda lemma:-lemma_count[lemma]):
  msg("* [[%s]] (%s occurrences): %s (refs: %s)" % (lemma, lemma_count[lemma],
    nonexistent_msg, ", ".join(nonexistent_lemmas_refs[lemma])))
