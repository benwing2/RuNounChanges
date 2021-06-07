#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

from collections import defaultdict

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if not args.partial_page:
    retval = blib.find_modifiable_lang_section(text, args.langname, pagemsg)
    if retval is None:
      return
    sections, j, secbody, sectail, has_non_lang = retval
  else:
    sections = [text]
    j = 0
    secbody = text
    sectail = ""

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  defn_subsection = None
  for k in xrange(2, len(subsections), 2):
    if "\n#" in subsections[k] and not re.search("=(Etymology|Pronunciation|Usage notes)", subsections[k - 1]):
      defn_subsection = k
    if "=Synonyms=" in subsections[k - 1]:
      if defn_subsection is None:
        pagemsg("WARNING: Encountered Synonyms section #%s without preceding definition section" % (k // 2 + 1))
        continue

      # Pull out all synonyms by number
      must_continue = False
      syns_by_number = defaultdict(list)
      unparsable = False
      for line in subsections[k].split("\n"):
        if not line.strip():
          continue
        m = re.search(r"^\* *\(([0-9]+)\) *(.*?)$", line)
        if m:
          defnum, syns = m.groups()
        else:
          m = re.search(r"^\* *(.*?) *\(([0-9]*)\)$", line)
          if m:
            syns, defnum = m.groups()
          else:
            # couldn't parse line
            pagemsg("Couldn't parse synonym line: %s" % line)
            unparsable = True
            break
        syns = re.split(" *, *", syns.strip())
        raw_syns = []
        must_break = False
        for syn in syns:
          orig_syn = syn
          syn = re.sub(r"\{\{[lm]\|%s\|([^{}]*)\}\}" % re.escape(args.lang), r"[[\1]]", syn)
          if "{{" in syn or "}}" in syn:
            pagemsg("WARNING: Unmatched braces in synonym '%s' in line: %s" % (orig_syn, line))
            must_break = True
            must_continue = True
            break
          if "''" in syn:
            pagemsg("WARNING: Italicized text in synonym '%s' in line: %s" % (orig_syn, line))
            must_break = True
            must_continue = True
            break
          # Strip brackets around entire synonym
          syn = re.sub(r"^\[\[([^\[\]]*)\]\]$", r"\1", syn)
          # If there are brackets around some words but not all, put brackets around the remaining words
          if "[[" in syn:
            split_by_brackets = re.split(r"(\[\[[^\[\]]*\]\])", syn)
            for i in xrange(0, len(split_by_brackets), 2):
              split_by_brackets[i] = re.sub("([^ ]+)", r"[[\1]]", split_by_brackets[i])
            new_syn = "".join(split_by_brackets)
            if new_syn != syn:
              pagemsg("Add brackets to '%s', producing '%s'" % (syn, new_syn))
              syn = new_syn
          syns_by_number[int(defnum)] += [syn]

        if must_break:
          break
      if unparsable or must_continue:
        continue

      # Find definitions
      m = re.search(r"\A(.*?)((?:^#[^\n]*\n)+)(.*?)\Z", subsections[defn_subsection], re.M | re.S)
      if not m:
        pagemsg("WARNING: Couldn't find definitions in definition subsection #%s" % (defn_subsection // 2 + 1))
        continue
      before_defn_text, defn_text, after_defn_text = m.groups()
      if re.search("^##", defn_text, re.M):
        pagemsg("WARNING: Found ## definition in definition subsection #%s, not sure what to do" % (defn_subsection // 2 + 1))
        continue
      defns = re.split("^(#[^*:].*\n(?:#[*:].*\n)*)", defn_text, 0, re.M)
      must_continue = False
      for between_index in xrange(0, len(defns), 2):
        if defns[between_index]:
          pagemsg("WARNING: Saw unknown text '%s' between definitions, not sure what to do" % defns[between_index].strip())
          must_continue = True
          break
      if must_continue:
        continue

      # Don't consider definitions with {{reflexive of|...}} in them
      defns = [x for i, x in enumerate(defns) if i % 2 == 1]
      reindexed_defns = {}
      next_index = 1
      for index, defn in enumerate(defns):
        if "{{reflexive of|" in defn:
          continue
        reindexed_defns[next_index] = index
        next_index += 1

      # Make sure synonyms don't refer to nonexistent definition
      max_syn = max(syns_by_number.keys())
      max_defn = max(reindexed_defns.keys())
      if max_syn > max_defn:
        pagemsg("WARNING: Numbered synonyms refer to maximum %s > maximum defn %s" % (max_syn, max_defn))
        continue

      # Add inline synonyms
      must_continue = False
      for synno, syns in syns_by_number.iteritems():
        if re.search(r"\{\{(syn|synonyms)\|", defns[reindexed_defns[synno]]):
          pagemsg("WARNING: Already saw inline synonyms in definition #%s: <%s>" % (synno, defns[reindexed_defns[synno]]))
          must_continue = True
          break
        defns[reindexed_defns[synno]] = re.sub("^(.*\n)", r"\1#: {{syn|%s|%s}}" % (args.lang, "|".join(syns)) + "\n",
            defns[reindexed_defns[synno]])
      if must_continue:
        continue

      # Put back new definition text and clear out synonyms
      subsections[defn_subsection] = before_defn_text + "".join(defns) + after_defn_text
      subsections[k - 1] = ""
      subsections[k] = ""
      notes.append("Convert synonyms in %s subsection %s to inline synonyms in subsection %s" % (
        args.langname, k // 2 + 1, defn_subsection // 2 + 1))
      defn_subsection = None

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Convert =Synonyms= sections to inline synonyms", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
parser.add_argument("--lang", required=True, help="Lang code of language to do.")
parser.add_argument("--langname", required=True, help="Lang name of language to do.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
