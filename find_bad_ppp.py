#!/usr/bin/env python
#coding: utf-8

#    find_pppp.py is free software: you can redistribute it and/or modify
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

# Go through all the terms we can find looking for pages that are
# missing a headword declaration.

# NOTES on how past passive participles are formed and when they're present:
#
# Participles exist only in transitive verbs, in perfective verbs as well
# as imperfective verbs not marked with the shaded circle sign. However,
# verbs marked with an x form participles with difficulty, and verbs marked
# with an x inside of a square lack participles.
#
# Verbs in -ать and -ять (except type 14) form participles by replacing -ть
# in the infinitive with -нный. If the stress is on the last syllable of the
# infinitive, it is one syllable to the left in the participle (if possible),
# else on the same syllable as the infinitive. However, verbs in -а́ть and
# -я́ть with the circled-7 mark have participles in -а́нный and -я́нный (there
# aren't very many of these). When the stress is moved relative to the
# infinitive, е changes to ё if the ё symbol is present.
#
# Verbs of type 4 and verbs in -еть of type 5 form participles by adding
# -енный (stressed -ённый) to the base of the 1sg present/future (i.e.
# iotated in the same way as the 1sg, if it is iotated). Verbs of type 4 have
# the stress on the same syllable as in the 3sg present/future (i.e. -ённый
# if type b, else somewhere on the stem with -енный); but verbs of type 4b
# with the circled-8 mark have the ending -енный with the stress on the last
# syllable of the stem, i.e. one syllable to the left compared with the
# infinitive). Verbs of type 5 have the stress as in -ать verbs (one syllable
# to the left of the infinitive if the infinitive stress is on the ending and
# the circled-7 mark isn't present, else in the same place as the infinitive).
#
# Verbs of type 1 in -еть form participles by replacing -еть with -ённый.
# The only such verbs with participles are одоле́ть, преодоле́ть, and verbs
# in -печатле́ть.
#
# Verbs of type 7 and 8 form participles by adding -енный (stressed -ённый)
# to the base of the 3sg present/future. The stress is on the same syllable
# as in the feminine singular past.
#
# Verbs of type 3 (3˚) and 10 form participles by adding -тый to the base
# of the infinitive. These verbs have the stress as in -ать verbs (one
# syllable to the left of the infinitive if the infinitive stress is on the
# ending, else in the same place as the infinitive).
#
# Verbs of type 9, 11, 12, 14, 15, 16 form participles by adding -тый to
# the masculine singular past (minus final -л if it's present). Stress is
# as in the masculine singular past.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def iotate(word):
  if re.search(u"[бвфпм]$", word):
    return [word + u"л"]
  if re.search(u"[зг]$", word):
    return [re.sub(u"[зг]$", u"ж", word)]
  if re.search(u"[сш]$", word):
    return [re.sub(u"[сш]$", u"ш", word)]
  if re.search(u"с[тк]$", word):
    return [re.sub(u"с[тк]$", u"щ", word)]
  if re.search(u"д$", word):
    return [re.sub(u"д$", u"ж", word), re.sub(u"д$", u"жд", word)]
  if re.search(u"т$", word):
    return [re.sub(u"т$", u"ч", word), re.sub(u"т$", u"щ", word)]
  if re.search(u"к$", word):
    return [re.sub(u"к$", u"ч", word)]
  return [word]

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  parsed = blib.parse(page)
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname.startswith("ru-conj-") and tname != "ru-conj-verb-see":
      m = re.search(r"^\{\{ru-conj-(.*?)\|(.*)\}\}$", unicode(t), re.S)
      verbtype, params = m.groups()
      tempcall = "{{ru-generate-verb-forms|type=%s|%s}}" % (verbtype, params)
      result = expand_text(tempcall)
      if not result:
        pagemsg("WARNING: Error generating forms, skipping")
        continue
      args = rulib.split_generate_args(result)
      if "past_pasv_part" in args:
        for form in re.split(",", args["past_pasv_part"]):
          form = re.sub("//.*", "", form)
          if not re.search(ur"([аяеё]́?нный|тый)$", form):
            pagemsg("WARNING: Past passive participle doesn't end correctly: %s" % form)
          unstressed_page = rulib.make_unstressed(pagetitle)
          unstressed_form = rulib.make_unstressed(form)
          if unstressed_form[0] != unstressed_page[0]:
            pagemsg("WARNING: Past passive participle doesn't begin with same letter, probably for wrong aspect: %s"
                % form)
          if form.endswith(u"нный"):
            if pagetitle.endswith(u"ать"):
              good_ending = u"анный"
            elif pagetitle.endswith(u"ять"):
              good_ending = u"янный"
            else:
              good_ending = u"енный"
            if not unstressed_form.endswith(good_ending):
              pagemsg("WARNING: Past passive participle doesn't end right, probably for wrong aspect: %s"
                  % form)

parser = blib.create_argparser(u"Find Russian terms without bad past passive participles")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for category in ["Russian verbs"]:
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
