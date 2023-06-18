#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  origtext = text
  notes = []
  def templatize_masc_fem_line(m):
    mm = re.search(r"^(.*)\{\{(it-noun\|.*?)\}\}[(' ]*([Mm]asculine|[Ff]eminine|[Mm]asculine of|[Ff]eminine of|[Ff]emale)[': ]*(\[\[[^\[\]{}\n]*?\]\]|\{\{[lm]\|it\|[^\[\]{}\n]*?\}\})[)' ]*$",
      m.group(0))
    if not mm:
      pagemsg("WARNING: Unable to parse line: <from> %s <to> %s <end>" % (m.group(0), m.group(0)))
      return m.group(0)
    pre_text, template, gender, gender_term = mm.groups()
    mmm = re.search(r"^\{\{[lm]\|it\|(.*)\}\}$", gender_term)
    if mmm:
      term = mmm.group(1)
    else:
      mmm = re.search(r"^\[\[(?:.*\|)?(.*)\]\]$", gender_term)
      if mmm:
        term = mmm.group(1)
      else:
        pagemsg("WARNING: Can't parse other-gender text <%s> in line: <from> %s <to> %s <end>" %
          (gender_text, m.group(0), m.group(0)))
        return m.group(0)
    gender = gender.lower()
    if gender in ["feminine", "female", "masculine of"]:
      gender = "feminine"
      param = "f"
    else:
      gender = "masculine"
      param = "m"
    notes.append("templatize %s equivalent %s into {{it-noun}}" % (
      gender, term))
    retval = "%s{{%s|%s=%s}}" % (pre_text, template, param, term)
    pagemsg("Replaced <%s> with <%s>" % (m.group(0), retval))
    return retval

  text = re.sub(r"^.*\{\{it-noun\|.*?\}\}.*(masculine|feminine).*$", templatize_masc_fem_line, text, 0, re.M)
  return text, notes

parser = blib.create_argparser("Templatize 'masculine/feminine' into {{it-noun}}",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
