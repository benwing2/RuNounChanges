#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, site

blib.getData()

# List of punctuation or spacing characters that are found inside of words.
# Used to exclude characters from the regex above.
wordPunc = u"-־׳״'.·*’་•:"
notWordPunc = "([^" + wordPunc + "]+)"

punc_chars = "".join("\\" + unichr(i) for i in range(sys.maxunicode)
    if unicodedata.category(unichr(i)).startswith('P'))

spacingPunctuation = "[" + punc_chars + r"\s]+"

# Return true if the given head is multiword according to the algorithm used
# in full_headword().
def head_is_multiword(head):
  for m in re.finditer(spacingPunctuation, head):
    possibleWordBreak = m.group(0)
    if re.search(notWordPunc, possibleWordBreak):
      return True

  return False

# Add links to a multiword head.
def add_multiword_links(head):
  def workaround_to_exclude_chars(m):
    return re.sub(notWordPunc, r"]]\1[[", m.group(0))

  head = "[[" + re.sub(spacingPunctuation, workaround_to_exclude_chars, head) + "]]"

  # Remove any empty links, which could have been created above
  # at the beginning or end of the string.
  head = re.sub(r"\[\[\]\]", "", head)
  return head

def template_changelog_name(t):
  tn = tname(t)
  def getp(param):
    return getparam(t, param)
  if tn == "head":
    return "head|%s|%s" % (getp("1"), getp("2"))
  elif any(tn.startswith(langcode + "-") for langcode in langcodes):
    return tn
  else:
    return "%s|%s" % (tn, getp("1"))


templates_messaged_about = set()

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    origt = str(t)
    params_to_check = None
    if tn in [
        "head",
        "de-adv",
        "cs-adj", "cs-adv", "cs-noun", "cs-proper noun", "cs-verb",
        "nl-adj", "nl-adv", "nl-noun", "nl-proper noun", "nl-noun-adj", "nl-noun-dim", "nl-past-ptc", "nl-verb",
        "eo-adv", "eo-card", "eo-con", "eo-det", "eo-head", "eo-interj", "eo-proper noun", "eo-part", "eo-part-form", "eo-prep",
        "hu-adj", "hu-adv", "hu-noun", "hu-pron", "hu-verb",
        "id-adj", "id-adv", "id-proper noun", "id-noun", "id-verb",
        "is-adj", "is-adv", "is-proper noun", "is-noun", "is-verb", "is-verb-preterite", "is-verb-ri", "is-verb-strong", "is-verb-weak",
    ]:
      params_to_check = ["head"]
    elif any(tn == langcode + "-phrase" for langcode in langcodes):
      params_to_check = ["1", "head"]
    elif tn in ["de-noun", "de-proper noun", "de-adj"]:
      # These templates have their own multiword link adding algorithm that conflicts with the default one
      pass
    elif tn not in templates_messaged_about and any(tn.startswith("%s-" % langcode) for langcode in langcodes):
      pagemsg("WARNING: Saw lang-specific template {{%s}}" % tn)
      templates_messaged_about.add(tn)
    if params_to_check:
      default_head = pagetitle
      if head_is_multiword(default_head):
        default_head = add_multiword_links(default_head)
      for param in params_to_check:
        if getp(param) == default_head:
          changelog_name = template_changelog_name(t)
          pagemsg("Removing redundant %s=%s in {{%s}}" % (param, default_head, changelog_name))
          rmparam(t, param)
          notes.append("remove redundant %s=%s in {{%s}}" % (param, default_head, changelog_name))
    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  text = str(parsed)
  return text, notes

parser = blib.create_argparser("Remove redundant head parameters", include_pagefile=True, include_stdin=True)
parser.add_argument("--langs", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

cats = []
langcodes = args.langs.split(",")
for langcode in langcodes:
  if langcode not in blib.languages_byCode:
    msg("WARNING: Unrecognized language code '%s'" % langcode)
  else:
    cats.append("%s terms with redundant head parameter" % blib.languages_byCode[langcode]["canonicalName"])

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_cats=cats, edit=True, stdin=True)
