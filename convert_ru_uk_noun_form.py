#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Convert {{ru-noun form}} and {{uk-noun form}} to use {{head}}.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, pagetext):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []
  parsed = blib.parse_text(pagetext)
  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    if tn == "ru-noun form":
      lang = "ru"
    elif tn == "uk-noun form":
      lang = "uk"
    else:
      continue
    head = None
    named_params = []
    must_continue = False
    for param in t.params:
      pn = pname(param)
      pv = str(param.value)
      if pn in ["1", "head"]:
        if head is not None:
          pagemsg("WARNING: Saw both 1= and head=, skipping: %s" % str(t))
          must_continue = True
          break
        head = pv
      elif pn == "2":
        named_params.append(("g", pv))
      elif re.search("^(head|tr|g)[0-9]*$", pn):
        named_params.append((pn, pv))
      else:
        pagemsg("WARNING: Unrecognized param %s=%s, skipping; %s" % (pn, pv, str(t)))
        must_continue = True
        break
    if must_continue:
      continue
    origt = str(t)
    del t.params[:]
    blib.set_template_name(t, "head")
    t.add("1", lang)
    t.add("2", "noun form")
    if head:
      t.add("head", head)
    for k, v in named_params:
      t.add(k, v, preserve_spacing=False)
    newt = str(t)
    if origt != newt:
      pagemsg("Replace %s with %s" % (origt, newt))
      notes.append("convert {{%s}} to {{head|%s|noun form}} per [[WT:RFDO#Template:%s-noun form]]" % (tn, lang, lang))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{ru-noun form}} and {{uk-noun form}} to use {{head}}",
                               include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
                           default_refs=["Template:uk-noun form", "Template:ru-noun form"])
