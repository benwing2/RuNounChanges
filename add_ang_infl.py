#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

pos_to_headword_template = {
  "noun": "ang-noun",
  "proper noun": "ang-proper noun",
  "verb": "ang-verb",
  "adjective": "ang-adj",
}

pos_to_new_style_infl_template = {
  "noun": "ang-ndecl",
  "proper noun": "ang-ndecl",
  "verb": "ang-conj",
  "adjective": "ang-adj",
}

pos_to_old_style_infl_template_prefix = {
  "noun": "ang-decl-noun",
  "proper noun": "ang-decl-noun",
  "verb": None,
  "adjective": None,
}

def get_indentation_level(header):
  return len(re.sub("[^=].*", "", header, 0, re.S))

def process_page(page, index, pos):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  cappos = pos.capitalize()
  notes = []

  pagemsg("Processing")

  text = unicode(page.text)
  retval = blib.find_modifiable_lang_section(text, "Old English", pagemsg)
  if retval is None:
    pagemsg("WARNING: Couldn't find Old English section")
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
          tn == "head" and getparam(t, "1") == "ang" and getparam(t, "2") in [pos, "%ss" % pos]
        ):
          newhead = getparam(t, "head").strip() or pagetitle
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
          pagemsg("Found %s inflection for headword %s: <from> %s <to> {{%s|%s}} <end>" %
              (pos, head or pagetitle, unicode(t), pos_to_new_style_infl_template[pos],
                getparam(t, "1") if pos == "verb" else head or pagetitle))
      if not inflt:
        pagemsg("Didn't find %s inflection for headword %s: <new> {{%s|%s%s}} <end>" % (
          pos, head or pagetitle, pos_to_new_style_infl_template[pos], head or pagetitle,
          "" if pos == "noun" else "<>"))
        if pages_to_infls:
          for l in range(k, endk, 2):
            if re.search(r"=\s*(Declension|Inflection|Conjugation)\s*=", subsections[l]):
              secparsed = blib.parse_text(subsections[l + 1])
              for t in secparsed.filter_templates():
                tn = tname(t)
                if tname(t) != "rfinfl":
                  pagemsg("WARNING: Saw unknown template %s in existing inflection section, skipping" % (
                    unicode(t)))
                  break
              else: # no break
                if pagetitle not in pages_to_infls:
                  pagemsg("WARNING: Couldn't find inflection for headword %s" % (
                    head or pagetitle))
                else:
                  m = re.search(r"\A(.*?)(\n*)\Z", subsections[l + 1], re.S)
                  sectext, final_newlines = m.groups()
                  subsections[l + 1] = pages_to_infls[pagetitle] + final_newlines
                  pagemsg("Replaced existing decl text <%s> with <%s>" % (
                    sectext, pages_to_infls[pagetitle]))
                  notes.append("replace decl text <%s> with <%s>" % (
                    sectext, pages_to_infls[pagetitle]))
              break
          else: # no break
            if pagetitle not in pages_to_infls:
              pagemsg("WARNING: Couldn't find inflection for headword %s" % (
                head or pagetitle))
            else:
              insert_k = k + 2
              while insert_k < endk and "Usage notes" in subsections[insert_k]:
                insert_k += 2
              if not subsections[insert_k - 1].endswith("\n\n"):
                subsections[insert_k - 1] = re.sub("\n*$", "\n\n",
                  subsections[insert_k - 1] + "\n\n")
              subsections[insert_k:insert_k] = [
                "%s%s%s\n" % ("=" * (level + 1), "Conjugation" if pos == "verb" else "Declension",
                  "=" * (level + 1)),
                pages_to_infls[pagetitle] + "\n\n"
              ]
              pagemsg("Inserted level-%s inflection section with inflection <%s>" % (
                level + 1, pages_to_infls[pagetitle]))
              notes.append("add decl <%s>" % pages_to_infls[pagetitle])
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

parser = blib.create_argparser("Find Old English noun/verb/adjective inflections or add new ones",
    include_pagefile=True)
parser.add_argument("--pos", help="Part of speech (noun, proper noun, verb, adjective)")
parser.add_argument("--new-infls", help="File of new inflections")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages_to_infls = {}
if args.new_infls:
  saw_multiple = set()
  for line in blib.yield_items_from_file(args.new_infls):
    m = re.search("^Page ([0-9]+) (.*?): .*<new> (.*?) <end>", line)
    if m:
      index, page, decl = m.groups()
      if page in pages_to_infls:
        msg("Page %s %s: WARNING: Saw multiple inflections %s and %s, skipping" % (
          index, page, pages_to_infls[page], decl))
        saw_multiple.add(page)
      pages_to_infls[page] = decl
  for page in saw_multiple:
    del pages_to_infls[page]

def do_process_page(page, index, parsed=None):
  return process_page(page, index, args.pos)

blib.do_pagefile_cats_refs(args, start, end, do_process_page,
    edit=not not pages_to_infls, default_cats=["Old English %ss" % args.pos])
