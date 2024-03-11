#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, set_template_name, msg, errandmsg, site, tname

blib.getLanguageData()

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  def ucfirst(txt):
    if not txt:
      return txt
    return txt[0].upper() + txt[1:]

  notes = []

  m = re.search("^Module:labels/data/lang/(.*)$", pagename)
  langname = None
  if m:
    code = m.group(1)
    if code in blib.languages_byCode:
      langname = blib.languages_byCode[code]["canonicalName"]
    else:
      errandpagemsg("WARNING: Can't locate language %s" % code)

  new_lines = []
  lines = text.split("\n")
  label = False
  topical_categories = []
  sense_categories = []
  pos_categories = []
  regional_categories = []
  plain_categories = []

  either_quote_string_re = '(".*?"|' + "'.*?')"
  true_or_either_quote_string_re = '(true|".*?"|' + "'.*?')"

  for lineind, line in enumerate(lines):
    lineno = lineind + 1
    def linemsg(txt):
      pagemsg("Line %s: %s" % (lineno, txt))
    if line.startswith("labels["):
      if label:
        errandpagemsg("WARNING: Saw nested labels on line %s, can't handle file" % lineno)
        return
      regional_categories = []
      plain_categories = []
      m = re.search(r"^labels\[%s\] = \{$" % (either_quote_string_re), line.rstrip())
      if not m:
        linemsg("WARNING: Unable to parse labels start line: %s" % line)
      else:
        label = m.group(1)[1:-1]
      new_lines.append(line)
    elif line.strip() == "}":
      label = False
      if not new_lines[-1].strip().endswith("{"):
        if not new_lines[-1].endswith(","):
          # FIXME: This could break if there are quotes around the comment sign
          m = re.search("^(.*?)(--.*)$", new_lines[-1])
          if m:
            pre_comment, comment = m.groups()
            if pre_comment.strip() and not pre_comment.strip().endswith(","):
              new_lines[-1] = "%s, %s" % (pre_comment.rstrip(), comment)
          else:
            new_lines[-1] += ","

      new_lines.append(line)
      for regcat in regional_categories:
        if regcat in langs_by_category_prefix:
          new_lines.append("-- regional category languages for '%s': %s" % (regcat, ", ".join(
            "%s (%s)" % (blib.languages_byCanonicalName[lang]["code"], lang) for lang in langs_by_category_prefix[regcat]
            )))
        else:
          new_lines.append("-- regional category languages for '%s': NONE" % regcat)
      for plaincat in plain_categories:
        if plaincat in category_prefixes:
          new_lines.append("-- plain category prefixes for '%s': %s" % (plaincat, ", ".join(
            "%s (%s=%s)" % (prefix, blib.languages_byCanonicalName[lang]["code"], lang)
            for prefix, lang in category_prefixes[plaincat]
          )))
        else:
          new_lines.append("-- plain category languages for '%s': NONE" % plaincat)

    elif label:
      origline = line
      line = line.strip()

      def extract_categories(raw_cats):
        m = re.search(r"^\{(.*)\},?$", raw_cats)
        if m:
          inside = m.group(1).strip()
          if not inside:
            linemsg("WARNING: Empty category line: %s" % line)
            return None
          if inside.endswith(","):
            inside = inside[:-1].strip()
          split_cats = re.split(true_or_either_quote_string_re, m.group(1).strip())
          cats = []
          for i, split_cat in enumerate(split_cats):
            if i % 2 == 1:
              if split_cat == "true":
                cats.append(True)
              else:
                cats.append(split_cat[1:-1])
            elif ((i == 0 or i == len(split_cats) - 1) and split_cat.strip()
                  or (i > 0 and i < len(split_cats) - 1) and split_cat.strip() != ","):
              linemsg("WARNING: Junk '%s' between categories: %s" % (split_cat, line))
              return None
          return cats
        m = re.search(r"^(.*?),?$", raw_cats)
        assert m
        inside = m.group(1).strip()
        if not re.search("^%s$" % true_or_either_quote_string_re, inside):
          linemsg("WARNING: Unable to parse category line: %s" % line)
          return None
        if inside == "true":
          return [True]
        else:
          return [inside[1:-1]]

      def process_cats(prefix, lst):
        m = re.search("^%s = (.*)$" % prefix, line)
        if m:
          cats = extract_categories(m.group(1).strip())
          if cats is None:
            new_lines.append(origline)
          else:
            for cat in cats:
              if cat is True:
                lst.append(ucfirst(label))
              else:
                lst.append(cat)

      process_cats("regional_categories", regional_categories)
      process_cats("topical_categories", topical_categories)
    else:
      new_lines.append(line)

  text = "\n".join(new_lines)

  return text, "clean categories in label module"

parser = blib.create_argparser("Split regional label data module", include_pagefile=True, include_stdin=True)
parser.add_argument("--categories", help="File containing categories.", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

langs_by_category_prefix = defaultdict(list)
category_prefixes = defaultdict(list)
for index, cat in blib.iter_items_from_file(args.categories, start, end):
  cat = re.sub("^Category:", "", cat)
  words = cat.split(" ")
  for i in range(len(words) - 1, 0, -1):
    lang_suffix = " ".join(words[i:])
    if lang_suffix in blib.languages_byCanonicalName:
      prefix = " ".join(words[:i])
      langs_by_category_prefix[prefix].append(lang_suffix)
      category_prefixes[cat].append((prefix, lang_suffix))

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
