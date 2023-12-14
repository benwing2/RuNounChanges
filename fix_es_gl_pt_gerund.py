#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site

lang_to_name = {
  "es": "Spanish",
  "gl": "Galician",
  "pt": "Portuguese",
}

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  langname = lang_to_name[args.lang]

  newtext = re.sub(r"(gerund|verb form\}\}\n)#", r"\1" + "\n#", text)
  if newtext != text:
    notes.append("insert missing newline after %s verb form/gerund headword" % langname)
    text = newtext

  parsed = blib.parse_text(text)

  headt = None

  for t in parsed.filter_templates():
    tn = tname(t)

    def getp(param):
      return getparam(t, param)

    if tn == "head" and getp("1") == args.lang and getp("2") == "verb form":
      if headt:
        pagemsg("WARNING: Saw two %s verb form head templates without {{%s-verb form of}}: %s and %s" % (
          langname, args.lang, str(headt), str(t)))
      headt = t
      continue

    verb_form_templates = ["gl-verb form of", "gl-reinteg-verb form of"] if args.lang == "gl" else [
      "%s-verb form of" % args.lang
    ]
    if tn in verb_form_templates:
      if headt is None:
        # Can happen, e.g. when the same verb form is a form of two different verbs
        continue
      conj = getp("1")
      if "((" in conj:
        pagemsg("WARNING: Unable to parse conjugation: %s" % conj)
        headt = None
        continue
      m = re.search("^(.*?)(<.*>)$", conj)
      if m:
        inf = m.group(1)
      else:
        inf = conj
      inf = re.sub("(se)?(-?l[aeo]s?)?$", "", inf)
      if len(inf) >= len(pagetitle):
        # mandar -> mando, hendir -> hiendo
        pagemsg("Skipping conjugation %s, not a gerund" % conj)
        headt = None
        continue
      headt.add("2", "gerund")
      notes.append("convert %s verb form headword to gerund for conjugation %s" % (langname, conj))
      headt = None

  if headt:
    pagemsg("WARNING: Saw %s verb form head template without {{%s-verb form of}}: %s" % (
      langname, args.lang, str(headt)))

  return str(parsed), notes

parser = blib.create_argparser("Fix Spanish, Galician or Portuguese gerunds to have {{head|LANG|gerund}}",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--lang", choices=list(lang_to_name.keys()), required=True, help="Code of lang to do.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["%s verb forms" % lang_to_name[args.lang]], skip_ignorable_pages=True)
