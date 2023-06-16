#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Convert {{quote-Fanny Hill|part=2|[passage]}} → {{RQ:Cleland Fanny Hill|passage=[passage]}}.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []
  for t in parsed.filter_templates():
    if tname(t) == "RQ:Don Quixote" and getparam(t, "lang").strip() == "fr":
      origt = str(t)
      blib.set_template_name(t, "RQ:Cervantes Viardot Don Quichotte")
      rmparam(t, "lang")
      volume = getparam(t, "volume").strip()
      rmparam(t, "volume")
      if volume == "2":
        volume = "II"
      if not volume:
        volume = "I"
      chapter = getparam(t, "chapter").strip()
      rmparam(t, "chapter")
      text = getparam(t, "text").strip() or getparam(t, "passage").strip()
      rmparam(t, "text")
      rmparam(t, "passage")
      translation = getparam(t, "t").strip() or getparam(t, "translation").strip()
      rmparam(t, "t")
      rmparam(t, "translation")
      # Fetch all params.
      numbered_params = []
      named_params = []
      for param in t.params:
        pname = str(param.name)
        if re.search("^[0-9]+$", pname):
          numbered_params.append((pname, param.value, param.showkey))
        else:
          named_params.append((pname, param.value, param.showkey))
      # Erase all params.
      del t.params[:]
      # Put numbered params in order.
      for name, value, showkey in numbered_params:
        t.add(name, value, showkey=showkey, preserve_spacing=False)
      t.add("volume", volume)
      if chapter:
        t.add("chapter", chapter)
      if text:
        t.add("text", text)
      if translation:
        t.add("t", translation)
      # Put named params in order.
      for name, value, showkey in named_params:
        t.add(name, value, showkey=showkey, preserve_spacing=False)
      notes.append("Replace {{RQ:Don Quixote}} with {{RQ:Cervantes Viardot Don Quichotte}}")
      newt = str(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))

  return parsed, notes

parser = blib.create_argparser(u"Convert {{RQ:Don Quixote}} to {{RQ:Cervantes Viardot Don Quichotte}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.references("Template:RQ:Don Quixote", start, end):
  blib.do_edit(page, i, process_page, save=args.save, verbose=args.verbose)
