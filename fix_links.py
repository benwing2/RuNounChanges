#!/usr/bin/env python
# -*- coding: utf-8 -*-

# This program replaces raw links of the form '[[foo]]' with templated links
# of the form '{{l|ru|foo}}', and raw two-part links of the form '[[foo|bar]]'
# with templated links of the form '{{l|ru|foo|bar}}', for various specified
# languages. When converting two-part links to templated links it is smart
# enough to recognize links of the form '[[foo#Russian|bar]]'', and smart
# enough to recognize cases where 'bar' is just the accented form of 'foo'
# and hence it can be converted to a one-part templated link. Links are only
# converted if they occur on a line beginning with '*', and will be converted
# to '{{m|ru|foo}}' rather than '{{l|ru|foo}}' in certain sections (e.g.
# Usage Notes sections).
#
# The program also looks for transliteration following the raw link, e.g. in
# the form '[[фоо]] (foo)'. It uses Levenshtein distance to check whether the
# thing in parens is actually a reasonable-looking transliteration, and
# ignores it if not. If so, it is converted to a |tr=foo param, or ignored
# entirely if the language ignores manual translit.
#
# The program handles one Latin-script language (French), and in that case
# is more careful to avoid converting raw links that are probably not to
# French vocabulary words (e.g. to numbers or symbols).

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru

lbracket_sub = u"\ufff1"
rbracket_sub = u"\ufff2"

def rsub_repeatedly(fr, to, text):
  while True:
    newtext = re.sub(fr, to, text)
    if newtext == text:
      return text
    text = newtext

def hy_remove_accents(text):
  text = re.sub(u"[՞՜՛՟]", "", text)
  text = re.sub(u"և", u"ե", text)
  text = re.sub(u"<sup>յ</sup>", u"յ", text)
  text = re.sub(u"<sup>ի</sup>", u"ի", text)
  return text

def grc_remove_accents(text):
  text = re.sub(u"[ᾸᾹ]", u"Α", text)
  text = re.sub(u"[ᾰᾱ]", u"α", text)
  text = re.sub(u"[ῘῙ]", u"Ι", text)
  text = re.sub(u"[ῐῑ]", u"ι", text)
  text = re.sub(u"[ῨῩ]", u"Υ", text)
  text = re.sub(u"[ῠῡ]", u"υ", text)
  return text

def he_remove_accents(text):
  text = re.sub(u"[\u0591-\u05BD\u05BF-\u05C5\u05C7]", "", text)
  return text

def ar_remove_accents(text):
  text = re.sub(u"\u0671", u"\u0627", text)
  text = re.sub(u"[\u064B-\u0652\u0670\u0640]", "", text)
  return text

# Each element is full language name, function to remove accents to normalize
# an entry, character set range(s), and whether to ignore translit (info
# from [[Module:links]], or "latin" if the language uses the Latin script and
# hence has no translit, or "notranslit" if the language doesn't do
# auto-translit)
languages = {
    'ru':["Russian", ru.remove_accents, u"Ѐ-џҊ-ԧꚀ-ꚗ", False],
    'hy':["Armenian", hy_remove_accents, u"Ա-֏ﬓ-ﬗ", True],
    'el':["Greek", lambda x:x, u"Ͱ-Ͽ", True],
    'grc':["Ancient Greek", grc_remove_accents, u"ἀ-῾Ͱ-Ͽ", True],
    'hi':["Hindi", lambda x:x, u"\u0900-\u097F\uA8E0-\uA8FD", False],
    'ta':["Tamil", lambda x:x, u"\u0B82-\u0BFA", True],
    'te':["Telugu", lambda x:x, u"\u0C00-\u0C7F", True],
    'gu':["Gujarati", lambda x:x, u"\u0A81-\u0AF9", "notranslit"],
    'or':["Oriya", lambda x:x, u"\u0B01-\u0B77", "notranslit"],
    'pa':["Punjabi", lambda x:x, u"\u0A01-\u0A75", "notranslit"],
    'he':["Hebrew", he_remove_accents, u"\u0590-\u05FF\uFB1D-\uFB4F", "notranslit"],
    'ar':["Arabic", ar_remove_accents, u"؀-ۿݐ-ݿࢠ-ࣿﭐ-﷽ﹰ-ﻼ", False],
    'fr':["French", lambda x:x, u"\\- '’.0-9A-Za-z¡-\u036FḀ-ỿ", "latin"]
}

thislangname = None
thislangcode = None
this_remove_accents = None
this_charset = None
this_ignore_translit = False

