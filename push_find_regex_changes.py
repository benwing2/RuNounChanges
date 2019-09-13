#!/usr/bin/env python
# -*- coding: utf-8 -*-

import blib
from blib import getparam, rmparam, msg, errmsg, errandmsg, site

import pywikibot, re, sys, codecs, argparse
import unicodedata

def process_page(index, page, contents, origcontents, verbose, lang_only):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  if contents == origcontents:
    pagemsg("Skipping contents for %s because no change" % pagetitle)
    return None, None
  if verbose:
    pagemsg("For [[%s]]:" % pagename)
    pagemsg("------- begin text --------")
    msg(contents.rstrip('\n'))
    msg("------- end text --------")
  comment = args.comment.decode('utf-8')
  if page.exists() and origcontents is not None:
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
        errandpagemsg("WARNING: Text has changed from supposed original text, not saving")
        return None, None
      sections[sec_to_search] = contents.rstrip('\n') + curnewlines
      contents = "".join(sections)
    else:
      curtext = unicodedata.normalize('NFC', page.text.rstrip('\n'))
      supposed_curtext = unicodedata.normalize('NFC', origcontents.rstrip('\n'))
      if curtext != supposed_curtext:
        errandpagemsg("WARNING: Text has changed from supposed original text, not saving")
        return None, None
  return contents, comment

def yield_text(lines, verbose):
  in_multiline = False
  while True:
    try:
      line = next(lines)
    except StopIteration:
      break
    if in_multiline and re.search("^-+ end text -+$", line):
      in_multiline = False
      yield pagename, "".join(templines)
    elif in_multiline:
      if line.rstrip('\n').endswith(':'):
        if verbose:
          errmsg("WARNING: Possible missing ----- end text -----: %s" % line.rstrip('\n'))
      templines.append(line)
    else:
      line = line.rstrip('\n')
      if line.endswith(':'):
        pagename = "Template:%s" % line[:-1]
        in_multiline = True
        templines = []
      else:
        m = re.search("^Page [0-9]+ (.*): -+ begin text -+$", line)
        if m:
          pagename = m.group(1)
          in_multiline = True
          templines = []
        elif verbose:
          msg("Skipping: %s" % line)

if __name__ == "__main__":
  parser = blib.create_argparser("Push changes made to find_regex.py output files")
  parser.add_argument('--direcfile', help="File containing directives.")
  parser.add_argument('--origfile', help="File containing unchanged directives.")
  parser.add_argument('--comment', help="Comment to use.", required="true")
  parser.add_argument('--lang-only', help="Change applies only to the specified language section.")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  origpages = {}

  if args.origfile:
    origlines = codecs.open(args.origfile, "r", "utf-8")
    for pagename, text in yield_text(origlines, args.verbose):
      origpages[pagename] = text

  lines = codecs.open(args.direcfile, "r", "utf-8")

  pagename_and_text = yield_text(lines, args.verbose)
  for index, (pagename, text) in blib.iter_items(pagename_and_text, start, end,
      get_name=lambda x:x[0]):
    def do_process_page(page, index, parsed):
      return process_page(index, page, text, origpages.get(pagename, None),
          args.verbose, args.lang_only)
    blib.do_edit(pywikibot.Page(site, pagename), index, do_process_page,
        save=args.save, verbose=args.verbose, diff=args.diff)
