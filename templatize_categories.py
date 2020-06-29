#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

import uklib

def process_page(page, index, lang, langname):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  text = unicode(page.text)
  newtext = re.sub(r"\[\[Category:%s:([^|\[\]{}]*)\|([^|\[\]{}]*)\]\]" % lang, r"{{topics|%s|\1|sort=\2}}" % lang, text)
  if newtext != text:
    notes.append("templatize topical categories with sort key for lang=%s using {{topics}}" % lang)
    text = newtext
  newtext = re.sub(r"\[\[Category:%s:([^|\[\]{}]*)\]\]" % lang, r"{{topics|%s|\1}}" % lang, text)
  if newtext != text:
    notes.append("templatize topical categories for lang=%s using {{topics}}" % lang)
    text = newtext
  newtext = re.sub(r"\{\{(?:C|c|top|topic|catlangcode)\|%s\|(.*?)\}\}" % lang, r"{{topics|%s|\1}}" % lang, text)
  if newtext != text:
    notes.append("standardize templatized topical categories for lang=%s using {{topics}}" % lang)
    text = newtext
  while True:
    newtext = re.sub(r"\{\{topics\|%s\|([^=\[\]{}]*)\}\}\n\{\{topics\|%s\|([^=\[\]{}]*)\}\}" % (lang, lang), r"{{topics|%s|\1|\2}}" % lang, text)
    if newtext != text:
      notes.append("combine templatized topical categories for lang=%s using {{topics}}" % lang)
      text = newtext
    else:
      break

  newtext = re.sub(r"\[\[Category:%s ([^|\[\]{}]*)\|([^|\[\]{}]*)\]\]" % langname, r"{{cln|%s|\1|sort=\2}}" % lang, text)
  if newtext != text:
    notes.append("templatize langname categories with sort key for lang=%s using {{cln}}" % lang)
    text = newtext
  newtext = re.sub(r"\[\[Category:%s ([^|\[\]{}]*)\]\]" % langname, r"{{cln|%s|\1}}" % lang, text)
  if newtext != text:
    notes.append("templatize langname categories for lang=%s using {{cln}}" % lang)
    text = newtext
  newtext = re.sub(r"\{\{catlangname\|%s\|(.*?)\}\}" % lang, r"{{cln|%s|\1}}" % lang, text)
  if newtext != text:
    notes.append("standardize templatized langname categories for lang=%s using {{cln}}" % lang)
    text = newtext
  while True:
    newtext = re.sub(r"\{\{cln\|%s\|([^=\[\]{}]*)\}\}\n\{\{cln\|%s\|([^=\[\]{}]*)\}\}" % (lang, lang), r"{{cln|%s|\1|\2}}" % lang, text)
    if newtext != text:
      notes.append("combine templatized langname categories for lang=%s using {{cln}}" % lang)
      text = newtext
    else:
      break

  return text, notes

parser = blib.create_argparser(u"Templatize categories", include_pagefile=True)
parser.add_argument("--lang", help="Code of language to templatize", required=True)
parser.add_argument("--langname", help="Name of language to templatize", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def do_process_page(page, index, parsed):
  return process_page(page, index, args.lang, args.langname)
blib.do_pagefile_cats_refs(args, start, end, do_process_page, default_cats=[args.langname + " lemmas"], edit=True)
