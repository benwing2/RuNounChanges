#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
from dataclasses import dataclass

import blib
from blib import getparam, rmparam, set_template_name, msg, errandmsg, site, tname

blib.getLanguageData()

@dataclass
class MiscProperties:
  Wikipedia: str
  Wikipedia_comment: str
  Wiktionary: str
  Wiktionary_comment: str
  display: str
  display_comment: str
  glossary: str
  glossary_comment: str

def make_empty_misc_properties():
  return MiscProperties(None, None, None, None, None, None, None, None)

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
  misc_properties: MiscProperties
  aliases: list

@dataclass
class ProcessForLabelObjectsRetval:
  labels_seen: list
  langcode: str
  langname: str
  saw_old_style_alias: bool

def ucfirst(txt):
  if not txt:
    return txt
  return txt[0].upper() + txt[1:]

def lcfirst(txt):
  if not txt:
    return txt
  return txt[0].lower() + txt[1:]

def process_text_on_page_for_label_objects(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  notes = []

  langname = None
  m = re.search("^Module:labels/data/lang/(.*)$", pagename)
  if not m:
    m = re.search("^Module:(.*):Dialects$", pagename)
  if m:
    langcode = m.group(1)
    if langcode in blib.languages_byCode:
      langname = blib.languages_byCode[langcode]["canonicalName"]
    else:
      errandpagemsg("WARNING: Can't locate language %s" % langcode)

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
  misc_properties = make_empty_misc_properties()
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
      misc_properties = make_empty_misc_properties()
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
                                   pos_categories, regional_categories, plain_categories, misc_properties,
                                   existing_aliases))
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
        def process_misc_property(propname):
          m = re.search("^%s *= *%s,?( *--.*)?$" % (propname, true_or_either_quote_string_re), line)
          if m:
            propval = m.group(1)
            if propval != "true":
              propval = '"%s"' % propval[1:-1] # canonicalize quotes
            propval_comment = m.group(2)
            if getattr(misc_properties, propname) is not None:
              pagemsg("WARNING: Saw %s = %s twice" % (propname, propval))
            else:
              setattr(misc_properties, propname, propval)
              setattr(misc_properties, propname + "_comment", propval_comment)
              return True
          return False
        if (not process_misc_property("display")
            and not process_misc_property("Wikipedia")
            and not process_misc_property("glossary")
            and not process_misc_property("Wiktionary")
        ):
          pagemsg("WARNING: Couldn't process label '%s' line: %s" % (label, line))
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

  return ProcessForLabelObjectsRetval(labels_seen, langcode, langname, saw_old_style_alias)

