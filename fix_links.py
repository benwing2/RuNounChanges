#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam

import rulib as ru

site = pywikibot.Site()

def hy_remove_accents(text):
  text = re.sub(u"[՞՜՛՟]", "", text)
  text = re.sub(u"և", u"ե", text)
  text = re.sub(u"<sup>յ</sup>", u"յ", text)
  text = re.sub(u"<sup>ի</sup>", u"ի", text)
  return text

def el_remove_accents(text):
  return text

def grc_remove_accents(text):
  text = re.sub(u"[ᾸᾹ]", u"Α", text)
  text = re.sub(u"[ᾰᾱ]", u"α", text)
  text = re.sub(u"[ῘῙ]", u"Ι", text)
  text = re.sub(u"[ῐῑ]", u"ι", text)
  text = re.sub(u"[ῨῩ]", u"Υ", text)
  text = re.sub(u"[ῠῡ]", u"υ", text)
  return text

return text

languages = {
    'ru':["Russian", ru.remove_accents, u"Ѐ-џҊ-ԧꚀ-ꚗ"],
    'hy':["Armenian", hy_remove_accents, u"Ա-֏ﬓ-ﬗ"],
    'el':["Greek", el_remove_accents, u"Ͱ-Ͽ"],
    'grc':["Ancient Greek", grc_remove_accents, u"ἀ-῾Ͱ-Ͽ"],
}

thislangname = None
thislangcode = None
this_remove_accents = None
this_charset = None

def msg(text):
  print text.encode("utf-8")

def errmsg(text):
  print >>sys.stderr, text.encode("utf-8")

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if not page.exists():
    pagemsg("WARNING: Page doesn't exist")
    return

  text = unicode(page.text)

  subbed_links = []

  # Split off templates or tables, in each case allowing one nested template
  template_table_split_re = r"(\{\{(?:[^{}]|\{\{[^{}]*\}\})*\}\}|\{\|(?:[^{}]|\{\{[^{}]*\}\})*\|\})"
  foundlang = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)
  newtext = text
  for j in xrange(2, len(sections), 2):
    if sections[j-1] == "==%s==\n" % thislangname:
      if foundlang:
        pagemsg("WARNING: Found multiple Russian sections")
        return
      foundlang = True

      subsections = re.split("(^==.*==\n)", sections[j], 0, re.M)
      for k in xrange(2, len(subsections), 2):
        m = re.search("^===*([^=]*)=*==\n$", subsections[k-1])
        subsectitle = m.group(1)
        if subsectitle in ["Etymology", "Pronunciation"]:
          continue

        def sub_one_part_link(m):
          subbed_links.append("[[%s]]" % m.group(1))
          template = subsectitle == "Usage notes" and "m" or "l"
          return "{{%s|%s|%s}}" % (template, thislangcode, m.group(1))

        def sub_two_part_link(m):
          subbed_links.append("[[%s|%s]]" % m.groups())
          template = subsectitle == "Usage notes" and "m" or "l"
          page, accented = m.groups()
          page = re.sub("#%s$" % thislangname, "", page)
          if this_remove_accents(accented) == page:
            return "{{%s|%s|%s}}" % (template, thislangcode, accented)
          else:
            pagemsg("WARNING: %s page %s doesn't match accented %s" % (thislangname, page, accented))
            return "{{%s|%s|%s|%s}}" % (template, thislangcode, page, accented)

        # Split templates, then rejoin text involving templates that don't
        # have newlines in them
        split_templates = re.split(template_table_split_re, subsections[k], 0, re.S)
        for l in xrange(0, len(split_templates), 2):
          if "{" in split_templates[l] or "}" in split_templates[l]:
            pagemsg("WARNING: Stray brace in split_templates[%s]: Skipping page: [[%s]]" % (l, split_templates[l].replace("\n", r"\n")))
            return
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

        #if verbose:
        #  pagemsg("Processing split_text: %s" % split_text)
        # Split on newlines and look for lines beginning with *. Then
        # split on templates and look for links without Latin in them.
        for kk in xrange(0, len(split_text), 2):
          lines = re.split(r"(\n)", split_text[kk])
          for l in xrange(0, len(lines), 2):
            line = lines[l]
            #if verbose:
            #  pagemsg("Processing line: %s" % line)
            if line.startswith("*"):
              split_line = re.split(template_table_split_re, line, 0, re.S)
              for ll in xrange(0, len(split_line), 2):
                subline = split_line[ll]
                subline = re.sub(r"\[\[([\W%s]*?)\]\]", sub_one_part_link, subline)
                subline = re.sub(r"\[\[([^A-Za-z\[\]|]*)\|([^A-Za-z\[\]|]*)\]\]", sub_two_part_link, subline)
                subline = re.sub(r"\[\[([^A-Za-z\[\]|]*)#%s\|([^A-Za-z\[\]|]*)\]\]" % thislangname, sub_two_part_link, subline)
                if subline != split_line[ll]:
                  pagemsg("Replacing %s with %s in %s section" % (split_line[ll], subline, subsectitle))
                  split_line[ll] = subline
                  lines[l] = "".join(split_line)
                  split_text[kk] = "".join(lines)
                  # Strip off the newline we added at the beginning
                  subsections[k] = "".join(split_text)
                  assert subsections[k][0] == "\n"
                  subsections[k] = subsections[k][1:]
                  sections[j] = "".join(subsections)
                  newtext = "".join(sections)

  if not foundlang:
    pagemsg("WARNING: Can't find %s section" % thislangname)
    return

  if text != newtext:
    if verbose:
      pagemsg("Replacing [[%s]] with [[%s]]" % (text, newtext))

    comment = "Replace raw links with templated links: %s" % ",".join(subbed_links)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = argparse.ArgumentParser(description="Replace raw links with templated links")
parser.add_argument('start', help="Starting page index", nargs="?")
parser.add_argument('end', help="Ending page index", nargs="?")
parser.add_argument('--save', action="store_true", help="Save results")
parser.add_argument('--verbose', action="store_true", help="More verbose output")
parser.add_argument('--lang', action="store_true", help="Language code for language to do")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

if not args.lang:
  raise ValueError("Language code must be specified")
if args.lang not in languages:
  raise ValueError("Unrecognized language code: %s" % args.lang)
thislangcode = args.lang
thislangname, this_remove_accents, this_charset = languages[thislangcode]

for category in ["%s lemmas" % thislangname, "%s non-lemma forms" % thislangname]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    msg("Page %s %s: Processing" % (i, unicode(page.title())))
    process_page(i, page, args.save, args.verbose)
