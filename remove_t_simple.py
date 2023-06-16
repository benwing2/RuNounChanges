#!/usr/bin/env python
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
    if tn == "t-simple":
      interwiki = getparam(t, "interwiki")
      rmparam(t, "interwiki")
      rmparam(t, "langname")
      g = getparam(t, "g")
      rmparam(t, "g")
      if g:
        t.add("3", g)
      if t.has("3") and not getparam(t, "3"):
        rmparam(t, "3")
      lang = getparam(t, "1")
      link = getparam(t, "2")
      alt = getparam(t, "alt")
      trans = alt or link
      tr = getparam(t, "tr")
      if tr and lang and trans and not args.no_remove_redundant_translit:
        autotr = expand_text("{{xlit|%s|%s}}" % (lang, trans))
        if autotr and autotr == tr:
          pagemsg("Removing redundant translit %s of %s for lang %s" % (tr, trans, lang))
          rmparam(t, "tr")
          notes.append("remove redundant translit from {{t-simple}}")
      if alt and link:
        autolink = expand_text("{{#invoke:languages/templates|makeEntryName|%s|%s}}" % (lang, alt))
        if autolink and autolink == link:
          pagemsg("Removing redundant alt form %s of %s for lang %s" % (alt, link, lang))
          t.add("2", alt)
          rmparam(t, "alt")
          notes.append("move redundant alt= to 2= in {{t-simple}}")
      if interwiki:
        tempname = "t+"
      else:
        tempname = "t"
      blib.set_template_name(t, tempname)
      notes.append("convert {{t-simple}} to {{%s}}" % tempname)

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{t-simple}} to {{t}} or {{t+}}",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--no-remove-redundant-translit", help="Don't remove redundant transliterations",
    action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
