#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

auto_cat_to_manual = {
  "Cornwall, England": "Cornwall",
  "Greater Manchester, England": "Greater Manchester",
  "Merseyside, England": "Merseyside",
  "Tyne and Wear, England": "Tyne and Wear",
  "the West Midlands, England": "West Midlands",
  "West Yorkshire, England": "West Yorkshire",
  "Alabama": "Alabama, USA",
  "Alaska": "Alaska, USA",
  "Arizona": "Arizona, USA",
  "Arkansas": "Arkansas, USA",
  "California": "California, USA",
  "Colorado": "Colorado, USA",
  "Connecticut": "Connecticut, USA",
  "Delaware": "Delaware, USA",
  "Florida": "Florida, USA",
  "Georgia": "Georgia, USA",
  "Hawaii": "Hawaii, USA",
  "Idaho": "Idaho, USA",
  "Illinois": "Illinois, USA",
  "Indiana": "Indiana, USA",
  "Iowa": "Iowa, USA",
  "Kansas": "Kansas, USA",
  "Kentucky": "Kentucky, USA",
  "Louisiana": "Louisiana, USA",
  "Maine": "Maine, USA",
  "Maryland": "Maryland, USA",
  "Massachusetts": "Massachusetts, USA",
  "Michigan": "Michigan, USA",
  "Minnesota": "Minnesota, USA",
  "Mississippi": "Mississippi, USA",
  "Missouri": "Missouri, USA",
  "Montana": "Montana, USA",
  "Nebraska": "Nebraska, USA",
  "Nevada": "Nevada, USA",
  "New Hampshire": "New Hampshire, USA",
  "New Jersey": "New Jersey, USA",
  "New Mexico": "New Mexico, USA",
  "New York": "New York, USA",
  "North Carolina": "North Carolina, USA",
  "North Dakota": "North Dakota, USA",
  "Ohio": "Ohio, USA",
  "Oklahoma": "Oklahoma, USA",
  "Oregon": "Oregon, USA",
  "Pennsylvania": "Pennsylvania, USA",
  "Rhode Island": "Rhode Island, USA",
  "South Carolina": "South Carolina, USA",
  "South Dakota": "South Dakota, USA",
  "Tennessee": "Tennessee, USA",
  "Texas": "Texas, USA",
  "Utah": "Utah, USA",
  "Vermont": "Vermont, USA",
  "Virginia": "Virginia, USA",
  "Washington": "Washington, USA",
  "West Virginia": "West Virginia, USA",
  "Wisconsin": "Wisconsin, USA",
  "Wyoming": "Wyoming, USA",
}

def process_page(page, index, parsed):
  global args
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  if ":" in pagetitle and not re.search("^(Appendix|Reconstruction|Citations):", pagetitle):
    return

  text = unicode(page.text)
  origtext = text
  pagemsg("Processing")
  notes = []
  removed_cats = []

  auto_added_categories = set()

  def should_remove_cat(cat):
    if cat in auto_added_categories:
      return True
    for c in auto_added_categories:
      m = re.search("^((?:.*?:)?)(.*?) +(?:of|in) (?:the )?(.*)$", c)
      if m and cat in [
        m.group(1) + m.group(2), # remove 'en:Cities' if auto-added cat is 'en:Cities in West Yorkshire, England'
        m.group(1) + m.group(3), # remove 'en:West Yorkshire, England' if auto-added cat is 'en:Cities in West Yorkshire, England'
        m.group(1) + auto_cat_to_manual.get(m.group(3), m.group(3)) # remove 'en:West Yorkshire' if auto-added cat is 'en:Cities in West Yorkshire, England'
      ]:
        return True
    return False

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "place":
      wikicode = expand_text(unicode(t))
      if not wikicode:
        continue
      for m in re.finditer(r"\[\[(?:[Cc]ategory|CAT):(.*?)\]\]", wikicode):
        cat = m.group(1)
        cat = re.sub(r"\|.*", "", cat)
        auto_added_categories.add(cat)

  text_to_remove = []
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["topics", "topic", "top", "c", "C", "catlangcode"]:
      lang = getparam(t, "1")
      cats = []
      for paramno in range(2, 30):
        cat = getparam(t, str(paramno))
        if cat:
          cats.append(cat)
      filtered_cats = []
      for cat in cats:
        full_cat = "%s:%s" % (lang, cat)
        if should_remove_cat(full_cat):
          if full_cat not in removed_cats:
            removed_cats.append(full_cat)
        else:
          filtered_cats.append(cat)
      if cats == filtered_cats:
        continue
      non_numbered_params = []
      for param in t.params:
        pname = unicode(param.name).strip()
        pval = unicode(param.value).strip()
        showkey = param.showkey
        if not re.search("^[0-9]+$", pname):
          non_numbered_params.append((pname, pval, showkey))
      if filtered_cats:
        origt = unicode(t)
        # Erase all params.
        del t.params[:]
        # Put back new params.
        t.add("1", lang)
        for catind, cat in enumerate(filtered_cats):
          t.add(str(catind + 2), cat)
        for pname, pval, showkey in non_numbered_params:
          t.add(pname, pval, showkey=showkey, preserve_spacing=False)
        if origt != unicode(t):
          pagemsg("Replaced %s with %s" % (origt, unicode(t)))
      else:
        text_to_remove.append(unicode(t))
  text = unicode(parsed)

  for m in re.finditer(r"\[\[(?:[Cc]ategory|CAT):(.*?)\]\]\n?", text):
    cat = m.group(1)
    cat = re.sub(r"\|.*", "", cat)
    if should_remove_cat(cat):
      text_to_remove.append(m.group(0))
      if m.group(1) not in removed_cats:
        removed_cats.append(m.group(1))
    auto_added_categories.add(cat)

  for remove_it in text_to_remove:
    text, did_replace = blib.replace_in_text(text, remove_it, "", pagemsg, no_found_repl_check=True)
    if not did_replace:
      return
    pagemsg("Removed %s" % remove_it.replace("\n", r"\n"))

  text = re.sub(r"\n\n+", "\n\n", text)
  if removed_cats:
    notes.append("remove cats redundant to {{place}}: %s" % ",".join(removed_cats))
  if text != origtext and not notes:
    notes.append("condense 3+ newlines")
  return text, notes

parser = blib.create_argparser("Remove redundant manually-added categories when {{place}} also adds them",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, default_refs=["Template:place"], edit=True)
