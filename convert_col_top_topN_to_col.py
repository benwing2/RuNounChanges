#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

blib.getLanguageData()
#blib.languages_byCanonicalName = {
#  "English": {"code": "en"},
#  "Japanese": {"code": "ja"},
#  "Chinese": {"code": "zh"},
#  "Spanish": {"code": "es"},
#  "French": {"code": "fr"},
#  "Portuguese": {"code": "pt"},
#  "Latin": {"code": "la"},
#  "Norwegian Bokmål": {"code": "nb"},
#  "Norwegian Nynorsk": {"code": "nn"},
#}

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


# Simplify a link consisting of `left` and possibly a `right` part. This may come from a raw or templated link.
# `altval` is an explicit |alt= value given in a templated link. `langcode`, if given, is the language code of the
# templated link, `sec_langcode` is the language code of the section we're in, and `sec_langname` is the corresponding
# language name.
def simplify_link(left, right, altval, langcode, sec_langcode, sec_langname, pagemsg):
  if "[[" in left:
    m = re.search(r"^\[\[([^\[\]|=]+)\]\]$", left)
    if m:
      left = m.group(1)
    else:
      m = re.search(r"^\[\[([^\[\]|]+)\|([^\[\]|]+)\]\]$", left)
      if m:
        newleft, newright = m.groups()
        if right:
          pagemsg("WARNING: Both two-part link %s and display value %s given; overriding the display in the former with the latter" % (
            left, right))
          newright = right
        left = newleft
        right = newright
      else:
        if right and altval:
          pagemsg("WARNING: All three of embedded link %s, display value %s and alt value %s given; ignoring display value, and beware that alt value will be ignored as well" % (
            left, right, altval))
          right = None
        elif right:
          pagemsg("WARNING: Both embedded link %s and display value %s given; converting display value to alt value, but beware that it will be ignored" % (
            left, right))
          altval = right
          right = None
        elif altval:
          pagemsg("WARNING: Both embedded link %s and alt value %s given; beware that alt value will be ignored" % (
            left, altval))

  origlink = left if "[[" in left else "[[%s%s]]" % (left, "|%s" % right if right else "")
  langcode = langcode or ""
  if langcode and langcode == sec_langcode:
    langcode = ""
  if "[[" not in left:
    m = re.search("^(.*?)#(.*)$", left)
    if m:
      newleft, explicit_langname = m.groups()
      if explicit_langname not in blib.languages_byCanonicalName:
        pagemsg("WARNING: Unknown language name %s in link %s, not removing" % (explicit_langname, origlink))
      else:
        explicit_langcode = blib.languages_byCanonicalName[explicit_langname]["code"]
        if not langcode or langcode == explicit_langcode:
          langcode = explicit_langcode
        else:
          pagemsg("WARNING: Language code '%s' explicitly found in link %s doesn't agree with language code '%s' explicitly specified in link template, which is different from language code '%s' of section; overriding link language code" % (
            explicit_langcode, origlink, langcode, sec_langcode))
          langcode = explicit_langcode
        left = newleft
        if langcode == sec_langcode:
          langcode = ""
  if right and left == right:
    right = None
  if not right and altval and "[[" not in altval:
    right = altval
    altval = None
    if left == right:
      right = None
  if "[[" not in left and right:
    link = "[[%s|%s]]" % (left, right)
  else:
    link = left
  return "%s%s%s%s" % (langcode, ":" if langcode else "", link, "<alt:%s>" % altval if altval else "")

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
      col_top_tn = None
      col_elements = None
      raw_col_lines = None
      cant_convert = False
      col_top_header = None
      for line in lines:
        if in_col_top:
          raw_col_lines.append(line)
          m = re.search("^\{\{ *((?:col-)?bottom) *\|", line.strip())
          if m:
            if not cant_convert:
              pagemsg("WARNING: Saw {{%s}} with params, can't convert to {{col}}: %s" % (m.group(1), line))
            newlines.extend(raw_col_lines)
            in_col_top = False
            continue
          m = re.search("^\{\{ *((?:col-)?bottom) *\}\}$", line.strip())
          if m:
            if cant_convert:
              newlines.extend(raw_col_lines)
              in_col_top = False
              continue
            if col_top_header and col_top_header != expected_abbrev:
              col_top_header = shortcut_to_expansion.get(col_top_header, col_top_header)
            else:
              col_top_header = ""
            col_bottom_tn = m.group(1)
            newlines.append("{{col|%s%s%s" % (
              langcode, "|sort=0" if langcode in ["ja", "ryu"] else "",
              "|title=%s" % col_top_header if col_top_header else ""
            ))
            newlines.extend(col_elements)
            newlines.append("}}")
            notes.append("convert {{%s}}/{{%s}} to {{col|%s|...}} with %s line%s" % (
              col_top_tn, col_bottom_tn, langcode, len(col_elements), "" if len(col_elements) == 1 else "s"))
            in_col_top = False
            continue
          if cant_convert:
            continue
          if not line.startswith("*"):
            pagemsg("WARNING: Non-bulleted line, can't yet convert to {{col}}: %s" % line)
            cant_convert = True
            continue
          if re.search(r"^\*[*:#]", line):
            pagemsg("WARNING: Multiply indented line, can't yet convert to {{col}}: %s" % line)
            cant_convert = True
            continue
          m = re.search(r"^\* *(.*)$", line)
          if not m:
            pagemsg("WARNING: Internal error: Line doesn't have a term after a single bullet: %s" % line)
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
          exterior_genders = []
          def extract_left_or_right_qualifier_or_gender(line, on_left=True):
            this_qual = None
            this_gender = None
            # check for left qualifiers specified using a qualifier template
            if on_left:
              left_re = ""
              right_re = " *(.*?)"
            else:
              left_re = "(.*?) "
              right_re = ""
            m = None
            if not m and not on_left:
              m = re.search(r"^%s\{\{(?:g|g2)\|([^{}=]*)\}\}%s$" % (left_re, right_re), line)
              if m:
                line, this_gender = m.groups()
                this_gender = this_gender.replace("|", ",")
            if not m:
              m = re.search(r"^%s\{\{(?:qualifier|qual|q|i)\|([^{}|=]*)\}\}%s$" % (left_re, right_re), line)
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
              return None, this_gender, line
            if not on_left:
              this_qual, line = line, this_qual
            return this_qual, this_gender, line

          while True:
            this_left_qual, this_left_gender, line = extract_left_or_right_qualifier_or_gender(line, on_left=True)
            if this_left_qual is None:
              break
            left_qual.append(this_left_qual)

          while True:
            this_right_qual, this_right_gender, line = extract_left_or_right_qualifier_or_gender(line, on_left=False)
            if this_right_qual is None and this_right_gender is None:
              break
            if this_right_qual:
              right_qual.append(this_right_qual)
            if this_right_gender:
              exterior_genders.append(this_right_gender)

          def append_with_quals(vals):
            def convert_quals(quals, is_left, has_pos, has_g):
              qualparts = []
              non_converted_quals = []
              def convert_qual(qual):
                nonlocal has_pos, has_g
                gender_map = {
                  "m": "m",
                  "m.": "m",
                  "masc": "m",
                  "masc.": "m",
                  "masculine": "m",
                  "f": "f",
                  "f.": "f",
                  "fem": "f",
                  "fem.": "f",
                  "feminine": "f",
                  "n": "n",
                  "n.": "n",
                  "neut": "n",
                  "neut.": "n",
                  "neuter": "n",
                  "mp": "m-p",
                  "m.p.": "m-p",
                  "m.pl.": "m-p",
                  "m-p": "m-p",
                  "m p": "m-p",
                  "m pl": "m-p",
                  "m. p.": "m-p",
                  "m. pl.": "m-p",
                  "masc pl": "m-p",
                  "masc. pl.": "m-p",
                  "masculine plural": "m-p",
                  "fp": "f-p",
                  "f.p.": "f-p",
                  "f.pl.": "f-p",
                  "f-p": "f-p",
                  "f p": "f-p",
                  "f pl": "f-p",
                  "f. p.": "f-p",
                  "f. pl.": "f-p",
                  "fem pl": "f-p",
                  "fem. pl.": "f-p",
                  "feminine plural": "f-p",
                  "np": "n-p",
                  "n.p.": "n-p",
                  "n.pl.": "n-p",
                  "n-p": "n-p",
                  "n p": "n-p",
                  "n pl": "n-p",
                  "n. p.": "n-p",
                  "n. pl.": "n-p",
                  "neut pl": "n-p",
                  "neut. pl.": "n-p",
                  "neuter plural": "f-p",
                  "pl": "p",
                  "pl.": "p",
                  "plural": "p",
                }
                if qual in [
                  "rare", "uncommon", "colloquial", "informal", "nonstandard", "non-standard", "offsensive",
                  "figurative", "figuratively", "formal", "learned", "impersonal", "slang",
                  "obsolete", "archaic", "dated", "diminutive", "US", "UK", "American", "British", "sports", "medicine",
                  "law", "logic", "Puter", "Sursilvan", "Sutsilvan", "Surmiran", "Vallader", "shipping", "theology",
                  "geology", "botany",
                ]:
                  qualparts.append("<%s:%s>" % ("l" if is_left else "ll", qual))
                elif not has_pos and qual in [
                  "noun", "proper noun", "adjective", "adj", "verb", "v", "vb", "adverb", "adv", "preposition", "prep",
                  "conjunction", "conj", "verbal noun", "[[vi]]", "[[vt]]",
                ]:
                  qualparts.append("<pos:%s>" % qual.replace("[[", "").replace("]]", ""))
                  has_pos = True
                elif not has_g and qual in gender_map:
                  if is_left:
                    qualparts.append("<g:%s>" % gender_map[qual])
                    has_g = True
                  else:
                    exterior_genders.append(gender_map[qual])
                else:
                  non_converted_quals.append(qual)
              for qual in quals:
                convert_qual(qual)
              if non_converted_quals:
                qualparts.append("<%s:%s>" % ("q" if is_left else "qq", ", ".join(non_converted_quals)))
              return "".join(qualparts)

            if left_qual:
              vals[0] += convert_quals(left_qual, True, "<pos:" in vals[0], "<g:" in vals[0])
            if right_qual:
              vals[-1] += convert_quals(right_qual, False, "<pos:" in vals[-1], "<g:" in vals[-1])
            if exterior_genders:
              if "<g:" in vals[-1]:
                pagemsg("WARNING: Saw both interior and exterior genders, trying to combine")
                vals[-1] = re.sub("(<g:.*?)>", r"\1,%s>" % ",".join(exterior_genders), vals[-1])
              else:
                vals[-1] += "<g:%s>" % ",".join(exterior_genders)
            col_elements.append("|%s" % ",".join(vals))

          match_link_template_re = r"\{\{ *[lm](?:-self)? *\|"

          def handle_parse_error(reason):
            nonlocal cant_convert
            if re.search(match_link_template_re, line):
              pagemsg("WARNING: %s and line has templated link, inserting raw: %s" % (reason, line))
              col_elements.append("|%s" % origline)
            else:
              pagemsg("WARNING: %s and no templated link present, can't convert to {{col}}: %s" % (reason, line))
              cant_convert = True

          if re.search(r"^%s|\[\[" % match_link_template_re, line):
            template_or_raw_link_split_re = (
              r"""(%s(?:[^{}]|\{\{[^{}]*\}\})*\}\}|\[\[[^\[\]]+\]\])""" % match_link_template_re
            )
            line_parts = re.split(template_or_raw_link_split_re, line)
            for i in range(0, len(line_parts), 2):
              if not re.search(r"^\s*([,/]|or)*\s*$", line_parts[i]):
                handle_parse_error("Unrecognized separator <%s> in line" % line_parts[i])
                break
            else: # no break
              els = []
              has_pos = False
              for i in range(1, len(line_parts), 2):
                if line_parts[i].startswith("[["):
                  els.append(simplify_link(line_parts[i], None, None, None, langcode, langname, pagemsg))
                  continue
                linkt = list(blib.parse_text(line_parts[i]).filter_templates())[0]
                def getp(param):
                  return getparam(linkt, param).strip()
                parts = []
                def app(val):
                  parts.append(val)
                link_langcode = getp("1")
                left = getp("2")
                right = getp("3")
                alt = getp("alt")
                link = simplify_link(left, right, alt, link_langcode, langcode, langname, pagemsg)
                app(link)
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
              append_with_quals(els)
          else:
            handle_parse_error("Can't parse links")
        else:
          m = re.search(r"^\{\{(col-top)\|[0-9]+\|([^|=]*)\}\}$", line)
          if m:
            col_top_tn, col_top_header = m.groups()
          if not m:
            m = re.search(r"^\{\{(top[0-9])\}\}$", line)
            if m:
              col_top_tn = m.group(1)
              col_top_header = ""
          if not m:
            m = re.search(r"^\{\{(top[0-9])\|([^{}]*)\}\}$", line)
            if m:
              col_top_tn, col_top_header = m.groups()
              if col_top_header == langcode:
                col_top_header = ""
              if col_top_header.startswith("title="):
                col_top_header = col_top_header[6:]
          if m:
            in_col_top = True
            col_elements = []
            cant_convert = False
            raw_col_lines = [line]
          else:
            newlines.append(line)
      if in_col_top:
        pagemsg("WARNING: Saw {{col-top}} without closing {{col-bottom}}")
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
