#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Convert Russian usage examples that are manually formatted using {{lang}}
# or links to use {{ru-ux}}

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = unicode(page.text)
  notes = []

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  def check_for_translation_italics(val, orig):
    val = val.replace("'', ''", ", ")
    if re.search("(?<!')''(?!')", val):
      pagemsg("WARNING: Italics in translation <<%s>>: <<%s>>" % (val, orig))
    return val

  def check_for_stray_vertical_bar(val):
    split_on_paired_brackets_braces = re.split(r"\[\[[^\[\]]*\]\]|\{\{[^{}]*\}\}", val)
    for outside_bracket_brace in split_on_paired_brackets_braces:
      if "|" in outside_bracket_brace:
        pagemsg("WARNING: Stray vertical bar in Russian or English, can't handle: <<%s>>" % val)
        return True
    return False

  for j in xrange(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      # Try to convert multi-line usex using #:
      def multi_line_usex(m):
        ru, tr, en = m.groups()
        en = check_for_translation_italics(en, m.group(0))
        if check_for_stray_vertical_bar(ru) or check_for_stray_vertical_bar(tr) or check_for_stray_vertical_bar(en):
          return m.group(0)
        retval = "#: {{ru-ux|%s|tr=%s|%s}}" % (ru, tr, en)
        pagemsg("Replaced <<%s>> with <<%s>>" % (m.group(0), retval))
        notes.append("converted raw multi-line usex to 'ru-ux'")
        return retval
      sections[j] = re.sub(r"^#: \{\{lang\|ru\|([^\n{}]*?)\}\}\n#:: (.*)\n#:::? (.*)$", multi_line_usex, sections[j], 0, re.M)

      # Try to convert multi-line usex using #*
      def multi_line_usex_hidden(m):
        ru, tr, en = m.groups()
        en = check_for_translation_italics(en, m.group(0))
        if check_for_stray_vertical_bar(ru) or check_for_stray_vertical_bar(tr) or check_for_stray_vertical_bar(en):
          return m.group(0)
        retval = "%s#*: {{ru-ux|%s|tr=%s|%s}}" % (ru, tr, en)
        pagemsg("Replaced <<%s>> with <<%s>>" % (m.group(0), retval))
        notes.append("converted raw multi-line hidden usex to 'ru-ux'")
        return retval
      sections[j] = re.sub(r"^(#\* .*?\n)#\*: \{\{lang\|ru\|([^\n{}]*?)\}\}\n#\*:: ([^{}\n]*)\n#\*:::? ([^{}\n]*)$", multi_line_usex_hidden, sections[j], 0, re.M)

      # Try to convert single-line usex that uses {{lang}}, {{l}} or {{m}}
      for tempname in ["lang", "l", "m"]:
        def single_line_usex_lang_l_m(m):
          ru, en = m.groups()
          en = check_for_translation_italics(en, m.group(0))
          if tempname == "lang" or "[" in ru:
            if check_for_stray_vertical_bar(ru) or check_for_stray_vertical_bar(en):
              return m.group(0)
            retval = "#: {{ru-ux|%s|%s|inline=y}}" % (ru, en)
          else:
            if "|tr=" in ru:
              pagemsg("WARNING: Found |tr= in link, can't handle: <<%s>>" %
                  m.group(0))
              return m.group(0)
            # A single vertical bar in ru is allowed here; it will be handled
            # correctly because we wrap it in a raw link
            if check_for_stray_vertical_bar(en):
              return m.group(0)
            retval = "#: {{ru-ux|[[%s]]|%s|inline=y}}" % (ru, en)
          pagemsg("Replaced <<%s>> with <<%s>>" % (m.group(0), retval))
          notes.append("converted raw single-line usex using {{%s}} to 'ru-ux'" % tempname)
          return retval
        # Version with ''...'' around the translation; do this first in case
        # we have bold (''') around the first Russian word and italics ('')
        # around the translation; in the opposite order, the bold will get
        # treated as italics
        sections[j] = re.sub(ur"^#:\*? \{\{%s\|ru\|([^\n{}]*?)\}\}(?: |\&nbsp;)(?:—|\&mdash;)(?: |\&nbsp;)''(.*?)''$" % tempname, single_line_usex_lang_l_m, sections[j], 0, re.M)
        # Version with ''...'' around the whole thing
        sections[j] = re.sub(ur"^#:\*? ''\{\{%s\|ru\|([^\n{}]*?)\}\}(?: |\&nbsp;)(?:—|\&mdash;)(?: |\&nbsp;)(.*?)''$" % tempname, single_line_usex_lang_l_m, sections[j], 0, re.M)
        # Version without ''...''
        sections[j] = re.sub(ur"^#:\*? \{\{%s\|ru\|([^\n{}]*?)\}\}(?: |\&nbsp;)(?:—|\&mdash;)(?: |\&nbsp;)(.*?)$" % tempname, single_line_usex_lang_l_m, sections[j], 0, re.M)

      # Try to convert single-line usex that is raw, maybe allowing braces
      # in the right side
      for allow_braces_on_right in [False, True]:
        maybe_exclude_braces = "" if allow_braces_on_right else "{}"
        allow_braces_msg = ", allowing braces on right side" if allow_braces_on_right else ""
        def single_line_usex_raw(m):
          ru, en = m.groups()
          en = check_for_translation_italics(en, m.group(0))
          if check_for_stray_vertical_bar(ru) or check_for_stray_vertical_bar(en):
            return m.group(0)
          retval = "#: {{ru-ux|%s|%s|inline=y}}" % (ru, en)
          pagemsg("Replaced <<%s>> with <<%s>>" % (m.group(0), retval))
          notes.append("converted pure raw single-line usex to 'ru-ux'%s" %
              allow_braces_msg)
          return retval
        # Version with ''...'' around the translation; do this first in case
        # we have bold (''') around the first Russian word and italics ('')
        # around the translation; in the opposite order, the bold will get
        # treated as italics
        sections[j] = re.sub(ur"^#:\*? ([^{}\n]*)(?: |\&nbsp;)(?:—|-|\&mdash;)(?: |\&nbsp;)''([^%s\n]*?)''$" % maybe_exclude_braces, single_line_usex_raw, sections[j], 0, re.M)
        # Version with ''...'' around the whole thing; the expression after
        # the '' is a disjunctive lookahead expression and says "(two single
        # quotes) either followed by 3 more quotes (combination bold+italic)
        # or not followed by any quote (to exclude bold = ''')
        sections[j] = re.sub(ur"^#:\*? ''(?:(?!')|(?='''))([^{}\n]*)(?: |\&nbsp;)(?:—|-|\&mdash;)(?: |\&nbsp;)([^%s\n]*?)''$" % maybe_exclude_braces, single_line_usex_raw, sections[j], 0, re.M)
        # Version without ''...''
        sections[j] = re.sub(ur"^#:\*? ([^{}\n]*)(?: |\&nbsp;)(?:—|-|\&mdash;)(?: |\&nbsp;)([^%s\n]*?)$" % maybe_exclude_braces, single_line_usex_raw, sections[j], 0, re.M)

  new_text = "".join(sections)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <<%s>> with <<%s>>" % (text, new_text))
    assert notes
    comment = "; ".join(blib.group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Convert manually formatted Russian usage examples to ru-ux")
parser.add_argument('--pagefile', help="File containing pages to fix.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.pagefile:
  lines = [x.strip() for x in codecs.open(args.pagefile, "r", "utf-8")]
  for i, page in blib.iter_items(lines, start, end):
    process_page(i, pywikibot.Page(site, page), args.save, args.verbose)
else:
  for cat in ["Russian lemmas", "Russian non-lemma forms"]:
    msg("Processing category %s" % cat)
    for i, page in blib.cat_articles(cat, start, end):
      process_page(i, page, args.save, args.verbose) 
