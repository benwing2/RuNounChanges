#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

borrowed_langs = {}

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  # re.sub() substitution function for replacing {{etyl|*|ru}} {{m|*|FOO}}
  # with either {{inh|ru|*|FOO}} or {{bor|ru|*|FOO}}, depending on the
  # language.
  def do_inh_bor(m, do_bor=False):
    prefix_text, text, langcode = m.groups()
    if do_bor:
      prefix_text = re.sub("^[Ff]rom +", "", prefix_text)
      prefix_text = re.sub(r"\. +From ", ". ", prefix_text)
      if langcode in ["orv", "sla-pro", "ine-bsl-pro", "ine-pro"]:
        pagemsg("Not creating {{bor}} for inherited language %s: %s" % (
          langcode, text))
        return m.group(0)
      borrowed_langs[langcode] = borrowed_langs.get(langcode, 0) + 1
    parsed = blib.parse_text(text)
    for t in parsed.filter_templates():
      targs = ""
      if str(t.name) in ["m", "l"] and getparam(t, "1") == langcode:
        targs = re.sub(r"^\{\{\s*[ml]\s*\|\s*%s\s*" % langcode, "", str(t))
      elif str(t.name) == "term" and getparam(t, "lang") == langcode:
        rmparam(t, "lang")
        targs = re.sub(r"^\{\{\s*term\s*", "", str(t))
      if targs:
        if targs.startswith("{{"):
          pagemsg("WARNING: Something went wrong in substitution with %s: %s" % (
              targs, text))
          return m.group(0)
        if do_bor:
          new_text = prefix_text + "{{bor|ru|%s%s" % (langcode, targs)
        else:
          new_text = prefix_text + "{{inh|ru|%s%s" % (langcode, targs)
        pagemsg("Replacing <%s> with <%s>" % (m.group(0), new_text))
        return new_text
    pagemsg("WARNING: Something went wrong, can't find {{m|...}} or {{l|...}} or {{term|...}}, or wrong langcode: %s" % (
      text))
    return m.group(0)

  # re.sub() substitution function for replacing {{etyl|*|ru}} [[FOO]]
  # with {{bor|ru|*|FOO}}.
  def do_bor_raw(m):
    langcode, term = m.groups()
    if langcode in ["orv", "sla-pro", "ine-bsl-pro", "ine-pro"]:
      pagemsg("Not creating {{bor}} for inherited language %s: %s" % (
        langcode, m.group(0)))
      return m.group(0)
    borrowed_langs[langcode] = borrowed_langs.get(langcode, 0) + 1
    return "{{bor|ru|%s|%s}}" % (langcode, term)

  text = str(page.text)
  orig_text = text

  # Do inherited cases. We look for a line beginning with either nothing or
  # some non-template text ending in [Ff]rom, followed by an inheritance chain
  # of zero or more {{inh|ru|*|...}} templates followed by ",? from ",
  # followed by {{etyl|*|ru}} {{m...}} or {{etyl|*|ru}} {{term...}}, where
  # in all cases * must be one of the languages in the inheritance chain
  # (orv, sla-pro, ine-bsl-pro or ine-pro) and the language inside of
  # {{m|...}} or {{term|...}} must match the * in the previous {{etyl}}
  # template. Repeat until no more substitutions, to handle chains of
  # inheritance.
  while True:
    new_text = re.sub(r"^((?:[^{}\n]*[Ff]rom +)?(?:\{\{inh\|ru\|(?:orv|sla-pro|ine-bsl-pro|ine-pro)(?:\|[^{}\n]*)}\},? +from +)*)(\{\{ety[lm]\|(orv|sla-pro|ine-bsl-pro|ine-pro)\|ru\}\} +\{\{(?:term|m)[^{}\n]*\}\})",
      do_inh_bor, text, 0, re.M)
    if new_text == text:
      break
    text = new_text

  found_borrowing = False

  # Do borrowings. We look for a line beginning with either [Ff]rom or nothing,
  # or beginning with a sentence followed by ". From ", followed by
  # {{etyl|*|ru}} {{m...}} or {{etyl|*|ru}} {{term...}}, where
  # * must not be one of the inheritance-chain languages (orv, sla-pro,
  # ine-bsl-pro or ine-pro) and the language inside of {{m|...} or
  # {{term|...}} must match the * in the previous {{etyl}} template.
  # There should only be one such substitution.
  new_text = re.sub(r"^([^{}\[\]\n]+\. +From +|[Ff]rom +| *)(\{\{ety[lm]\|([^|{}\n]*)\|ru\}\} +\{\{(?:term|m|l)[^{}\n]*\}\})",
    lambda m:do_inh_bor(m, do_bor=True), text, 0, re.M)
  if new_text != text:
    found_borrowing = True
  text = new_text

  new_text = re.sub(r"^(?:[Ff]rom +)?\{\{ety[lm]\|([^|{}\n]*)\|ru\}\} +\[\[(.*?)\]\]",
    do_bor_raw, text, 0, re.M)
  if new_text != text:
    found_borrowing = True
  text = new_text

  if not found_borrowing:
    for m in re.finditer(r"\{\{bor(rowing)?\|[^{}]*\}\}", text):
      parsed = blib.parse_text(m.group(0))
      for t in parsed.filter_templates():
        if str(t.name) in ["bor", "borrowing"] and (
            getparam(t, "lang") == "ru" or
            not getparam(t, "lang") and getparam(t, "1") == "ru"):
          found_borrowing = True
          pagemsg("Already contains borrowing: %s" % m.group(0))

  if not found_borrowing:
    pagemsg("WARNING: Can't find proper borrowing template")

  return text, "Use {{inh}}/{{bor}} in Russian for terms inherited or borrowed"

parser = blib.create_argparser("Use {{inh}} and {{bor}} where possible in Russian",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian lemmas", "Russian non-lemma forms"])

msg("")
msg("Processed borrowed languages:")
for lang, count in sorted(borrowed_langs.items(), key=lambda x:-int(x[1])):
  msg("%s = %s" % (lang, count))
