#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

blib.getData()

def one_char(t):
  return len(t) == 1 or len(t) == 2 and 0xD800 <= ord(t[0]) <= 0xDBFF

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "autocat":
      blib.set_template_name(t, "auto cat")
      notes.append("{{autocat}} -> {{auto cat}}")
    elif tn == "charactercat":
      m = re.search("^Category:(.*) terms spelled with (.*)$", pagetitle)
      if not m:
        pagemsg("WARNING: Can't parse page title")
        continue
      langname, char = m.groups()
      t_lang = getparam(t, "1")
      t_char = getparam(t, "2")
      t_alt = getparam(t, "alt")
      t_sort = getparam(t, "sort")
      t_context = getparam(t, "context")
      t_context2 = getparam(t, "context2")
      if langname not in blib.languages_byCanonicalName:
        pagemsg("WARNING: Unrecognized language name: %s" % langname)
        continue
      if not t_lang:
        t_lang = blib.languages_byCanonicalName[langname]["code"]
      elif blib.languages_byCanonicalName[langname]["code"] != t_lang:
        pagemsg("WARNING: Auto-determined code %s for language name %s != manually specified %s" % (
          blib.languages_byCanonicalName[langname]["code"], langname, t_lang))
        continue
      if t_char == char:
        t_char = None
      if langname in ["Japanese", "Okinawan"]:
        if not one_char(char):
          pagemsg("WARNING: Japanese/Okinawan category with multichar character (length %s), skipping: %s" % (len(char), str(t)))
          continue
        if t_char:
          pagemsg("WARNING: Japanese/Okinawan category with manual char %s != automatic char: %s" % (t_char, str(t)))
        if not t_sort:
          pagemsg("WARNING: Japanese/Okinawan category without manual sort key: %s" % str(t))
        else:
          autosort = expand_text("{{#invoke:zh-sortkey/templates|sortkey|%s|%s}}" % (t_char or char, t_lang))
          if autosort == t_sort:
            t_sort = None
          else:
            pagemsg("WARNING: Japanese/Okinawan category with manual sort key %s != automatic %s: %s" % (t_sort, autosort, str(t)))
      elif t_sort:
        autosort = expand_text("{{#invoke:languages/templates|getByCode|%s|makeSortKey|%s}}" % (t_lang, t_char or char))
        if autosort == t_sort:
          t_sort = None
        else:
          pagemsg("%s category with manual sort key %s != automatic %s: %s" % (langname, t_sort, autosort, str(t)))

      must_continue = False
      all_existing_params = ["1", "2", "alt", "sort", "context", "context2"]
      for param in t.params:
        pn = pname(param)
        if pn not in all_existing_params:
          pagemsg("WARNING: Unrecognized param %s=%s in charactercat: %s" % (pn, str(param.value), str(t)))
          must_continue = True
          break
      if must_continue:
        continue
      for param in all_existing_params:
        rmparam(t, param)
      blib.set_template_name(t, "auto cat")
      if t_char:
        t.add("char", t_char)
      if t_alt:
        t.add("alt", t_alt)
      if t_sort:
        t.add("sort", t_sort)
      if t_context:
        t.add("context", t_context)
      if t_context2:
        t.add("context2", t_context2)
      notes.append("convert {{%s}} to {{auto cat}}" % tn)

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{charactercat}} to {{auto cat}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
