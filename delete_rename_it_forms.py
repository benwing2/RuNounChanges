#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, json, unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site

output_pages_to_delete = []

def remove_anagram_from_page(index, page, pagetitle_to_remove):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  if not blib.safe_page_exists(page, errandpagemsg):
    pagemsg("WARNING: Trying to remove anagram '%s' but page itself doesn't exist" % pagetitle_to_remove)
    return

  notes = []

  text = blib.safe_page_text(page, errandpagemsg)
  if not text:
    return

  retval = blib.find_modifiable_lang_section(text, "Italian", pagemsg, force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
  for k in xrange(2, len(subsections), 2):
    if "===Anagrams===" in subsections[k - 1]:
      parsed = blib.parse_text(subsections[k])
      for t in parsed.filter_templates():
        tn = tname(t)
        def getp(param):
          return getparam(t, param)
        if tn == "anagrams":
          if getp("1") != "it":
            pagemsg("WARNING: Wrong language in {{anagrams}}: %s" % unicode(t))
            return
          anagrams = blib.fetch_param_chain(t, "2")
          anagrams = [x for x in anagrams if x != pagetitle_to_remove]
          if anagrams:
            blib.set_param_chain(t, anagrams, "2")
            notes.append("remove anagram '%s', page deleted or renamed%s" % (pagetitle_to_remove, annotation))
            subsections[k] = unicode(parsed)
          else:
            subsections[k - 1] = ""
            subsections[k] = ""
            notes.append("remove Anagrams section; only had '%s', which has been deleted or renamed%s"
                % (pagetitle_to_remove, annotation))

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)

  return text, notes

def process_page_for_anagrams(index, page, modify_this_page):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  text = blib.safe_page_text(page, errandpagemsg)
  if not text:
    return

  retval = blib.find_modifiable_lang_section(text, "Italian", pagemsg, force_final_nls=True)
  if retval is None:
    return

  sections, j, secbody, sectail, has_non_lang = retval

  anagrams = []

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
  for k in xrange(2, len(subsections), 2):
    if "===Anagrams===" in subsections[k - 1]:
      parsed = blib.parse_text(subsections[k])
      for t in parsed.filter_templates():
        tn = tname(t)
        def getp(param):
          return getparam(t, param)
        if tn == "anagrams":
          if getp("1") != "it":
            pagemsg("WARNING: Wrong language in {{anagrams}}: %s" % unicode(t))
            return
          for anagram in blib.fetch_param_chain(t, "2"):
            if anagram not in anagrams:
              anagrams.append(anagram)
        elif tn == "l":
          if getp("1") != "it":
            pagemsg("WARNING: Wrong language in {{l}}: %s" % unicode(t))
            return
          anagram = getp("2")
          if anagram not in anagrams:
            anagrams.append(anagram)
      if modify_this_page:
        subsections[k - 1] = ""
        subsections[k] = ""
        notes.append("remove Anagrams section prior to renaming page%s" % annotation)
  secbody = "".join(subsections)

  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)

  for anagram in anagrams:
    def do_process_page(page, index, parsed):
      return remove_anagram_from_page(index, page, pagetitle)
    blib.do_edit(pywikibot.Page(site, anagram), index, do_process_page,
      save=args.save, verbose=args.verbose, diff=args.diff)

  return text, notes

def process_page_for_deletion(index, page):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  if not blib.safe_page_exists(page, errandpagemsg):
    pagemsg("Skipping because page doesn't exist")
    return

  notes = []

  text = blib.safe_page_text(page, errandpagemsg)
  if not text:
    return

  retval = blib.find_modifiable_lang_section(text, "Italian", pagemsg)
  if retval is None:
    return

  sections, j, secbody, sectail, has_non_lang = retval
  if not has_non_lang:
    # Can delete the whole page, but check for non-blank section 0
    cleaned_sec0 = re.sub("^\{\{also\|.*?\}\}\n", "", sections[0])
    if cleaned_sec0.strip():
      pagemsg("WARNING: Whole page deletable except that there's text above all sections: <%s>" % cleaned_sec0.strip())
      return
    pagemsg("Page should be deleted")
    output_pages_to_delete.append(pagetitle)
    return

  del sections[j]
  del sections[j-1]
  notes.append("remove Italian section for bad (nonexistent or misspelled) form%s" % annotation)
  if j > len(sections):
    # We deleted the last section, remove the separator at the end of the
    # previous section.
    sections[-1] = re.sub(r"\n+--+\n*\Z", "", sections[-1])
  text = "".join(sections)

  return text, notes


