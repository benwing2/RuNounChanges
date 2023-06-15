#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

borrowed_langs = {}

#templates_to_process = ["given name", "surname"]
#templates_to_process = ["rfdatek", "rfquotek"]
#templates_to_process = ["rfdate"] # requires --lang-as-1
#templates_to_process = ["rfc-header", "tea room"]
#templates_to_process = ["rfc"] # requires --lang-as-1
#templates_to_process = ["SeeCites", "seecites"]
templates_to_rename = {
  "SeeCites": "seeCites",
  "seecites": "seeCites",
}
#templates_to_process = ["elements"]
#templates_to_process = ["abbreviated", "cuneiform", "patronymic", "IPA letters",
#  "seeSynonyms", "SI-unit"]
templates_to_process = ["SI-unit-np"]
blib.getData()

def process_page(page, index, parsed, lang_in_1):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if blib.page_should_be_ignored(pagetitle):
    pagemsg("Skipping ignored page")
    return None, None

  langparam = "1" if lang_in_1 else "lang"
      
  def hack_templates(parsed, langname, langnamecode=None, is_citation=False):
    if langname not in blib.languages_byCanonicalName:
      if not is_citation:
        langnamecode = None
    else:
      langnamecode = blib.languages_byCanonicalName[langname]["code"]

    for t in parsed.filter_templates():
      origt = unicode(t)
      tn = tname(t)
      if tn in ["citation", "citations"] and is_citation:
        langnamecode = getparam(t, "lang") or getparam(t, "1")
      if tn in templates_to_process:
        if getparam(t, langparam):
          pass
        elif not langnamecode:
          pagemsg("WARNING: Unrecognized language %s, unable to add language to %s" % (langname, origt))
        else:
          notes.append("infer %s=%s for {{%s}} based on section it's in" % (
            langparam, langnamecode, tn))
          newline = "\n" if "\n" in unicode(t.name) else ""
          if langparam == "1":
            if t.has("lang"):
              pagemsg("WARNING: Template has lang=, removing: %s" % origt)
              notes.append("remove lang= from {{%s}}" % tn)
              rmparam(t, "lang")
            t.add(langparam, langnamecode + newline, preserve_spacing=False)
          else:
            # Fetch all params.
            params = []
            for param in t.params:
              pname = unicode(param.name)
              params.append((pname, param.value, param.showkey))
            # Erase all params.
            del t.params[:]
            t.add(langparam, langnamecode + newline, preserve_spacing=False)
            # Put remaining parameters in order.
            for name, value, showkey in params:
              t.add(name, value, showkey=showkey, preserve_spacing=False)
      if tn in templates_to_rename:
        blib.set_template_name(t, templates_to_rename[tn])
        notes.append("rename {{%s}} to {{%s}}" % (tn, templates_to_rename[tn]))
      newt = unicode(t)
      if newt != origt:
        pagemsg("Replaced <%s> with <%s>" % (origt, newt))

    return langnamecode

  pagemsg("Processing")

  text = unicode(page.text)
  notes = []

  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  if not pagetitle.startswith("Citations"):
    for j in range(2, len(sections), 2):
      m = re.search("^==(.*)==\n$", sections[j - 1])
      assert m
      langname = m.group(1)
      parsed = blib.parse_text(sections[j])
      hack_templates(parsed, langname)
      sections[j] = unicode(parsed)
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
      langnamecode = hack_templates(parsed, langname,
          langnamecode=langnamecode, is_citation=True)
      sections[j] = unicode(parsed)

  newtext = "".join(sections)
  return newtext, notes

parser = blib.create_argparser("Add language to templates, based on the section they're within",
  include_pagefile=True)
parser.add_argument("--lang-in-1", action="store_true", help="Add language in 1= instead of lang=")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def do_process_page(page, index, parsed):
  return process_page(page, index, parsed, args.lang_in_1)

blib.do_pagefile_cats_refs(args, start, end, do_process_page, edit=True,
  default_refs=["Template:%s" % template for template in templates_to_process])
