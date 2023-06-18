#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_text_on_page(index, pagetitle, pagetext, subs):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if not args.stdin:
    pagemsg("Processing")

  notes = []

  def frob(value, wherefrom):
    for refrom, reto in subs:
      newvalue = re.sub(refrom, reto, value)
      if newvalue != value:
        notes.append("replace '%s' -> '%s' in %s" % (refrom, reto, wherefrom))
        return newvalue
    return value

  def frobparam(t, param):
    value = getparam(t, param)
    if value:
      newvalue = frob(value, "{{%s|%s=}}" % (tname(t), param))
      if newvalue != value:
        t.add(param, newvalue)

  parsed = blib.parse_text(pagetext)
  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    origt = str(t)
    tn = tname(t)
    if tn in ["R:wsource"]:
      frobparam(t, "2")
      frobparam(t, "dab")
    elif tn in ["wsource"]:
      frobparam(t, "1")
    elif tn in ["wikisource"]:
      frobparam(t, "1")
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  pagetext = str(parsed)
  newpagetext = re.sub(r"url=(\[(s|wikisource):.*?\])", lambda m: "urls=[%s]" % m.group(1).replace("{{!}}", "|"), pagetext)
  if newpagetext != pagetext:
    notes.append("convert url=(hacked-up Wikisource link) to urls=(proper Wikisouce link)")
    pagetext = newpagetext
  newpagetext = pagetext
  newpagetext = re.sub(r"\[\[(s|wikisource):([^][|]*?)\]\]", lambda m: "[[%s:%s]]" % (m.group(1), frob(m.group(2).replace("_", " "), "[[%s:...]]" % m.group(1))), newpagetext)
  newpagetext = re.sub(r"\[\[(s|wikisource):([^][|]*?)\|([^][|]*?)\]\]", lambda m: "[[%s:%s|%s]]" %
      (m.group(1), frob(m.group(2).replace("_", " "), "[[%s:...]]" % m.group(1)), m.group(3)), newpagetext)
  if newpagetext != pagetext and not notes:
    notes.append("convert _ to space in [[s:...]]/[[wikisource:...]]")
  pagetext = newpagetext

  return pagetext, notes
  
parser = blib.create_argparser(u"Fix broken Wikisource links", include_pagefile=True, include_stdin=True)
parser.add_argument("--direcfile", help="File containing regex substitutions of the form 'FROM ||| TO'", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

subs = []
for lineno, line in blib.iter_items_from_file(args.direcfile, start, end):
  refrom, reto = line.split(" ||| ")
  subs.append((refrom, reto))

def do_process_text_on_page(index, pagetitle, text):
  return process_text_on_page(index, pagetitle, text, subs)

blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page, edit=True, stdin=True)
