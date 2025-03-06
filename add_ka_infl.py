#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

pos_to_headword_template = {
  "noun": "ka-noun",
  "proper noun": "ka-proper noun",
  "verb": "ka-verb",
  "adjective": "ka-adj",
}

pos_to_new_style_infl_template = {
  "noun": None,
  "proper noun": None,
  "verb": None,
  "adjective": "ka-decl-adj",
}

def adj_indeclinable(pagetitle):
  return pagetitle[-1] in "აეოუ" or pagetitle[-2] in "აეიოუ"

def get_indentation_level(header):
  return len(re.sub("[^=].*", "", header, 0, re.S))

def escape_newlines(txt):
  return txt.replace("\n", r"\n")

def process_text_on_page(index, pagetitle, text, pos):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  cappos = pos.capitalize()
  notes = []

  pagemsg("Processing")

  if pos == "adjective" and adj_indeclinable(pagetitle):
    pagemsg("Skipping indeclinable adjective")
    return

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Georgian", pagemsg)
  if retval is None:
    pagemsg("WARNING: Couldn't find Georgian section")
    return
  sections, j, secbody, sectail, has_non_lang = retval
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
      found_rfinfl = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == pos_to_headword_template[pos] or (
          tn == "head" and getparam(t, "1") == "ka" and getparam(t, "2") in [pos, "%ss" % pos]
        ):
          newhead = getparam(t, "head").strip() or pagetitle
          if head:
            pagemsg("WARNING: Found two heads under one POS section: %s and %s" % (head, newhead))
          head = newhead
        if tn == pos_to_new_style_infl_template[pos]:
          if inflt:
            pagemsg("WARNING: Found two inflection templates under one POS section: %s and %s" % (
              str(inflt), str(t)))
          inflt = t
          pagemsg("Found %s inflection for headword %s: <from> %s <to> {{%s|%s}} <end>" %
              (pos, head or pagetitle, str(t), pos_to_new_style_infl_template[pos],
                getparam(t, "1") if pos == "verb" else head or pagetitle))
      if not inflt:
        pagemsg("Didn't find %s inflection for headword %s: <new> {{%s|%s%s}} <end>" % (
          pos, head or pagetitle, pos_to_new_style_infl_template[pos], head or pagetitle,
          "" if pos == "noun" else "<>"))
        new_infl = "{{%s}}" % pos_to_new_style_infl_template[pos]
        for l in range(k, endk, 2):
          if re.search(r"=\s*(Declension|Inflection|Conjugation)\s*=", subsections[l]):
            secparsed = blib.parse_text(subsections[l + 1])
            for t in secparsed.filter_templates():
              tn = tname(t)
              if tname(t) not in ["rfinfl", "ka-infl-noun"]:
                pagemsg("WARNING: Saw unknown template %s in existing inflection section, skipping" % (
                  str(t)))
                break
            else: # no break
              m = re.search(r"\A(.*?)(\n*)\Z", subsections[l + 1], re.S)
              sectext, final_newlines = m.groups()
              newsectext = sectext
              if "{{rfinfl|" in sectext:
                newsectext = new_infl
              else:
                newsectext = new_infl + "\n" + sectext
              subsections[l + 1] = newsectext + final_newlines
              pagemsg("Replaced existing decl text <%s> with <%s>" % (
                escape_newlines(sectext), escape_newlines(newsectext)))
              notes.append("replace decl text <%s> with <%s>" % (escape_newlines(sectext), escape_newlines(newsectext)))
            break
        else: # no break
          insert_k = k + 2
          while insert_k < endk and "Usage notes" in subsections[insert_k]:
            insert_k += 2
          if not subsections[insert_k - 1].endswith("\n\n"):
            subsections[insert_k - 1] = re.sub("\n*$", "\n\n",
              subsections[insert_k - 1] + "\n\n")
          subsections[insert_k:insert_k] = [
            "%s%s%s\n" % ("=" * (level + 1), "Conjugation" if pos == "verb" else "Declension",
              "=" * (level + 1)),
            new_infl + "\n\n"
          ]
          pagemsg("Inserted level-%s inflection section with inflection <%s>" % (
            level + 1, new_infl))
          notes.append("add decl <%s>" % new_infl)
          endk += 2 # for the two subsections we inserted

      k = endk
    else:
      m = re.search(r"=\s*(Noun|Proper noun|Pronoun|Determiner|Verb|Adjective|Adverb|Interjection|Conjunction)\s*=", subsections[k])
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
  sections[j] = secbody + sectail
  text = "".join(sections)
  text = re.sub("\n\n\n+", "\n\n", text)
  if not notes:
    notes.append("convert 3+ newlines to 2")
  return text, notes

parser = blib.create_argparser("Add Georgian noun/verb/adjective inflections", include_pagefile=True,
                               include_stdin=True)
parser.add_argument("--pos", help="Part of speech (noun, proper noun, verb, adjective)", required=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def do_process_text_on_page(index, pagetitle, text):
  return process_text_on_page(index, pagetitle, text, args.pos)

blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page,
    edit=True, stdin=True, default_cats=["Georgian %ss" % args.pos])
