#!/usr/bin/env python
# -*- coding: utf-8 -*-

from blib import getparam, rmparam, msg, errmsg, site
import pywikibot, re, sys, codecs, argparse

parser = argparse.ArgumentParser(description="Push changes made to find_regex.py output files.")
parser.add_argument('--direcfile', help="File containing directives.")
parser.add_argument('--save', help="Save pages.", action="store_true")
parser.add_argument('--comment', help="Comment to use.", required="true")
args = parser.parse_args()

lines = codecs.open(args.direcfile, "r", "utf-8")
in_multiline = False

nextpage = 0
def save_page(pagename, contents, save):
  global nextpage
  msg("For [[%s]]:" % pagename)
  msg("------- begin text --------")
  msg(contents.rstrip('\n'))
  msg("------- end text --------")
  comment = args.comment
  nextpage += 1
  if save:
    page = pywikibot.Page(site, pagename)
    msg("Page %s %s: Saving with comment = %s" % (nextpage, pagename, comment))
    page.text = contents
    page.save(comment=comment)
  else:
    msg("Page %s %s: Would save with comment = %s" % (nextpage, pagename, comment))

while True:
  try:
    line = next(lines)
  except StopIteration:
    break
  if in_multiline and re.search("^-+ end text -+$", line):
    in_multiline = False
    save_page(pagename, "".join(templines), args.save)
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
      else:
        msg("Skipping: %s" % line)
