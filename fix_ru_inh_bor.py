#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam

site = pywikibot.Site()

def msg(text):
  print text.encode("utf-8")

def errmsg(text):
  print >>sys.stderr, text.encode("utf-8")

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def do_inh(m, langcode, has_prefix_text=False):
    if has_prefix_text:
      prefix_text, text = m.groups()
    else:
      prefix_text = ""
      text = m.group(1)
    parsed = blib.parse_text(text)
    for t in parsed.filter_templates():
      targs = ""
      if unicode(t.name) == "m" and getparam(t, "1") == langcode:
        targs = re.sub(r"^\{\{\s*m\s*\|\s*%s\s*" % langcode, "", unicode(t))
      if unicode(t.name) == "term" and getparam(t, "lang") == langcode:
        rmparam(t, "lang")
        targs = re.sub(r"^\{\{\s*term\s*", "", unicode(t))
      if targs:
        if targs.startswith("{{"):
          pagemsg("WARNING: Something went wrong in substitution with %s: %s" % (
              targs, text))
          return m.group(0)
        new_text = prefix_text + "{{inh|ru|%s%s" % (langcode, targs)
        pagemsg("Replacing <%s> with <%s>" % (m.group(0), new_text))
        return new_text
    pagemsg("WARNING: Something went wrong, can't find {{m|...}} or {{term|...}}: %s" % (
      text))
    return m.group(0)

  text = unicode(page.text)
  orig_text = text
  text = re.sub(r"^((?:[^{}\n]*[Ff]rom )?)(\{\{etyl\|orv\|ru\}\} \{\{(?:term|m)[^{}\n]*\}\})",
      lambda x:do_inh(x, "orv", has_prefix_text=True), text, 0, re.M)
  text = re.sub(r"^((?:[^{}\n]*[Ff]rom )?)(\{\{etyl\|sla-pro\|ru\}\} \{\{(?:term|m)[^{}]*\}\})",
      lambda x:do_inh(x, "sla-pro", has_prefix_text=True), text, 0, re.M)
  text = re.sub(r"^((?:[^{}\n]*[Ff]rom )?\{\{inh\|ru\|orv\|[^{}\n]*}\}, from )(\{\{etyl\|sla-pro\|ru\}\} \{\{(?:term|m)[^{}]*\}\})",
      lambda x:do_inh(x, "sla-pro", has_prefix_text=True), text, 0, re.M)

  if text != orig_text:
    comment = "Use {{inh}} in Russian for terms inherited from orv and sla-pro"
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)
  else:
    pagemsg("Skipping")

parser = argparse.ArgumentParser(description="Use {{inh}} and {{bor}} where possible in Russian")
parser.add_argument('start', help="Starting page index", nargs="?")
parser.add_argument('end', help="Ending page index", nargs="?")
parser.add_argument('--save', action="store_true", help="Save results")
parser.add_argument('--verbose', action="store_true", help="More verbose output")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for cat in ["Russian terms derived from Old East Slavic", "Russian terms derived from Proto-Slavic"]:
  msg("Processing category %s" % cat)
  for i, page in blib.cat_articles(cat, start, end):
    msg("Page %s %s: Processing" % (i, unicode(page.title())))
    process_page(i, page, args.save, args.verbose)
