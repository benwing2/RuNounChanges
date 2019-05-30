#!/usr/bin/env python
# -*- coding: utf-8 -*-

from blib import getparam, rmparam, msg, errmsg, errandmsg, site
import pywikibot, re, sys, codecs, argparse
import unicodedata

parser = argparse.ArgumentParser(description="Push changes made to find_regex.py output files.")
parser.add_argument('--direcfile', help="File containing directives.")
parser.add_argument('--origfile', help="File containing unchanged directives.")
parser.add_argument('--save', help="Save pages.", action="store_true")
parser.add_argument('--verbose', help="Output pages changed.", action="store_true")
parser.add_argument('--comment', help="Comment to use.", required="true")
args = parser.parse_args()

nextpage = 0
def save_page(pagename, contents, origcontents, save, verbose):
  global nextpage
  if contents == origcontents:
    msg("Skipping contents for %s because no change" % pagename)
    return
  if verbose:
    msg("For [[%s]]:" % pagename)
    msg("------- begin text --------")
    msg(contents.rstrip('\n'))
    msg("------- end text --------")
  comment = args.comment.decode('utf-8')
  nextpage += 1
  page = pywikibot.Page(site, pagename)
  if page.exists() and origcontents is not None:
    curtext = unicodedata.normalize('NFC', page.text.rstrip('\n'))
    supposed_curtext = unicodedata.normalize('NFC', origcontents.rstrip('\n'))
    if curtext != supposed_curtext:
      errandmsg("Page %s %s: WARNING: Text has changed from supposed original text, not saving" % (nextpage, pagename))
      return
  if save:
    msg("Page %s %s: Saving with comment = %s" % (nextpage, pagename, comment))
    page.text = contents
    page.save(comment=comment)
  else:
    msg("Page %s %s: Would save with comment = %s" % (nextpage, pagename, comment))

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

origpages = {}

if args.origfile:
  origlines = codecs.open(args.origfile, "r", "utf-8")
  for pagename, text in yield_text(origlines, args.verbose):
    origpages[pagename] = text

lines = codecs.open(args.direcfile, "r", "utf-8")

for pagename, text in yield_text(lines, args.verbose):
  save_page(pagename, text, origpages.get(pagename, None), args.save, args.verbose)
