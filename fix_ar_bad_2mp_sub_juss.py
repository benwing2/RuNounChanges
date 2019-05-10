#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

recognized_tag_sets = [
  "2|m|p|non-past|actv|subj",
  "2|m|p|non-past|actv|jussive",
  "2|m|p|non-past|pasv|subj",
  "2|m|p|non-past|pasv|jussive",
  "2|m|p|actv|impr",
]

split_recognized_tag_sets = [
  tag_set.split("|") for tag_set in recognized_tag_sets
]

def fix_new_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Fixing new page")

  origtext = unicode(page.text)
  text = origtext
  newtext = re.sub("^\{\{also\|.*?\}\}\n", "", text)
  if text != newtext:
    notes.append("remove no-longer-relevant {{also}} hatnote")
    text = newtext

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    if tn == "ar-verb-form":
      form = getparam(t, "1")
      assert form.endswith(u"و")
      form = form + u"ا"
      t.add("1", form)
      notes.append("add missing final waw to form in {{ar-verb-form}}")
    newt = unicode(t)
    if origt != newt:
      pagemsg("Replaced %s with %s" % (origt, newt))

  text = unicode(parsed)

  if text != origtext:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (origtext, text))
    assert notes
    comment = "; ".join(blib.group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)


def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  if not pagetitle.endswith(u"و"):
    pagemsg("Page title doesn't end with waw, skipping")
    return
  if not page.exists():
    pagemsg("WARNING: Page doesn't exist, skipping")
    return

  text = unicode(page.text)
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in xrange(2, len(sections), 2):
    if sections[j-1] != "==Arabic==\n":
      pagemsg("WARNING: Non-Arabic text found, skipping")
      return

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "also":
      continue
    if tn == "ar-verb-form":
      form = getparam(t, "1")
      if not form.endswith(u"و"):
        pagemsg("WARNING: ar-verb-form form doesn't end with waw, skipping: %s" % unicode(t))
        return
      continue
    if tn != "inflection of":
      pagemsg("WARNING: Unrecognized template on page, skipping: %s" % unicode(t))
      return
    if getparam(t, "lang"):
      lang = getparam(t, "lang")
      first_tag_param = 3
    else:
      lang = getparam(t, "1")
      first_tag_param = 4
    tags = []
    for param in t.params:
      pn = pname(param)
      pv = unicode(param.value).strip()
      if re.search("^[0-9]+$", pn) and int(pn) >= first_tag_param:
        tags.append(pv)
    if tags not in split_recognized_tag_sets:
      pagemsg("WARNING: Unrecognized {{inflection of}} tag set, skipping: %s" % unicode(t))

  new_pagetitle = pagetitle + u"ا"
  new_page = pywikibot.Page(site, new_pagetitle)
  if new_page.exists():
    pagemsg("WARNING: New page %s already exists, can't rename" % new_pagetitle)
    return
  comment = "Rename misspelled 2nd masc pl subj/juss non-lemma form"
  pagemsg("Moving to %s (comment=%s)" % (new_pagetitle, comment))
  if save:
    try:
      page.move(new_pagetitle, reason=comment, movetalk=True, noredirect=True)
    except pywikibot.PageRelatedError as error:
      pagemsg("Error moving to %s: %s" % (new_pagetitle, error))
      return

  fix_new_page(index, pywikibot.Page(site, new_pagetitle), save, verbose)


parser = blib.create_argparser(u"Fix misspelling in Arabic 2nd masc pl non-past subj/juss forms")
parser.add_argument('--pagefile', help="File containing pages to search.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
for index, page in blib.iter_items(lines, start, end):
  process_page(index, pywikibot.Page(site, page), args.save, args.verbose)
