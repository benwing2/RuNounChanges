#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

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
    elif tn in ["ja-readingcat", "ryu-readingcat"]:
      m = re.search("^Category:(Japanese|Okinawan) terms spelled with (.*?) read as (.*)$", pagetitle)
      if not m:
        pagemsg("WARNING: Can't parse page title")
        continue
      langname, kanji, reading = m.groups()
      if langname == "Japanese":
        auto_lang = "ja"
      else:
        auto_lang = "ryu"
      t_lang = re.sub("-.*", "", tn)
      if t_lang != auto_lang:
        pagemsg("WARNING: Auto-determined lang code %s for language name %s != template specified %s: %s" % (
          auto_lang, langname, t_lang, str(t)))
        continue
      t_kanji = getparam(t, "1").strip()
      t_reading = getparam(t, "2").strip()
      if t_kanji != kanji:
        pagemsg("WARNING: Auto-determined kanji %s != template specified %s: %s" % (kanji, t_kanji, str(t)))
        continue
      if t_reading != reading:
        pagemsg("WARNING: Auto-determined reading %s != template specified %s: %s" % (reading, t_reading, str(t)))
        continue
      numbered_params = []
      must_continue = False
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn in ["1", "2"]:
          pass
        elif re.search("^[0-9]+$", pn):
          numbered_params.append(pv)
        else:
          pagemsg("WARNING: Saw unknown non-numeric param %s=%s, skipping: %s" % (pn, pv, str(t)))
          must_continue = True
          break
      if must_continue:
        continue
      if len(numbered_params) == 0:
        pagemsg("WARNING: No reading types given, skipping: %s" % str(t))
        continue
      blib.set_template_name(t, "auto cat")
      del t.params[:]
      for index, numbered_param in enumerate(numbered_params):
        t.add(str(index + 1), numbered_param, preserve_spacing=False)
      notes.append("convert {{%s}} to {{auto cat}}" % tn)

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{ja-readingcat}}/{{ryu-readingcat}} to {{auto cat}}",
    include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_refs=["Template:ja-readingcat", "Template:ryu-readingcat"], edit=True, stdin=True)
