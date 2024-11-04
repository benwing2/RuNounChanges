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

parser = blib.create_argparser("Move lect data in {{auto cat}} calls to label data module", include_pagefile=True, include_stdin=True)
parser.add_argument("--label-data-module", help="File containing 'Module:labels/data/LANG'", required=True)
parser.add_argument("--langname", help="Language name of label data module", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

label_data_module_text = open(args.label_data_module, "r", encoding="utf-8").read()
label_data = clean_label_module.process_text_on_page_for_label_objects(
    1, args.label_data_module, label_data_module_text)
if label_data is None:
  errandmsg("WARNING: Error parsing regional label data module '%s', stopping" % args.label_data_module)
else:
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
