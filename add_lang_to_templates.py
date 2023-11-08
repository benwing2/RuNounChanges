#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

blib.getData()

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if blib.page_should_be_ignored(pagetitle):
    pagemsg("Skipping ignored page")
    return

  notes = []

  def hack_templates(parsed, langname, langnamecode=None, is_citation=False):
    if langname not in blib.languages_byCanonicalName:
      if not is_citation:
        langnamecode = None
    else:
      langnamecode = blib.languages_byCanonicalName[langname]["code"]

    for t in parsed.filter_templates():
      origt = str(t)
      tn = tname(t)
      if tn in templates_to_process:
        existing_lang = getparam(t, "lang")
        if existing_lang:
          notes.append("move lang= to 1= in {{%s}}" % tn)
          new_lang = existing_lang
        elif langnamecode is None:
          pagemsg("WARNING: Unable to add infer language from section for template: %s" % origt)
          continue
        else:
          notes.append("infer 1=%s for {{%s}} based on section it's in" % (langnamecode, tn))
          new_lang = langnamecode
        newline = "\n" if "\n" in str(t.name) else ""
        # Fetch all params.
        params = []
        for param in t.params:
          pn = pname(param)
          pv = str(param.value)
          if re.search("^[0-9]+$", pn):
            pn = str(int(pn) + 1)
          params.append((pn, pv, param.showkey))
        # Erase all params.
        del t.params[:]
        t.add("1", new_lang + newline, preserve_spacing=False)
        # Put remaining parameters in order.
        for name, value, showkey in params:
          t.add(name, value, showkey=showkey, preserve_spacing=False)
        if tn != templates_to_process[tn]:
          blib.set_template_name(t, templates_to_process[tn])
          notes.append("rename {{%s}} to {{%s}}" % (tn, templates_to_process[tn]))
      newt = str(t)
      if newt != origt:
        pagemsg("Replaced <%s> with <%s>" % (origt, newt))

    return langnamecode

  pagemsg("Processing")

  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  if not pagetitle.startswith("Citations"):
    for j in range(2, len(sections), 2):
      m = re.search("^==(.*)==\n$", sections[j - 1])
      assert m
      langname = m.group(1)
      parsed = blib.parse_text(sections[j])
      hack_templates(parsed, langname)
      sections[j] = str(parsed)
  else:
    # Citation section?
    langnamecode = None
    for j in range(0, len(sections), 2):
      if j == 0:
        langname = "Unknown"
      else:
        m = re.search("^==(.*)==\n$", sections[j - 1])
        assert m
        langname = m.group(1)
      parsed = blib.parse_text(sections[j])
      langnamecode = hack_templates(parsed, langname, langnamecode=langnamecode, is_citation=True)
      sections[j] = str(parsed)

  newtext = "".join(sections)
  return newtext, notes

parser = blib.create_argparser("Add language to templates, based on the section they're within",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--from", help="Old name of template; multiple comma-separated templates can be given",
    metavar="FROM", dest="from_", required=True)
parser.add_argument("--to", help="New name of template; multiple comma-separated templates can be given",
    required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

from_templates = args.from_.split(",")
to_templates = args.to.split(",")

if len(from_templates) != len(to_templates):
  raise ValueError("Saw %s template(s) '%s' but %s new name(s) '%s'; both must agree in number" % (
      (len(from_templates), ",".join(from_templates), len(to_templates), ",".join(to_templates))))
templates_to_process_list = list(zip(from_templates, to_templates))
templates_to_process = dict(templates_to_process_list)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:%s" % template for template, new_name in templates_to_process_list])
