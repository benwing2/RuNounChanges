#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Delete erroneously created forms given the declensions that led to those
# forms being created.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

suffixes = ["e", "es", "ent", "erai", "eras", "era", "erons", "erez", "eront",
    "erais", "erait", "erions", "eriez", "eraient"]
all_suffixes = ["e", "es", "ons", "ez", "ent",
    "ais", "ait", "ions", "iez", "aient",
    "erai", "eras", "era", "erons", "erez", "eront",
    "erais", "erait", "erions", "eriez", "eraient",
    "ai", "as", "a", u"âmes", u"âtes", u"èrent",
    "asse", "asses", u"ât", "assions", "assiez", "assent",
    "ant", u"é"]

def process_er_verb(index, pagetitle, save, verbose, doall):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if not pagetitle.endswith("er"):
    pagemsg("WARNING: Page %s doesn't end in -er, skipping")
    return

  stem = re.sub("er$", "", pagetitle)
  for suffix in all_suffixes if doall else suffixes:
    form = stem + suffix
    formpage = pywikibot.Page(site, form)
    if not formpage.exists():
      pagemsg("WARNING: Form page '%s' doesn't exist, skipping" % form)
    elif form == pagetitle:
      pagemsg("WARNING: Attempt to delete dictionary form, skipping")
    else:
      text = str(formpage.text)
      if "Etymology 1" in text:
        pagemsg("WARNING: Found 'Etymology 1', skipping form %s" % form)
      else:
        skip_form = False
        for m in re.finditer(r"^==([^=]*?)==$", text, re.M):
          if m.group(1) != "French":
            pagemsg("WARNING: Found entry for non-French language %s, skipping form '%s'" %
                (m.group(1), form))
            skip_form = True
        if not skip_form:
          for m in re.finditer(r"\{\{also\|.*\}\}", text, re.M):
            pagemsg("WARNING: Found %s in page '%s' to delete" % (m.group(0), form))
          comment = "Delete erroneously created form of %s" % pagetitle
          if save:
            pagemsg("Page text for form '%s' follows:\n=============================\n%s\n=============================" % (form, text))
            formpage.delete(comment)
          else:
            pagemsg("Would delete page '%s' with comment=%s" %
                (form, comment))

parser = blib.create_argparser(u"Delete erroneously created French -er verb forms")
parser.add_argument("--declfile", help="File containing verbs to delete.")
parser.add_argument("--all-suffixes", action="store_true",
    help="If specifies, do all conjugational suffixes rather than just those using the stressed or future stem.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, line in blib.iter_items_from_file(args.declfile, start, end):
  process_er_verb(i, line, args.save, args.verbose, args.all_suffixes)
