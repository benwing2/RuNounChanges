#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

add_stress = {
  "a": u"á",
  "e": u"é",
  "i": u"í",
  "o": u"ó",
  "u": u"ú",
}

vowel = u"aeiouáéíóúý"
V = "[" + vowel + "]"
C = "[^" + vowel + "]"

def singularize(word):
  if not word.endswith("s") or len(re.sub("[^aeiou]", "", word)) <= 1 or re.search(u"[áéíóúiu]s$", word):
    # not a plural
    return "[[%s]]" % word
  if re.search(V + "[ns]es$", word):
    if re.search(u"[áéíóúý]", word) or len(re.sub("[^aeiou]", "", word)) <= 2:
      return "[[%s]]es" % word[:-2]
    # need to add an accent in the singular
    return "[[%s%s%s|%s]]" % (word[:-4], add_stress[word[-4]], word[-3], word)
  if re.search(V + "ces$", word):
    return "[[%sz|%s]]" % (word[:-3], word)
  if re.search(V + "[rld]es$", word):
    return "[[%s]]es" % word[:-2]
  return "[[%s]]s" % word[:-1]

def process_page_for_generate(page, index, verbs):
  pagename = unicode(page.title())
  def pagemsg(txt):
    msg("# Page %s %s: %s" % (index, pagename, txt))
  if " " not in pagename:
    pagemsg("WARNING: No space in page title")
    return
  if pagename.startswith("no "):
    prefix, verb_rest = pagename.split(" ", 1)
    if " " in verb_rest:
      verb, rest = verb_rest.split(" ", 1)
    else:
      verb = verb_rest
      rest = ""
    prefix = prefix + " "
  else:
    verb, rest = pagename.split(" ", 1)
    prefix = ""
  if verb not in verbs:
    pagemsg("WARNING: Unrecognized verb '%s'" % verb)
    return
  linked_rest = " ".join(singularize(x) for x in rest.split(" "))
  spec = verbs[verb]
  if spec == "*":
    spec = "<>"
  msg("%s%s%s %s" % (prefix, verb, spec, linked_rest))

def process_text_on_page_for_full_conj(index, pagename, text, verbs):
  pass

def process_text_on_page_for_single_word(index, pagename, text, spec):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = unicode(t)
    if tn == "es-verb":
      if not getparam(t, "attn"):
        pagemsg("Didn't see attn=1: %s" % unicode(t))
        continue
      rmparam(t, "attn")
      if "<" in spec:
        t.add("1", "%s%s" % (pagename, spec))
        notes.append("add conjugation %s%s to Spanish verb" % (pagename, spec))
      elif spec == "*":
        notes.append("add conjugation (default) to Spanish verb")
      else:
        t.add("pres", spec)
        notes.append("add conjugation pres=%s to Spanish verb" % spec)
    if origt != unicode(t):
      pagemsg("Replaced %s with %s" % (origt, unicode(t)))

  return unicode(parsed), notes

parser = blib.create_argparser("Add conjugations to Spanish verbs lacking them",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--direcfile", help="File of conjugated verbs")
parser.add_argument("--mode", choices=["full-conj", "single-word", "generate"], help="Operating mode. If 'full-conj', --direcfile contains full conjugations with <>. If 'single-word', --direcfile contains the first word followed by the conjugation of that word.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

assert args.mode != "full-conj", "'--mode full-conj' not yet supported"

if args.mode == "full-conj":
  verbs = {}
  for line in codecs.open(args.direcfile, "r", encoding="utf-8"):
    line = line.strip()
    if line.startswith("#"):
      continue
    verb = re.sub("<.*?>", "", line)
    verbs[verb] = line
  def do_process_text_on_page(index, pagename, text):
    return process_text_on_page_for_full_conj(index, pagename, text, verbs)
  blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page, edit=True, stdin=True)
elif args.mode == "generate":
  verbs = {}
  for line in codecs.open(args.direcfile, "r", encoding="utf-8"):
    line = line.strip()
    if line.startswith("#"):
      continue
    if " " not in line:
      errandmsg("WARNING: No space in line: %s" %  line)
      continue
    verb, spec = line.split(" ", 1)
    verbs[verb] = spec
  def do_process_page(page, index):
    return process_page_for_generate(page, index, verbs)
  blib.do_pagefile_cats_refs(args, start, end, do_process_page)
else:
  lineno = 0
  for line in codecs.open(args.direcfile, "r", encoding="utf-8"):
    lineno += 1
    line = line.strip()
    if line.startswith("#"):
      continue
    if " " not in line:
      errandmsg("WARNING: No space in line: %s" %  line)
      continue
    verb, spec = line.split(" ", 1)
    page = pywikibot.Page(site, verb)
    if not page.exists():
      errandmsg("WARNING: Page %s doesn't exist" % verb)
    else:
      def do_process_page(page, index, parsed=None):
        pagetitle = unicode(page.title())
        def pagemsg(txt):
          msg("Page %s %s: %s" % (index, pagetitle, txt))
        pagetext = blib.safe_page_text(page, pagemsg)
        return process_text_on_page_for_single_word(index, pagetitle, pagetext, spec)
      blib.do_edit(page, lineno, do_process_page, save=args.save, verbose=args.verbose, diff=args.diff)
