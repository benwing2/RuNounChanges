#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

def get_indentation_level(header):
  return len(re.sub("[^=].*", "", header, 0, re.S))

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

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
    if re.search(r"=\s*Adjective\s*=", subsections[k]):
      level = get_indentation_level(subsections[k])
      last_pos = "Adjective"
      endk = k + 2
      while endk < len(subsections) and get_indentation_level(subsections[endk]) > level:
        endk += 2
      pos_text = "".join(subsections[k:endk])
      parsed = blib.parse_text(pos_text)
      head = None
      declt = None
      found_rfinfl = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "ang-adj" or (
          tn == "head" and getparam(t, "1") == "ang" and getparam(t, "2") in ["adjective", "adjectives"]
        ):
          newhead = getparam(t, "head").strip() or pagetitle
          if head:
            pagemsg("WARNING: Found two heads under one POS section: %s and %s" % (head, newhead))
          head = newhead
        if tn == "ang-adecl" or tn.startswith("ang-decl-adj"):
          if declt:
            pagemsg("WARNING: Found two declension templates under one POS section: %s and %s" % (
              unicode(declt), unicode(t)))
          declt = t
          pagemsg("Found adjective declension for headword %s: <from> %s <to> {{ang-adecl|%s}} <end>" %
              (head or pagetitle, unicode(t), head or pagetitle))
      if not declt:
        pagemsg("Didn't find adjective declension for headword %s: <new> {{ang-adecl|%s}} <end>" % (
          head or pagetitle, head or pagetitle))
        if pages_to_decls:
          for l in xrange(k, endk, 2):
            if re.search(r"=\s*(Declension|Inflection)\s*=", subsections[l]):
              secparsed = blib.parse_text(subsections[l + 1])
              for t in secparsed.filter_templates():
                tn = tname(t)
                if tname(t) != "rfinfl":
                  pagemsg("WARNING: Saw unknown template %s in existing Declension section, skipping" % (
                    unicode(t)))
                  break
              else: # no break
                if pagetitle not in pages_to_decls:
                  pagemsg("WARNING: Couldn't find declension for headword %s" % (
                    head or pagetitle))
                else:
                  m = re.search(r"\A(.*?)(\n*)\Z", subsections[l + 1], re.S)
                  sectext, final_newlines = m.groups()
                  subsections[l + 1] = pages_to_decls[pagetitle] + final_newlines
                  pagemsg("Replaced existing decl text <%s> with <%s>" % (
                    sectext, pages_to_decls[pagetitle]))
                  notes.append("replace decl text <%s> with <%s>" % (
                    sectext, pages_to_decls[pagetitle]))
              break
          else: # no break
            if pagetitle not in pages_to_decls:
              pagemsg("WARNING: Couldn't find declension for headword %s" % (
                head or pagetitle))
            else:
              insert_k = k + 2
              while insert_k < endk and "Usage notes" in subsections[insert_k]:
                insert_k += 2
              if not subsections[insert_k - 1].endswith("\n\n"):
                subsections[insert_k - 1] = re.sub("\n*$", "\n\n",
                  subsections[insert_k - 1] + "\n\n")
              subsections[insert_k:insert_k] = [
                "%sDeclension%s\n" % ("=" * (level + 1), "=" * (level + 1)),
                pages_to_decls[pagetitle] + "\n\n"
              ]
              pagemsg("Inserted level-%s declension section with declension <%s>" % (
                level + 1, pages_to_decls[pagetitle]))
              notes.append("add decl <%s>" % pages_to_decls[pagetitle])
              endk += 2 # for the two subsections we inserted

      k = endk
    else:
      m = re.search(r"=\s*(Noun|Proper noun|Pronoun|Determiner|Verb|Adverb|Interjection|Conjunction)\s*=", subsections[k])
      if m:
        last_pos = m.group(1)
      if re.search(r"=\s*(Declension|Inflection)\s*=", subsections[k]):
        if not last_pos:
          pagemsg("WARNING: Found declension header before seeing any parts of speech: %s" % 
              (subsections[k].strip()))
        elif last_pos == "Adjective":
          pagemsg("WARNING: Found probably misindented declension header after ==Adjective== header: %s" % 
              (subsections[k].strip()))
      k += 2

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  text = "".join(sections)
  text = re.sub("\n\n\n+", "\n\n", text)
  if not notes:
    notes.append("convert 3+ newlines to 2")
  return text, notes

parser = blib.create_argparser("Find Old English adjective declensions or add new ones",
    include_pagefile=True)
parser.add_argument("--new-decls", help="File of new declensions")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pages_to_decls = {}
saw_multiple = set()
for line in codecs.open(args.new_decls, "r", "utf-8"):
  line = line.strip()
  m = re.search("^Page [0-9]+ (.*?): .*<new> (.*?) <end>", line)
  if m:
    page, decl = m.groups()
    if page in pages_to_decls:
      msg("WARNING: Saw multiple declensions for %s: %s and %s, skipping" % (
        page, pages_to_decls[page], decl))
      saw_multiple.add(page)
    pages_to_decls[page] = decl
for page in saw_multiple:
  del pages_to_decls[page]

blib.do_pagefile_cats_refs(args, start, end, process_page,
    edit=not not pages_to_decls, default_cats=["Old English adjectives"])
