#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Move text outside of {{RQ:Brmnghm Gsmr}} and {{RQ:Fielding Tom Jones}}
# templates inside, with some renaming of templates and args.
# Specifically, we replace:
#
# #* {{RQ:Brmnghm Gsmr|I|01}}
# #*: It is never possible to settle down to the ordinary routine of life at sea until the screw begins to revolve. There is an '''hour''' or two, after the passengers have embarked, which is disquieting and fussy.
#
# with:
#  
# #* {{RQ:Birmingham Gossamer|chapter=I|passage=It is never possible to settle down to the ordinary routine of life at sea until the screw begins to revolve. There is an '''hour''' or two, after the passengers have embarked, which is disquieting and fussy.}}
#
# We also replace:
#
# #* {{RQ:Fielding Tom Jones|IV|i}}
# #*: That our work, therefore, might be in no danger of being likened to the labours of these historians, we have taken every '''occasion''' of interspersing through the whole sundry similes, descriptions, and other kind of poetical embellishments.
#
# with:
#
# #* {{RQ:Fielding Tom Jones|volume=[TO BE INSERTED]|book=IV|chapter=I|passage=That our work, therefore, might be in no danger of being likened to the labours of these historians, we have taken every '''occasion''' of interspersing through the whole sundry similes, descriptions, and other kind of poetical embellishments.}}
#
# where the volume is based on the book.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, set_template_name, msg, errmsg, site

replace_templates = [
  "RQ:Brmnghm Gsmr", "RQ:Fielding Tom Jones"
]

fielding_book_to_volume = {
  "I": "I",
  "II": "I",
  "III": "I",
  "IV": "II",
  "V": "II",
  "VI": "II",
  "VII": "III",
  "VIII": "III",
  "IX": "III",
  "X": "IV",
  "XI": "IV",
  "XII": "IV",
  "XIII": "V",
  "XIV": "V",
  "XV": "V",
  "XVI": "VI",
  "XVII": "VI",
  "XVIII": "VI",
}

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if not page.exists():
    pagemsg("WARNING: Page doesn't exist")
    return

  if ":" in pagetitle and not re.search(
      "^(Citations|Appendix|Reconstruction|Transwiki|Talk|Wiktionary|[A-Za-z]+ talk):", pagetitle):
    pagemsg("WARNING: Colon in page title and not a recognized namespace to include, skipping page")
    return

  text = str(page.text)
  notes = []

  newtext = text
  curtext = newtext

  newtext = re.sub(r"\{\{RQ:Brmnghm Gsmr\|([^|]*?)\|[^|]*?\}\}\n#\*: (.*?)\n",
    r"{{RQ:Birmingham Gossamer|chapter=\1|passage=\2}}\n", curtext)
  if curtext != newtext:
    notes.append("reformat {{RQ:Brmnghm Gsmr}}")
    curtext = newtext

  def replace_rq_fielding_tom_jones(m):
    book = m.group(1).upper()
    chapter = m.group(2).upper()
    volume = fielding_book_to_volume[book]
    return "{{RQ:Fielding Tom Jones|book=%s|chapter=%s|passage=%s}}\n" % (book, chapter, m.group(3))
  newtext = re.sub(r"\{\{RQ:Fielding Tom Jones\|([^|]*?)\|([IVXLCDMivxlcdm]+)\}\}\n#\*: (.*?)\n",
      replace_rq_fielding_tom_jones, curtext)
  if curtext != newtext:
    notes.append("reformat {{RQ:Fielding Tom Jones}}")
    curtext = newtext

  return curtext, notes

if __name__ == "__main__":
  parser = blib.create_argparser("Reformat {{RQ:Brmnghm Gsmr}} and {{RQ:Fielding Tom Jones}}",
    include_pagefile=True)
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
    default_refs=["Template:%s" % template for template in replace_templates],
    # FIXME: formerly had includelinks=True on call to blib.references();
    # doesn't exist any more
  )
