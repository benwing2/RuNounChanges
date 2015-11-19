#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix ru-noun headers to be ru-noun+ and ru-proper noun to ru-proper noun+
# for multiword nouns by looking up the individual declensions of the words.

# Example page:
# 
# ==Russian==
# 
# ===Pronunciation===
# * {{ru-IPA|са́харная ва́та}}
# 
# ===Noun===
# {{ru-noun|[[сахарный|са́харная]] [[вата|ва́та]]|f-in}}
# 
# # [[cotton candy]], [[candy floss]], [[fairy floss]]
# 
# ====Declension====
# {{ru-decl-noun-see|сахарный|вата}}
# 
# [[Category:ru:Foods]]

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam

import rulib as ru

site = pywikibot.Site()

def msg(text):
  print text.encode("utf-8")

def errmsg(text):
  print >>sys.stderr, text.encode("utf-8")

def arg1_is_stress(arg1):
  if not arg1:
    return False
  for arg in re.split(",", arg1):
    if not (re.search("^[a-f]'?'?$", arg) or re.search(r"^[1-6]\*?$", arg)):
      return False
  return True

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  origtext = page.text
  parsed = blib.parse_text(origtext)

  # Find the declension arguments for PAGENAME. Return value is a tuple of
  # three items: a list of (NAME, VALUE) tuples for the arguments,
  # the value of n= (if given), and the value of a= (if given).
  def find_decl_args(pagename):
    declpage = pywikibot.Page(site, page)

    if not declpage.exists():
      pagemsg("WARNING: Page doesn't exist, can't locate decl for %s" % pagename)
      return None
    parsed = blib.parse_text(declpage.text)
    decl_template = None
    for t in parsed.filter_templates():
      if unicode(t.name) in ["ru-noun-table", "ru-decl-adj"]:
        if decl_template:
          pagemsg("WARNING: Multiple decl templates during decl lookup for %s" % pagename)
          return None
        decl_template = t

    if not decl_template:
      pagemsg("WARNING: No decl template during decl lookup for %s" % pagename)
      return None

    if unicode(decl_template.name) == "ru-decl-adj":
      adjhead = getparam(decl_template, "1")
      if re.search(ur"\bь\b", getparam(decl_template, "2")):
        return [("1", adjhead), ("2", u"+ь")], None, None
      else:
        return [("1", adjhead), ("2", "+")], None, None

    # ru-noun-table
    assert unicode(decl_template.name) == "ru-noun-table"
    ...


  headword_template = None
  see_template = None
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == "ru-decl-noun-see":
      if see_template:
        pagemsg("WARNING: Multiple ru-decl-noun-see templates, skipping")
        return
      see_template = t
    if tname in ["ru-noun+", "ru-proper noun+"]:
      pagemsg("Found %s, skipping" % tname)
      return
    if tname in ["ru-noun", "ru-proper noun"]:
      if headword_template:
        pagemsg("WARNING: Multiple ru-noun or ru-proper noun templates, skipping")
        return
      headword_template = t

  if not see_template:
    pagemsg("No ru-decl-noun-see templates, skipping")
    return
  if not headword_template:
    pagemsg("WARNING: Can't find headword template, skipping")
    return

  inflected_words = set(ru.remove_links(x.value) for x in see_template.params)
  headword = getparam(headword_template, "1")
  headwords = re.findall(r"\[\[(.*?)\]\]|[^ ]+", headword)
  pagemsg("Found headwords: %s" % " @@ ".join(headwords))

  # {{ru-noun|[[сахарный|са́харная]] [[вата|ва́та]]|f-in}}

  ...

  new_text = unicode(parsed)

  if new_text != origtext:
    comment = "Replace ru-(proper )noun with ru-(proper )noun+ with appropriate declension"
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = argparse.ArgumentParser(description="Convert ru-noun to ru-noun+, ru-proper noun to ru-proper noun+ for multiword nouns")
parser.add_argument('start', help="Starting page index", nargs="?")
parser.add_argument('end', help="Ending page index", nargs="?")
parser.add_argument('--save', action="store_true", help="Save results")
parser.add_argument('--verbose', action="store_true", help="More verbose output")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for pos in ["nouns", "proper nouns"]:
  refpage = "Template:tracking/ru-headword/space-in-headword/%s" % pos
  msg("PROCESSING REFERENCES TO: %s" % refpage)
  for i, page in blib.references(refpage, start, end):
    msg("Page %s %s: Processing" % (i, unicode(page.title())))
    process_page(i, page, args.save, args.verbose)
