#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  seen_trans = [pagetitle]
  english_section = blib.find_lang_section(text, "English", pagemsg)
  if english_section:
    subsections, subsections_by_header, subsection_headers, subsection_levels = (
        blib.split_text_into_subsections(english_section, pagemsg))
  if "Translations" in subsections_by_header:
    for k in subsections_by_header["Translations"]:
      expanded = expand_text(subsections[k])
      if expanded:
        for m in re.finditer(r'<span class="[A-Z].*?" lang=".*?">\[\[([^\[\]\|]*)\|([^\[\]\|]*)\]\]</span>',
                             expanded):
          trans = re.sub("^:", "", re.sub("#.*", "", m.group(1)))
          if trans and trans not in seen_trans:
            seen_trans.append(trans)
    for trans in seen_trans:
      def pagemsg_with_trans(txt):
        pagemsg("%s: %s" % (trans, txt))
      if blib.safe_page_exists(pywikibot.Page(site, trans), pagemsg_with_trans):
        msg("Page %s %s: Found existing translation for %s" % (index, trans, pagetitle))

parser = blib.create_argparser("Find page-existing translations for terms", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, stdin=True)
