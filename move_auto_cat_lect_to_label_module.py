#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, set_template_name, msg, errandmsg, site, tname

import clean_label_module
from clean_label_module import LabelData, Field, FieldReference

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "auto cat":
      def getp(param):
        return getparam(t, param)
      if not getp("lect"):
        pagemsg("WARNING: Saw {{auto cat}} without lect= specified")
        return
      for param in t.params:
        FIXME

  lang_specific_label_data = clean_label_module.process_text_on_page_for_label_objects(index, pagename, text)
  if lang_specific_label_data is None:
    return
  langcode = lang_specific_label_data.langcode
  if langcode is None:
    errandpagemsg("Can't locate or parse language code from module name")
    return
  existing_langs_seen.add(langcode)

  lang_specific_labels = {}

  for labelobj in lang_specific_label_data.labels_seen:
    if isinstance(labelobj, LabelData):
      if labelobj.label in lang_specific_labels:
        pagemsg("WARNING: Lang-specific label '%s' seen more than once as label or alias%s" % (
          labelobj.label,
          " (existing label is canonical)" if lang_specific_labels[labelobj.label].label == labelobj.label else
          " (existing label is alias for '%s')" % lang_specific_labels[labelobj.label].label))
      else:
        lang_specific_labels[labelobj.label] = labelobj
      if hasattr(labelobj.fields, "aliases"):
        for alias in labelobj.fields.aliases.value:
          if alias in lang_specific_labels:
            pagemsg("WARNING: Lang-specific alias '%s' of label '%s' seen more than once as label or alias%s" % (
              alias, labelobj.label,
              " (existing label is canonical)" if lang_specific_labels[alias].label == alias else
              " (existing label is alias for '%s')" % lang_specific_labels[alias].label))
          else:
            lang_specific_labels[alias] = labelobj

  extra_lines_at_end = clean_label_module.extract_extra_lines_at_end(lang_specific_label_data.labels_seen)

  if langcode not in regional_labelobjs_by_lang:
    return
  num_incorporated_regional_labelobjs = 0
  incorporated_regional_labels = []
  commented_out_incorporated_regional_labels = []
  for labelobj in regional_labelobjs_by_lang[langcode]:
    assert isinstance(labelobj, LabelData)
    num_incorporated_regional_labelobjs += 1
    def is_canonical(label):
      return (
        " (existing label is canonical)" if lang_specific_labels[label].label == label else
        " (existing label is alias for '%s')" % lang_specific_labels[label].label
      )
    def comment_out(labelobj, dupmsg):
      new_lines = clean_label_module.output_labels([labelobj], pagemsg)
      return ["", "-- %s" % dupmsg] + ["-- %s" % line for line in new_lines]
    dupmsgs = []
    if labelobj.label in lang_specific_labels:
      dupmsg = "Regional label '%s' duplicated in lang-specific data%s, adding commented-out" % (
        labelobj.label, is_canonical(labelobj.label))
      pagemsg("WARNING: %s" % dupmsg)
      dupmsgs.append(dupmsg)
    if hasattr(labelobj.fields, "aliases"):
      for alias in labelobj.fields.aliases.value:
        if alias in lang_specific_labels:
          dupmsg = "Regional alias '%s' of label '%s' duplicated in lang-specific data%s, adding commented-out" % (
            alias, labelobj.label, is_canonical(alias))
          pagemsg("WARNING: %s" % dupmsg)
          dupmsgs.append(dupmsg)
    if dupmsgs:
      commented_out_incorporated_regional_labels.append(labelobj.label)
      new_lines = comment_out(labelobj, "; ".join(dupmsgs))
      lang_specific_label_data.labels_seen.append(new_lines)
    else:
      incorporated_regional_labels.append(labelobj.label)
      lang_specific_label_data.labels_seen.append([""])
      lang_specific_label_data.labels_seen.append(labelobj)

  lang_specific_label_data.labels_seen.extend(extra_lines_at_end)

  new_lines = clean_label_module.output_labels(lang_specific_label_data.labels_seen, pagemsg)
  text = "\n".join(new_lines)
  text = text.replace("\n\n\n", "\n\n")
  text = re.sub("^    ", "\t", text, 0, re.M)

  if num_incorporated_regional_labelobjs > 0:
    label_msg_parts = []
    def add_part(prefix, labels):
      if len(labels) > 25:
        labels = ",".join(labels[0:25]) + ",..."
      else:
        labels = ",".join(labels)
      label_msg_parts.append(prefix + labels)
    if incorporated_regional_labels:
      add_part("", incorporated_regional_labels)
    if commented_out_incorporated_regional_labels:
      add_part("commented-out ", commented_out_incorporated_regional_labels)
    notes = ["move %s label(s) (%s) from [[%s]] to lang-specific labels data module" % (
             num_incorporated_regional_labelobjs, " + ".join(label_msg_parts), args.regional_data_module_name)]
  else:
    notes = ["clean lang-specific labels data module"]
  return text, notes

