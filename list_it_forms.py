#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json, unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site

AC = "\u0301"
GR = "\u0300"

def list_forms(template, errandpagemsg, expand_text):
  template = re.sub(r"\}\}$", "|json=1}}", template)
  forms = expand_text(template)
  if not forms:
    errandpagemsg("WARNING: Error generating forms, skipping: %s" % template)
    return None
  forms = json.loads(forms)["forms"]
  infinitive = forms["inf"][0]["form"]
  infinitive = unicodedata.normalize("NFD", blib.remove_links(infinitive))
  # Remove non-final accents
  infinitive = re.sub("[" + AC + GR + "](.)", r"\1", infinitive)
  infinitive = unicodedata.normalize("NFC", infinitive)
  for key, values in forms.items():
    for v in values:
      linktext = []
      displaytext = []
      parts = re.split(r"(\[\[.*?\]\])", v["form"])
      for i, part in enumerate(parts):
        if i % 2 == 0:
          linktext.append(part)
          displaytext.append(part)
        elif "|" in part:
          link, display = part[2:-2].split("|")
          linktext.append(link)
          displaytext.append(display)
        else:
          link = part[2:-2]
          linktext.append(link)
          displaytext.append(link)
      msg("%s\t%s\t%s\t%s" % (infinitive, key, "".join(linktext), "".join(displaytext)))

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "it-conj":
      pagename = getparam(t, "pagename") or pagetitle
      def expand_text(tempcall):
        return blib.expand_text(tempcall, pagename, pagemsg, args.verbose)
      list_forms(getparam(t, "1"), errandpagemsg, expand_text)

parser = blib.create_argparser("List all forms of a verb",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--direcfile", help="File listing conjugations.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.direcfile:
  for lineno, line in blib.yield_items_from_file(args.direcfile, include_original_lineno=True):
    t = list(blib.parse_text(line).filter_templates())[0]
    pagetitle = getparam(t, "pagename") or "NONE"
    def pagemsg(txt):
      msg("Page %s %s: %s" % (lineno, pagetitle, txt))
    def errandpagemsg(txt):
      errandmsg("Page %s %s: %s" % (lineno, pagetitle, txt))
    def expand_text(tempcall):
      return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
    list_forms(line, errandpagemsg, expand_text)
else:
  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