parser = blib.create_argparser("Delete/rename Italian forms, fixing up anagrams")
parser.add_argument("--direcfile", help="File listing forms to delete/rename.", required=True)
parser.add_argument("--comment", help="Optional additional comment to use.")
parser.add_argument("--output-pages-to-delete", help="Output file containing forms to delete.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)
annotation = " (%s)" % args.comment if args.comment else ""

input_pages_to_delete = []
output_pages_to_delete = []
pages_to_rename = []

# Separate pages to delete and rename. Do pages to delete first so we can run this in sysop mode
# (python login.py --sysop), and it will first delete the necessary pages, then ask for the non-sysop password and
# rename the remaining pages.
for index, line in blib.iter_items_from_file(args.direcfile, start, end):
  m = re.search("^(.*) -> (.*)$", line)
  if m:
    frompagetitle, topagetitle = m.groups()
    pages_to_rename.append((index, frompagetitle, topagetitle))
  else:
    m = re.search("^(.*): delete$", line)
    if m:
      badpagetitle = m.group(1)
      input_pages_to_delete.append((index, badpagetitle))
    else:
      errandmsg("Line %s: Unrecognized line: %s" % (index, line))

for index, badpagetitle in input_pages_to_delete:
  badpage = pywikibot.Page(site, badpagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, badpagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, badagetitle, txt))
  if not blib.safe_page_exists(badpage, errandpagemsg):
    pagemsg("Skipping because page doesn't exist")
    continue
  process_page_for_anagrams(index, badpage, modify_this_page=False)
  def do_process_page(page, index, parsed):
    return process_page_for_deletion(index, page)
  blib.do_edit(badpage, index, do_process_page, save=args.save, verbose=args.verbose, diff=args.diff)
  #this_comment = 'delete bad Italian non-lemma form'
  #if args.save:
  #  existing_text = blib.safe_page_text(badpage, errandpagemsg, bad_value_ret=None)
  #  if existing_text is not None:
  #    badpage.delete('%s (content was "%s")' % (this_comment, existing_text))
  #    errandpagemsg("Deleted (comment=%s)" % this_comment)
  #else:
  #  pagemsg("Would delete (comment=%s)" % this_comment)

for index, frompagetitle, topagetitle in pages_to_rename:
  frompage = pywikibot.Page(site, frompagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, frompagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, frompagetitle, txt))
  if not blib.safe_page_exists(frompage, errandpagemsg):
    pagemsg("Skipping because page doesn't exist")
    continue
  def do_process_page(page, index, parsed):
    return process_page_for_anagrams(index, page, modify_this_page=True)
  blib.do_edit(frompage, index, do_process_page,
    save=args.save, verbose=args.verbose, diff=args.diff)
  topage = pywikibot.Page(site, topagetitle)
  if blib.safe_page_exists(topage, errandpagemsg):
    errandpagemsg("Destination page %s already exists, not moving" %
      topagetitle)
    continue
  this_comment = 'rename bad Italian non-lemma form'
  if args.save:
    try:
      frompage.move(topagetitle, reason=this_comment, movetalk=True, noredirect=True)
      errandpagemsg("Renamed to %s" % topagetitle)
    except pywikibot.PageRelatedError as error:
      errandpagemsg("Error moving to %s: %s" % (topagetitle, error))
  else:
    pagemsg("Would rename to %s (comment=%s)" % (topagetitle, this_comment))

msg("The following pages need to be deleted:")
for page in output_pages_to_delete:
  msg(page)
if args.output_pages_to_delete:
  with codecs.open(args.output_pages_to_delete, "w", "utf-8") as fp:
    for page in output_pages_to_delete:
      print >> fp, page
