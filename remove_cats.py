#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

blib.getLanguageData()

topics_templates = ["topics", "topic", "top", "c", "C", "catlangcode"]
catlangname_templates = ["catlangname", "cln"]
categorize_templates = ["categorize", "cat"]
no_lang_templates = {
  "zh-cat": "zh",
}

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  #if ":" in pagetitle and not re.search("^(Appendix|Reconstruction|Citations):", pagetitle):
  #  return

  origtext = text
  notes = []
  removed_cats = []

  def should_remove_cat(cat):
    return re.match(args.regex + "$", cat.replace("_", " "))

  parsed = blib.parse_text(text)

  text_to_remove = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in topics_templates or tn in catlangname_templates or tn in categorize_templates or tn in no_lang_templates:
      if tn in no_lang_templates:
        first_cat_param = 1
        has_lang_param = False
        lang = no_lang_templates[tn]
      else:
        first_cat_param = 2
        has_lang_param = True
        lang = getparam(t, "1").strip()
      cats = []
      for paramno in range(first_cat_param, 30):
        cat = getparam(t, str(paramno)).strip()
        if cat:
          cats.append(cat)
      filtered_cats = []
      for cat in cats:
        if tn in topics_templates or tn in no_lang_templates:
          full_cat = "%s:%s" % (lang, cat)
        elif tn in categorize_templates:
          full_cat = cat
        else:
          if lang not in blib.languages_byCode:
            pagemsg("WARNING: Saw unrecognized language code '%s'" % lang)
            return
          else:
            full_cat = "%s %s" % (blib.languages_byCode[lang]["canonicalName"], cat)
        if should_remove_cat(full_cat):
          if full_cat not in removed_cats:
            removed_cats.append(full_cat)
        else:
          filtered_cats.append(cat)
      if cats == filtered_cats:
        continue
      non_numbered_params = []
      for param in t.params:
        pname = str(param.name).strip()
        pval = str(param.value).strip()
        showkey = param.showkey
        if not re.search("^[0-9]+$", pname):
          non_numbered_params.append((pname, pval, showkey))
      if filtered_cats:
        origt = str(t)
        # Erase all params.
        del t.params[:]
        # Put back new params.
        if has_lang_param:
          t.add("1", lang)
        for catind, cat in enumerate(filtered_cats):
          t.add(str(catind + first_cat_param), cat)
        for pname, pval, showkey in non_numbered_params:
          t.add(pname, pval, showkey=showkey, preserve_spacing=False)
        if origt != str(t):
          pagemsg("Replaced %s with %s" % (origt, str(t)))
      else:
        text_to_remove.append(str(t))

  text = str(parsed)

  for m in re.finditer(r"\[\[(?:[Cc][Aa][Tt][Ee][Gg][Oo][Rr][Yy]|[Cc][Aa][Tt]):(.*?)\]\]\n?", text):
    cat = m.group(1)
    cat = re.sub(r"\|.*", "", cat)
    if should_remove_cat(cat):
      text_to_remove.append(m.group(0))
      if m.group(1) not in removed_cats:
        removed_cats.append(m.group(1))

  for remove_it in text_to_remove:
    text, did_replace = blib.replace_in_text(text, remove_it, "", pagemsg, no_found_repl_check=True)
    if not did_replace:
      return
    pagemsg("Removed %s" % remove_it.replace("\n", r"\n"))

  text = re.sub(r"\n\n+", "\n\n", text)
  if removed_cats:
    notes.append("remove categories: %s%s" % (",".join(removed_cats), " (%s)" % args.comment if args.comment else ""))
  if text != origtext and not notes:
    notes.append("condense 3+ newlines")
  return text, notes

parser = blib.create_argparser("Remove categories based on a regex", include_pagefile=True, include_stdin=True)
parser.add_argument("--regex", required=True, help="Regex matching full category name to remove.")
parser.add_argument("--comment", help="Comment fragment to add to comments indicating what is removed.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
