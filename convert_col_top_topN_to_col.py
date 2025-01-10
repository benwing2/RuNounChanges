#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname
from collections import defaultdict

blib.languages_byCanonicalName = {
  "English": {"code": "en"},
  "Old English": {"code": "ang"},
  "Greek": {"code": "el"},
  "Hungarian": {"code": "hu"},
  "Japanese": {"code": "ja"},
  "Chinese": {"code": "zh"},
  "Spanish": {"code": "es"},
  "French": {"code": "fr"},
  "Portuguese": {"code": "pt"},
  "Latin": {"code": "la"},
  "Norwegian Bokmål": {"code": "nb"},
  "Norwegian Nynorsk": {"code": "nn"},
}
blib.getLanguageData()

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

seen_quals = defaultdict(int)

def escape_inline_val(val):
  # If < or > in the value, check if they are balanced. If not, escape them all (safest thing to do).
  if "<" in val or ">" in val:
    try:
      segments = blib.parse_balanced_segment_run(val, "<", ">")
    except blib.ParseException:
      return val.replace("<", "&lt;").replace(">", "&gt;")
  return val
def make_inline_modifier(key, val):
  return "<%s:%s>" % (key, escape_inline_val(val))

# Simplify a link `link` that may have an `altval` (display value) specified in |3= or |alt= if the link comes from a
# templated link. `langcode`, if given, is the language code of the templated link, `sec_langcode` is the language code
# of the section we're in, and `sec_langname` is the corresponding language name.
def simplify_link(link, altval, langcode, sec_langcode, sec_langname, pagemsg, expand_text):
  link = link or ""
  right = ""
  altval = altval or ""
  langcode = langcode or ""

  # Blank out langcode if specified and same as section language code.
  if langcode and langcode == sec_langcode:
    langcode = ""

  origlink = link

  # First try to simplify one-part or two-part link.
  if link and "[[" in link:
    m = re.search(r"^\[\[([^\[\]|=]+)\]\]$", link)
    if m:
      link = m.group(1)
    else:
      m = re.search(r"^\[\[([^\[\]|]+)\|([^\[\]|]+)\]\]$", link)
      if m:
        link, right = m.groups()

  # If link part does not have embedded links and has an explicit language code, try to remove it or transfer it to the
  # language prefix.
  if link and "[[" not in link:
    m = re.search("^(.*?)#(.*)$", link)
    if m:
      newlink, explicit_langname = m.groups()
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
        link = newlink
        if langcode == sec_langcode:
          langcode = ""

  # Remove right or altval same as link.
  if link == right:
    right = ""
  if link == altval:
    altval = ""
  # If link and either right side of link or display form map to the same entry name, use the latter as the link.
  if link and "[[" not in link and (right or altval and "[[" not in altval):
    link_entry_name = expand_text("{{#invoke:languages/templates|getByCode|%s|makeEntryName|%s}}" % (
      langcode or sec_langcode, link))
    if link_entry_name and right:
      right_entry_name = expand_text("{{#invoke:languages/templates|getByCode|%s|makeEntryName|%s}}" % (
        langcode or sec_langcode, right))
      if right_entry_name and right_entry_name == link_entry_name:
        pagemsg("Using right side of link '%s' in place of left side '%s' because both map to the same entry name" % (
          right, link))
        link = right
        right = ""
    elif altval and "[[" not in altval:
      altval_entry_name = expand_text("{{#invoke:languages/templates|getByCode|%s|makeEntryName|%s}}" % (
        langcode or sec_langcode, altval))
      if altval_entry_name and altval_entry_name == link_entry_name:
        pagemsg("Using display value '%s' in place of left side link '%s' because both map to the same entry name" % (
          altval, link))
        link = altval
        altval = ""

  if not link:
    # If link is empty, we must use the format '<alt:foo>' with an empty link, not '[[|foo]]'.
    if right and altval:
      pagemsg("WARNING: Empty link along with both right side '%s' and display value '%s' given; using right side in place of display value" % (
        right, altval))
    if right:
      altval = right
      right = ""
  elif "[[" in link:
    # If link still has embedded links (we tried to remove them above), display value will be ignored, but we can at
    # least put something there (in <alt:...>) to minimize loss of information.
    if right:
      pagemsg("WARNING: Internal error: Right '%s' should not be set" % right)
      right = ""
    if altval:
      pagemsg("WARNING: Display value '%s' found along with embedded link '%s'; the former will be ignored" % (
        altval, link))
  elif right:
    if "[[" in right:
      pagemsg("WARNING: Internal error: Right '%s' should not have embedded links" % right)
      right = ""
    else:
      link = "[[%s|%s]]" % (link, right)
  elif altval and "[[" not in altval:
    link = "[[%s|%s]]" % (link, altval)
    altval = ""
  elif "~" in link or re.search(r",[^ ]", link):
    # If embedded comma in link not followed by space, or tilde in link, the brackets must be preserved to avoid the
    # comma or tilde being interpreted as a delimiter.
    link = "[[%s]]" % link

  return "%s%s%s%s" % (langcode, ":" if langcode else "", link, make_inline_modifier("alt", altval) if altval else "")

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  match_link_template_re = r"\{\{ *(?:[lm](?:-self)?|ll) *\|"

  def extract_left_and_right_qualifiers_and_genders(line):
    left_qual = []
    right_qual = []
    right_gloss = []
    exterior_genders = []
    line_comment = ""

    m = re.search("^(.*)(<!--.*?-->)$", line)
    if m:
      line, line_comment = m.groups()
      line = line.strip()
    def extract_left_or_right_qualifier_or_gender(line, on_left=True):
      this_qual = None
      this_gender = None
      this_gloss = None
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
      if not m and not on_left:
        m = re.search(r"^%s\{\{(?:gloss|gl)\|([^{}=]*)\}\}%s$" % (left_re, right_re), line)
        if m:
          line, this_gloss = m.groups()
          this_gloss = this_gloss.replace("|", "; ")
      if not m:
        m = re.search(r"^%s\{\{(?:qualifier|qual|q|qf|i)\|([^{}=]*)\}\}%s$" % (left_re, right_re), line)
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
      if this_qual is not None and not on_left:
        this_qual, line = line, this_qual
      if this_qual is not None:
        # Split on comma+space and on | (separate params), but not | or comma+space inside of links.
        # Don't split if the qualifier text begins "literally".
        if re.search("^'*literally", this_qual):
          this_qual = [this_qual]
        else:
          segments = blib.parse_balanced_segment_run(this_qual, "[", "]")
          alternating_runs = blib.split_alternating_runs(segments, "(?:\||,\s+)")
          this_qual = ["".join(x) for x in alternating_runs]
      return this_qual, this_gender, this_gloss, line

    while True:
      this_left_quals, this_left_gender, this_left_gloss, line = extract_left_or_right_qualifier_or_gender(
        line, on_left=True)
      if this_left_quals is None:
        break
      left_qual.extend(this_left_quals)

    while True:
      this_right_quals, this_right_gender, this_right_gloss, line = extract_left_or_right_qualifier_or_gender(
        line, on_left=False)
      if this_right_quals is None and this_right_gender is None and this_right_gloss is None:
        break
      if this_right_quals:
        right_qual.extend(this_right_quals)
      if this_right_gender:
        exterior_genders.append(this_right_gender)
      if this_right_gloss:
        right_gloss.append(this_right_gloss)

    return line, left_qual, right_qual, exterior_genders, right_gloss, line_comment

  def construct_line_with_quals(vals, left_qual, right_qual, exterior_genders, right_gloss, line_comment):
    def convert_quals(quals, is_left, has_pos, has_g):
      qualparts = []
      non_converted_quals = []
      labels = []
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
          #"n": "n", existing uses seem to be "noun" not "neuter"
          #"n.": "n", existing uses seem to be "noun" not "neuter"
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
        label_map = {
          "archaic or obsolete": "archaic,or,obsolete",
          "Sanskritized, rare": "Sanskritized,rare",
          "Sanskritized, Rare": "Sanskritized,rare",
          "Sanskritized, literary": "Sanskritized,literary",
          "Sanskritized, formal or literary": "Sanskritized,formal,or,literary",
          "Persianized, rare": "Persianized,rare",
          "chiefly Islam": "chiefly,Islam",
          "chiefly Hinduism": "chiefly,Hinduism",
          "Mediaeval Latin": "Medieval Latin",
          "Med. Lat.": "Medieval Latin",
          "Mediaeval": "Medieval",
          "BrE": "UK",
          "obsolete, rare": "obsolete,rare",
          "zoölogy": "zoology",
          "South African English": "South Africa",
          "place name": "toponym",
          "placename": "toponym",
          "place": "toponym",
        }
        pos_map = {
          "adj.": "adj",
          "adjective and noun": "adjective, noun",
          "n.": "n",
          "intransitive": "vi",
          "transitive": "vt",
        }
        m = re.search("^'*literally[:;'\" ]+(.*?)['\"]+$", qual)
        if m:
          qualparts.append(make_inline_modifier("lit", m.group(1)))
        elif qual in label_map:
          labels.append(label_map[qual])
        elif qual in [
          "rare", "uncommon", "colloquial", "informal", "nonstandard", "non-standard", "offensive",
          "figurative", "figuratively", "formal", "learned", "impersonal", "slang", "vulgar", "literary", "historical",
          "humble speech", "jocular", "euphemistic", "derogatory", "expressive", "vernacular", "childish",
          "abbreviation", "initialism", "back-formation", "clipping", "blend", "proverb",
          "active", "passive", "reflexive",
          "dialectal", "regional", "poetic", "uncertain",
          "toponym", "surname", "patronymic", "female patronymic", "male patronymic", "former name",
          "obsolete", "archaic", "dated", "deprecated", "diminutive", "augmentative", "endearing", "semelfactive",
          "US", "American", "North America", "Canada", "Canadian", "UK", "British", "Britain", "British English",
          "Australia", "Australian", "Ireland", "Irish", "New Zealand", "Indian English",
          "Anglo-Norman", "Standard Malay", "Indonesian",
          "Spain", "Argentina", "Venezuela", "Dominican Republic", "Costa Rica", "Mexico", "Puerto Rico", "Paraguay",
          "Uruguay", "Chile", "Bolivia", "Colombia", "Costa Rica", "Cuba", "Panama", "Nicaragua", "Ecuador",
          "El Salvador", "Honduras", "Peru", "Guatemala", "Brazil", "Portugal",
          "Puter", "Sursilvan", "Sutsilvan", "Surmiran", "Vallader",
          "sports", "medicine", "law", "logic", "shipping", "theology", "phonology", "music", "grammar", "religion",
          "linguistics", "geology", "botany", "ornithology", "sociology", "psychiatry", "zoology", "anatomy",
          "chemistry", "architecture", "phonetics", "biology",
          "Sanskritized", "Sanskritised", "Persianized", "Persianised", "Netherlands",
          "Late Latin", "Classical", "Byzantine", "Vulgar Latin", "Medieval Latin", "New Latin",
        ]:
          labels.append(qual)
        elif not has_pos and qual in pos_map:
          qualparts.append(make_inline_modifier("pos", pos_map[qual]))
          has_pos = True
        elif not has_pos and qual in [
          "noun", "n", "proper noun", "adjective", "adj", "verb", "v", "vb", "adverb", "adv", "preposition", "prep",
          "conjunction", "conj", "verbal noun", "[[vi]]", "[[vt]]", "participle", "adjective, noun",
        ]:
          qualparts.append(make_inline_modifier("pos", qual.replace("[[", "").replace("]]", "")))
          has_pos = True
        elif not has_g and qual in gender_map:
          if is_left:
            qualparts.append(make_inline_modifier("g", gender_map[qual]))
            has_g = True
          else:
            exterior_genders.append(gender_map[qual])
        else:
          seen_quals[qual] += 1
          non_converted_quals.append(qual)
      for qual in quals:
        convert_qual(qual)
      if labels:
        qualparts.append(make_inline_modifier("l" if is_left else "ll", ",".join(labels)))
      if non_converted_quals:
        qualparts.append(make_inline_modifier("q" if is_left else "qq", ", ".join(non_converted_quals)))
      return "".join(qualparts)

    if left_qual:
      vals[0] += convert_quals(left_qual, True, "<pos:" in vals[0], "<g:" in vals[0])
    if right_qual:
      vals[-1] += convert_quals(right_qual, False, "<pos:" in vals[-1], "<g:" in vals[-1])
    if exterior_genders:
      if "<g:" in vals[-1]:
        pagemsg("WARNING: Saw both interior and exterior genders, trying to combine")
        vals[-1] = re.sub("(<g:.*?)>", r"\1,%s>" % escape_inline_val(",".join(exterior_genders)), vals[-1])
      else:
        vals[-1] += make_inline_modifier("g", ",".join(exterior_genders))
    if right_gloss:
      if "<t:" in vals[-1]:
        pagemsg("WARNING: Saw both interior and exterior glosses, trying to combine")
        vals[-1] = re.sub("(<t:.*?)>", r"\1; %s>" % escape_inline_val("; ".join(right_gloss)), vals[-1])
      else:
        vals[-1] += make_inline_modifier("t", "; ".join(right_gloss))
    return ",".join(vals) + line_comment

  def convert_one_line(line):
    this_notes = []
    if re.search(r"^%s|\[\[" % match_link_template_re, line):
      template_or_raw_link_split_re = (
        r"""(%s(?:[^{}]|\{\{[^{}]*\}\})*\}\}|\[\[[^\[\]]+\]\])""" % match_link_template_re
      )
      line_parts = re.split(template_or_raw_link_split_re, line)
      for i in range(0, len(line_parts), 2):
        # The delimiter must either be a comma, slash or the word "or", or an empty string at the beginning or end of
        # the line; otherwise, don't do any conversion.
        if not (re.search(r"^\s*([,/]|or)\s*$", line_parts[i]) or (i == 0 or i == len(line_parts) - 1) and
                not line_parts[i].strip()):
          return "Unrecognized separator <%s> in line" % line_parts[i], []
      else: # no break
        els = []
        has_pos = False
        for i in range(1, len(line_parts), 2):
          if line_parts[i].startswith("[["):
            els.append(simplify_link(line_parts[i], None, None, langcode, langname, pagemsg, expand_text))
            continue
          linkt = list(blib.parse_text(line_parts[i]).filter_templates())[0]
          def getp(param):
            return getparam(linkt, param).strip()
          parts = []
          def app(val):
            parts.append(val)
          link_langcode = getp("1")
          link = getp("2")
          display = getp("3")
          alt = getp("alt")
          if display and alt:
            pagemsg("WARNING: Found both 3=%s and alt=%s; this should be triggering a Lua error: %s" % (
              display, alt, str(linkt)))
          alt = alt or display
          link = simplify_link(link, alt, link_langcode, langcode, langname, pagemsg, expand_text)
          app(link)
          gloss = getp("t") or getp("gloss") or getp("4")
          if gloss:
            app(make_inline_modifier("t", gloss))
          def append_if(param):
            val = getp(param)
            if val:
              if param == "tr" and val == "-" and link_langcode == "el":
                this_notes.append("remove tr=- from Modern Greek link")
              else:
                app(make_inline_modifier(param, val))
          append_if("tr")
          append_if("ts")
          append_if("sc")
          append_if("pos")
          append_if("lit")
          append_if("id")
          genders = blib.fetch_param_chain(linkt, "g")
          if genders:
            app(make_inline_modifier("g", ",".join(genders)))
          els.append("".join(parts))
        return els, this_notes
    else:
      return None, []

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

      if args.do_col and re.search(r"\{\{ *col[0-9]* *\|", subsections[k]):
        parsed = blib.parse_text(subsections[k])
        for t in parsed.filter_templates():
          tn = tname(t)
          if tn in ["col", "col1", "col2", "col3", "col4", "col5", "col6"]:
            newparams = []
            numrows = 0
            numchangedrows = 0
            origt = str(t)
            tlang = getparam(t, "1").strip()
            for param in t.params:
              pn = pname(param)
              pv = str(param.value)
              if pn != "1" and re.search("^[0-9]+$", pn):
                numrows += 1
                m = re.search(r"(\s*)(.*?)(\s*)$", pv, re.S)
                beginspace, maintext, endspace = m.groups()
                newmaintext, left_qual, right_qual, exterior_genders, right_gloss, line_comment = (
                  extract_left_and_right_qualifiers_and_genders(maintext))
                newparts, new_notes = convert_one_line(newmaintext)
                if type(newparts) is str:
                  pagemsg("WARNING: %s, not changing: %s" % (newparts, pv.strip()))
                elif newparts is not None:
                  newmaintext = construct_line_with_quals(
                    newparts, left_qual, right_qual, exterior_genders, right_gloss, line_comment)
                  newpv = beginspace + newmaintext + endspace
                  numchangedrows += 1
                  pagemsg("Replaced %s=<%s> with <%s> in {{%s|%s}} in ==%s==" % (
                    pn, pv.strip(), newpv.strip(), tn, tlang, header.strip()))
                  pv = newpv
                  notes.extend(new_notes)
              newparams.append((pn, pv, param.showkey))
            del t.params[:]
            for pn, pv, showkey in newparams:
              t.add(pn, pv, showkey=showkey, preserve_spacing=False)
            if origt != str(t):
              notes.append("optimize %s of %s row%s in {{%s|%s}} in ==%s==" % (
                numchangedrows, numrows, "s" if numrows != 1 else "", tn, tlang, header.strip()))
        subsections[k] = str(parsed)

      expected_abbrev = header_to_col_top_abbrev.get(header, None)
      lines = subsections[k].split("\n")
      newlines = []
      in_col_top = False
      col_top_tn = None
      col_elements = None
      new_notes = []
      raw_col_lines = None
      cant_convert = False
      col_top_header = None
      for line in lines:
        if in_col_top:
          raw_col_lines.append(line)
          m = re.search("^\{\{ *((?:col-)?bottom) *\|", line.strip())
          if m:
            if not cant_convert:
              pagemsg("WARNING: Saw {{%s}} with params, can't convert to {{col}}: %s" % (m.group(1), origline))
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
            newlines.append("{{col|%s%s" % (
              langcode, "|title=%s" % col_top_header if col_top_header else ""
            ))
            newlines.extend(col_elements)
            newlines.append("}}")
            notes.extend(new_notes)
            notes.append("convert {{%s}}/{{%s}} to {{col|%s|...}} with %s line%s" % (
              col_top_tn, col_bottom_tn, langcode, len(col_elements), "" if len(col_elements) == 1 else "s"))
            in_col_top = False
            continue
          if cant_convert:
            continue
          if not line.startswith("*"):
            pagemsg("WARNING: Non-bulleted line, can't convert to {{col}} (yet?): %s" % line)
            cant_convert = True
            continue
          if re.search(r"\{\{ *desc *\|", line):
            pagemsg("WARNING: Line with {{desc}}, can't convert to {{col}}: %s" % line)
            cant_convert = True
            continue
          m = re.search(r"^(\*+)(.*)$", line)
          if not m:
            pagemsg("WARNING: Internal error: Line doesn't have a term after a single bullet: %s" % line)
            cant_convert = True
            continue
          origline = line
          number_of_bullets, line = m.groups()
          if re.search("^[:#]", line):
            pagemsg("WARNING: Saw *: or *# at beginning of line, can't convert to {{col}}: %s" % origline)
            cant_convert = True
            continue
          if len(number_of_bullets) == 1:
            bullet_prefix = ""
          else:
            bullet_prefix = number_of_bullets[1:] + " "
          line = line.strip()
          bulleted_line = bullet_prefix + line
          if re.search(r"\{\{ *(ja-l|ja-r|ja-r/args|ryu-l|ryu-r|ryu-r/args|ko-l|zh-l|vi-l|he-l) *\|", line):
            pagemsg("WARNING: Unable to convert Asian specialized linking template to {{col}} format, inserting raw: %s" % origline)
            col_elements.append("|%s" % bulleted_line)
            continue

          def handle_parse_error(reason):
            nonlocal cant_convert
            if re.search(match_link_template_re, line):
              pagemsg("WARNING: %s and line has templated link, inserting raw: %s" % (reason, origline))
              col_elements.append("|%s" % bulleted_line)
            else:
              pagemsg("WARNING: %s and no templated link present, can't convert to {{col}}: %s" % (reason, origline))
              cant_convert = True

          line, left_qual, right_qual, exterior_genders, right_gloss, line_comment = (
            extract_left_and_right_qualifiers_and_genders(line))
          els, this_new_notes = convert_one_line(line)
          if type(els) is str:
            handle_parse_error(els)
          elif els is None:
            handle_parse_error("Can't parse links")
          else:
            newline = "|%s%s" % (bullet_prefix, construct_line_with_quals(
              els, left_qual, right_qual, exterior_genders, right_gloss, line_comment))
            col_elements.append(newline)
            new_notes.extend(this_new_notes)

        else:
          m = None
          if not m and args.do_col_top:
            m = re.search(r"^\{\{(col-top)\|[0-9]+\|([^|=]*)\}\}$", line)
            if m:
              col_top_tn, col_top_header = m.groups()
          if not m and args.do_top:
            m = re.search(r"^\{\{(top[0-9])\}\}$", line)
            if m:
              col_top_tn = m.group(1)
              col_top_header = ""
          if not m and args.do_top:
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
            new_notes = []
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
parser.add_argument("--do-top", action="store_true", help="Do {{top2}} through {{top6}}.")
parser.add_argument("--do-col-top", action="store_true", help="Do {{col-top}}.")
parser.add_argument("--do-col", action="store_true", help="Do {{col}} and {{col1}} through {{col6}}.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(
  args, start, end, process_text_on_page, edit=True, stdin=True)

msg("")
msg("%-50s | %s" % ("Qualifier", "Count"))
msg("-" * 58)
for qual, count in sorted(seen_quals.items(), key=lambda x: -x[1]):
  msg("%-50s = %s" % (qual, count))