# From wikibooks
def levenshtein(s1, s2):
    if len(s1) < len(s2):
        return levenshtein(s2, s1)

    # len(s1) >= len(s2)
    if len(s2) == 0:
        return len(s1)

    previous_row = range(len(s2) + 1)
    for i, c1 in enumerate(s1):
        current_row = [i + 1]
        for j, c2 in enumerate(s2):
            insertions = previous_row[j + 1] + 1 # j+1 instead of j since previous_row and current_row are one character longer
            deletions = current_row[j] + 1       # than s2
            substitutions = previous_row[j] + (c1 != c2)
            current_row.append(min(insertions, deletions, substitutions))
        previous_row = current_row

    return previous_row[-1]

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

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
        pagemsg("WARNING: Found multiple %s sections" % thislangname)
        return
      foundlang = True

      subsections = re.split("(^==.*==\n)", sections[j], 0, re.M)
      for k in xrange(2, len(subsections), 2):
        m = re.search("^===*([^=]*)=*==\n$", subsections[k-1])
        subsectitle = m.group(1)
        if subsectitle in ["Etymology", "Pronunciation"]:
          continue

        def sub_link(orig, text, translit, origtemplate):
          if subsectitle in ["Usage notes", "Descendants", "References"] and this_ignore_translit == "latin":
            pagemsg("Ignoring putative link in '%s', might be English or some other language: %s" % (subsectitle, orig))
            return orig
          if re.search("[\[\]]", text):
            pagemsg("WARNING: Stray brackets in link, skipping: %s" % orig)
            return orig
          if this_ignore_translit == "latin":
            if not re.search("^[#|%s]+$" % this_charset, text):
              pagemsg("WARNING: Link contains characters not in proper charset, skipping: %s" % orig)
              return orig
          else:
            if not re.search("[^ -~]", text):
              pagemsg("No non-Latin characters in link, skipping: %s" % orig)
              return orig
            if not re.search("^[ -~%s]*$" % this_charset, text):
              pagemsg("WARNING: Link contains non-Latin characters not in proper charset, skipping: %s" % orig)
              return orig
          parts = re.split(r"\|", text)
          if len(parts) > 2:
            pagemsg("WARNING: Too many parts in link, skipping: %s" % orig)
            return orig
          template = origtemplate or subsectitle == "Usage notes" and "m" or "l"
          if not origtemplate and thislangcode == "grc" and subsectitle == "Descendants":
            pagemsg("Using langcode=el instead of grc in Descendants section")
            langcode = "el"
          else:
            langcode = thislangcode
          subbed_links.append("[[%s]]" % text)
          page = None
          if len(parts) == 1:
            accented = text
          else:
            page, accented = parts
            page = re.sub("#%s$" % thislangname, "", page)
          if page:
            if this_remove_accents(accented) == page:
              page = None
            elif re.search("[#:]", page):
              pagemsg("WARNING: Found special chars # or : in left side of link, skipping: %s" % orig)
              return orig
            else:
              pagemsg("WARNING: %s page %s doesn't match accented %s, converting to two-part link" % (thislangname, page, accented))
          translit_arg = ""
          post_translit_arg = ""
          if translit and this_ignore_translit == "notranslit":
            pagemsg("WARNING: Unable to determine whether putative explicit translit %s is translit of %s" % (
              translit, accented))
            post_translit_arg = " (%s)" % translit
          elif translit:
            orig_translit = translit
            translit = re.sub(r"^\[\[(.*)\]\]$", r"\1", translit)
            translit = re.sub(r"^''(.*)''$", r"\1", translit)
            accented_translit = expand_text("{{xlit|%s|%s}}" % (langcode,
                accented))
            if accented_translit == "":
              pagemsg("WARNING: Unable to transliterate %s (putative explicit transit %s)" % (
                accented, translit))
            if not accented_translit:
              # Error occurred computing transliteration
              post_translit_arg = " (%s)" % orig_translit
            elif accented_translit == translit:
              pagemsg("No translit difference between explicit %s and auto %s (%s %s)" % (
                translit, accented_translit, thislangname, accented))
              # Translit same as explicit translit, ignore
              pass
            else:
              levdist = levenshtein(accented_translit, translit)
              tranlen = min(len(translit), len(accented_translit))
              if accented_translit[0].isupper() != translit[0].isupper():
                pagemsg("WARNING: Upper/lower mismatch between explicit %s and auto %s, not treating as translit (%s %s)" % (
                  translit, accented_translit, thislangname, accented))
                post_translit_arg = " (%s)" % orig_translit
              elif thislangcode == "grc" and (translit.endswith("ic") or translit.endswith("an")):
                pagemsg("WARNING: Explicit translit %s ends with -ic or -an, not treating as translit vs. auto-translit %s (Levenshtein distance %s, %s %s)" % (
                  translit, accented_translit, levdist, thislangname, accented))
                post_translit_arg = " (%s)" % orig_translit
              elif (levdist == 1 and tranlen >= 3 or levdist == 2 and tranlen >= 4
                  or levdist == 3 and tranlen >= 5 or levdist == 4 and tranlen >= 7
                  or levdist == 5 and tranlen >= 9):
                pagemsg("Levenshtein distance %s and length %s, accept translit difference between explicit %s and auto %s (%s %s)" % (
                  levdist, tranlen, translit, accented_translit, thislangname, accented))
                if not this_ignore_translit:
                  translit_arg = "|tr=%s" % translit
              else:
                pagemsg("WARNING: Levenshtein distance %s too big for length %s, not treating %s as transliteration of %s (%s %s)" % (
                levdist, tranlen, translit, accented_translit, thislangname, accented))
                post_translit_arg = " (%s)" % orig_translit

          if page:
            return "{{%s|%s|%s|%s%s}}%s" % (template, langcode, page,
                accented, translit_arg, post_translit_arg)
          else:
            return "{{%s|%s|%s%s}}%s" % (template, langcode, accented,
                translit_arg, post_translit_arg)

        def obfuscate_brackets(text):
          return text.replace("[", lbracket_sub).replace("]", rbracket_sub)

        def unobfuscate_brackets(text):
          return text.replace(lbracket_sub, "[").replace(rbracket_sub, "]")

        def sub_raw_latin_link(m):
          if m.group(1).count('(') != m.group(1).count(')'):
            pagemsg("WARNING: Unbalanced parens preceding raw link: %s" %
                unobfuscate_brackets(m.group(0)))
            retsub = m.group(2)
          else:
            retsub = sub_link(m.group(2), m.group(3), None, None)
          return m.group(1) + obfuscate_brackets(retsub)

        def sub_raw_link(m):
          return sub_link(m.group(0), m.group(1), m.group(2), None)

        def sub_template_link(m):
          return sub_link(m.group(0), m.group(2), m.group(3), m.group(1))

        # Split templates, then rejoin text involving templates that don't
        # have newlines in them
        split_templates = re.split(template_table_split_re, subsections[k], 0, re.S)
        for l in xrange(0, len(split_templates), 2):
          if "{" in split_templates[l] or "}" in split_templates[l]:
            pagemsg("WARNING: Stray brace in split_templates[%s]: Skipping page: <<%s>>" % (l, split_templates[l].replace("\n", r"\n")))
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
                replaced = False
                if this_ignore_translit == "latin":
                  new_subline = unobfuscate_brackets(
                      rsub_repeatedly(r"^(.*?)(\[\[(.*?)\]\])", sub_raw_latin_link, subline))
                else:
                  new_subline = re.sub(r"\[\[([^A-Za-z]*?)\]\](?: \(([^()|]*?)\))?", sub_raw_link, subline)
                if new_subline != subline:
                  pagemsg("Replacing %s with %s in %s section" % (subline, new_subline, subsectitle))
                  subline = new_subline
                  replaced = True
                if this_ignore_translit !="latin":
                  # Only try subbing template links with what looks like a
                  # following translit
                  new_subline = re.sub(r"\{\{([lm])\|%s\|([^A-Za-z{}]*?)\}\}(?: \(([^()|]*?)\))" % thislangcode, sub_template_link, subline)
                  if new_subline != subline:
                    pagemsg("Replacing %s with %s in %s section" % (subline, new_subline, subsectitle))
                    subline = new_subline
                    replaced = True
                if replaced:
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
      pagemsg("Replacing <<%s>> with <<%s>>" % (text, newtext))

    comment = "Replace raw links with templated links: %s" % ",".join(subbed_links)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

if __name__ == "__main__":
  parser = blib.create_argparser("Replace raw links with templated links")
  parser.add_argument('--lang', help="Language code for language to do")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  if not args.lang:
    raise ValueError("Language code must be specified")
  if args.lang not in languages:
    raise ValueError("Unrecognized language code: %s" % args.lang)
  thislangcode = args.lang
  thislangname, this_remove_accents, this_charset, this_ignore_translit = (
      languages[thislangcode])

  for category in ["%s lemmas" % thislangname, "%s non-lemma forms" % thislangname]:
    msg("Processing category: %s" % category)
    for i, page in blib.cat_articles(category, start, end):
      msg("Page %s %s: Processing" % (i, unicode(page.title())))
      process_page(i, page, args.save, args.verbose)
