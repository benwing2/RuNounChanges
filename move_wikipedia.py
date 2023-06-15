#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else args.langname, pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  sect_for_wiki = 0
  seen_lemmas = []
  for k in range(1, len(subsections), 2):
    if re.search(r"==\s*Etymology [0-9]+\s*==", subsections[k]):
      sect_for_wiki = k + 1
      seen_lemmas = []
    else:
      lines = subsections[k + 1].strip().split("\n")
      lines = [line for line in lines]
      lines_so_far = []
      for lineind, line in enumerate(lines):
        if re.search(r"^\{\{(wp|wiki|wikipedia|Wikipedia)\|[^{}]*\}\}$", line):
          if len(seen_lemmas) >= 1:
            pagemsg("Already saw preceding lemma(s) %s, not moving wikipedia line %s" % (
              ",".join(seen_lemmas), line))
            lines_so_far.append(line)
          else:
            # Put after any other wikipedia lines.
            m = re.search(r"\A(.*?)(\n*)\Z", subsections[sect_for_wiki], re.S)
            stripped_sect_for_wiki, sect_for_wiki_endlines = m.groups()
            sect_for_wiki_lines = stripped_sect_for_wiki.split("\n")
            for i in range(len(sect_for_wiki_lines)):
              if not re.search(r"^\{\{(wp|wiki|wikipedia|Wikipedia)\|[^{}]*\}\}$", sect_for_wiki_lines[i]):
                break
            sect_for_wiki_lines[i:i] = [line]
            subsections[sect_for_wiki] = "\n".join(sect_for_wiki_lines) + sect_for_wiki_endlines
            subsections[k + 1] = "%s\n\n" % "\n".join(lines_so_far + lines[lineind + 1:])
            notes.append("move {{wikipedia}} line to top of etym section")
        else:
          lines_so_far.append(line)
      if re.search(blib.pos_regex, subsections[k]): # Maybe a lemma
        lines = subsections[k + 1].strip().split("\n")
        for lineind, line in enumerate(lines):
          if re.search(r"\{\{(head\|[^{}]*|[a-z][a-z][a-z]?-[^{}|]*)forms?\b", line):
            pagemsg("Saw potential lemma section %s but appears to be a non-lemma form due to line #%s: %s" %
                (subsections[k].strip(), lineind + 1, line))
            break
        else: # no break
          seen_lemmas.append(subsections[k].strip())

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  if args.langname == "Italian": # why this special case?
    newsecj = re.sub(r"(\{\{it-noun[^{}]*\}\}\n)([^\n])", r"\1" + "\n" + r"\2", sections[j])
    if newsecj != sections[j]:
      notes.append("add missing newline after {{it-noun}}")
      sections[j] = newsecj
  text = "".join(sections)
  newtext = re.sub(r"\n\n\n+", "\n\n", text)
  if text != newtext:
    notes.append("convert 3+ newlines to 2 newlines")
  text = newtext
  return text, notes

parser = blib.create_argparser("Move {{wikipedia}} lines to top of etym section",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
parser.add_argument("--langname", help="Only do this language name (optional).")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
