#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def process_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  def fix_up_section(sectext, indent):
    subsections = re.split("(^%s[^=\n]+=+\n)" % indent, sectext, 0, re.M)
    saw_adecl = False
    for k in xrange(2, len(subsections), 2):
      parsed = blib.parse_text(subsections[k])
      la_adecl_template = None
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "la-adecl":
          if la_adecl_template:
            pagemsg("WARNING: Saw multiple {{la-adecl}} templates: %s and %s" % (
              la_adecl_template, t))
          else:
            la_adecl_template = t
            saw_adecl = True
      if not la_adecl_template:
        continue
      split_subsec = re.split("(^# .*substantive.*\n)", subsections[k], 0, re.M)
      remaining_parts = []
      defn_parts = []
      if len(split_subsec) == 1:
        pagemsg("WARNING: Didn't see substantive defn, skipping")
        continue
      for i in xrange(len(split_subsec)):
        if i % 2 == 0:
          remaining_parts.append(split_subsec[i])
        else:
          defn_parts.append(split_subsec[i])
      param1 = getparam(la_adecl_template, "1")
      if param1.endswith("us"):
        param1 += "<2>"
        gspec = ""
      elif param1.endswith("is"):
        param1 += "<3>"
        gspec = "|g=m"
      else:
        pagemsg("WARNING: Unrecognized ending on param1: %s" % param1)
        gspec = ""
      subsections[k] = ("".join(remaining_parts).rstrip('\n') +
        "\n\n%sNoun%s\n{{la-noun|%s%s}}\n\n%s\n%s=Declension=%s\n{{la-ndecl|%s}}\n\n" % (
          indent, indent, param1, gspec, "".join(defn_parts), indent, indent,
          param1))
    if not saw_adecl:
      pagemsg("WARNING: Saw no {{la-adecl}} in section")
    return "".join(subsections)

  # If there are multiple Etymology sections, split on them, otherwise do
  # whole section.
  has_etym_1 = "==Etymology 1==" in text
  if not has_etym_1:
    text = fix_up_section(text, "===")
  else:
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", text, 0, re.M)
    for k in xrange(2, len(etym_sections), 2):
      etym_sections[k] = fix_up_section(etym_sections[k], "====")
    text = "".join(etym_sections)

  pagemsg("------- begin text --------")
  msg(text.rstrip('\n'))
  msg("------- end text --------")

parser = blib.create_argparser("Lowercase adjectives from find_regex.py output")
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = codecs.open(args.direcfile, "r", "utf-8")

pagename_and_text = blib.yield_text_from_find_regex(lines, args.verbose)
for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
    get_name=lambda x:x[0]):
  process_page(index, pagename, text)
