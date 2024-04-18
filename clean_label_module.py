#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
from dataclasses import dataclass, field
from collections import defaultdict
from typing import Any, Callable

import blib
from blib import getparam, rmparam, set_template_name, msg, errandmsg, site, tname

blib.getLanguageData()

@dataclass
class Field:
  value: Any
  comment: str = None

@dataclass
class FieldReference:
  field: str

class Properties:
  pass

recognized_fields = [
  "Wikipedia",
  "Wiktionary",
  "Wikidata",
  "display",
  "special_display",
  "glossary",
  "track",
  "omit_preComma",
  "omit_postComma",
  "topical_categories",
  "sense_categories",
  "pos_categories",
  "regional_categories",
  "plain_categories",
  "aliases",
  "deprecated_aliases",
  "langs",
  # lect fields
  "region",
  "parent",
  "prep",
  "verb",
  "def",
  "fulldef",
  "noreg",
  "nolink",
  "the",
]

@dataclass
class CategorySpec:
  # List of "categories"; also used for aliases. Actual categories are either the string "true" or a category with
  # double quotes around the category; aliases do not include the double quotes.
  cats: list = field(default_factory=list)
  comment: str = None

@dataclass
class LabelData:
  label: str
  first_label_line: str
  label_lines: list
  last_label_line: str
  fields: dict
  lines_after: list = field(default_factory=list)

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

def combine_comments(a, b):
  if a is None and b is None:
    return None
  if a is None:
    return b
  if b is None:
    return a
  return "%s, %s" % (a, re.sub("^ *-- *", "", b))

