#!/usr/bin/env python
# -*- coding: utf-8 -*-

import blib
from blib import getparam, rmparam, msg, errmsg, errandmsg, site

import pywikibot, re, sys, codecs, argparse
import unicodedata

def process_page(index, page, contents, origcontents, verbose, comment,
    lang_only, allow_page_creation):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  if contents == origcontents:
    pagemsg("Skipping contents for %s because no change" % pagetitle)
    return None, None
  if verbose:
    pagemsg("For [[%s]]:" % pagetitle)
    pagemsg("------- begin text --------")
    msg(contents.rstrip('\n'))
    msg("------- end text --------")
  page_exists = page.exists() and origcontents is not None
  if not page_exists:
    if lang_only or not allow_page_creation:
      errandpagemsg("WARNING: Trying to create page when --lang-only or not --allow-page-creation")
      return None, None
  else:
    if lang_only:
      foundlang = False
      sec_to_search = 0
      sections = re.split("(^==[^=]*==\n)", page.text, 0, re.M)

      for j in xrange(2, len(sections), 2):
        if sections[j-1] == "==%s==\n" % lang_only:
          if foundlang:
            errandpagemsg("WARNING: Found multiple %s sections, skipping page" % lang_only)
            return None, None
          foundlang = True
          sec_to_search = j
      if not sec_to_search:
        errandpagemsg("WARNING: Couldn't find %s section, skipping page" % lang_only)
        return None, None
      m = re.match(r"\A(.*?)(\n*)\Z", sections[sec_to_search], re.S)
      curtext, curnewlines = m.groups()
      curtext = unicodedata.normalize('NFC', curtext)
      supposed_curtext = unicodedata.normalize('NFC', origcontents.rstrip('\n'))
      if curtext != supposed_curtext:
        if curtext == contents.rstrip('\n'):
          pagemsg("Section has already been changed to new text, not saving")
        else:
          errandpagemsg("WARNING: Text has changed from supposed original text, not saving")
        return None, None
      sections[sec_to_search] = contents.rstrip('\n') + curnewlines
      contents = "".join(sections)
    else:
      curtext = unicodedata.normalize('NFC', page.text.rstrip('\n'))
      supposed_curtext = unicodedata.normalize('NFC', origcontents.rstrip('\n'))
      if curtext != supposed_curtext:
        if curtext == contents.rstrip('\n'):
          pagemsg("Page has already been changed to new text, not saving")
        else:
          errandpagemsg("WARNING: Text has changed from supposed original text, not saving")
        return None, None
  return contents, comment

if __name__ == "__main__":
  parser = blib.create_argparser("Push changes made to find_regex.py output files",
    include_pagefile=True)
  parser.add_argument('--direcfile', help="File containing directives.")
  parser.add_argument('--origfile', help="File containing unchanged directives.")
  parser.add_argument('--comment', help="Comment to use.", required="true")
  parser.add_argument('--lang-only', help="Change applies only to the specified language section.")
  parser.add_argument('--allow-page-creation', help="Allow page creation.", action="store_true")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  origpages = {}

  if args.origfile:
    origlines = codecs.open(args.origfile.decode("utf-8"), "r", "utf-8")
    for index, pagetitle, text in blib.yield_text_from_find_regex(origlines, args.verbose):
      origpages[pagetitle] = text

  if blib.args_has_non_default_pages(args):
    newpages = {}
    lines = codecs.open(args.direcfile.decode("utf-8"), "r", "utf-8")
    for index, pagetitle, text in blib.yield_text_from_find_regex(lines, args.verbose):
      newpages[pagetitle] = text

    def do_process_page(page, index, parsed):
      pagetitle = unicode(page.title())
      def pagemsg(txt):
        msg("Page %s %s: %s" % (index, pagetitle, txt))
      origcontents = origpages.get(pagetitle, None)
      newtext = newpages.get(pagetitle, None)
      if not newtext:
        pagemsg("Skipping because not found in among new page contents")
        return
      if origcontents == newtext:
        pagemsg("Page %s %s: Skipping contents for %s because no change" % pagetitle)
        return
      return process_page(index, page, newtext, origcontents,
        args.verbose, args.comment.decode("utf-8"), args.lang_only and args.lang_only.decode("utf-8"),
        args.allow_page_creation)
    blib.do_pagefile_cats_refs(args, start, end, do_process_page, edit=True)

  else:
    lines = codecs.open(args.direcfile.decode("utf-8"), "r", "utf-8")

    index_pagetitle_and_text = blib.yield_text_from_find_regex(lines, args.verbose)
    for _, (index, pagetitle, newtext) in blib.iter_items(index_pagetitle_and_text, start, end,
        get_name=lambda x:x[1], get_index=lambda x:x[0]):
      origcontents = origpages.get(pagetitle, None)
      if origcontents == newtext:
        msg("Page %s %s: Skipping contents for %s because no change" % (index, pagetitle, pagetitle))
      else:
        def do_process_page(page, index, parsed):
          return process_page(index, page, newtext, origcontents,
              args.verbose, args.comment.decode("utf-8"), args.lang_only and args.lang_only.decode("utf-8"),
              args.allow_page_creation)
        blib.do_edit(pywikibot.Page(site, pagetitle), index, do_process_page,
            save=args.save, verbose=args.verbose, diff=args.diff)