def combine_comments(a, b):
  if a is None and b is None:
    return None
  if a is None:
    return b
  if b is None:
    return a
  return "%s, %s" % (a, re.sub("^ *-- *", "", b))

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  new_lines = []
  retval = process_text_on_page_for_label_objects(index, pagename, text)
  if retval is None:
    return

  # Extract off any literal lines at the end (including the call to finalize_labels()). Any additions need to go
  # before these final lines.
  earliest_extra_lines_at_end = len(retval.labels_seen)
  for i in range(len(retval.labels_seen) - 1, -1, -1):
    if not isinstance(retval.labels_seen[i], LabelData):
      earliest_extra_lines_at_end = i
    else:
      break
  if earliest_extra_lines_at_end < len(retval.labels_seen):
    extra_lines_at_end = retval.labels_seen[earliest_extra_lines_at_end:]
    del retval.labels_seen[earliest_extra_lines_at_end:]
  else:
    extra_lines_at_end = []

  alt_data = None
  num_alt_labels = 0
  labelobjs_by_label = {}
  for labelobj in retval.labels_seen:
    if isinstance(labelobj, LabelData):
      if labelobj.label in labelobjs_by_label:
        pagemsg("WARNING: Saw duplicate label '%s'" % labelobj.label)
      else:
        labelobjs_by_label[labelobj.label] = labelobj

  if retval.langcode:
    alt_data = alt_data_modules.get(retval.langcode, None)
    if alt_data:
      lines_before_label = []
      for labelobj in alt_data.labels_seen:
        if isinstance(labelobj, LabelData):
          num_alt_labels += 1
          existing = labelobjs_by_label.get(labelobj.label, None)
          if existing is None:
            existing = labelobjs_by_label.get(ucfirst(labelobj.label), None)
            if existing:
              pagemsg(
                "Saw lowercase {{alt}} label '%s' and corresponding capitalized {{lb}} label '%s', adopting former" % (
                  labelobj.label, existing.label))
              existing.label = labelobj.label
          if existing is None:
            existing = labelobjs_by_label.get(lcfirst(labelobj.label), None)
            if existing:
              pagemsg(
                "Saw capitalized {{alt}} label '%s' and corresponding lowercase {{lb}} label '%s', retaining latter" % (
                  labelobj.label, existing.label))
          if existing is None:
            pagemsg("Didn't see {{alt}} label '%s', appending" % labelobj.label)
            if lines_before_label:
              retval.labels_seen.append(lines_before_label)
            else:
              retval.labels_seen.append([""])
            retval.labels_seen.append(labelobj)
          else:
            if labelobj.aliases:
              for alias in labelobj.aliases:
                if alias not in existing.aliases:
                  existing.aliases.append(alias)
            def check_and_combine_fields(field):
              existing_props = existing.misc_properties
              labelobj_props = labelobj.misc_properties
              existing_comment = getattr(existing_props, field + "_comment")
              labelobj_comment = getattr(labelobj_props, field + "_comment")
              if getattr(labelobj_props, field):
                if not getattr(existing_props, field):
                  setattr(existing_props, field, getattr(labelobj_props, field))
                  setattr(existing_props, field + "_comment", labelobj_comment)
                elif getattr(labelobj_props, field) == getattr(existing_props, field):
                  setattr(existing_props, field + "_comment", combine_comments(existing_comment, labelobj_comment))
                else:
                  pagemsg("WARNING: {{alt}} label '%s' has %s value '%s' different from existing '%s'" % (
                    labelobj.label, field, getattr(labelobj_props, field), getattr(existing_props, field)))
                  new_comment = (
                    " -- FIXME: {{alt}} label %s value '%s' different from existing" % (
                      field, getattr(labelobj_props, field)))
                  new_comment = combine_comments(labelobj_comment, new_comment)
                  setattr(existing_props, field + "_comment", combine_comments(existing_comment, new_comment))
            check_and_combine_fields("Wikipedia")
            check_and_combine_fields("display")
            if [x for x in lines_before_label if x.strip()]:
              pagemsg("WARNING: {{alt}} label '%s' has non-empty literal line(s) before it, inserting them raw" %
                labelobj.label)
              retval.labels_seen.append(lines_before_label)
            lines_before_label = []
            if labelobj.label_lines:
              pagemsg("WARNING: {{alt}} label '%s' has %s unparsable line(s), inserting them raw" % (
                labelobj.label, len(labelobj.label_lines)))
              retval.labels_seen.append(labelobj.label_lines)

        else:
          lines_before_label.extend(labelobj)

  retval.labels_seen.extend(extra_lines_at_end)

  for labelobj in retval.labels_seen:
    if isinstance(labelobj, LabelData):
      new_lines.append(labelobj.first_label_line)
      if labelobj.aliases:
        new_lines.append("\taliases = {%s}," % ", ".join(labelobj.aliases))
      def output_misc_property(propname):
        propval = getattr(labelobj.misc_properties, propname)
        propval_comment = getattr(labelobj.misc_properties, propname + "_comment")
        if propval is None and propval_comment is not None:
          errandpagemsg("WARNING: Internal error: Saw %s=None but %s_comment=%s" % (
            propname, propname, propval_comment))
          return
        if propval is not None:
          new_lines.append("\t%s = %s,%s" % (propname, propval, propval_comment or ""))
      output_misc_property("display")
      output_misc_property("Wikipedia")
      output_misc_property("glossary")
      output_misc_property("Wiktionary")
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

  notes = ["clean categories in label data module"]
  if retval.saw_old_style_alias:
    notes.append("move old-style alias specs to `aliases =`")
  if num_alt_labels > 0:
    notes.append("incorporate %s {{alt}} label(s) from [[Module:%s:dialects]] into label data module" % (
      num_alt_labels, retval.langcode))
  return text, notes

parser = blib.create_argparser("Clean label modules", include_pagefile=True, include_stdin=True)
parser.add_argument("--alt-data-modules", help="{{alt}} data modules to merge")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

alt_data_modules = {}
if args.alt_data_modules:
  for index, module_name, modtext, comments in blib.yield_text_from_find_regex(
      open(args.alt_data_modules, "r", encoding="utf-8"), args.verbose):
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, module_name, txt))
    def errandpagemsg(txt):
      errandmsg("Page %s %s: %s" % (index, module_name, txt))
    if comments:
      pagemsg("Skipping comments: %s" % comments)
    langname = None
    m = re.search("^Module:(.*):Dialects$", module_name)
    if m:
      code = m.group(1)
      if code not in blib.languages_byCode:
        errandpagemsg("WARNING: Can't locate language %s, skipping entire file" % code)
        continue
    else:
      errandpagemsg("WARNING: Can't parse module file for language code, skipping entire file")
      continue
    if code in alt_data_modules:
      errandpagemsg("WARNING: Saw code '%s' twice, skipping second instance" % code)
      continue
    alt_data_modules[code] = process_text_on_page_for_label_objects(index, module_name, modtext)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
