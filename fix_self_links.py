#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  origtext = text
  notes = []

  def fix_sec_self_links(sectext):
    template_split_re = r'''(\{\{(?:[^{}]|\{\{[^{}]*\}\})*\}\})'''
    lines = sectext.split("\n")
    new_lines = []
    changed = False
    for line in lines:
      if line.startswith("#"):
        # Split templates and only change non-template text
        split_templates = re.split(template_split_re, line)
        for l in xrange(0, len(split_templates), 2):
          while True:
            newtext = re.sub(r"^#(.*?)\[\[%s\]\]" % pagetitle, r"#\1[[#English|%s]]" % pagetitle, split_templates[l], 0, re.M)
            if newtext == split_templates[l]:
              break
            changed = True
            split_templates[l] = newtext
        line = "".join(split_templates)
      new_lines.append(line)
    if changed:
      notes.append("fix raw self links to English terms")
    return "\n".join(new_lines)

  if args.lang:
    retval = blib.find_modifiable_lang_section(text, args.lang, pagemsg)
    if retval is None:
      pagemsg("WARNING: Couldn't find %s section" % args.lang)
      return
    sections, j, secbody, sectail, has_non_lang = retval

    secbody = fix_sec_self_links(secbody)
    sections[j] = secbody + sectail
    text = "".join(sections)
  else:
    text = fix_sec_self_links(text)

  return text, notes

parser = blib.create_argparser("Fix raw self links to English terms on the same page",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--lang", help="Language to do (optional)")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
