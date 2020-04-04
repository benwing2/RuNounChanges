#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import find_regex

pos_to_headword_template = {
  "noun": "bg-noun",
  "proper noun": "bg-proper noun",
  "verb": "bg-verb",
  "adjective": "bg-adj",
}

pos_to_new_style_infl_template = {
  "noun": "bg-ndecl",
  "proper noun": "bg-ndecl",
  "verb": "bg-conj",
  "adjective": "bg-adecl",
}

pos_to_old_style_infl_template_prefix = {
  "noun": "bg-noun-",
  "proper noun": "bg-decl-noun",
  "verb": None,
  "adjective": None,
}

def get_indentation_level(header):
  return len(re.sub("[^=].*", "", header, 0, re.S))

def process_page(index, pagetitle, text, pos):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  cappos = pos.capitalize()
  notes = []

  pagemsg("Processing")

  # Extract off trailing separator
  mm = re.match(r"^(.*?\n)(\n*--+\n*)$", text, re.S)
  if mm:
    secbody, sectail = mm.group(1), mm.group(2)
  else:
    secbody = text
    sectail = ""

  # Split off categories at end
  mm = re.match(r"^(.*?\n)(\n*(\[\[Category:[^\]]+\]\]\n*)*)$",
      secbody, re.S)
  if mm:
    secbody, secbodytail = mm.group(1), mm.group(2)
    sectail = secbodytail + sectail

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
  k = 1
  last_pos = None
  while k < len(subsections):
    if re.search(r"=\s*%s\s*=" % cappos, subsections[k]):
      level = get_indentation_level(subsections[k])
      last_pos = cappos
      endk = k + 2
      while endk < len(subsections) and get_indentation_level(subsections[endk]) > level:
        endk += 2
      pos_text = "".join(subsections[k:endk])
      parsed = blib.parse_text(pos_text)
      head = None
      inflt = None
      found_bg_pre_reform = False
      for t in parsed.filter_templates():
        tn = tname(t)
        newhead = None
        if tn == pos_to_headword_template[pos]:
          newhead = getparam(t, "1")
        elif tn == "head" and getparam(t, "1") == "bg" and getparam(t, "2") in [pos, "%ss" % pos]:
          newhead = getparam(t, "head").strip() or pagetitle
        if newhead:
          if head:
            pagemsg("WARNING: Found two heads under one POS section: %s and %s" % (head, newhead))
          head = newhead
        if tn == pos_to_new_style_infl_template[pos] or (
            pos_to_old_style_infl_template_prefix[pos] and tn.startswith(pos_to_old_style_infl_template_prefix[pos])
        ):
          if inflt:
            pagemsg("WARNING: Found two inflection templates under one POS section: %s and %s" % (
              unicode(inflt), unicode(t)))
          inflt = t
          pagemsg("Found %s inflection for headword %s: %s" % (pos, head or pagetitle, unicode(t)))
        if tn == "bg-pre-reform":
          pagemsg("Found bg-pre-reform, won't add inflection: %s" % (unicode(t)))
          found_bg_pre_reform = True
      if not inflt and not found_bg_pre_reform:
        pagemsg("Didn't find %s inflection for headword %s" % (pos, head or pagetitle))
        infl = "{{%s|%s<>}}" % (pos_to_new_style_infl_template[pos], head or pagetitle)
        insert_k = k + 2
        while insert_k < endk and "Usage notes" in subsections[insert_k]:
          insert_k += 2
        if not subsections[insert_k - 1].endswith("\n\n"):
          subsections[insert_k - 1] = re.sub("\n*$", "\n\n",
            subsections[insert_k - 1] + "\n\n")
        subsections[insert_k:insert_k] = [
          "%s%s%s\n" % ("=" * (level + 1), "Conjugation" if pos == "verb" else "Inflection",
            "=" * (level + 1)), infl + "\n\n"
        ]
        pagemsg("Inserted level-%s inflection section with inflection <%s>" % (
          level + 1, infl))
        endk += 2 # for the two subsections we inserted

      k = endk
    else:
      m = re.search(r"=\s*(Noun|Proper noun|Pronoun|Determiner|Verb|Adverb|Interjection|Conjunction)\s*=", subsections[k])
      if m:
        last_pos = m.group(1)
      if re.search(r"=\s*(Declension|Inflection|Conjugation)\s*=", subsections[k]):
        if not last_pos:
          pagemsg("WARNING: Found inflection header before seeing any parts of speech: %s" %
              (subsections[k].strip()))
        elif last_pos == cappos:
          pagemsg("WARNING: Found probably misindented inflection header after ==%s== header: %s" %
              (cappos, subsections[k].strip()))
      k += 2

  secbody = "".join(subsections)
  text = secbody + sectail
  text = re.sub("\n\n\n+", "\n\n", text)
  pagemsg("------- begin text --------")
  msg(text.rstrip('\n'))
  msg("------- end text --------")

parser = blib.create_argparser("Add Bulgarian noun/verb/adjective inflections")
parser.add_argument("--pos", help="Part of speech (noun, proper noun, verb, adjective)")
parser.add_argument('--direcfile', help="File containing output from find_regex.py.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = codecs.open(args.direcfile, "r", "utf-8")

pagename_and_text = find_regex.yield_text_from_find_regex(lines, args.verbose)
for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
    get_name=lambda x:x[0]):
  process_page(index, pagename, text, args.pos)
