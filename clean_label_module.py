#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
from dataclasses import dataclass

import blib
from blib import getparam, rmparam, set_template_name, msg, errandmsg, site, tname

@dataclass
class LabelData:
  label: str
  first_label_line: str
  label_lines: list
  last_label_line: str
  topical_categories: list
  sense_categories: list
  pos_categories: list
  regional_categories: list
  plain_categories: list
  aliases: list

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
  saw_old_style_alias = False
  labels_seen = []
  indexed_labels = {}
  first_label_line = None
  label_lines = []
  label = False
  topical_categories = []
  sense_categories = []
  pos_categories = []
  regional_categories = []
  plain_categories = []
  existing_aliases = []

  either_quote_string_re = '(".*?"|' + "'.*?')"
  true_or_either_quote_string_re = '(true|".*?"|' + "'.*?')"

  for lineind, line in enumerate(lines):
    lineno = lineind + 1
    def linemsg(txt):
      pagemsg("Line %s: %s" % (lineno, txt))
    if re.search(r"^labels *\[", line):
      if label:
        errandpagemsg("WARNING: Saw nested labels on line %s, can't handle file: %s" % (lineno, line))
        return
      m = re.search(r"^labels *\[%s\] = %s$" % (either_quote_string_re, either_quote_string_re), line.rstrip())
      if m:
        # an alias
        alias, canon = m.groups()
        canon = canon[1:-1] # discard quotes
        if canon not in indexed_labels:
          linemsg("WARNING: Unable to locate canonical label '%s' for aliases: %s" % (canon, line))
          label_lines.append(line)
          continue
        labels_seen[indexed_labels[canon]].aliases.append(alias)
        continue
      if label_lines:
        labels_seen.append(label_lines)
        label_lines = []
      topical_categories = []
      sense_categories = []
      pos_categories = []
      regional_categories = []
      plain_categories = []
      existing_aliases = []
      m = re.search(r"^labels *\[%s\] = \{$" % (either_quote_string_re), line.rstrip())
      if not m:
        linemsg("WARNING: Unable to parse labels start line: %s" % line)
        label_lines.append(line)
      else:
        label = m.group(1)[1:-1]
        first_label_line = line
    elif line.strip() == "}":
      if not label:
        errandpagemsg("WARNING: Saw non-label object on line %s, can't handle file: %s" % (lineno, line))
        return
      if label_lines and not label_lines[-1].endswith(","):
        # FIXME: This could break if there are quotes around the comment sign
        m = re.search("^(.*?)(--.*)$", label_lines[-1])
        if m:
          pre_comment, comment = m.groups()
          if pre_comment.strip() and not pre_comment.strip().endswith(","):
            label_lines[-1] = "%s, %s" % (pre_comment.rstrip(), comment)
        else:
          label_lines[-1] += ","

      labels_seen.append(LabelData(label, first_label_line, label_lines, line, topical_categories, sense_categories,
                                   pos_categories, regional_categories, plain_categories, existing_aliases))
      indexed_labels[label] = len(labels_seen) - 1
      label = False
      label_lines = []
      first_label_line = None
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

      def process_cats(prefix, lst, process_one_cat):
        m = re.search("^%s = (.*)$" % prefix, line)
        if m:
          cats = extract_categories(m.group(1).strip())
          if cats is None:
            label_lines.append(origline)
          else:
            for cat in cats:
              if cat is True:
                lst.append("true")
              elif not process_one_cat(cat):
                lst.append('"%s"' % cat)
          return True
        return False

      def process_aliases(cat):
        return
      def process_topical(cat):
        if cat == label or cat == ucfirst(label):
          topical_categories.append("true")
          return True
      def process_sense(cat):
        if cat == label:
          sense_categories.append("true")
          return True
      def process_pos(cat):
        if cat == label:
          pos_categories.append("true")
          return True
      def process_regional(cat):
        if cat == label or cat == ucfirst(label):
          regional_categories.append("true")
          return True
      def process_plain(cat):
        if cat == label or cat == ucfirst(label):
          plain_categories.append("true")
          return True
        elif langname and cat.endswith(" " + langname):
          regcat = cat[:-(len(langname) + 1)] # +1 for preceding space
          if regcat == label or regcat == ucfirst(label):
            regional_categories.append("true")
          else:
            regional_categories.append('"%s"' % regcat)
          return True
      if (not process_cats("aliases", existing_aliases, process_aliases)
        and not process_cats("topical_categories", topical_categories, process_topical)
        and not process_cats("sense_categories", sense_categories, process_sense)
        and not process_cats("pos_categories", pos_categories, process_pos)
        and not process_cats("regional_categories", regional_categories, process_regional)
        and not process_cats("plain_categories", plain_categories, process_plain)
      ):
        label_lines.append(origline)

    elif line.startswith("alias("):
      m = re.search(r"""^alias\(%s, *{(.*?)}\)$""" % either_quote_string_re, line)
      if not m:
        linemsg("WARNING: Unable to parse alias line: %s" % line)
        label_lines.append(line)
        continue
      canon, aliases = m.groups()
      canon = canon[1:-1] # discard quotes
      if canon not in indexed_labels:
        linemsg("WARNING: Unable to locate canonical label '%s' for aliases: %s" % (canon, line))
        label_lines.append(line)
        continue
      saw_old_style_alias = True
      aliases = re.split(", *", aliases)
      labels_seen[indexed_labels[canon]].aliases.extend(aliases)

    elif line.startswith("local function alias("):
      pass

    elif line == "return labels":
      label_lines.append('return require("Module:labels").finalize_data(labels)')

    else:
      label_lines.append(line)

  if label_lines:
    labels_seen.append(label_lines)

  for labelobj in labels_seen:
    if isinstance(labelobj, LabelData):
      new_lines.append(labelobj.first_label_line)
      if labelobj.aliases:
        new_lines.append("\taliases = {%s}," % ", ".join(labelobj.aliases))
      new_lines.extend(labelobj.label_lines)
      def output_cats(cats, prefix):
        if len(cats) == 0:
          return
        if len(cats) == 1:
          new_lines.append("\t%s = %s," % (prefix, cats[0]))
        else:
          new_lines.append("\t%s = {%s}," % (prefix, ", ".join(cats)))
      output_cats(labelobj.topical_categories, "topical_categories")
      output_cats(labelobj.sense_categories, "sense_categories")
      output_cats(labelobj.pos_categories, "pos_categories")
      output_cats(labelobj.regional_categories, "regional_categories")
      output_cats(labelobj.plain_categories, "plain_categories")
      new_lines.append(labelobj.last_label_line)
    else:
      new_lines.extend(labelobj)

  text = "\n".join(new_lines)
  text = text.replace("\n\n\n", "\n\n")
  text = re.sub("^    ", "\t", text, 0, re.M)

  notes = ["clean categories in label module"]
  if saw_old_style_alias:
    notes.append("move old-style alias specs to `aliases =`")
  return text, notes

parser = blib.create_argparser("Clean label modules", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
