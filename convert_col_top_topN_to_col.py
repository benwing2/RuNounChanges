#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

blib.getLanguageData()
#blib.languages_byCanonicalName = {"English": {"code": "en"}}

shortcut_to_expansion = {
  "alt": "Alternative forms",
  "ant": "Antonyms",
  "co": "Collocations",
  "col": "Collocations",
  "cog": "Cognates",
  "com": "Compounds",
  "cot": "Coordinate terms",
  "der": "Derived terms",
  "des": "Descendants",
  "desc": "Descendants",
  "dia": "Dialectal forms",
  "fur": "Further reading",
  "id": "Idioms",
  "hyper": "Hypernyms",
  "hypo": "Hyponyms",
  "prov": "Proverbs",
  "ref": "References",
  "rel": "Related terms",
  "see": "See also",
  "syn": "Synonyms",
  "tr": "Translations",
  "trans": "Translations",
}

header_to_col_top_abbrev = {
  "Alternative forms": "alt",
  "Antonyms": "ant",
  "Cognates": "cog",
  "Compounds": "com",
  "Coordinate terms": "cot",
  "Derived terms": "der",
  "Dialectal forms": "dia",
  "Idioms": "id",
  "Hypernyms": "hyper",
  "Hyponyms": "hypo",
  "Proverbs": "prov",
  "Related terms": "rel",
  "Synonyms": "syn",
}

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  sections, sections_by_lang, section_langs = blib.split_text_into_sections(text, pagemsg)
  section_langs = dict(section_langs)
  for j in range(2, len(sections), 2):
    langname = section_langs[j]
    if langname not in blib.languages_byCanonicalName:
      pagemsg("WARNING: Unknown language name %s, skipping section %s" % (langname, j // 2))
      continue
    langcode = blib.languages_byCanonicalName[langname]["code"]
    subsections, subsections_by_header, subsection_headers, subsection_levels = (
      blib.split_text_into_subsections(sections[j], pagemsg)
    )
    for k in range(2, len(subsections), 2):
      header = subsection_headers[k]
      expected_abbrev = header_to_col_top_abbrev.get(header, None)
      lines = subsections[k].split("\n")
      newlines = []
      in_col_top = False
      col_elements = None
      raw_col_lines = None
      cant_convert = False
      ncol = None
      col_top_header = None
      for line in lines:
        if in_col_top:
          raw_col_lines.append(line)
          if re.search("^\{\{ *col-bottom *\|", line.strip()):
            if not cant_convert:
              pagemsg("WARNING: Saw {{col-bottom}} with params, can't convert to {{col}}: %s" % line)
            newlines.extend(raw_col_lines)
            in_col_top = False
            continue
          if re.search("^\{\{ *col-bottom *\}\}$", line.strip()):
            if cant_convert:
              newlines.extend(raw_col_lines)
              in_col_top = False
              continue
            if col_top_header != expected_abbrev:
              col_top_header = shortcut_to_expansion.get(col_top_header, col_top_header)
              newlines.append("{{q|%s}}:" % col_top_header)
            newlines.append("{{col|%s" % langcode)
            newlines.extend(col_elements)
            newlines.append("}}")
            notes.append("convert {{col-top}}/{{col-bottom}} to {{col|%s|...}} with %s line%s" % (
              langcode, len(col_elements), "" if len(col_elements) == 1 else "s"))
            in_col_top = False
            continue
          if cant_convert:
            continue
          if not line.startswith("*"):
            pagemsg("WARNING: Non-bulleted line, can't yet convert to {{col}}: %s" % line)
            cant_convert = True
            continue
          if line.startswith("**"):
            pagemsg("WARNING: Multiply indented line, can't yet convert to {{col}}: %s" % line)
            cant_convert = True
            continue
          m = re.search(r"^\* *([\[{'].*)$", line)
          if not m:
            pagemsg("WARNING: Line doesn't have a term after a single bullet: %s" % line)
            cant_convert = True
            continue
          line = m.group(1).strip()
          origline = line
          if re.search(r"\{\{ *(ja-l|ja-r|ja-r/args|ryu-l|ryu-r|ryu-r/args|ko-l|zh-l|vi-l|he-l) *\|", line):
            pagemsg("WARNING: Unable to convert Asian specialized linking template to {{col}} format, inserting raw: %s" % line)
            col_elements.append("|%s" % origline)
            continue
          left_qual = []
          right_qual = []
          def extract_left_or_right_qualifier(line, on_left=True):
            this_qual = None
            # check for left qualifiers specified using a qualifier template
            if on_left:
              left_re = ""
              right_re = " *(.*?)"
            else:
              left_re = "(.*?) "
              right_re = ""
            m = re.search(r"^%s\{\{(?:qualifier|qual|q|i)\|([^{}|=]*)\}\}%s" % (left_re, right_re), line)
            if m:
              this_qual, line = m.groups()
            if not m:
              # check for qualifier-like ''(...)''
              m = re.search(r"^%s''\(([^'{}]*)\)''%s$" % (left_re, right_re), line)
              if m:
                this_qual, line = m.groups()
            if not m:
              # check for qualifier-like (''...'')
              m = re.search(r"^%s\(''([^'{}]*)''\)%s$" % (left_re, right_re), line)
              if m:
                this_qual, line = m.groups()
            if not m:
              # check for somewhat qualifier-like ''...''
              m = re.search(r"^%s''([^'{}]*)''%s$" % (left_re, right_re), line)
              if m:
                this_qual, line = m.groups()
            if this_qual is None:
              return None, line
            if not on_left:
              this_qual, line = line, this_qual
            return this_qual, line

          while True:
            this_left_qual, line = extract_left_or_right_qualifier(line, on_left=True)
            if this_left_qual is None:
              break
            left_qual.append(this_left_qual)

          while True:
            this_right_qual, line = extract_left_or_right_qualifier(line, on_left=False)
            if this_right_qual is None:
              break
            right_qual.append(this_right_qual)

          def append_with_quals(vals):
            if left_qual:
              vals[0] += "<q:%s>" % ", ".join(left_qual)
            if right_qual:
              vals[-1] += "<qq:%s>" % ", ".join(right_qual)
            col_elements.append("|%s" % ",".join(vals))

          def handle_parse_error(reason):
            nonlocal cant_convert
            if re.search(r"\{\{ *[lm] *\|", line):
              pagemsg("WARNING: %s and line has templated link, inserting raw: %s" % (reason, line))
              col_elements.append("|%s" % origline)
            else:
              pagemsg("WARNING: %s and no templated link present, can't convert to {{col}}: %s" % (reason, line))
              cant_convert = True

          if re.search(r"^\{\{ *[lm] *\||\[\[", line):
            template_or_raw_link_split_re = r"""(\{\{ *[lm] *\|(?:[^{}]|\{\{[^{}]*\}\})*\}\}|\[\[[^\[\]|=]+\]\])"""
            line_parts = re.split(template_or_raw_link_split_re, line)
            for i in range(0, len(line_parts), 2):
              if not re.search(r"^\s*,*\s*$", line_parts[i]):
                handle_parse_error("Unrecognized separator <%s> in line" % line_parts[i])
                break
            else: # no break
              els = []
              for i in range(1, len(line_parts), 2):
                m = re.search(r"^\[\[([^\[\]|=]+)\]\]$", line_parts[i])
                if m:
                  els.append(m.group(1))
                  continue
                m = re.search(r"^\[\[([^\[\]|=]+)\|([^\[\]|=]+)\]\]$", line_parts[i])
                if m:
                  els.append(line_parts[i])
                  continue
                if line_parts[i].startswith("[["):
                  handle_parse_error("Unable to convert raw link <%s> in bulleted line to {{col}} element" %
                                     line_parts[i])
                  break
                linkt = list(blib.parse_text(line_parts[i]).filter_templates())[0]
                def getp(param):
                  return getparam(linkt, param).strip()
                parts = []
                def app(val):
                  parts.append(val)
                link_langcode = getp("1")
                if link_langcode != langcode:
                  app("%s:" % link_langcode)
                dest = getp("2")
                alt = getp("alt") or getp("3")
                if alt:
                  if "[" not in dest and "[" not in alt:
                    app("[[%s|%s]]" % (dest, alt))
                  else:
                    app("%s<alt:%s>" % (dest, alt))
                else:
                  app(dest)
                gloss = getp("t") or getp("gloss") or getp("4")
                if gloss:
                  app("<t:%s>" % gloss)
                def append_if(param):
                  val = getp(param)
                  if val:
                    app("<%s:%s>" % (param, val))
                append_if("tr")
                append_if("ts")
                append_if("sc")
                append_if("pos")
                append_if("lit")
                append_if("id")
                genders = blib.fetch_param_chain(linkt, "g")
                if genders:
                  app("<g:%s>" % ",".join(genders))
                els.append("".join(parts))
              else: # no break
                append_with_quals(els)
          else:
            handle_parse_error("Can't parse links")
        else:
          m = re.search(r"^\{\{col-top\|([0-9]+)\|([^|=]*)\}\}$", line)
          if m:
            ncol, col_top_header = m.groups()
            in_col_top = True
            col_elements = []
            cant_convert = False
            raw_col_lines = [line]
          else:
            newlines.append(line)
      if in_col_top:
        pagemsg("WARNING: Saw {{col-top}} with closing {{col-bottom}}")
        newlines.extend(raw_col_lines)
      subsections[k] = "\n".join(newlines)
    sections[j] = "".join(subsections)

  return "".join(sections), notes

parser = blib.create_argparser("Convert {{col-top}}/{{col-bottom}} to {{col}} when possible",
                               include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(
  args, start, end, process_text_on_page, edit=True, stdin=True)
