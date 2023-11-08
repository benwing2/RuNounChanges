#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

topics_templates = ["topics", "topic", "top", "c", "C", "catlangcode"]
catlangname_templates = ["catlangname", "cln"]
categorize_templates = ["categorize", "cat"]

blib.getLanguageData()

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  #if ":" in pagetitle and not re.search("^(Appendix|Reconstruction|Citations):", pagetitle):
  #  return

  origtext = text
  notes = []

  sections, sections_by_lang, section_langs = blib.split_text_into_sections(text, pagemsg)

  for j, seclangname in section_langs:

    def matches(cat, cat_type):
      cat = cat.replace("_", " ")
      for fromre, from_type, tore, to_type in moves_to_do:
        if cat_type == from_type and re.search("^" + fromre + "$", cat):
          return re.sub("^" + fromre + "$", tore, cat), to_type
      return None, None

    sectext = sections[j]
    parsed = blib.parse_text(sectext)

    text_to_remove = []
    cats_to_add = []

    for t in parsed.filter_templates():
      def getp(param):
        return getparam(t, param)
      tn = tname(t)

      def process_template(temptype):
        lang = getp("1")
        numbered_params = []
        non_numbered_params = []
        did_change = False
        for param in t.params:
          pn = pname(param)
          pv = str(param.value)
          if pn == "1":
            pass # handled specially
          elif re.search("^[0-9]+$", pn):
            newv, newtype = matches(pv.strip(), temptype)
            if newv is not None:
              did_change = True
              if newtype == temptype:
                notes.append("replace %s cat '%s' with '%s' for lang=%s" % (temptype, pv, newv, lang))
                numbered_params.append(newv)
              else:
                notes.append("move %s cat '%s' to %s cat '%s' for lang=%s" % (temptype, pv, newtype, newv, lang))
                cats_to_add.append((lang, newv, newtype, getp("sort") or None))
            else:
              numbered_params.append(pv)
          else:
            non_numbered_params.append((pn, pv))
        if did_change:
          if numbered_params:
            origt = str(t)
            # Erase all params.
            del t.params[:]
            # Put back new params.
            t.add("1", lang)
            for catind, cat in enumerate(numbered_params):
              t.add(str(catind + 2), cat)
            for pn, pv in non_numbered_params:
              t.add(pn, pv, preserve_spacing=False)
            if origt != str(t):
              pagemsg("Replaced %s with %s" % (origt, str(t)))
          else:
            text_to_remove.append(str(t))

      if tn in topics_templates:
        process_template("topic")
      elif tn in catlangname_templates:
        process_template("poscat")
      elif tn in categorize_templates:
        process_template("raw")

    sectext = str(parsed)

    for m in re.finditer(r"\[\[(?:[Cc][Aa][Tt][Ee][Gg][Oo][Rr][Yy]|[Cc][Aa][Tt]):(.*?)((?:\|[^|\[\]\n]*)?)\]\]\n?", sectext):
      fullcat, sortkey = m.groups()
      fullcatspec = m.group(0)
      if sortkey:
        sortkey = sortkey[1:] # discard initial | sign; don't strip as we want to preserve space-initial sortkey
      else:
        sortkey = None
      m = re.search("^(.*?):(.*)$", fullcat)
      if m:
        langcode, cat = m.groups()
        if langcode not in blib.languages_byCode:
          pagemsg("WARNING: Unrecognized lang code %s for category '%s'" % (langcode, fullcat))
          continue
        cat = cat.strip()
        cattype = "topic"
      else:
        catwords = fullcat.strip().split(" ")
        cat = None
        cattype = None
        langcode = None
        for i in range(len(catwords) - 1, 0, -1): # always include at least one word in the language we check
          putative_lang = " ".join(catwords[:i])
          putative_cat = " ".join(catwords[i:])
          if putative_lang in blib.languages_byCanonicalName:
            langcode = blib.languages_byCanonicalName[putative_lang]["code"]
            cat = putative_cat
            cattype = "poscat"
            break
        if langcode is None:
          if seclangname not in blib.languages_byCanonicalName:
            pagemsg("WARNING: Found raw category '%s' and unrecognized language '%s' in section header %s" % (
              fullcat, seclangname, j // 2))
            continue
          else:
            langcode = blib.languages_byCanonicalName[seclangname]["code"]
            cat = fullcat.strip()
            cattype = "raw"

      newv, newtype = matches(cat, cattype)
      if newv is not None:
        text_to_remove.append(fullcatspec)
        cats_to_add.append((langcode, newv, newtype, sortkey))
        notes.append("move raw-coded %s cat '%s' to %s cat '%s' for lang=%s" % (cattype, cat, newtype, newv, langcode))

    must_continue = False
    for remove_it in text_to_remove:
      # See how many trailing newlines there are before removing the category, and make sure there are the same number
      # after removing the category.
      m = re.match(r"^(.*?)(\n*)$", sectext, re.S)
      trailing_newlines = m.group(2)
      # Try to remove a following newline as well, in case the template occurs in the middle of several lines of
      # such templates; otherwise we'll get an unwanted blank line in the middle. For raw-coded categories, we check
      # for the newline when we match the raw-coded category in finditer().
      if remove_it.startswith("{") and remove_it + "\n" in sectext:
        remove_it += "\n"
      sectext, did_replace = blib.replace_in_text(sectext, remove_it, "", pagemsg, no_found_repl_check=True)
      if not did_replace:
        # Something went wrong removing category; skip section
        must_continue = True
        break
      m = re.match(r"^(.*?)(\n*)$", sectext, re.S)
      stripped_sectext = m.group(1)
      sectext = stripped_sectext + trailing_newlines
      pagemsg("Removed %s" % remove_it.replace("\n", r"\n"))
    if must_continue:
      continue

    # (Try to) add new categories to existing category templates.
    def add_cats_to_existing_templates():
      nonlocal sectext
      parsed = blib.parse_text(sectext)
      for t in parsed.filter_templates():
        def getp(param):
          return getparam(t, param)
        tn = tname(t)

        def process_template(temptype):
          lang = getp("1")
          sortkey = getp("sort") or None
          nonlocal cats_to_add
          filtered_cats_to_add = []
          did_change = False
          cats_to_append = []
          for catlang, cat, cattype, catsortkey in cats_to_add:
            if cattype == temptype and catlang == lang and catsortkey == sortkey:
              cats_to_append.append(cat)
            else:
              filtered_cats_to_add.append((catlang, cat, cattype, catsortkey))
          if cats_to_append:
            numbered_params = []
            non_numbered_params = []
            cats_seen = set()
            did_change = False
            for param in t.params:
              pn = pname(param)
              pv = str(param.value)
              if pn == "1":
                pass # handled specially
              elif re.search("^[0-9]+$", pn):
                cats_seen.add(pv.strip())
                numbered_params.append(pv)
              else:
                non_numbered_params.append((pn, pv))
            for cat in cats_to_append:
              if cat not in cats_seen:
                numbered_params.append(cat)
                did_change = True
            if did_change:
              origt = str(t)
              # Erase all params.
              del t.params[:]
              # Put back new params.
              t.add("1", lang)
              for catind, cat in enumerate(numbered_params):
                t.add(str(catind + 2), cat)
              for pn, pv in non_numbered_params:
                t.add(pn, pv, preserve_spacing=False)
              if origt != str(t):
                pagemsg("Replaced %s with %s" % (origt, str(t)))
          cats_to_add = filtered_cats_to_add

        if tn in topics_templates:
          process_template("topic")
        elif tn in catlangname_templates:
          process_template("poscat")
        elif tn in categorize_templates:
          process_template("raw")

      sectext = str(parsed)

    # Try to add new categories to existing category templates once at first, before generating new ones.
    add_cats_to_existing_templates()

    # Add any remaining categories as new ones.
    while cats_to_add:
      catlang, cat, cattype, catsortkey = cats_to_add[0]
      empty_cat_temp = "{{%s|%s%s}}" % ("C" if cattype == "topic" else "cln" if cattype == "poscat" else "cat",
                                        catlang, "|sort=" + catsortkey if catsortkey is not None else "")
      secbody, sectail = blib.split_trailing_categories(sectext, "")
      if sectail.strip(): # categories at end, no blank line between sectext and categories
        text_to_add = empty_cat_temp
      else: # blank line between sectext and categories
        text_to_add = "\n" + empty_cat_temp
      m = re.match(r"^(.*?)(\n*)$", sectext, re.S)
      stripped_sectext, trailing_newlines = m.groups()
      sectext = stripped_sectext + "\n" + text_to_add + trailing_newlines
      add_cats_to_existing_templates()

    sections[j] = sectext

  text = "".join(sections) 
  text = re.sub(r"\n\n+", "\n\n", text)
  if text != origtext and not notes:
    notes.append("condense 3+ newlines")

  def group_notes_across_lang(notes):
    if isinstance(notes, str):
      return [notes]
    notes_langs = {}
    uniq_notes = []
    # Preserve ordering of notes but combine duplicate notes with previous notes,
    # maintaining a count.
    for note in notes:
      m = re.search("^(.*) for lang=(.*?)$", note)
      if m:
        common_note, lang = m.groups()
        if common_note in notes_langs:
          notes_langs[common_note].append(lang)
        else:
          notes_langs[common_note] = [lang]
          uniq_notes.append((common_note, True))
      else:
        uniq_notes.append((note, False))
    def fmt_note(note, has_lang):
      if has_lang:
        langs = notes_langs[note]
        return "%s for lang=%s" % (note, ",".join(langs))
      else:
        return note
    notes = [fmt_note(note, has_lang) for note, has_lang in uniq_notes]
    return notes

  return text, group_notes_across_lang(notes)

parser = blib.create_argparser("Move categories based on a regex", include_pagefile=True, include_stdin=True)
parser.add_argument("--from", help="Old name of template; can be specified multiple times",
    metavar="FROM", dest="from_", action="append", required=True)
parser.add_argument("--to", help="New name of template; can be specified multiple times",
    action="append", required=True)
parser.add_argument("--from-type", help="Old type of template; can be specified multiple times",
    action="append", required=True, choices=["topic", "poscat", "raw"])
parser.add_argument("--to-type", help="New type of template; can be specified multiple times",
    action="append", required=True, choices=["topic", "poscat", "raw"])
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

num_moves = len(args.from_)
if num_moves != len(args.to):
  raise ValueError("Saw %s 'from' spec(s) '%s' but %s 'to' spec(s) '%s'; both must agree in number" % (
      (len(args.from_), ",".join(args.from_), len(args.to), ",".join(args.to))))
if num_moves != len(args.from_type):
  raise ValueError("Saw %s 'from' spec(s) '%s' but %s 'from' type(s) '%s'; both must agree in number" % (
      (len(args.from_), ",".join(args.from_), len(args.from_type), ",".join(args.from_type))))
if num_moves != len(args.to_type):
  raise ValueError("Saw %s 'from' spec(s) '%s' but %s 'to' type(s) '%s'; both must agree in number" % (
      (len(args.from_), ",".join(args.from_), len(args.to_type), ",".join(args.to_type))))
moves_to_do = list(zip(args.from_, args.from_type, args.to, args.to_type))

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
