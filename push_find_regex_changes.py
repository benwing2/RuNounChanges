#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import blib
from blib import getparam, rmparam, msg, errmsg, errandmsg, site

import pywikibot, re, sys, argparse
import unicodedata

# process_text_on_page() callback. `index` is the index of the page whose title is `pagetitle`. `curtext` is the
# actual current text of the page. `contents` is the desired text of the page (or of the specific language section if
# --lang-only or --subset-of-langs), and `origcontents` is the previous text of the page (or of the specific language
# section) from which `contents` was derived. We need `origcontents` so we can check to see if the page (or specific
# language section) was changed by someone else in the meantime; if so, we can't save.
def process_text_on_page(index, pagetitle, curtext, contents, prev_comment, origcontents):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  def normalize_text(text):
    if text is None:
      return text
    return blib.normalize_text_for_save(text).rstrip("\n")

  if normalize_text(contents) == normalize_text(origcontents):
    pagemsg("Skipping contents because no change")
    return
  if args.verbose:
    pagemsg("For [[%s]]:" % pagetitle)
    pagemsg("------- begin text --------")
    # Strip final newline because msg() adds one.
    contents_minus_newline = contents
    if contents_minus_newline.endswith("\n"):
      contents_minus_newline = contents_minus_newline[-1]
    msg(contents_minus_newline)
    msg("------- end text --------")
  page_exists = curtext and origcontents is not None
  if not page_exists:
    if args.lang_only or args.subset_of_langs or not args.allow_page_creation:
      errandpagemsg("WARNING: Trying to create page when --lang-only, --subset-of-langs or not --allow-page-creation")
      return
  else:
    if args.lang_only or args.subset_of_langs:
      sections, sections_by_lang, _ = blib.split_text_into_sections(curtext, pagemsg)

      def replace_lang_section(lang, newsectext, origsectext):
        newsectext = unicodedata.normalize("NFC", newsectext)
        supposed_cursectext = unicodedata.normalize("NFC", origsectext)
        if lang not in sections_by_lang:
          errandpagemsg("WARNING: Couldn't find %s section, skipping page; showing our changes:" % lang)
          blib.show_diff(supposed_cursectext, newsectext)
          return False
        langsec = sections_by_lang[lang]
        cursectext = unicodedata.normalize("NFC", sections[langsec])
        # If we're editing the last language of the page, there won't be a newline in the page text but there's always
        # one in the find_regex content, so we have to add one to make the comparisons work. It won't matter if we add
        # an extra newline at the end of the page because it will be stripped by MediaWiki.
        if not cursectext.endswith("\n"):
          cursectext += "\n"
        if cursectext != supposed_cursectext:
          if cursectext == newsectext:
            pagemsg("%s section has already been changed to new text, not saving" % lang)
          else:
            errandpagemsg("WARNING: %s text has changed from supposed original text, not saving; showing our changes:" % lang)
            blib.show_diff(supposed_cursectext, newsectext)
          return False
        sections[langsec] = newsectext
        return True

      if args.lang_only:
        changed = replace_lang_section(args.lang_only, contents, origcontents)
        if not changed:
          return
      else:
        origcontents_sections, origcontents_sections_by_lang, _ = blib.split_text_into_sections(origcontents, pagemsg)
        contents_sections, contents_sections_by_lang, _ = blib.split_text_into_sections(contents, pagemsg)
        if origcontents_sections_by_lang != contents_sections_by_lang:
          errandpagemsg("WARNING: Languages differ or have been rearranged between original and replacement text, not saving")
          return
        for lang, langsec in origcontents_sections_by_lang.items():
          lang_origcontents = origcontents_sections[langsec]
          lang_contents = contents_sections[langsec]
          if lang_origcontents == lang_contents:
            pagemsg("Skipping contents for %s because no change" % lang)
          elif not replace_lang_section(lang, lang_contents, lang_origcontents):
            return
      contents = "".join(sections)
    else:
      nfc_curtext = normalize_text(curtext)
      supposed_nfc_curtext = normalize_text(origcontents)
      contents = normalize_text(contents)
      if nfc_curtext != supposed_nfc_curtext:
        if nfc_curtext == contents:
          pagemsg("Page has already been changed to new text, not saving")
        else:
          errandpagemsg("WARNING: Text has changed from supposed original text, not saving; showing our changes:")
          blib.show_diff(supposed_nfc_curtext, contents)
        return
  if not prev_comment and not args.comment:
    errandpagemsg("WARNING: Trying to save page and neither previous comment not --comment available")
    return
  if not prev_comment:
    comment = args.comment
  elif not args.comment:
    comment = prev_comment
  else:
    comment = "%s; %s" % (prev_comment, args.comment)
  return contents.rstrip("\n"), comment

if __name__ == "__main__":
  parser = blib.create_argparser("Push changes made to find_regex.py output files",
    include_pagefile=True, include_stdin=True)
  parser.add_argument("--direcfile", help="File containing directives.")
  parser.add_argument("--origfile", help="File containing unchanged directives.")
  parser.add_argument("--comment", help="Comment to use (in addition to any existing comment).")
  parser.add_argument("--lang-only", help="Change applies only to the specified language section.")
  parser.add_argument("--subset-of-langs", action="store_true",
    help="find_regex.py output contains a subset of all languages on the page.")
  parser.add_argument("--allow-page-creation", action="store_true", help="Allow page creation.")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  origpages = {}

  if args.origfile:
    origlines = open(args.origfile, "r", encoding="utf-8")
    for index, pagetitle, text, comment in blib.yield_text_from_find_regex(origlines, args.verbose):
      origpages[pagetitle] = text

  lines = open(args.direcfile, "r", encoding="utf-8")

  if blib.args_has_non_default_pages(args):
    newpages = {}
    for index, pagetitle, text, comment in blib.yield_text_from_find_regex(lines, args.verbose):
      newpages[pagetitle] = (text, comment)

    def do_process_text_on_page(index, pagetitle, curtext):
      def pagemsg(txt):
        msg("Page %s %s: %s" % (index, pagetitle, txt))
      origcontents = origpages.get(pagetitle, None)
      newtext, comment = newpages.get(pagetitle, (None, None))
      if not newtext:
        pagemsg("Skipping because not found in among new page contents")
        return
      if origcontents == newtext:
        pagemsg("Skipping contents because no change")
        return
      return process_text_on_page(index, pagetitle, curtext, newtext, comment, origcontents)
    blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page, edit=True, stdin=True)

  else:
    index_pagetitle_text_comment = blib.yield_text_from_find_regex(lines, args.verbose)
    for _, (index, pagetitle, newtext, comment) in blib.iter_items(index_pagetitle_text_comment, start, end,
        get_name=lambda x:x[1], get_index=lambda x:x[0]):
      origcontents = origpages.get(pagetitle, None)
      if origcontents == newtext:
        msg("Page %s %s: Skipping contents because no change" % (index, pagetitle))
      else:
        def do_process_page(page, index, parsed):
          return process_text_on_page(index, str(page.title()), page.text, newtext, comment, origcontents)
        blib.do_edit(pywikibot.Page(site, pagetitle), index, do_process_page,
            save=args.save, verbose=args.verbose, diff=args.diff)
    blib.elapsed_time()
