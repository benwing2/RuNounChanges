#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

subtag_replacements = [
  ("first person", "first-person"),
  ("second person", "second-person"),
  ("third person", "third-person"),
]

tag_replacements = {
  "first person": "1",
  "second person": "2",
  "third person": "3",
  "per": "pers",
  "pas": "pass",
  "personal and animate masculine": ["pers//an", "m"],
  "(impersonal)": "impers",
  "positive": "posd",
  "(single possession)": "spos",
  "(multiple possessions)": "mpos",
  "negative conjugation": ["neg", "form"],
  "archaiac": "archaic",
  "innesive": "inessive",
}

tags_with_spaces = defaultdict(int)

bad_tags = defaultdict(int)

good_tags = set()

num_total_templates = 0
num_templates_with_bad_tags = 0

def parse_form_of_data(lines):
  curtag = None
  for line in lines:
    line = line.strip()
    m = re.search('^tags\["(.*?)"\] = \{$', line)
    if m:
      curtag = m.group(1)
      good_tags.add(curtag)
    if line == "}":
      curtag = None
    m = re.search('^\s*shortcuts = \{(.*?)\},$', line)
    if m:
      shortcuts = [x.strip().strip('"') for x in m.group(1).split(',')]
      for shortcut in shortcuts:
        good_tags.add(shortcut)
    m = re.search('^\s*shortcuts\["(.*?)"\] =', line)
    if m:
      good_tags.add(m.group(1))

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

      def canonicalize_tag(tag):
        if tag in good_tags or tag == ";":
          return tag
        if tag in tag_replacements:
          return tag_replacements[tag]
        if " " in tag:
          newtag = tag
          for fro, to in subtag_replacements:
            newtag = newtag.replace(fro, to)
          split_tags = newtag.split(" ")
          if all([t in good_tags for t in split_tags]):
            return split_tags
        lowertag = tag.lower()
        if lowertag != tag:
          repl = canonicalize_tag(lowertag)
          if repl:
            return repl
        m = re.search('^\[\[(.*)\]\]$', tag)
        if m:
          repl = canonicalize_tag(m.group(1))
          if repl:
            return repl
        return None

      canon_tags = []

      for tag in tags:
        repl = canonicalize_tag(tag)
        if repl is None:
          if ' ' in tag:
            pagemsg("WARNING: Bad multiword tag '%s', can't canonicalize" % tag)
            repl = tag
          else:
            pagemsg("WARNING: Bad tag %s, can't canonicalize" % tag)
            repl = tag
        elif repl != tag:
          notemsg = ("replaced bad multiword inflection tag '%s' with %s" if ' ' in tag else
            "replaced bad inflection tag %s with %s")
          notes.append(notemsg % (tag, "|".join(repl) if type(repl) is list else repl))
        if type(repl) is list:
          for tag in repl:
            canon_tags.append(tag)
        else:
          canon_tags.append(repl)

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
      has_bad_tags = False
      for tag in tags:
        if " " in tag:
          tags_with_spaces[tag] += 1
        if "//" in tag:
          split_tags = tag.split("//")
        else:
          split_tags = [tag]
        for split_tag in split_tags:
          if split_tag != ";" and split_tag not in good_tags:
            bad_tags[split_tag] += 1
            has_bad_tags = True
            pagemsg("Saw bad tag: %s" % split_tag)
        t.add(str(next_tag_param), tag)
        next_tag_param += 1
      for pname, pval, showkey in params:
        t.add(pname, pval, showkey=showkey, preserve_spacing=False)
      if origt != unicode(t):
        if not notes:
          notes.append("canonicalized {{inflection of}}")
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))
      global num_total_templates
      num_total_templates += 1
      global num_templates_with_bad_tags
      if has_bad_tags:
        num_templates_with_bad_tags += 1

  return unicode(parsed), notes

def process_page(page, index, parsed):
  pagetitle = unicode(page.title())
  text = unicode(page.text)
  return process_text_on_page(pagetitle, index, text)

parser = blib.create_argparser("Clean up bad inflection tags")
parser.add_argument("--pagefile", help="List of pages to process.")
parser.add_argument("--textfile", help="File containing inflection templates to process.")
parser.add_argument("--form-of-files", help="Comma-separated list of files containing form-of data.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.form_of_files:
  files = args.form_of_files.split(',')
  for f in files:
    with open(f, 'r') as fp:
      parse_form_of_data(fp)

if args.textfile:
  with codecs.open(args.textfile, "r", "utf-8") as fp:
    text = fp.read()
  pages = text.split('\001')
  for index, page in blib.iter_items(pages, start, end):
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

msg("Fraction of templates with bad tags = %s / %s = %.2f%%" % (
  num_templates_with_bad_tags, num_total_templates,
  float(num_templates_with_bad_tags) * 100 / float(num_total_templates)
))
msg("Bad tags:")
for key, val in sorted(bad_tags.iteritems(), key=lambda x: -x[1]):
  msg("%s = %s" % (key, val))
msg("Tags with spaces:")
for key, val in sorted(tags_with_spaces.iteritems(), key=lambda x: -x[1]):
  msg("%s = %s" % (key, val))
