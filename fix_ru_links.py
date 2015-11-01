#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam

import rulib as ru

site = pywikibot.Site()

def msg(text):
  print text.encode("utf-8")

def errmsg(text):
  print >>sys.stderr, text.encode("utf-8")

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def sub_two_part_link(m):
    page, accented = m.groups()
    page = re.sub("#Russian$", "", page)
    if ru.remove_links(accented) == page:
      return "{{l|ru|%s}}" % accented
    else:
      pagemsg("WARNING: Russian page %s doesn't match accented %s" % (page, accented))
      return "{{l|ru|%s|%s}}" % (page, accented)

  if not page.exists():
    pagemsg("WARNING: Page doesn't exist")
    return

  text = unicode(page.text)

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)
  newtext = text
  for j in xrange(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections")
        return
      foundrussian = True

      subsections = re.split("(^==.*==\n)", sections[j], 0, re.M)
      for k in xrange(2, len(subsections), 2):
        m = re.search("^===*([^=]*)=*==\n$", subsections[k-1])
        subsectitle = m.group(1)
        if subsectitle in ["Etymology", "Pronunciation"]:
          continue
        # Split templates, then rejoin text involving templates that don't
        # have newlines in them
        split_templates = re.split(r"(\{\{(?:[^{}]|\{\{[^{}]*\}\})*\}\})", subsections[k], 0, re.S)
        # Add an extra newline to first item so we can consistently check
        # below for lines beginning with *, rather than * directly after
        # a template; will remove the newline later
        split_text = ["\n" + split_templates[0]]
        for l in xrange(1, len(split_templates), 2):
          if "\n" in split_templates[l]:
            split_text.append(split_templates[l])
            split_text.append(split_templates[l+1])
          else:
            split_text[-1] += split_templates[l] + split_templates[l+1]

        # Split on newlines and look for lines beginning with *. Then
        # split on templates and look for links without Latin in them.
        for kk in xrange(0, len(split_text), 2):
          lines = re.split(r"(\n)", split_text[kk])
          for l in xrange(1, len(lines), 2):
            line = lines[l]
            if "{" in line or "}" in line:
              pagemsg("WARNING: Stray brace in line %s: Skipping page" % line)
              return
            if line.startswith("*"):
              split_line = re.split(r"(\{\{(?:[^{}]|\{\{[^{}]*\}\})*\}\})", line, 0, re.S)
              for ll in xrange(0, len(split_line), 2):
                subline = re.sub(r"\[\[([^A-Za-z\[\]|]*)\]\]", r"{{l|ru|\1}}", split_line[ll])
                subline = re.sub(r"\[\[([^A-Za-z\[\]|]*)\|([^A-Za-z\[\]|]*)\]\]", sub_two_part_link, subline)
                subline = re.sub(r"\[\[([^A-Za-z\[\]|]*)#Russian\|([^A-Za-z\[\]|]*)\]\]", sub_two_part_link, subline)
                if subline != split_line[ll]:
                  pagemsg("Replacing %s with %s in %s section" % (split_line[ll], subline, subsectitle))
                  split_line[ll] = subline
                  lines[l] = "".join(split_line)
                  split_text[kk] = "".join(lines)
                  # Strip off the newline we added at the beginning
                  subsections[k] = ("".join(split_text))[1:]
                  sections[j] = "".join(subsections)
                  newtext = "".join(sections)

  if not foundrussian:
    pagemsg("WARNING: Can't find Russian section")
    return

  if text != newtext:
    if verbose:
      pagemsg("Replacing [[%s]] with [[%s]]" % (text, newtext))

    comment = "Replace raw links with {{l|ru|...}} links"
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = argparse.ArgumentParser(description="Replace raw links with Russian-templated links")
parser.add_argument('start', help="Starting page index", nargs="?")
parser.add_argument('end', help="Ending page index", nargs="?")
parser.add_argument('--save', action="store_true", help="Save results")
parser.add_argument('--verbose', action="store_true", help="More verbose output")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for category in ["Russian lemmas", "Russian non-lemma forms"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    msg("Page %s %s: Processing" % (i, unicode(page.title())))
    process_page(i, page, args.save, args.verbose)
