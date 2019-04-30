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
  "per": "perf",
  "pas": "pass",
  "personal and animate masculine": ["pers//an", "m"],
  "(impersonal)": "impers",
  "positive": "posd",
  "(single possession)": "spos",
  "(multiple possessions)": "mpos",
  "negative conjugation": ["neg", "form"],
  "archaiac": "archaic",
  "honorofic": "honorific",
  "innesive": "inessive",
  "contraced": "contracted",
  "m;": ["m", ";"],
}

cases = {
  "nom": "nom",
  "nominative": "nom",
  "acc": "acc",
  "accc": "acc",
  "accusative": "acc",
  "accusative,": "acc",
  "voc": "voc",
  "vocative": "voc",
  "gen": "gen",
  "dat": "dat",
  "ins": "ins",
  "abl": "abl",
  "loc": "loc",
}

tenses = {
  "pres": "pres",
  "fut": "fut",
  "futr": "fut",
  "impf": "impf",
  "pret": "pret",
  "perf": "perf",
  "perfect": "perf",
  "plup": "plup",
}

genders = {
  "m": "m",
  "f": "f",
  "n": "n",
}

persons = {
  "1": "1",
  "2": "2",
  "3": "3",
}

moods = {
  "ind": "ind",
  "indc": "ind",
  "sub": "sub",
  "subj": "sub",
  "imp": "imp",
  "impr": "imp",
}

strengths = {
  "str": "str",
  "strong": "str",
  "wk": "wk",
  "weak": "wk",
  "weak,": "wk",
  "mix": "mix",
  "mixed": "mix",
}

multitag_replacements = {
  ("strong,", "weak,", "and", "mixed"): "str//wk//mix",
  ("first", "s"): ["1", "s"],
  ("second", "s"): ["2", "s"],
  ("first", "p"): ["1", "p"],
  ("second", "p"): ["2", "p"],
}

dimensions_to_tags = {
  "case": cases,
  "tense": tenses,
  "mood": moods,
  "person": persons,
  "gender": genders,
  "strength": strengths,
}

combininable_tags_by_dimension = {
  tag: dim for dim, tagdict in dimensions_to_tags.iteritems() for tag in tagdict
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

      # (1) Extract the tags and the non-tag parameters. Remove empty tags.

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
        if re.search("^[0-9]+$", pname):
          if int(pname) >= term_param + 2:
            if pval:
              tags.append(pval)
            else:
              notes.append("removed empty tags from {{inflection of}}")
        elif pname not in ["lang", "tr", "alt"]:
          params.append((pname, pval, param.showkey))

      # (2) Canonicalize tags on a tag-by-tag basis. This may involve applying the
      # replacements listed in tag_replacements or subtag_replacements, and may
      # involve splitting tags on spaces if each component is a recognized tag.

      def canonicalize_tag(tag):
        # Canonicalize a tag into either a single tag or a sequence of tags.
        # Return value is None if the tag isn't recognized, else a string or
        # a list of strings.
        if tag in good_tags:
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
        if "/" in tag:
          if "//" in tag:
            split_tags = tag.split("//")
          else:
            split_tags = tag.split("/")
          canon_split_tags = [canonicalize_tag(t) for t in split_tags]
          if all(isinstance(t, basestring) for t in canon_split_tags):
            return "//".join(canon_split_tags)
          else:
            pagemsg("WARNING: Found slash in tag and wasn't able to canonicalize completely: %s" % tag)
        m = re.search('^\[\[(.*)\]\]$', tag)
        if m:
          repl = canonicalize_tag(m.group(1))
          if repl:
            return repl
        return None

      canon_tags = []

      for tag in tags:
        if tag == ";":
          repl = tag
        else:
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
          canon_tags.extend(repl)
        else:
          canon_tags.append(repl)

      tags = canon_tags

      # (3) Apply multi-tag substitutions, e.g. "strong,|weak,|and|mixed" -> "str//wk/mix".

      canon_tags = []
      i = 0
      while i < len(tags):
        for fro, to in multitag_replacements.iteritems():
          if i + len(fro) <= len(tags):
            for j in range(len(fro)):
              if fro[j] != tags[i + j]:
                break
            else:
              if type(to) is list:
                canon_tags.extend(to)
                notes.append("replaced inflection tag sequence %s with %s" % ("|".join(fro), "|".join(to)))
              else:
                canon_tags.append(to)
                notes.append("replaced inflection tag sequence %s with %s" % ("|".join(fro), to))
              i += len(fro)
              break
        else:
          canon_tags.append(tags[i])
          i += 1
      tags = canon_tags

      # (4) Canonicalize tags by combining e.g. 'nom|and|voc' to 'nom//voc'.

      canon_tags = []
      i = 0
      while i < len(tags):
        if i < len(tags) - 4 and (
          tags[i] in combininable_tags_by_dimension and
          tags[i + 1] in ['and', '/'] and
          tags[i + 2] in combininable_tags_by_dimension and
          combininable_tags_by_dimension[tags[i]] == combininable_tags_by_dimension[tags[i + 2]] and
          tags[i + 3] in ['and', '/'] and
          tags[i + 4] in combininable_tags_by_dimension and
          combininable_tags_by_dimension[tags[i + 2]] == combininable_tags_by_dimension[tags[i + 4]]
        ):
          # We have foo|and|bar|and|baz where foo, bar and baz are in the same dimension.
          dim = combininable_tags_by_dimension[tags[i]]
          tag1 = dimensions_to_tags[dim][tags[i]]
          tag2 = dimensions_to_tags[dim][tags[i + 2]]
          tag3 = dimensions_to_tags[dim][tags[i + 4]]
          combined_tag = "%s//%s//%s" % (tag1, tag2, tag3)
          canon_tags.append(combined_tag)
          notes.append("combined %s tags into %s" % (dim, combined_tag))
          i += 5
        elif i < len(tags) - 2 and (
          tags[i] in combininable_tags_by_dimension and
          tags[i + 1] in ['and', '/'] and
          tags[i + 2] in combininable_tags_by_dimension and
          combininable_tags_by_dimension[tags[i]] == combininable_tags_by_dimension[tags[i + 2]]
        ):
          # We have foo|and|bar where foo and bar are in the same dimension.
          dim = combininable_tags_by_dimension[tags[i]]
          tag1 = dimensions_to_tags[dim][tags[i]]
          tag2 = dimensions_to_tags[dim][tags[i + 2]]
          combined_tag = "%s//%s" % (tag1, tag2)
          canon_tags.append(combined_tag)
          notes.append("combined %s tags into %s" % (dim, combined_tag))
          i += 3
        else:
          canon_tags.append(tags[i])
          i += 1
      tags = canon_tags

      # (5) Put back the new parameters. In the process, log and unrecognized ("bad") tags,
      # and any tags with spaces in them.

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
