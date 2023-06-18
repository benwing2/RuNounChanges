#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, site, tname, pname

recognized_tag_sets = [
  "2|m|p|non-past|actv|subj",
  "2|m|p|non-past|actv|jussive",
  "2|m|p|non-past|pasv|subj",
  "2|m|p|non-past|pasv|jussive",
  "3|m|p|non-past|actv|subj",
  "3|m|p|non-past|actv|jussive",
  "3|m|p|non-past|pasv|subj",
  "3|m|p|non-past|pasv|jussive",
  "2|m|p|actv|impr",
]

split_recognized_tag_sets = [
  tag_set.split("|") for tag_set in recognized_tag_sets
]

def fix_new_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Fixing new page")

  origtext = str(page.text)
  text = origtext
  newtext = re.sub("^\{\{also\|.*?\}\}\n", "", text)
  if text != newtext:
    notes.append("remove no-longer-relevant {{also}} hatnote")
    text = newtext

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    if tn == "ar-verb-form":
      form = getparam(t, "1")
      if form.endswith("ا"):
        continue
      elif not form.endswith("و") and not form.endswith("وْ"):
        pagemsg("WARNING: Form doesn't end in waw or alif: %s" % origt)
        continue
      form = form + "ا"
      t.add("1", form)
      notes.append("add missing final alif to form in {{ar-verb-form}}")
    newt = str(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

def convert_etym_subsection_to_single_etymology_section(text):
  subsections = re.split("(^==+[^=\n]+==+\n)", text, 0, re.M)
  if subsections[0].strip():
    # There's etymology at top, make a section for it.
    subsections = ["", "====Etymology====\n"] + subsections
    # If there's an Alternative forms section below, put the Etymology
    # section below it.
    if len(subsections) >= 5 and subsections[3] == "====Alternative forms====\n":
      altforms_subsecs = subsections[3:5]
      subsections[3:5] = subsections[1:3]
      subsections[1:3] = altforms_subsecs
  # Remove one indentation level from each header.
  for j in range(1, len(subsections), 2):
    subsections[j] = subsections[j][1:-2] + "\n"
  return "".join(subsections)


def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errpagemsg(txt):
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")
  if not pagetitle.endswith("و"):
    pagemsg("Page title doesn't end with waw, skipping")
    return
  if not page.exists():
    pagemsg("WARNING: Page doesn't exist, skipping")
    return

  text = str(page.text)
  origtext = text
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  has_non_arabic = False

  arabic_j = -1
  for j in range(2, len(sections), 2):
    if sections[j-1] != "==Arabic==\n":
      has_non_arabic = True
    else:
      if arabic_j >= 0:
        pagemsg("WARNING: Found two Arabic sections, skipping")
        return
      arabic_j = j
  if arabic_j < 0:
    pagemsg("WARNING: Can't find Arabic section, skipping")
    return
  j = arabic_j

  # Extract off trailing separator
  mm = re.match(r"^(.*?\n)(\n*--+\n*)$", sections[j], re.S)
  if mm:
    # Note that this changes the number of sections, which is seemingly
    # a problem because the for-loop above calculates the end point
    # at the beginning of the loop, but is not actually a problem
    # because we always break after processing the Russian section.
    secbody, sectail = mm.group(1), mm.group(2)
  else:
    secbody = sections[j]
    sectail = ""

  # Split off categories at end
  mm = re.match(r"^(.*?\n)(\n*(\[\[Category:[^\]]+\]\]\n*)*)$",
      secbody, re.S)
  if mm:
    # See comment above.
    secbody, secbodytail = mm.group(1), mm.group(2)
    sectail = secbodytail + sectail

  def etym_section_is_movable(sectext, header):
    parsed = blib.parse_text(sectext)
    inflection_of_templates_with_unrecognized_tags = []
    saw_inflection_of_with_recognized_tag = False
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "inflection of":
        if getparam(t, "lang"):
          lang = getparam(t, "lang")
          first_tag_param = 3
        else:
          lang = getparam(t, "1")
          first_tag_param = 4
        if lang != "ar":
          pagemsg("WARNING: Non-Arabic language in Arabic {{inflection of}} in %s, skipping: %s" % (header, str(t)))
          return False
        tags = []
        for param in t.params:
          pn = pname(param)
          pv = str(param.value).strip()
          if re.search("^[0-9]+$", pn) and int(pn) >= first_tag_param:
            tags.append(pv)
        if tags not in split_recognized_tag_sets:
          inflection_of_templates_with_unrecognized_tags.append(str(t))
        else:
          saw_inflection_of_with_recognized_tag = True

    if not saw_inflection_of_with_recognized_tag:
      return False

    if inflection_of_templates_with_unrecognized_tags:
      pagemsg("WARNING: Unrecognized {{inflection of}} tag set mixed with recognized ones in %s, skipping: %s" %
        (header, " / ".join(inflection_of_templates_with_unrecognized_tags)))
      return False

    for t in parsed.filter_templates():
      tn = tname(t)
      if tn in ["also", "ar-root", "nonlemma", "ar-IPA"]:
        continue
      if tn == "ar-verb-form":
        form = getparam(t, "1")
        if not form.endswith("و") and form.endswith("وْ"):
          pagemsg("WARNING: ar-verb-form form doesn't end with waw in %s with recognized {{inflection of}} tags, skipping: %s" % (header, str(t)))
          return False
        continue
      if tn != "inflection of":
        pagemsg("WARNING: Unrecognized template in %s with recognized {{inflection of}} tags, skipping: %s" % (header, str(t)))
        return False
    return True

  has_non_movable_etym_sections = False
  movable_sections = []

  def remove_arabic_section():
    # No sections left, need to remove the whole Arabic section.
    if not has_non_arabic:
      # Can move the whole page
      notes.append("excised %s subsection%s for Arabic forms wrongly lacking final aleph, leaving nothing" %
        (len(movable_sections), "" if len(movable_sections) == 1 else "s"))
      return ""
    else:
      del sections[j]
      del sections[j-1]
      notes.append("excised %s subsection%s for Arabic forms wrongly lacking final aleph, leaving no Arabic section" %
        (len(movable_sections), "" if len(movable_sections) == 1 else "s"))
      if j > len(sections):
        # We deleted the last section, remove the separator at the end of the
        # previous section.
        sections[-1] = re.sub(r"\n+--+\n*\Z", "", sections[-1])
      return "".join(sections)

  if "==Etymology 1==" in secbody:
    movable_sections_are_etym_subsections = True
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
    k = 2
    while k < len(etym_sections):
      m = re.search("Etymology [0-9]+", etym_sections[k - 1])
      header = m.group(0)
      if etym_section_is_movable(etym_sections[k], header):
        movable_sections.append(etym_sections[k])
        del etym_sections[k]
        del etym_sections[k-1]
      else:
        has_non_movable_etym_sections = True
        k += 2
    if not movable_sections:
      pagemsg("Can't take action on page")
      return
    if len(etym_sections) > 3:
      # Two or more remaining etym sections, just renumber.
      next_etym_section = 1
      for k in range(1, len(etym_sections), 2):
        etym_sections[k] = "===Etymology %s===\n" % next_etym_section
        next_etym_section += 1
      secbody = "".join(etym_sections)
      sections[j] = secbody + sectail
      text = "".join(sections)
      notes.append("excised %s subsection%s for Arabic forms wrongly lacking final aleph" %
        (len(movable_sections), "" if len(movable_sections) == 1 else "s"))
    elif len(etym_sections) == 3:
      # Only one etym section left, convert it to a non-etym-split section
      non_etym_split_section = convert_etym_subsection_to_single_etymology_section(etym_sections[2])
      secbody = etym_sections[0] + non_etym_split_section
      sections[j] = secbody + sectail
      text = "".join(sections)
      notes.append("excised %s subsection%s for Arabic forms wrongly lacking final aleph, leaving one non-etym-split section" %
        (len(movable_sections), "" if len(movable_sections) == 1 else "s"))
    else:
      # Arabic section as a whole needs to go.
      text = remove_arabic_section()
  else:
    movable_sections_are_etym_subsections = False
    if etym_section_is_movable(secbody, "single etymology section"):
      movable_sections.append(secbody)
      # Arabic section as a whole needs to go.
      text = remove_arabic_section()
    else:
      pagemsg("Can't take action on page")
      return

  # This frequently happens as a result of our cutting and pasting
  newtext = re.sub(r"\n\n+", "\n\n", text)
  if newtext != text:
    if not notes:
      notes.append("compress sequences of 3 blank lines")
  text = newtext

  if not text:
    # We can move the whole page
    new_pagetitle = pagetitle + "ا"
    new_page = pywikibot.Page(site, new_pagetitle)
    if new_page.exists():
      pagemsg("New page %s already exists, can't rename" % new_pagetitle)
      pagemsg("Page should be deleted")
      return
    comment = "Rename misspelled 2nd/3rd masc pl subj/juss/impr non-lemma form"
    pagemsg("Moving to %s (comment=%s)" % (new_pagetitle, comment))
    errpagemsg("Moving to %s (comment=%s)" % (new_pagetitle, comment))
    if save:
      try:
        page.move(new_pagetitle, reason=comment, movetalk=True, noredirect=True)
      except pywikibot.PageRelatedError as error:
        pagemsg("Error moving to %s: %s" % (new_pagetitle, error))
        return
    blib.do_edit(pywikibot.Page(site, new_pagetitle), index, fix_new_page,
        save=args.save, verbose=args.verbose, diff=args.diff)

  else:
    return text, notes

parser = blib.create_argparser("Fix misspelling in Arabic 2nd/3rd masc pl non-past subj/juss forms",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
