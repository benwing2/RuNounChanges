#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text, lang, langname, topicstemp):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  newtext = re.sub(r"\[\[[Cc][Aa][Tt]:(%s:.*?)\]\]" % re.escape(lang), r"[[Category:\1]]", text)
  if newtext != text:
    notes.append("standardize [[CAT:%s:...]] to [[Category:%s:...]]" % (lang, lang))
    text = newtext
  newtext = re.sub(r"\[\[[Cc][Aa][Tt]:(%s[ _].*?)\]\]" % re.escape(langname), r"[[Category:\1]]", text)
  if newtext != text:
    notes.append("standardize [[CAT:%s ...]] to [[Category:%s ...]]" % (langname, langname))
    text = newtext
  newtext = re.sub(r"\[\[[Cc][Aa][Tt][Ee][Gg][Oo][Rr][Yy]:(%s:.*?)\]\]" % re.escape(lang), r"[[Category:\1]]", text)
  if newtext != text:
    notes.append("standardize [[category:%s:...]] to [[Category:%s:...]]" % (lang, lang))
    text = newtext
  newtext = re.sub(r"\[\[[Cc][Aa][Tt][Ee][Gg][Oo][Rr][Yy]:(%s[ _].*?)\]\]" % re.escape(langname), r"[[Category:\1]]", text)
  if newtext != text:
    notes.append("standardize [[category:%s ...]] to [[Category:%s ...]]" % (langname, langname))
    text = newtext
  def replace_undercores(m):
    return m.group(0).replace("_", " ")
  newtext = re.sub(r"\[\[Category:%s_.*?\]\]" % re.escape(langname), replace_undercores, text)
  if newtext != text:
    notes.append("replace underscores with spaces in [[Category:%s_...]]" % langname)
    text = newtext

  newtext = re.sub(r"\[\[Category:%s:([^|\[\]{}]*)\|([^|\[\]{}]*)\]\]" % re.escape(lang), r"{{%s|%s|\1|sort=\2}}" % (topicstemp, lang), text)
  if newtext != text:
    notes.append("templatize topical categories with sort key for lang=%s using {{%s}}" % (lang, topicstemp))
    text = newtext
  newtext = re.sub(r"\[\[Category:%s:([^|\[\]{}]*)\]\]" % re.escape(lang), r"{{%s|%s|\1}}" % (topicstemp, lang), text)
  if newtext != text:
    notes.append("templatize topical categories for lang=%s using {{%s}}" % (lang, topicstemp))
    text = newtext
  newtext = re.sub(r"\{\{(?:c|C|top|topic|topics|catlangcode)\|%s\|(.*?)\}\}" % re.escape(lang), r"{{%s|%s|\1}}" % (topicstemp, lang), text)
  if newtext != text:
    notes.append("standardize templatized topical categories for lang=%s using {{%s}}" % (lang, topicstemp))
    text = newtext
  while True:
    newtext = re.sub(r"\{\{%s\|%s\|([^=\[\]{}]*)\}\}\n\{\{C\|%s\|([^=\[\]{}]*)\}\}" % (re.escape(topicstemp), re.escape(lang), re.escape(lang)),
        r"{{%s|%s|\1|\2}}" % (topicstemp, lang), text)
    if newtext != text:
      notes.append("combine templatized topical categories for lang=%s using {{%s}}" % (lang, topicstemp))
      text = newtext
    else:
      break

  newtext = re.sub(r"\[\[Category:%s ([^|\[\]{}]*)\|([^|\[\]{}]*)\]\]" % re.escape(langname), r"{{cln|%s|\1|sort=\2}}" % lang, text)
  if newtext != text:
    notes.append("templatize langname categories with sort key for lang=%s using {{cln}}" % lang)
    text = newtext
  newtext = re.sub(r"\[\[Category:%s ([^|\[\]{}]*)\]\]" % re.escape(langname), r"{{cln|%s|\1}}" % lang, text)
  if newtext != text:
    notes.append("templatize langname categories for lang=%s using {{cln}}" % lang)
    text = newtext
  newtext = re.sub(r"\{\{catlangname\|%s\|(.*?)\}\}" % re.escape(lang), r"{{cln|%s|\1}}" % lang, text)
  if newtext != text:
    notes.append("standardize templatized langname categories for lang=%s using {{cln}}" % lang)
    text = newtext
  while True:
    newtext = re.sub(r"\{\{cln\|%s\|([^=\[\]{}]*)\}\}\n\{\{cln\|%s\|([^=\[\]{}]*)\}\}" % (re.escape(lang), re.escape(lang)), r"{{cln|%s|\1|\2}}" % lang, text)
    if newtext != text:
      notes.append("combine templatized langname categories for lang=%s using {{cln}}" % lang)
      text = newtext
    else:
      break

  return text, notes

if __name__ == "__main__":
  parser = blib.create_argparser(u"Templatize categories", include_pagefile=True, include_stdin=True)
  parser.add_argument("--langcode", help="Code of language to templatize", required=True)
  parser.add_argument("--langname", help="Name of language to templatize", required=True)
  parser.add_argument("--topics-template", help="Name of topics template to use", default="C")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  def do_process_text_on_page(index, pagetitle, text):
    return process_text_on_page(index, pagetitle, text, args.langcode, args.langname, args.topics_template)
  blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page, default_cats=[args.langname + " lemmas"], edit=True, stdin=True)