parser = blib.create_argparser("Split regional label data module", include_pagefile=True, include_stdin=True)
parser.add_argument("--regional-data-module", help="File containing 'Module:labels/data/regional'", required=True)
parser.add_argument("--regional-data-module-name", help="Name of regional data module", default="Module:labels/data/regional")
parser.add_argument("--categories", help="File containing categories.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

regional_module_text = open(args.regional_data_module, "r", encoding="utf-8").read()
regional_label_data = clean_label_module.process_text_on_page_for_label_objects(
    1, args.regional_data_module, regional_module_text)
if regional_label_data is None:
  errandmsg("WARNING: Error parsing regional label data module '%s', stopping" % args.regional_data_module)
else:
  langs_by_category_prefix = defaultdict(list)
  if args.categories:
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

  regional_labels_by_lang = defaultdict(dict)
  regional_labelobjs_by_lang = defaultdict(list)
  def pagemsg(txt):
    msg("Page 0 %s: %s" % (args.regional_data_module, txt))
  filtered_regional_label_data = []
  lines_before_label = []
  num_removed_labels = 0
  for labelobj in regional_label_data.labels_seen:
    if isinstance(labelobj, LabelData):
      remove_langs_field = False
      if args.categories:
        langs_for_label = set()
        def canon_cat(cat):
          if cat == "true":
            return clean_label_module.ucfirst(labelobj.label)
          else:
            return cat[1:-1]
        for regcat in labelobj.regional_categories.cats:
          regcat = canon_cat(regcat)
          pagemsg("For regional label '%s', regional category '%s', languages: %s" % (
              labelobj.label, regcat, regcat not in langs_by_category_prefix and "NONE" or ", ".join(
                "%s (%s)" % (blib.languages_byCanonicalName[lang]["code"], lang) for lang in
                langs_by_category_prefix[regcat])))
          for lang in langs_by_category_prefix[regcat]:
            langs_for_label.add(blib.languages_byCanonicalName[lang]["code"])
        for plaincat in labelobj.plain_categories.cats:
          plaincat = canon_cat(plaincat)
          pagemsg("For regional label '%s', plain category '%s', languages: %s" % (
              labelobj.label, plaincat, plaincat not in category_prefixes and "NONE" or ", ".join(
                "%s (%s=%s)" % (prefix, blib.languages_byCanonicalName[lang]["code"], lang) for prefix, lang in
                category_prefixes[plaincat])))
          for prefix, lang in category_prefixes[plaincat]:
            langs_for_label.add(blib.languages_byCanonicalName[lang]["code"])
        langs_for_label = sorted(list(langs_for_label))
      elif hasattr(labelobj.fields, "langs"):
        langs_for_label = labelobj.fields.langs.value
        remove_langs_field = True
      else:
        pagemsg("WARNING: No langs specified for regional label '%s'" % labelobj.label)
        langs_for_label = []
      keep = False
      if not langs_for_label:
        pagemsg("WARNING: No languages for regional label '%s'" % labelobj.label)
        keep = True
        lines_before_label.append("-- WARNING: No existing languages or categories associated with label; add to `langs` as needed")
      elif len(langs_for_label) > 3:
        pagemsg("WARNING: Not removing regional label '%s' with %s languages %s > 3" % (
          labelobj.label, len(langs_for_label), ",".join(langs_for_label)))
        keep = True
      elif hasattr(labelobj.fields, "aliases") and len(labelobj.fields.aliases.value) > 1 and len(langs_for_label) > 1:
        pagemsg("WARNING: Not removing regional label '%s' with %s aliases %s > 1 and %s languages %s > 1" % (
          labelobj.label, len(labelobj.fields.aliases.value), ",".join(labelobj.fields.aliases.value),
          len(langs_for_label), ",".join(langs_for_label)))
        keep = True
      if keep:
        if labelobj.label != "regional" and not hasattr(labelobj.fields, "langs"):
          labelobj.fields.langs = Field(langs_for_label)
        filtered_regional_label_data.append(lines_before_label)
        filtered_regional_label_data.append(labelobj)
      else:
        for lang in langs_for_label:
          regional_labelobjs_by_lang[lang].append(labelobj)
          if labelobj.label in regional_labels_by_lang[lang]:
            existing_labelobj = regional_labels_by_lang[lang][labelobj.label]
            pagemsg("WARNING: For language %s (%s), regional label '%s' seen more than once as label or alias%s" % (
              (blib.languages_byCanonicalName[lang]["code"], lang, labelobj.label,
               "" if existing_labelobj.label == labelobj.label else
               " (existing label is alias for '%s')" % existing_labelobj.label)))
          else:
            regional_labels_by_lang[lang][labelobj.label] = labelobj
        pagemsg("Removing label %s from [[%s]], moved to lang-specific modules" % (
                labelobj.label, args.regional_data_module_name))
        num_removed_labels += 1
        if remove_langs_field:
          delattr(labelobj.fields, "langs")
          labelobj.label_lines = [
            label_line for label_line in labelobj.label_lines
            if type(label_line) is not FieldReference or label_line.field != "langs"
          ]
        if [x for x in lines_before_label if x.strip()]:
          pagemsg("WARNING: Skipped regional label '%s' has non-empty literal line(s) before it, inserting them raw" %
            labelobj.label)
          filtered_regional_label_data.append(lines_before_label)
      lines_before_label = []
    else:
      lines_before_label.extend(labelobj)

  filtered_regional_label_data.append(["", 'return require("Module:labels").finalize_data(labels)'])
  new_regional_lines = clean_label_module.output_labels(filtered_regional_label_data, pagemsg)
  blib.do_handle_stdin_retval(
      args, ("\n".join(new_regional_lines), "move %s label(s) to lang-specific modules" % num_removed_labels),
      regional_module_text, None, pagemsg, is_find_regex=True, edit=True)

  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

  for index, (lang, labelobjs) in enumerate(sorted(list(regional_labelobjs_by_lang.items()), key=lambda x: x[0])):
    lang_specific_module = "Module:labels/data/lang/%s" % lang
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, lang_specific_module, txt))
    if lang not in existing_langs_seen:
      labelobjs_with_text = []
      labelobjs_with_text.append(["local labels = {}"])
      for labelobj in labelobjs:
        labelobjs_with_text.append([""])
        labelobjs_with_text.append(labelobj)
      labelobjs_with_text.append(["", 'return require("Module:labels").finalize_data(labels)'])
      new_lang_specific_lines = clean_label_module.output_labels(labelobjs_with_text, pagemsg)
      blib.do_handle_stdin_retval(
        args, ("\n".join(new_lang_specific_lines),
               "move %s label(s) from [[%s]] to new lang-specific module" % (
                 len(labelobjs), args.regional_data_module_name)),
        "", None, pagemsg, is_find_regex=True, edit=True)
