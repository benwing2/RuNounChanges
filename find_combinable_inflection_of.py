#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

def process_text_on_page(pagetitle, index, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  #pagemsg("Processing")

  if blib.page_should_be_ignored(pagetitle):
    #pagemsg("WARNING: Page should be ignored")
    return

  if "inflection of" not in text:
    return

  subsections = re.split("(^==+[^=\n]+==+\n)", text, 0, re.M)
  for j in xrange(2, len(subsections), 2):
    if re.search(r"^[#*]+ \{\{inflection of.*\n[#*]+ \{\{inflection of.*", subsections[j], re.M):
      pagemsg("Found subsection with combinable inflection-of:\n%s" %
          subsections[j].strip())

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  text = unicode(page.text)
  process_text_on_page(pagetitle, index, text)

parser = blib.create_argparser("Find occurrences of multiple 'inflection of' tags in a single subsection")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

page_index = 0
def process_page_callback(title, text):
  global page_index
  page_index += 1
  process_text_on_page(title, page_index, text)

blib.parse_dump(sys.stdin, process_page_callback)
