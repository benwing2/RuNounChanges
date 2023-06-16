#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

inflection_of_templates = [
  "inflection of",
  "noun form of",
  "verb form of",
  "adj form of",
  "participle of"
]

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  #pagemsg("Processing")

  if blib.page_should_be_ignored(pagetitle):
    #pagemsg("WARNING: Page should be ignored")
    return

  if all(x not in text for x in inflection_of_templates):
    return

  subsections = re.split("(^==+[^=\n]+==+\n)", text, 0, re.M)
  for j in range(2, len(subsections), 2):
    for template in inflection_of_templates:
      if re.search(r"^[#*]+ \{\{%s.*\n[#*]+ \{\{%s.*" % (template, template), subsections[j], re.M):
        pagemsg("Found subsection with combinable %s:\n%s" %
            (template, subsections[j].strip()))

parser = blib.create_argparser("Find occurrences of multiple 'inflection of' tags in a single subsection")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.parse_dump(sys.stdin, process_text_on_page, startprefix=start, endprefix=end)
