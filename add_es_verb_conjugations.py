#!/usr/bin/env python3
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
  pagename = str(page.title())
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
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  if pagename not in verbs:
    pagemsg("WARNING: Can't find entry, skipping")
    return

  entry = verbs[pagename]
  origentry = entry
  first, rest = pagename.split(" ", 1)
  restwords = rest.split(" ")
  def_link = "%s<> %s" % (first, " ".join("[[%s]]" % word for word in restwords))
  if def_link == entry:
    pagemsg("Replacing entry '%s' with a blank entry because it's the default" % entry)
    entry = ""
  elif re.sub("<.*?>", "<>", entry) == def_link:
    newentry = blib.remove_links(entry)
    pagemsg("Replacing entry '%s' with entry without links '%s'" % (entry, newentry))
    entry = newentry

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn == "es-verb":
      if not getparam(t, "attn"):
        pagemsg("Didn't see attn=1: %s" % str(t))
        continue
      rmparam(t, "attn")
      if entry:
        t.add("1", entry)
        notes.append("add conjugation '%s' to Spanish verb" % entry)
      else:
        notes.append("add conjugation (default) to Spanish verb")
    if tn == "head" and getparam(t, "1") == "es" and getparam(t, "2") == "verb":
      head = getparam(t, "head")
      if head:
        pagemsg("WARNING: Removing head=%s compared with entry '%s', original entry '%s': %s" %
            (head, entry, origentry, str(t)))
        rmparam(t, "head")
      rmparam(t, "2")
      rmparam(t, "1")
      blib.set_template_name(t, "es-verb")
      if entry:
        t.add("1", entry)
        notes.append("convert {{head|es|verb}} to {{es-verb|%s}}" % entry)
      else:
        notes.append("convert {{head|es|verb}} to {{es-verb}}")
    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes


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
    origt = str(t)
    if tn == "es-verb":
      if not getparam(t, "attn"):
        pagemsg("Didn't see attn=1: %s" % str(t))
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
    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Add conjugations to Spanish verbs lacking them",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--direcfile", help="File of conjugated verbs")
parser.add_argument("--mode", choices=["full-conj", "single-word", "generate"], help="Operating mode. If 'full-conj', --direcfile contains full conjugations with <>. If 'single-word', --direcfile contains the first word followed by the conjugation of that word.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.mode == "full-conj":
  verbs = {}
  for lineno, line in blib.iter_items_from_file(args.direcfile, start, end):
    verb = blib.remove_links(re.sub("<.*?>", "", line))
    verbs[verb] = line
    def do_process_page(page, index, parsed=None):
      pagetitle = str(page.title())
      def pagemsg(txt):
        msg("Page %s %s: %s" % (index, pagetitle, txt))
      pagetext = blib.safe_page_text(page, pagemsg)
      return process_text_on_page_for_full_conj(index, pagetitle, pagetext, verbs)
    page = pywikibot.Page(site, verb)
    blib.do_edit(page, lineno, do_process_page, save=args.save, verbose=args.verbose, diff=args.diff)
elif args.mode == "generate":
  verbs = {}
  for lineno, line in blib.yield_items_from_file(args.direcfile, include_original_lineno=True):
    if " " not in line:
      errandmsg("Line %s: WARNING: No space in line: %s" % (lineno, line))
      continue
    verb, spec = line.split(" ", 1)
    verbs[verb] = spec
  def do_process_page(page, index):
    return process_page_for_generate(page, index, verbs)
  blib.do_pagefile_cats_refs(args, start, end, do_process_page)
else:
  for lineno, line in blib.iter_items_from_file(args.direcfile, start, end):
    if " " not in line:
      errandmsg("Line %s: WARNING: No space in line: %s" % (lineno, line))
      continue
    verb, spec = line.split(" ", 1)
    page = pywikibot.Page(site, verb)
    if not page.exists():
      errandmsg("Page %s %s: WARNING: Page doesn't exist" % (lineno, verb))
    else:
      def do_process_page(page, index, parsed=None):
        pagetitle = str(page.title())
        def pagemsg(txt):
          msg("Page %s %s: %s" % (index, pagetitle, txt))
        pagetext = blib.safe_page_text(page, pagemsg)
        return process_text_on_page_for_single_word(index, pagetitle, pagetext, spec)
      blib.do_edit(page, lineno, do_process_page, save=args.save, verbose=args.verbose, diff=args.diff)
