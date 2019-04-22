#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

tag_replacements = {
  "first person": "1",
  "second person": "2",
  "third person": "3",
  "[[past historic]]": "phis",
  "per": "pers",
  "personal masculine": ["pers", "m"],
  "personal and animate masculine": ["pers//an", "m"],
  "(impersonal)": "impers",
  ("simple", "fut"): "sfut",
  ("simple", "futr"): "sfut",
  ("simple", "past"): "spast",
  "positive": "posd",
  "subject non-past participle": ["subject", "non-past", "part"],
  "definite masculine": ["def", "m"],
  "definite feminine": ["def", "f"],
  "indefinite masculine": ["indef", "m"],
  "indefinite feminine": ["indef", "f"],
  "(single possession)": "spos",
  "past habitual": ["past", "hab"],
  "first-person singular simple present possessive": ["1s", "spres", "poss"],
  "Active participle": ["act", "part"],
}

tags_with_spaces = defaultdict(int)

def process_text_on_page(pagetitle, index, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  if ":" in pagetitle and not re.search(
      "^(Citations|Appendix|Reconstruction|Transwiki|Talk|Wiktionary|[A-Za-z]+ talk):", pagetitle):
    pagemsg("WARNING: Colon in page title and not a recognized namespace to include, skipping page")
    return None, None

  parsed = blib.parse_text(text)

  templates_to_replace = []

  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn in ["inflection of"]:
      params = []
      if getparam(t, "lang"):
        lang = getparam(t, "lang")
        term_param = 1
        notes.append("moved lang= in {{inflection of}} to 1=")
      else:
        lang = getparam(t, "1")
        term_param = 2
      tr = getparam(t, "tr")
      term = getparam(t, str(term_param))
      alt = getparam(t, "alt") or getparam(t, str(term_param + 1))
      tags = []
      for param in t.params:
        pname = unicode(param.name).strip()
        pval = unicode(param.value).strip()
        if re.search("^[0-9]$", pname):
          if int(pname) >= term_param + 2:
            if pval:
              tags.append(pval)
            else:
              notes.append("removed empty params from {{inflection of}}")
        elif pname not in ["lang", "tr", "alt"]:
          params.append((pname, pval, param.showkey))

      canon_tags = []
      def append_repl(repl):
        if type(repl) is list:
          for tag in repl:
            canon_tags.append(tag)
        else:
          canon_tags.append(repl)
      i = 0
      while i < len(tags):
        if i < len(tags) - 1 and (tags[i], tags[i + 1]) in tag_replacements:
          repl = tag_replacements[(tags[i], tags[i + 1])]
          notes.append("replaced bad inflection tag %s|%s with %s" % (
            tags[i], tags[i + 1], "|".join(repl) if type(repl) is list else repl))
          append_repl(repl)
          i += 2
        elif tags[i] in tag_replacements:
          repl = tag_replacements[tags[i]]
          notes.append("replaced bad inflection tag %s with %s" % (
            tags[i], "|".join(repl) if type(repl) is list else repl))
          append_repl(repl)
          i += 1
        else:
          canon_tags.append(tags[i])
          i += 1
      tags = canon_tags

      # Erase all params.
      del t.params[:]
      # Put back new params.
      t.add("1", lang)
      t.add("2", term)
      if tr:
        t.add("tr", tr)
      t.add("3", alt)
      next_tag_param = 4
      for tag in tags:
        if " " in tag:
          tags_with_spaces[tag] += 1
        t.add(str(next_tag_param), tag)
        next_tag_param += 1
      for pname, pval, showkey in params:
        t.add(pname, pval, showkey=showkey, preserve_spacing=False)
      if origt != unicode(t):
        if not notes:
          notes.append("canonicalized {{inflection of}}")
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))

  return unicode(parsed), notes

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  text = unicode(page.text)
  return process_text_on_page(pagetitle, index, text)

parser = blib.create_argparser("Clean up bad inflection tags")
parser.add_argument("--pagefile", help="List of pages to process.")
parser.add_argument("--textfile", help="File containing inflection templates to process.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.textfile:
  with codecs.open(args.textfile, "r", "utf-8") as fp:
    text = fp.read()
  pages = text.split('\001')
  for index, page in enumerate(pages):
    if not page: # e.g. first entry
      continue
    pagetitle, pagetext = page.split('\n', 1)
    newtext, notes = process_text_on_page(pagetitle, index, pagetext)
    if newtext != pagetext:
      msg("Page %s %s: Would save with comment = %s" % (index, pagetitle,
        "; ".join(blib.group_notes(notes))))
      
elif args.pagefile:
  pages = [x.rstrip('\n') for x in codecs.open(args.pagefile, "r", "utf-8")]
  for i, page in blib.iter_items(pages, start, end):
    blib.do_edit(pywikibot.Page(site, page), i, process_page, save=args.save,
        verbose=args.verbose)

msg("Bad tags with spaces:")
for key, val in sorted(tags_with_spaces.iteritems(), key=lambda x: -x[1]):
  msg("%s = %s" % (key, val))
