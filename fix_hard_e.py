#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose, direc):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub(".*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  notes = []
  text = unicode(page.text)
  parsed = blib.parse(page)

  def frob_gender_param(t, param):
    val = getparam(t, param)
    if val == "n":
      t.add(param, "n-in")
    elif val == "n-p":
      t.add(param, "n-in-p")

  for t in parsed.filter_templates():
    if unicode(t.name) in ["ru-noun+", "ru-noun-table"]:
      origt = unicode(t)
      for param in t.params:
        if unicode(param.name) != "1":
          pagemsg("WARNING: Found other than a single param in template, skipping: %s" % unicode(t))
          return
      FIXME
      if origt != unicode(t):
        param3 = getparam(t, "3")
        if param3 != "-":
          if fix_indeclinable:
            if param3:
              pagemsg("WARNING: Can't make indeclinable, has genitive singular given: %s" % origt)
              return
            else:
              t.add("3", "-")
              notes.append("make indeclinable")
              pagemsg("Making indeclinable: %s" % unicode(t))
          else:
            pagemsg("WARNING: Would add inanimacy to neuter, but isn't marked as indeclinable: %s" % origt)
            return
        pagemsg("Replacing %s with %s" % (origt, unicode(t)))

  new_text = unicode(parsed)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, new_text))
    if notes:
      comment = "Add inanimacy to neuters (%s)" % "; ".join(notes)
    else:
      comment = "Add inanimacy to neuters"
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Fix hard-е nouns according to directives")
parser.add_argument("--direcfile",
    help="File listing directives to apply to nouns")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if not args.direcfile:
  raise RuntimeError("--direcfile required")
for i, line in blib.iter_items(codecs.open(args.direcfile, "r", "utf-8"),
    start, end):
  line = line.strip()
  if "!!!" in line:
    page, direc = re.split("!!!", line)
  else:
    page, direc = re.split(" ", line)
    process_page(i, pywikibot.Page(site, page), args.save, args.verbose,
        direc)
