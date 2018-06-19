#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

borrowed_langs = {}

blib.getData()

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  pagetext = unicode(page.text)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  # Split into (sub)sections
  splitsections = re.split("(^===*[^=\n]+=*==\n)", pagetext, 0, re.M)
  # Extract off pagehead and recombine section headers with following text
  pagehead = splitsections[0]
  sections = []
  for i in xrange(1, len(splitsections)):
    if (i % 2) == 1:
      sections.append("")
    sections[-1] += splitsections[i]

  def replace_with_cog(m):
    punct, cognate_with, cog, langname, tempname, langcode, vbar = m.groups()
    origtext = "".join(m.groups())
    if langname.startswith("{{etyl"):
      m = re.search(r"^\{\{etyl\|(.*?)\|-\}\}$", langname)
      if not m:
        pagemsg("WARNING: Something wrong, can't match template call %s" % langname)
        return origtext
      if m.group(1) != langcode:
        pagemsg("WARNING: Mismatched language codes, saw %s vs. %s in %s {{m|%s|...}}"
          % (m.group(1), langcode, langname, langcode))
        return origtext
      newtext = "%s%s%s{{cog|%s|" % (punct, cognate_with, cog, langcode)
      pagemsg("Replacing <%s> with <%s>" % (origtext, newtext))
      return newtext
    if langcode not in blib.languages_byCode:
      pagemsg("WARNING: Saw unrecognized lang code %s (lang name=%s)" % (
        langcode, langname))
      return "".join(m.groups())
    else:
      expected_langname = blib.languages_byCode[langcode]["canonicalName"]
      if expected_langname != langname:
        pagemsg("WARNING: For lang code %s, saw lang name <%s> when expected <%s>"
          % (langcode, langname, expected_langname))
        return origtext
      else:
        newtext = "%s%s%s{{cog|%s|" % (punct, cognate_with, cog, langcode)
        pagemsg("Replacing <%s> with <%s>" % (origtext, newtext))
        return newtext

  # Go through each section in turn, looking for Etymology sections
  for i in xrange(len(sections)):
    if re.match("^===*Etymology( [0-9]+)?=*==", sections[i]):
      text = sections[i]
      while True:
        new_text = re.sub(r"(^|[;:,.] +|\()((?:[Cc]ognate +(?:with +|of +|to +)|[Cc]ognates +include +|[Cc]ompare +(?:with +|to +)?)(?:the +)?)((?:\{\{cog\|[A-Za-z0-9.-]+\|(?:[^{}]|\{\{[^{}]*?\}\})*\}\},? *(?:(?:and|or) +)?)*)([A-Z][A-Za-z]+(?: [A-Za-z]+)*?|\{\{etyl\|[A-Za-z0-9.-]+\|-\}\})( +\{\{(?:[ml]|term)\|)([A-Za-z0-9.-]+)(\|)",
          replace_with_cog, text, 0, re.M)
        if new_text == text:
          break
        sections[i] = new_text
        text = new_text

  new_pagetext = pagehead + "".join(sections)
  if new_pagetext != pagetext:
    comment = "Use {{cog}} for cognates in place of LANG {{m|CODE|...}} or {{etyl|CODE|-}} {{m|CODE|...}}"
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (pagetext, new_pagetext))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser("Use {{cog}} for cognates in place of LANG {{m|CODE|...}} or {{etyl|CODE|-}} {{m|CODE|...}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for refs in ["Template:m"]:
  msg("Processing references to %s" % refs)
  for i, page in blib.references(refs, start, end):
    process_page(i, page, args.save, args.verbose)
