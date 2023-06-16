#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

name_templates = ["surname", "given name"]
name_template_re = "(?:%s)" % "|".join(name_templates)

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  origtext = text
  notes = []

  if blib.page_should_be_ignored(pagetitle):
    return

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in name_templates:
      origt = str(t)
      def getp(param):
        return getparam(t, param).strip()
      lang = getp("1")
      aval = getp("A")
      if lang != "en":
        if aval in ["A", "a", "An", "an"]:
          pagemsg("Remove redundant article A=%s in {{%s|%s}}: %s" % (aval, tn, lang, str(t)))
          notes.append("remove redundant article A=%s in {{%s|%s}}" % (aval, tn, lang))
          rmparam(t, "A")
        else:
          m = re.search("^(A|An) +(.*)$", aval)
          if m:
            pagemsg("Change explicit article A=%s to lowercase in non-English {{%s|%s}}: %s" % (aval, tn, lang, str(t)))
            notes.append("change explicit article A=%s to lowercase in non-English {{%s|%s}}" % (aval, tn, lang))
            aval = "a" + aval[1:]
            t.add("A", aval)

      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  text = str(parsed)
  lines = text.split("\n")
  for lineno, line in enumerate(lines):
    if re.search(r"\{\{%s\|" % name_template_re, line):
      parsed = blib.parse_text(line)
      lang = None
      namet = None
      must_continue = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn in name_templates:
          def getp(param):
            return getparam(t, param).strip()
          if lang is not None:
            pagemsg("WARNING: Saw more than one {{surname}}/{{given name}} template on line: <from> %s <to> %s <end>" %
                (line, line))
            must_continue = True
            break
          lang = getp("1")
          namet = t
      if must_continue:
        continue
      if lang is None:
        pagemsg("WARNING: No templates on line with {{surname}}/{{given name}}?: %s" % line)
        continue
      if lang != "en":
        origline = line
        line = line.strip()
        if line.endswith(".") and not line.endswith("etc."):
          line = line[:-1]
          pagemsg("Replaced line #%s <%s> with <%s>" % (lineno + 1, origline, line))
          lines[lineno] = line
          notes.append("remove final dot from non-English {{%s|%s}} line" % (tn, lang))
      m = re.search(r"^(#\s*)\{\{[lm]\|([^{}|]*)\|([^{}|]*)\}\}[;:,]\s*(\{\{%s\|([^{}|]*)[^{}]*)\}\}(.*)$" % name_template_re,
          line)
      if m:
        beginning, en_lang, en_name, name_template, name_lang, rest = m.groups()
        name_lang = name_lang.strip()
        en_lang = en_lang.strip()
        if name_lang == "en":
          pagemsg("WARNING: Saw English {{surname}}/{{given name}} line with English-equivalent name: <from> %s <to> %s <end>" %
              (line, line))
          continue
        if name_lang == en_lang:
          pagemsg("WARNING: Saw non-English {{surname}}/{{given name}} line with English-equivalent name using the same language '%s', assuming should be English: %s" %
            (en_lang, line))
          en_lang = "en"
        if en_lang == "en":
          xlit_param = "xlit"
          xlit = en_name
        else:
          xlit_param = "eq"
          xlit = "%s:%s" % (en_lang, en_name)
        if namet.has(xlit_param):
          pagemsg("WARNING: Would incorporate English or other-language borrowing '%s' as %s=%s but param already exists: %s" %
            (en_name, xlit_param, xlit, line))
          continue
        origline = line
        line = "%s%s|%s=%s}}%s" % (beginning, name_template, xlit_param, xlit, rest)
        pagemsg("Replaced line #%s <%s> with <%s>" % (lineno + 1, origline, line))
        lines[lineno] = line
        notes.append("incorporate English or other-language borrowing '%s' of non-English {{%s|%s}} line" %
          (en_name, tn, lang))
        parsed = blib.parse_text(line)

      templates = list(parsed.filter_templates())
      if len(templates) == 2 and tname(templates[0]) in ["lb", "label"] and tname(templates[1]) in name_templates:
        # this is common enough and should remain
        continue
      if len(templates) > 1:
        pagemsg("WARNING: Saw multiple templates on line with {{surname}}/{{given name}}: <from> %s <to> %s <end>" %
            (line, line))

  text = "\n".join(lines)

  return text, notes

parser = blib.create_argparser("Do basic clean up of {{surname}} and {{given name}}, removing redundant articles and final periods", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_refs=["Template:surname", "Template:given name"],
  edit=True, stdin=True)
