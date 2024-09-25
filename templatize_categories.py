#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text, langcode, langname, topicstemp):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  escaped_langcode = re.escape(langcode)
  escaped_langname = re.escape(langname).replace(r"\ ", "[ _]")
  newtext = re.sub(r"\[\[\s*[Cc][Aa][Tt]\s*:\s*(%s)\s*:\s*(.*?)\s*\]\]" % escaped_langcode, r"[[Category:\1:\2]]", text)
  if newtext != text:
    notes.append("standardize [[CAT:%s:...]] to [[Category:%s:...]]" % (langcode, langcode))
    text = newtext
  newtext = re.sub(r"\[\[\s*[Cc][Aa][Tt]\s*:\s*(%s[ _].*?)\s*\]\]" % escaped_langname, r"[[Category:\1]]", text)
  if newtext != text:
    notes.append("standardize [[CAT:%s ...]] to [[Category:%s ...]]" % (langname, langname))
    text = newtext
  newtext = re.sub(r"\[\[\s*[Cc][Aa][Tt][Ee][Gg][Oo][Rr][Yy]\s*:\s*(%s)\s*:\s*(.*?)\s*\]\]" % escaped_langcode, r"[[Category:\1:\2]]", text)
  if newtext != text:
    notes.append("standardize [[category:%s:...]] to [[Category:%s:...]]" % (langcode, langcode))
    text = newtext
  newtext = re.sub(r"\[\[\s*[Cc][Aa][Tt][Ee][Gg][Oo][Rr][Yy]\s*:\s*(%s[ _].*?)\s*\]\]" % escaped_langname, r"[[Category:\1]]", text)
  if newtext != text:
    notes.append("standardize [[category:%s ...]] to [[Category:%s ...]]" % (langname, langname))
    text = newtext
  def replace_undercores(m):
    return m.group(0).replace("_", " ")
  newtext = re.sub(r"\[\[Category:%s:.*?\]\]" % escaped_langcode, replace_undercores, text)
  if newtext != text:
    notes.append("replace underscores with spaces in [[Category:%s:...]]" % langcode)
    text = newtext
  newtext = re.sub(r"\[\[Category:%s_.*?\]\]" % escaped_langname, replace_undercores, text)
  if newtext != text:
    notes.append("replace underscores with spaces in [[Category:%s_...]]" % langname)
    text = newtext

  def process_sort_key(m, prefix):
    lang_indep_category, sortkey = m.groups()
    if sortkey == "":
      sortkey = "&#32;"
    elif sortkey == "{{SUBPAGENAME}}":
      sortkey = None
    if sortkey:
      sortkey = "|sort=%s" % sortkey
    else:
      sortkey = ""
    return "{{%s|%s%s}}" % (prefix, lang_indep_category, sortkey)

  newtext = re.sub(
    r"\[\[Category:%s:\s*([^|\[\]{}]*?)\s*\|\s*([^|\[\]]*?)\s*\]\]" % escaped_langcode,
    lambda m: process_sort_key(m, "%s|%s" % (topicstemp, langcode)), text)
  if newtext != text:
    notes.append("templatize topical categories with sort key for langcode=%s using {{%s}}" % (langcode, topicstemp))
    text = newtext
  newtext = re.sub(r"\[\[Category:%s:\s*([^|\[\]{}]*?)\s*\]\]" % escaped_langcode, r"{{%s|%s|\1}}" % (topicstemp, langcode), text)
  if newtext != text:
    notes.append("templatize topical categories for langcode=%s using {{%s}}" % (langcode, topicstemp))
    text = newtext
  newtext = re.sub(r"\{\{\s*(?:c|C|top|topic|topics|catlangcode)\s*\|\s*%s\s*\|\s*(.*?)\s*\}\}" % escaped_langcode, r"{{%s|%s|\1}}" % (topicstemp, langcode), text)
  if newtext != text:
    notes.append("standardize templatized topical categories for langcode=%s using {{%s}}" % (langcode, topicstemp))
    text = newtext
  while True:
    newtext = re.sub(r"\{\{%s\|%s\|([^=\[\]{}]*)\}\}\n\{\{%s\|%s\|([^=\[\]{}]*)\}\}" % (re.escape(topicstemp), escaped_langcode, re.escape(topicstemp), escaped_langcode),
        r"{{%s|%s|\1|\2}}" % (topicstemp, langcode), text)
    if newtext != text:
      notes.append("combine templatized topical categories for langcode=%s using {{%s}}" % (langcode, topicstemp))
      text = newtext
    else:
      break

  newtext = re.sub(
    r"\[\[Category:%s ([^|\[\]{}]*?)\s*\|\s*([^|\[\]]*?)\s*\]\]" % escaped_langname,
    lambda m: process_sort_key(m, "cln|%s" % langcode), text)
  if newtext != text:
    notes.append("templatize langname categories with sort key for langcode=%s using {{cln}}" % langcode)
    text = newtext
  newtext = re.sub(r"\[\[Category:%s ([^|\[\]{}]*?)\s*\]\]" % escaped_langname, r"{{cln|%s|\1}}" % langcode, text)
  if newtext != text:
    notes.append("templatize langname categories for langcode=%s using {{cln}}" % langcode)
    text = newtext
  newtext = re.sub(r"\{\{\s*(?:catlangname|cln)\s*\|\s*%s\s*\|\s*(.*?)\s*\}\}" % escaped_langcode, r"{{cln|%s|\1}}" % langcode, text)
  if newtext != text:
    notes.append("standardize templatized langname categories for langcode=%s using {{cln}}" % langcode)
    text = newtext
  while True:
    newtext = re.sub(r"\{\{cln\|%s\|([^=\[\]{}]*)\}\}\n\{\{cln\|%s\|([^=\[\]{}]*)\}\}" % (escaped_langcode, escaped_langcode), r"{{cln|%s|\1|\2}}" % langcode, text)
    if newtext != text:
      notes.append("combine templatized langname categories for langcode=%s using {{cln}}" % langcode)
      text = newtext
    else:
      break

  return text, notes

if __name__ == "__main__":
  parser = blib.create_argparser("Templatize categories", include_pagefile=True, include_stdin=True)
  parser.add_argument("--langcode", help="Code of language to templatize")
  parser.add_argument("--langname", help="Name of language to templatize")
  parser.add_argument("--topics-template", help="Name of topics template to use", default="C")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  langcode = args.langcode
  langname = args.langname
  if not langcode and not langname:
    raise ValueError("Either --langcode or --langname must be specified")
  if not langcode:
    blib.getData()
    if langname not in blib.languages_byCanonicalName:
      pagemsg("WARNING: Unknown language name %s" % langname)
    else:
      langcode = blib.languages_byCanonicalName[langname]["code"]
  elif not langname:
    blib.getData()
    if langcode not in blib.languages_byCode:
      pagemsg("WARNING: Unknown language code %s" % langcode)
    else:
      langname = blib.languages_byCode[langcode]["canonicalName"]

  if langcode and langname:
    def do_process_text_on_page(index, pagetitle, text):
      return process_text_on_page(index, pagetitle, text, langcode, langname, args.topics_template)
    blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page, default_cats=[langname + " lemmas"], edit=True, stdin=True)
