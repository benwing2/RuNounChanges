#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import blib
from blib import getparam, rmparam, msg, errmsg, errandmsg, site

import pywikibot, re, sys, codecs, argparse
import unicodedata

def process_page(index, page, contents, prev_comment, origcontents, verbose, arg_comment,
    lang_only, allow_page_creation):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  if contents == origcontents:
    pagemsg("Skipping contents because no change")
    return
  if verbose:
    pagemsg("For [[%s]]:" % pagetitle)
    pagemsg("------- begin text --------")
    # Strip final newline because msg() adds one.
    contents_minus_newline = contents
    if contents_minus_newline.endswith("\n"):
      contents_minus_newline = contents_minus_newline[-1]
    msg(contents_minus_newline)
    msg("------- end text --------")
  page_exists = page.exists() and origcontents is not None
  if not page_exists:
    if lang_only or not allow_page_creation:
      errandpagemsg("WARNING: Trying to create page when --lang-only or not --allow-page-creation")
      return
  else:
    if lang_only:
      foundlang = False
      sec_to_search = 0
      sections = re.split("(^==[^=]*==\n)", page.text, 0, re.M)

      for j in range(2, len(sections), 2):
        if sections[j-1] == "==%s==\n" % lang_only:
          if foundlang:
            errandpagemsg("WARNING: Found multiple %s sections, skipping page" % lang_only)
            return
          foundlang = True
          sec_to_search = j
      if not sec_to_search:
        errandpagemsg("WARNING: Couldn't find %s section, skipping page" % lang_only)
        return
      curtext = unicodedata.normalize("NFC", sections[sec_to_search])
      # If we're editing the last language of the page, there won't be a newline in the page text but there's always
      # one in the find_regex content, so we have to add one to make the comparisons work. It won't matter if we add
      # an extra newline at the end of the page because it will be stripped by MediaWiki.
      if not curtext.endswith("\n"):
        curtext += "\n"
      supposed_curtext = unicodedata.normalize("NFC", origcontents)
      if curtext != supposed_curtext:
        if curtext == contents:
          pagemsg("Section has already been changed to new text, not saving")
        else:
          errandpagemsg("WARNING: Text has changed from supposed original text, not saving")
        return
      sections[sec_to_search] = contents
      contents = "".join(sections)
    else:
      curtext = unicodedata.normalize("NFC", page.text)
      # MediaWiki strips newlines from the end of the page so we need to do the same for comparison.
      supposed_curtext = unicodedata.normalize("NFC", origcontents.rstrip("\n"))
      if curtext != supposed_curtext:
        if curtext == contents.rstrip("\n"):
          pagemsg("Page has already been changed to new text, not saving")
        else:
          errandpagemsg("WARNING: Text has changed from supposed original text, not saving")
        return
  if not prev_comment and not arg_comment:
    errandpagemsg("WARNING: Trying to save page and neither previous comment not --comment available")
    return
  if not prev_comment:
    comment = arg_comment
  elif not arg_comment:
    comment = prev_comment
  else:
    comment = "%s; %s" % (prev_comment, arg_comment)
  return contents.rstrip("\n"), comment

if __name__ == "__main__":
  parser = blib.create_argparser("Push changes made to find_regex.py output files",
    include_pagefile=True)
  parser.add_argument("--direcfile", help="File containing directives.")
  parser.add_argument("--origfile", help="File containing unchanged directives.")
  parser.add_argument("--comment", help="Comment to use (in addition to any existing comment).")
  parser.add_argument("--lang-only", help="Change applies only to the specified language section.")
  parser.add_argument("--allow-page-creation", help="Allow page creation.", action="store_true")
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

    def do_process_page(page, index, parsed):
      pagetitle = str(page.title())
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
      return process_page(index, page, newtext, comment, origcontents,
        args.verbose, args.comment, args.lang_only, args.allow_page_creation)
    blib.do_pagefile_cats_refs(args, start, end, do_process_page, edit=True)

  else:
    index_pagetitle_text_comment = blib.yield_text_from_find_regex(lines, args.verbose)
    for _, (index, pagetitle, newtext, comment) in blib.iter_items(index_pagetitle_text_comment, start, end,
        get_name=lambda x:x[1], get_index=lambda x:x[0]):
      origcontents = origpages.get(pagetitle, None)
      if origcontents == newtext:
        msg("Page %s %s: Skipping contents because no change" % (index, pagetitle))
      else:
        def do_process_page(page, index, parsed):
          return process_page(index, page, newtext, comment, origcontents,
              args.verbose, args.comment, args.lang_only, args.allow_page_creation)
        blib.do_edit(pywikibot.Page(site, pagetitle), index, do_process_page,
            save=args.save, verbose=args.verbose, diff=args.diff)