existing_label_module_langs_seen = set()
def process_text_on_page_for_label_objects(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  notes = []

  langcode = None
  langname = None
  m = re.search("^Module:labels/data/lang/(.*)$", pagename)
  if m:
    existing_label_module_langs_seen.add(m.group(1))
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
  fields = {}
  label = False

  either_quote_string_re = '(".*?"|' + "'.*?')"
  true_false_or_either_quote_string_re = '(true|false|".*?"|' + "'.*?')"

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
        alias = alias[1:-1] # discard quotes
        canon = canon[1:-1] # discard quotes
        if canon not in indexed_labels:
          linemsg("WARNING: Unable to locate canonical label '%s' for aliases: %s" % (canon, line))
          label_lines.append(line)
          continue
        labels_seen[indexed_labels[canon]].aliases.cats.append(alias)
        continue
      m = re.search(r"^labels *\[%s\] = \{$" % (either_quote_string_re), line.rstrip())
      if not m:
        linemsg("WARNING: Unable to parse labels start line: %s" % line)
        label_lines.append(line)
      else:
        label = m.group(1)[1:-1]
        first_label_line = line
        if label_lines:
          labels_seen.append(label_lines)
          label_lines = []
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

      labels_seen.append(LabelData(label, first_label_line, label_lines, line, fields))
      indexed_labels[label] = len(labels_seen) - 1
      label = False
      label_lines = []
      first_label_line = None
    elif label:
      origline = line
      line = line.strip()

      m = re.search("^([A-Za-z_][A-Za-z0-9]*)%s *= *(.*?),?( *--.*)?$", line)
      if m:
        fieldname, rawval, comment = m.groups()
        if fieldname not in recognized_fields:
          linemsg("WARNING: Unrecognized field '%s': %s" % (fieldname, line))
          label_lines.append(origline)
          continue
        def parse_single_value(rawval):
          if re.match("^" + true_false_or_either_quote_string_re + "$", rawval):
            if rawval == "true":
              return True
            if rawval == "false":
              return True
            return rawval[1:-1]
          return None
        def parse_value(rawval):
          single_val = parse_single_value(rawval)
          if single_val is not None:
            return single_val
          m = re.search(r"^\{(.*)\}$", rawval)
          if m:
            inside = m.group(1).strip()
            if not inside:
              linemsg("WARNING: Empty list for field '%s': %s" % (fieldname, line))
              return None
            if inside.endswith(","):
              inside = inside[:-1].strip()
            split_vals = re.split(true_false_or_either_quote_string_re, insde)
            vals = []
            for i, split_val in enumerate(split_vals):
              if i % 2 == 1:
                val = parse_single_value(split_val)
                if val is None:
                  linemsg("WARNING: Internal error: Can't parse value '%s' for field '%s': %s" % (
                    split_val, fieldname, line))
                  return None
                vals.append(val)
              elif ((i == 0 or i == len(split_vals) - 1) and split_val.strip()
                    or (i > 0 and i < len(split_vals) - 1) and split_val.strip() != ","):
                linemsg("WARNING: Junk '%s' between values for field '%s': %s" % (split_val, fieldname, line))
                return None
            return vals
          linemsg("WARNING: Unable to parse value '%s' for field '%s': %s" % (rawval, fieldname, line))
          return None

        val = parse_value(rawval)
        if val is None:
          label_lines.append(origline)
        elif hasattr(fields, fieldname):
          linemsg("WARNING: Saw field '%s' twice: %s" % (fieldname, line))
          label_lines.append(origline)
        else:
          setattr(fields, fieldname, Field(val, comment))
          label_lines.append(FieldReference(fieldname))

      def process_cats(prefix, spec, process_one_cat):
        m = re.search("^%s *= *(.*?),?( *--.*)?$" % prefix, line)
        if m:
          spec.comment = combine_comments(spec.comment, m.group(2))
          cats = extract_categories(m.group(1).strip())
          if cats is None:
            label_lines.append(origline)
          else:
            for cat in cats:
              if cat is True:
                spec.cats.append("true")
              elif not process_one_cat(cat):
                spec.cats.append('"%s"' % cat)
          return True
        return False

      def process_aliases(cat):
        aliases.cats.append(cat)
        return True
      def process_deprecated_aliases(cat):
        deprecated_aliases.cats.append(cat)
        return True
      def process_topical(cat):
        if cat == label or cat == ucfirst(label):
          topical_categories.cats.append("true")
          return True
      def process_sense(cat):
        if cat == label:
          sense_categories.cats.append("true")
          return True
      def process_pos(cat):
        if cat == label:
          pos_categories.cats.append("true")
          return True
      def process_regional(cat):
        if cat == label or cat == ucfirst(label):
          regional_categories.cats.append("true")
          return True
      def process_plain(cat):
        if cat == label or cat == ucfirst(label):
          plain_categories.cats.append("true")
          return True
        elif langname and cat.endswith(" " + langname):
          regcat = cat[:-(len(langname) + 1)] # +1 for preceding space
          if regcat == label or regcat == ucfirst(label):
            regional_categories.cats.append("true")
          else:
            regional_categories.cats.append('"%s"' % regcat)
          return True
      if (not process_cats("aliases", aliases, process_aliases)
          and not process_cats("deprecated_aliases", deprecated_aliases, process_deprecated_aliases)
          and not process_cats("topical_categories", topical_categories, process_topical)
          and not process_cats("sense_categories", sense_categories, process_sense)
          and not process_cats("pos_categories", pos_categories, process_pos)
          and not process_cats("regional_categories", regional_categories, process_regional)
          and not process_cats("plain_categories", plain_categories, process_plain)
      ):
        def process_str_property(propname):
          m = re.search("^%s *= *%s,?( *--.*)?$" % (propname, true_or_either_quote_string_re), line)
          if m:
            propval = m.group(1)
            if propval == "true":
              propval = label
            else:
              propval = propval[1:-1] # remove existing quotes
            propval = '"%s"' % propval # canonicalize quotes
            propval_comment = m.group(2)
            if getattr(str_properties, propname) is not None:
              pagemsg("WARNING: Saw %s = %s twice" % (propname, propval))
            else:
              setattr(str_properties, propname, propval)
              setattr(str_properties, propname + "_comment", propval_comment)
              return True
          return False
        def process_bool_property(propname):
          m = re.search("^%s *= true,?$" % propname, line)
          if m:
            if getattr(bool_properties, propname) is not None:
              pagemsg("WARNING: Saw %s = true twice" % propname)
            else:
              setattr(bool_properties, propname, True)
              return True
          return False

        if (not process_str_property("display")
            and not process_str_property("special_display")
            and not process_str_property("Wikipedia")
            and not process_str_property("glossary")
            and not process_str_property("Wiktionary")
            and not process_str_property("Wikidata")
            and not process_bool_property("track")
            and not process_bool_property("omit_preComma")
            and not process_bool_property("omit_postComma")
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
      for alias in aliases:
        alias = alias[1:-1] # discard quotes
        labels_seen[indexed_labels[canon]].aliases.cats.append(alias)

    elif line.startswith("local function alias("):
      pass

    elif line == "return labels":
      label_lines.append('return require("Module:labels").finalize_data(labels)')

    else:
      label_lines.append(line)

  if label_lines:
    labels_seen.append(label_lines)

  return ProcessForLabelObjectsRetval(
    labels_seen, langcode, langname, saw_old_style_alias
  )

def output_labels(labels_seen, pagemsg):
  new_lines = []
  for labelobj in labels_seen:
    if isinstance(labelobj, LabelData):
      new_lines.append(labelobj.first_label_line)
      def output_value(val):
        if val is True:
          return "true"
        elif val is False:
          return "false"
        elif type(val) is str:
          return '"%s"' % val
        elif type(val) is list:
          vals = []
          for v in val:
            vals.append(output_value(v))
          return "{%s}" % ", ".join(vals)
        else:
          pagemsg("WARNING: Internal error: Unrecognized field value '%s'" % val)
          return "nil"
      for label_line in labelobj.label_lines:
        if type(label_line) is str:
          new_lines.append(label_line)
        else:
          fieldval = getattr(labelobj.fields, label_line.field)
          new_lines.append("\t%s = %s,%s" % (label_line.field, output_value(fieldval.value), fieldval.comment or ""))
      new_lines.append(labelobj.last_label_line)
      new_lines.extend(labelobj.lines_after)
    else:
      new_lines.extend(labelobj)
  return new_lines

def extract_extra_lines_at_end(labels_seen):
  # Extract off any literal lines at the end (including the call to finalize_labels()). Any additions need to go
  # before these final lines.
  earliest_extra_lines_at_end = len(labels_seen)
  for i in range(len(labels_seen) - 1, -1, -1):
    if not isinstance(labels_seen[i], LabelData):
      earliest_extra_lines_at_end = i
    else:
      break
  if earliest_extra_lines_at_end < len(labels_seen):
    extra_lines_at_end = labels_seen[earliest_extra_lines_at_end:]
    del labels_seen[earliest_extra_lines_at_end:]
  else:
    extra_lines_at_end = []
  return extra_lines_at_end

def comment_out(labelobj, dupmsg, pagemsg):
  new_lines = output_labels([labelobj], pagemsg)
  return ["-- FIXME: %s" % dupmsg] + ["-- %s" % line for line in new_lines]

max_label_index_seen = 0
def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  global max_label_index_seen
  max_label_index_seen = max(max_label_index_seen, index)
  retval = process_text_on_page_for_label_objects(index, pagename, text)
  if retval is None:
    return

  extra_lines_at_end = extract_extra_lines_at_end(retval.labels_seen)

  alt_data = None
  num_alt_labels = 0
  num_new_alt_labels = 0
  labelobjs_by_label = {}
  label_is_regional = set()
  canonical_lang_specific_label_with_regional_aliases_bleeding_through = {}

  for labelobj in retval.labels_seen:
    if isinstance(labelobj, LabelData):
      if labelobj.label in labelobjs_by_label:
        pagemsg("WARNING: Saw duplicate label '%s'" % labelobj.label)
      else:
        labelobjs_by_label[labelobj.label] = labelobj
      for alias in labelobj.aliases.cats:
        if alias in labelobjs_by_label:
          if labelobjs_by_label[alias].label == alias:
            pagemsg("WARNING: Saw alias '%s' of label '%s' duplicating label" % (alias, labelobj.label))
          else:
            pagemsg("WARNING: Saw alias '%s' of label '%s' duplicating alias of label '%s'" % (
              alias, labelobj.label, labelobjs_by_label[alias].label))
        else:
          labelobjs_by_label[alias] = labelobj

  for labelobj in regional_label_data.labels_seen:
    if isinstance(labelobj, LabelData):
      # Define the "alias set" of a label as the set containing the label and all its aliases. Now, for a given
      # regional label, if any label in a given label's alias set is overridden at the lang-specific level, we
      # want to check that the alias set of the regional label is a subset of the alias set of the overriding
      # lang-specific label. If not, we say that a member of the regional label's alias set is bleeding through,
      # which should be corrected, and so we output the regional label definition after the definition of the
      # lang-specific label definition. Note that it's possible for different members of a given regional
      # label's alias set to be overridden by different lang-specific labels, and so for each overridding
      # lang-specific label, we have to check for bleed-through and if so, output the regional label's
      # definition after the relevant lang-specific label definition.
      regional_alias_set = set(labelobj.fields.aliases.value) | {labelobj.label}
      any_bleed_through = False
      not_completely_overridden = False
      canon_labels_with_bleed_through = set()
      for member in regional_alias_set:
        if member in labelobjs_by_label:
          lang_specific_obj = labelobjs_by_label[member]
          lang_specific_alias_set = set(lang_specific_obj.aliases.cats) | {lang_specific_obj.label}
          bleeding_through_members = regional_alias_set - lang_specific_alias_set
          if bleeding_through_members:
            any_bleed_through = True
            if lang_specific_obj.label not in canon_labels_with_bleed_through:
              canon_labels_with_bleed_through.add(lang_specific_obj.label)
              dupmsg = "WARNING: Alias set members '%s' of regional label '%s' with aliases '%s' are bleeding through with respect to lang-specific label '%s' with aliases '%s'" % (
                ",".join(sorted(list(bleeding_through_members))), labelobj.label, ",".join(labelobj.aliases.cats),
                lang_specific_obj.label, ",".join(lang_specific_obj.aliases.cats))
              pagemsg(dupmsg)
              lang_specific_obj.lines_after.extend(
                  comment_out(labelobj, dupmsg + "; regional label definition follows:", pagemsg))
        else:
          not_completely_overridden = True
      if not_completely_overridden and not any_bleed_through:
        if labelobj.label in labelobjs_by_label:
          pagemsg("WARNING: Saw duplicate regional label '%s'" % labelobj.label)
        else:
          labelobjs_by_label[labelobj.label] = labelobj
          label_is_regional.add(labelobj.label)
        for alias in labelobj.aliases.cats:
          if alias in labelobjs_by_label:
            if labelobjs_by_label[alias].label == alias:
              pagemsg("WARNING: Saw alias '%s' of regional label '%s' duplicating regional label" % (alias, labelobj.label))
            else:
              pagemsg("WARNING: Saw alias '%s' of regional label '%s' duplicating alias of regional label '%s'" % (
                alias, labelobj.label, labelobjs_by_label[alias].label))
          else:
            labelobjs_by_label[alias] = labelobj

  if retval.langcode:
    alt_data = alt_data_modules.get(retval.langcode, None)
    if alt_data:
      lines_before_label = []
      canon_labels_duplicating = defaultdict(set)
      for labelobj in alt_data.labels_seen:
        if isinstance(labelobj, LabelData):
          num_alt_labels += 1
          match = labelobj.label
          existing = labelobjs_by_label.get(match, None)
          def output_dup_with_regional(alias):
            if labelobj.label not in canon_labels_duplicating[existing.label]:
              dupmsg = "WARNING: {{alt}} label '%s' %s existing regional %s, inserting both commented-out%s" % (
                labelobj.label,
                "has alias '%s' matching" % alias if alias is not None else "matches",
                "label '%s'" % match if match == existing.label else "alias '%s' of label '%s'" % (match, existing.label),
                " (also duplicates label(s) '%s')" % ",".join(sorted(list(canon_labels_duplicating[existing.label])))
                if canon_labels_duplicating[existing.label] else "")
              pagemsg(dupmsg)
              canon_labels_duplicating[existing.label].add(labelobj.label)
              if lines_before_label:
                retval.labels_seen.append(lines_before_label)
              else:
                retval.labels_seen.append([""])
              retval.labels_seen.append(comment_out(labelobj, dupmsg, pagemsg))
              retval.labels_seen.append(comment_out(existing, "corresponding regional label follows:", pagemsg))
          if existing is None:
            match = ucfirst(labelobj.label)
            existing = labelobjs_by_label.get(match, None)
            if existing:
              pagemsg(
                "Saw lowercase {{alt}} label '%s' and corresponding capitalized {{lb}} label '%s', adopting former" % (
                  labelobj.label, existing.label))
              existing.label = labelobj.label
          if existing is None:
            match = lcfirst(labelobj.label)
            existing = labelobjs_by_label.get(match, None)
            if existing:
              pagemsg(
                "Saw capitalized {{alt}} label '%s' and corresponding lowercase {{lb}} label '%s', retaining latter" % (
                  labelobj.label, existing.label))
          if existing is None:
            has_dup_alias = False
            for alias in labelobj.aliases.cats:
              match = ucfirst(alias)
              existing = labelobjs_by_label.get(match, None)
              if existing is None:
                match = lcfirst(alias)
                existing = labelobjs_by_label.get(match, None)
              if existing:
                has_dup_alias = True
                if labelobj.label not in canon_labels_duplicating[existing.label]:
                  # we check to see that we haven't already seen the label because an {{alt}} tag and corresponding
                  # {{lb}} label might share multiple aliases
                  if existing.label in label_is_regional:
                    output_dup_with_regional(alias)
                  else:
                    dupmsg = "WARNING: {{alt}} label '%s' has alias '%s' matching existing %s, inserting commented-out%s" % (
                      labelobj.label, alias,
                      "label '%s'" % match if match == existing.label else "alias '%s' of label '%s'" % (match, existing.label),
                      " (also duplicates label(s) '%s')" % ",".join(sorted(list(canon_labels_duplicating[existing.label])))
                      if canon_labels_duplicating[existing.label] else "")
                    pagemsg(dupmsg)
                    canon_labels_duplicating[existing.label].add(labelobj.label)
                    existing.lines_after.extend(comment_out(labelobj, dupmsg, pagemsg))
            if not has_dup_alias:
              num_new_alt_labels += 1
              pagemsg("Didn't see {{alt}} label '%s', appending" % labelobj.label)
              if lines_before_label:
                retval.labels_seen.append(lines_before_label)
              else:
                retval.labels_seen.append([""])
              retval.labels_seen.append(labelobj)
          elif existing.label in label_is_regional:
            # We are matching a regional label. We can't merge the {{alt}} tag with the label so we output both at the
            # end.
            output_dup_with_regional(None)
          elif match != existing.label:
            # the canonical {{alt}} tag matched an existing alias of some {{lb}} label
            if match not in canon_labels_duplicating[existing.label]:
              # we check to see that we haven't already seen the label because an {{alt}} tag and corresponding
              # {{lb}} label might share multiple aliases
              dupmsg = "WARNING: {{alt}} label '%s' matches existing alias '%s' of label '%s', inserting commented-out%s" % (
                labelobj.label, match, existing.label,
                " (also duplicates label(s) '%s')" % ",".join(sorted(list(canon_labels_duplicating[existing.label])))
                if canon_labels_duplicating[existing.label] else "")
              pagemsg(dupmsg)
              canon_labels_duplicating[existing.label].add(match)
              existing.lines_after.extend(comment_out(labelobj, dupmsg, pagemsg))
          else:
            if labelobj.aliases.cats:
              for alias in labelobj.aliases.cats:
                if alias not in existing.aliases.cats:
                  existing.aliases.cats.append(alias)
              existing.aliases.comment = combine_comments(existing.aliases.comment, labelobj.aliases.comment)
            def check_and_combine_fields(field):
              existing_props = existing.str_properties
              labelobj_props = labelobj.str_properties
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

  new_lines = output_labels(retval.labels_seen, pagemsg)
  text = "\n".join(new_lines)
  text = text.replace("\n\n\n", "\n\n")
  text = re.sub("^    ", "\t", text, 0, re.M)

  notes = ["clean categories in label data module"]
  if retval.saw_old_style_alias:
    notes.append("move old-style alias specs to `aliases =`")
  if num_alt_labels > 0:
    notes.append("incorporate %s {{alt}} label(s) (%s new) from [[Module:%s:Dialects]] into label data module" % (
      num_alt_labels, num_new_alt_labels, retval.langcode))
  return text, notes

if __name__ == "__main__":
  parser = blib.create_argparser("Clean label modules", include_pagefile=True, include_stdin=True)
  parser.add_argument("--regional-data-module", help="File containing 'Module:labels/data/regional'")
  parser.add_argument("--alt-data-modules", help="{{alt}} data modules to merge")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  alt_data_modules = {}
  if args.alt_data_modules:
    if not args.regional_data_module:
      raise ValueError("If --alt-data-modules is given, so must --regional-data-module")
    regional_module_text = open(args.regional_data_module, "r", encoding="utf-8").read()
    regional_label_data = process_text_on_page_for_label_objects(0, args.regional_data_module, regional_module_text)
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

  for index, alt_langcode in enumerate(sorted(list(alt_data_modules.keys()))):
    if alt_langcode not in existing_label_module_langs_seen:
      lang_specific_module = "Module:labels/data/lang/%s" % alt_langcode
      def pagemsg(txt):
        msg("Page %s %s: %s" % (index + max_label_index_seen + 1, lang_specific_module, txt))
      labelobjs_with_text = []
      labelobjs_with_text.append(["local labels = {}"])
      labels_seen = alt_data_modules[alt_langcode].labels_seen
      for labelobj in labels_seen:
        if isinstance(labelobj, LabelData):
          labelobjs_with_text.append([""])
          labelobjs_with_text.append(labelobj)
        else:
          labelobjs_with_text.append(labelobj)
      labelobjs_with_text.append(['return require("Module:labels").finalize_data(labels)'])
      new_lang_specific_lines = output_labels(labelobjs_with_text, pagemsg)
      blib.do_handle_stdin_retval(
        args, ("\n".join(new_lang_specific_lines),
               "move %s {{alt}} label(s) from [[Module:%s:Dialects]] into new label data module" % (
               len(list(x for x in labels_seen if isinstance(x, LabelData))), alt_langcode)), 
        "", None, pagemsg, is_find_regex=True, edit=True)
