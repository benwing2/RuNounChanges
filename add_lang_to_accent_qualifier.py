#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

accent_templates = ["a", "accent"]
blib.getData()

lang_for_special_pages = {
  "Wiktionary:Entry layout": "en",
  "Appendix:Chemical elements/English": "en",
  "Wiktionary:Pronunciation": "en",
  "Appendix:English prefixes": "en",
  "Wiktionary:Style guide": "en",
  "Appendix:Australian English vocabulary": "en",
  "Wiktionary:Beer parlour/2007/October": "en",
  "Wiktionary:Beer parlour/2007/December": "en",
  "Appendix:Collocations of do, have, make, and take": "en",
  "Appendix:English nationality prefixes": "en",
  "Wiktionary:Beer parlour/2008/January": "en",
  "Wiktionary:Beer parlour/2008/April": "en",
  "Wiktionary:Beer parlour/2008/August": "en",
  "Wiktionary:Grease pit/2008/February": "la",
  "Wiktionary:Grease pit/2008/June": "en",
  "Appendix:Latin cardinal numerals": "la",
  "Wiktionary:Information desk/Archive 2008/January-June": "en",
  "Wiktionary:Requested entries (Albanian)": "sq",
  "Template:accent/documentation": "en",
  "Wiktionary:Information desk/Archive 2010/July-December": "de",
  "Wiktionary:Dialects": "en",
  "Wiktionary:Beer parlour/2010/December": "en",
  "Wiktionary:Beer parlour/2011/May": "ja",
  "Wiktionary:Grease pit/2011/June": "ja",
  "Wiktionary:Beer parlour/2012/October": "en",
  "Wiktionary:Tea room/2012/December": "en",
  "Wiktionary:Tea room/2013/February": "en",
  "Wiktionary:Tea room/2013/April": "en",
  #"Wiktionary:Beer parlour/2014/January": "en" and "he",
  "Wiktionary:Beer parlour/2014/February": "en",
  "Wiktionary:Beer parlour/2014/March": "en",
  "Template:hu-IPA/documentation": "hu",
  "Wiktionary:Grease pit/2015/June": "sq",
  "Wiktionary:Beer parlour/2016/February": "en",
  "Wiktionary:Beer parlour/2016/October": "en",
  "Wiktionary:Grease pit/2017/May": "ar",
  "Wiktionary:Beer parlour/2018/May": "en",
  "Wiktionary:Grease pit/2018/June": "en",
  "Wiktionary:Tea room/2018/February": "acn",
  "Wiktionary:Tea room/2019/November": "en",
  "Wiktionary:Information desk/2019/August": "en",
  "Wiktionary:Beer parlour/2020/January": "en",
  "Wiktionary:Tea room/2020/December": "en",
  "Wiktionary:Information desk/2020/March": "en",
  "Wiktionary:Beer parlour/2021/July": "la",
  "Wiktionary:Tea room/2022/February": "en",
  "Wiktionary:Beer parlour/2022/November": "tl",
  "Template:ms-IPA/documentation": "ms",
  "Wiktionary:Requests for verification/Italic": "pt",
  "Wiktionary:Tea room/2023/March": "en",
  "Wiktionary:Beer parlour/2023/August": "ko",
  "Wiktionary:Beer parlour/2023/October": "en",
  "Wiktionary:Beer parlour/2023/December": "en",
  "Appendix:English prefixes by semantic category": "en",
  "Appendix:English prefixes/M-Z": "en",
  "Appendix:Australian English motoring terms": "en",
  "Appendix:Australian English geographic terms": "en",
  "Appendix:Protologisms/Long words/Titin": "en",
  "Appendix:Polish pronunciation": "en",
  "Appendix:Chavacano Swadesh list": "cbk",
  "Appendix:Silesian pronunciation": "en",
  "Appendix:Masurian pronunciation": "en",
}

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if not re.search(r"\{\{ *(a|accent) *\|", text):
    return
  def hack_templates(sectext, langname, langnamecode=None, is_citation=False):
    if langname not in blib.languages_byCanonicalName:
      if not is_citation:
        langnamecode = None
    else:
      langnamecode = blib.languages_byCanonicalName[langname]["code"]

    lines = sectext.split("\n")
    for i, line in enumerate(lines):
      def incorporate_a_into_IPA(m, accent_first):
        if accent_first:
          raw_accent_t, raw_ipa_t = m.groups()
        else:
          raw_ipa_t, raw_accent_t = m.groups()
        accent_t = list(blib.parse_text(raw_accent_t).filter_templates())[0]
        ipa_t = list(blib.parse_text(raw_ipa_t).filter_templates())[0]
        accents = blib.fetch_param_chain(accent_t, "1")
        if accent_first:
          a_param_name = "a"
        else:
          a_param_name = "aa"
        if getparam(ipa_t, a_param_name):
          pagemsg("WARNING: Already saw %s= in {{IPA}}, not changing: %s" % (a_param_name, line))
          return m.group(0)
        a_param = ",".join(x.strip() for x in accents)
        ipa_t.add(a_param_name, a_param)
        notes.append("incorporate %s=%s into {{IPA|%s}}" % (a_param_name, a_param, getparam(ipa_t, "1")))
        return str(ipa_t)
      newline = re.sub(
        r"(\{\{ *(?:a|accent) *\|(?:\{\{[^{}]*\}\}|[^{}=])+\}\}) *(\{\{ *IPA *\|(?:\{\{[^{}]*\}\}|[^{}])+\}\})",
        lambda m: incorporate_a_into_IPA(m, accent_first=True), line)
      newline = re.sub(
        r"(\{\{ *IPA *\|(?:\{\{[^{}]*\}\}|[^{}])+\}\}) *(\{\{ *(?:a|accent) *\|(?:\{\{[^{}]*\}\}|[^{}=])+\}\})",
        lambda m: incorporate_a_into_IPA(m, accent_first=False), newline)
      if newline != line:
        pagemsg("Replace <%s> with <%s>" % (line, newline))
        lines[i] = newline
    sectext = "\n".join(lines)

    parsed = blib.parse_text(sectext)
    for t in parsed.filter_templates():
      origt = str(t)
      tn = tname(t)
      thislangcode = langnamecode
      if tn in ["citation", "citations"] and is_citation:
        thislangcode = getparam(t, "1")
        langnamecode = thislangcode
      elif tn in accent_templates:
        numbered_params = blib.fetch_param_chain(t, "1")
        if not numbered_params:
          pagemsg("WARNING: No params: %s" % str(t))
          continue
        param1 = numbered_params[0]
        if (args.skip_already_done and param1 in blib.languages_byCode and
            len(numbered_params) > 1):
          pagemsg("Skipping likely already-done template: %s" % str(t))
          continue
        must_continue = False
        for param in t.params:
          pn = pname(param)
          if not re.search("^[0-9]+$", pn):
            pagemsg("WARNING: Unrecognized param %s=%s: %s" % (pn, str(param.value), str(t)))
            must_continue = True
            break
        if not thislangcode:
          if "Todo/Westrobothnian" in pagetitle:
            pagemsg("Westrobothnian TODO, using 'und' as langcode")
            thislangcode = "und"
            notes.append("use 1=%s for {{%s}} in Westrobothnian TODO page" % (thislangcode, tn))
          elif "Appendix:Kotava" in pagetitle:
            pagemsg("Kotava appendix, using 'en' as langcode")
            thislangcode = "en"
            notes.append("use 1=%s for {{%s}} in Kotava appendix page" % (thislangcode, tn))
          elif pagetitle in lang_for_special_pages:
            thislangcode = lang_for_special_pages[pagetitle]
            pagemsg("Recognized special page, using '%s' as langcode" % thislangcode)
            notes.append("use 1=%s for {{%s}} in specially recognized page" % (thislangcode, tn))
          else:
            pagemsg("WARNING: Unrecognized language %s, unable to add language: %s" % (langname, str(t)))
            continue
        elif pagetitle.startswith("Rhymes:"):
          notes.append("infer 1=%s for {{%s}} based on page title" % (thislangcode, tn))
        else:
          notes.append("infer 1=%s for {{%s}} based on section it's in" % (thislangcode, tn))
        # Erase all params.
        del t.params[:]
        t.add("1", thislangcode)
        blib.set_param_chain(t, numbered_params, "2")
        pagemsg("Replace <%s> with <%s>" % (origt, str(t)))

    return str(parsed), langnamecode

  pagemsg("Processing")

  if pagetitle.startswith("Rhymes:"):
    m = re.search("^Rhymes:(.*?)/.*$", pagetitle)
    if not m:
      m = re.search("^Rhymes:(.*)$", pagetitle)
    assert m
    newtext, _ = hack_templates(text, m.group(1))
  elif pagetitle.startswith("Appendix:"):
    newtext, _ = hack_templates(text, "Unknown")
  else:
    sections, sections_by_lang, lang_sections = blib.split_text_into_sections(text, pagemsg)
    if not pagetitle.startswith("Citations"):
      for j, langname in lang_sections:
        sections[j], _ = hack_templates(sections[j], langname)
      newtext = "".join(sections)
    else:
      # Citation section?
      sections, sections_by_lang, lang_sections = blib.split_text_into_sections(text, pagemsg)
      sections[0], langnamecode = hack_templates(sections[0], "Unknown", langnamecode=None, is_citation=True)
      for j, langname in lang_sections:
        sections[j], langnamecode = hack_templates(sections[j], langname, langnamecode=langnamecode, is_citation=True)
      newtext = "".join(sections)

  return newtext, notes

parser = blib.create_argparser("Add language to {{a}} and {{accent}} templates, based on the section it's within",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--skip-already-done", action="store_true", help="Skip if it looks like the lang code has already been added.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
                           default_refs=["Template:accent"])
