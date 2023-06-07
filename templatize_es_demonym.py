#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

placetypes = [
  "city",
  "town",
  "municipality",
  "district",
  "state",
  "province",
  "canton",
  "department",
  "region",
  "island",
  "nation",
]
placetype_re = "(?:%s)" % "|".join(placetypes)

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  notes = []
  origtext = text

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Spanish", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  sectail_is_demonym = re.search(r"\{\{(C|c|top|topic|topics|catlangcode)\|es(\|[^{}=|]*)*\|Demonyms([|}])", sectail)

  rawest_toponym_to_marked_up = {}
  need_to_remove_cat = [False]

  for k in xrange(2, len(subsections), 2):
    def raw_toponym_to_toponym(raw_toponym):
      toponym = None
      rawest_toponym = None
      dont_add = False
      dont_append_country = False

      placetype = ""
      mm = re.search(ur"^the (%s(?: (?:and|or) %s)*) of (.*?)$" % (placetype_re, placetype_re), raw_toponym)
      if mm:
        placetype, raw_toponym = mm.groups()
        placetype = "<qq:%s>" % placetype

      country_or_state = ""
      toponym_word_re = u"(?:[A-ZÁÉÍÓÚÝÑ][a-záéíóúýñ]*|de)"
      toponym_re = "%s(?: %s)*" % (toponym_word_re, toponym_word_re)
      possibly_bracketed_toponym_re = r"(?:%s|\[\[%s\]\])" % (toponym_re, toponym_re)
      toponym_and_country_state_re = r"^(.*?)(?:,| in) (%s(?:, %s)*)$" % (possibly_bracketed_toponym_re, possibly_bracketed_toponym_re)
      mm = re.search(toponym_and_country_state_re, raw_toponym)
      if mm:
        raw_toponym, country_or_state = mm.groups()
        country_or_state_parts = country_or_state.split(", ")
        def bracket_if_not_already(part):
          if part.startswith("[["):
            return part
          return "[[%s]]" % part
        country_or_state = ", " + ", ".join(bracket_if_not_already(part) for part in country_or_state_parts)

      def generate_wikilink(wikilang, link, display):
        if link == display:
          if country_or_state:
            if wikilang:
              toponym = "{{lw|%s|%s}}" % (wikilang, link)
            else:
              toponym = "{{w|%s}}" % link
          else:
            if wikilang:
              toponym = "w:%s:%s" % (wikilang, link)
            else:
              toponym = "w:%s" % link
        else:
          if wikilang:
            toponym = "[[w:%s:%s|%s]]" % (wikilang, link, display)
          else:
            toponym = "[[w:%s|%s]]" % (link, display)
        return toponym

      if not toponym:
        if re.search(r"^\{\{w\|[^{}]*\}\}$", raw_toponym):
          parsed_wikilink = blib.parse_text(raw_toponym)
          linkt = list(parsed_wikilink.filter_templates())[0]
          link = getparam(linkt, "1")
          display = getparam(linkt, "2") or link
          wikilang = getparam(linkt, "lang")
          for param in linkt.params:
            pn = pname(param)
            if pn not in ["1", "2", "lang"]:
              pagemsg("WARNING: Can't parse Wikipedia link, unrecognized param %s=%s: %s"
                % unicode(pn, unicode(param.value), linkt))
              return None
          rawest_toponym = display
          toponym = generate_wikilink(wikilang, link, display)

      if not toponym:
        mm = re.search(r"^\{\{l\|([^\[\]|={}]*)\|([^{}|=]*)\}\}$", raw_toponym)
        if mm:
          lang, link = mm.groups()
          rawest_toponym = link
          if country_or_state:
            toponym = raw_toponym
          else:
            toponym = "%s:%s" % (lang, link)

      if not toponym:
        mm = re.search(r"^\[\[[wW]:([^\[\]|={}]*)\|([^\[\]|={}]*)\]\]$", raw_toponym)
        if mm:
          link, display = mm.groups()
          rawest_toponym = display
          mmm = re.search("^([a-zA-Z0-9_-]+):(.*)$", link)
          if mmm:
            wikilang, link = mmm.groups()
          else:
            wikilang = None
          toponym = generate_wikilink(wikilang, link, display)

      if not toponym:
        mm = re.search(r"^\[\[([^\[\]|={}]*)\]\]$", raw_toponym)
        if mm:
          rawest_toponym = mm.group(1)
          toponym = raw_toponym

      if not toponym:
        mm = re.search(ur"^\[*%s\]*$" % toponym_re, raw_toponym)
        if mm:
          rawest_toponym = raw_toponym
          dont_add = True
          toponym_to_look_up = raw_toponym + country_or_state
          if toponym_to_look_up in rawest_toponym_to_marked_up:
            toponym = rawest_toponym_to_marked_up[toponym_to_look_up]
            dont_append_country = True
          else:
            toponym = raw_toponym
            if country_or_state:
              toponym = "[[%s]]" % toponym

      if not toponym:
        return None

      if not dont_append_country:
        toponym += country_or_state

      toponym = blib.remove_redundant_links(toponym)

      def add_markup(rawest_toponym, toponym):
        if toponym != rawest_toponym:
          if rawest_toponym in rawest_toponym_to_marked_up:
            marked_up = rawest_toponym_to_marked_up[rawest_toponym]
            if marked_up != toponym:
              if len(marked_up) < len(toponym):
                pagemsg("WARNING: Saw two different possible markups for raw toponym '%s': existing %s and new %s; using new because it's longer"
                  % (rawest_toponym, marked_up, toponym))
                rawest_toponym_to_marked_up[rawest_toponym] = toponym
              else:
                pagemsg("WARNING: Saw two different possible markups for raw toponym '%s': existing %s and new %s; keeping existing because it's longer"
                  % (rawest_toponym, marked_up, toponym))
          else:
            rawest_toponym_to_marked_up[rawest_toponym] = toponym

      if not dont_add:
        add_markup(rawest_toponym, toponym)
        if country_or_state:
          add_markup(rawest_toponym + country_or_state, toponym)

      return toponym + placetype

    of_or_from_re = "(?:of or from|(?:of|from) or (?:relating|related|pertaining) to|of, from or (?:relating|related|pertaining) to|of|from)"
    gloss_qual_re = "(?:gl|gloss|q|i|qual|qualifier)"

    if "==Adjective==" in subsections[k - 1] and sectail_is_demonym:

      def replace_of(m):
        gloss = ""
        raw_toponym = m.group(1)
        mm = re.search(r"^(.*) \{\{(?:gl|gloss|q|i|qual|qualifier)\|([^{}]*)\}\}$", raw_toponym)
        if mm:
          raw_toponym, gloss = mm.groups()
          gloss = "<t:%s>" % gloss
        raw_demonym = ""
        mm = re.search(r"^(.*); \[\[([^\[\]|={}]+)\]\]$", raw_toponym)
        if mm:
          raw_toponym, raw_demonym = mm.groups()
          raw_demonym = "|t=%s" % raw_demonym
        toponym = raw_toponym_to_toponym(raw_toponym)
        if not toponym:
          pagemsg("WARNING: Unable to parse raw toponym: %s" % raw_toponym)
          return m.group(0)
        notes.append("templatize raw demonym adjective definition for Spanish toponym '%s'" % raw_toponym)
        need_to_remove_cat[0] = True
        return "# {{demonym-adj|es|%s%s%s}}" % (toponym, gloss, raw_demonym)

      subsections[k] = re.sub(r"^# *(?:\{\{lb\|es\|relational\}\} *)?%s (.*)$" % of_or_from_re, replace_of, subsections[k], 0, re.M)

      def replace_of_with_raw_demonym(m):
        raw_demonym, raw_toponym = m.groups()
        toponym = raw_toponym_to_toponym(raw_toponym)
        if not toponym:
          pagemsg("WARNING: Unable to parse raw toponym: %s" % raw_toponym)
          return m.group(0)
        notes.append("templatize raw demonym adjective definition for Spanish toponym '%s' with demonym gloss '%s'"
          % (raw_toponym, raw_demonym))
        need_to_remove_cat[0] = True
        return "# {{demonym-adj|es|%s|t=%s}}" % (toponym, raw_demonym)

      subsections[k] = re.sub(r"^# *\[\[([^\[\]|={}]+)\]\] \{\{%s\|%s (.*)\}\}$" % (gloss_qual_re, of_or_from_re),
        replace_of_with_raw_demonym, subsections[k], 0, re.M)

    if "==Noun==" in subsections[k - 1]:
      demonym_gender = None
      parsed = blib.parse_text(subsections[k])
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "es-noun":
          g = blib.fetch_param_chain(t, "1", "g")
          if g in [["m"], ["f"]]:
            demonym_gender = g[0]
          elif g in [["mf"], ["mfbysense"], ["m", "f"]]:
            demonym_gender = ""
          elif g not in [["m-p"], ["f-p"], ["mf-p"], ["mfbysense-p"], ["mfequiv"]]:
            pagemsg("WARNING: Unable to determine demonym gender from headword template: %s" % unicode(t))
          break
      if demonym_gender is not None:
        someone_from_re = "(?:(?:someone|(?:a )?person) from|(?:an? )?(?:native or )?(?:resident|inhabitant) (?:of|from))"
        def replace_someone_from(m, demonym_gender):
          raw_toponym = m.group(1)
          toponym = raw_toponym_to_toponym(raw_toponym)
          if not toponym:
            pagemsg("WARNING: Unable to parse raw toponym: %s" % raw_toponym)
            return m.group(0)
          notes.append("templatize raw demonym noun definition for Spanish toponym '%s'" % raw_toponym)
          if demonym_gender:
            demonym_gender = "|g=%s" % demonym_gender
          need_to_remove_cat[0] = True
          return "# {{demonym-noun|es|%s%s}}" % (toponym, demonym_gender)

        subsections[k] = re.sub(r"^# *%s (.*)$" % someone_from_re,
          lambda m: replace_someone_from(m, demonym_gender), subsections[k], 0, re.M)

        def replace_native_or_resident_with_raw_demonym(m, demonym_gender):
          raw_demonym, raw_toponym = m.groups()
          toponym = raw_toponym_to_toponym(raw_toponym)
          if not toponym:
            pagemsg("WARNING: Unable to parse raw toponym: %s" % raw_toponym)
            return m.group(0)
          notes.append("templatize raw demonym noun definition for Spanish toponym '%s' with demonym gloss '%s'"
            % (raw_toponym, raw_demonym))
          if demonym_gender:
            demonym_gender = "|g=%s" % demonym_gender
          need_to_remove_cat[0] = True
          return "# {{demonym-noun|es|%s%s|t=%s}}" % (toponym, demonym_gender, raw_demonym)

        subsections[k] = re.sub(r"^# *\[\[([^\[\]|={}]+)\]\] \{\{%s\|%s (.*)\}\}$" % (gloss_qual_re, someone_from_re),
          lambda m: replace_native_or_resident_with_raw_demonym(m, demonym_gender), subsections[k], 0, re.M)

  if sectail_is_demonym and need_to_remove_cat[0]:
    # ensure same number of newlines (1 or 2) at end of sectail after removing category
    m = re.search(r"\A(.*?)(\n*)\Z", sectail, re.S)
    sectail, sectail_finalnl = m.groups()
    newsectail = re.sub(r"\{\{(C|c|top|topic|topics|catlangcode)\|es\|Demonyms\}\}", "", sectail)
    if newsectail != sectail:
      notes.append("remove manually-specified {{C|es|Demonyms}} cat")
      sectail = newsectail
    newsectail = re.sub(r"(\{\{(?:C|c|top|topic|topics|catlangcode)\|es(?:\|[^{}=|]*)?)\|Demonyms([|}])", r"\1\2", sectail)
    if newsectail != sectail:
      notes.append("remove manually-specified 'Demonyms' cat from {{C|es|...}}")
      sectail = newsectail
    sectail = sectail.rstrip("\n") + sectail_finalnl

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)

  # need to condense 3+ newlines that may have been created when removing {{C|es|Demonyms}}; doing it this way is the
  # easiest way of ensuring that the syntax stays correct when removing categories
  text = re.sub(r"\n\n+", "\n\n", text)
  if text != origtext and not notes:
    notes.append("condense 3+ newlines")
  return text, notes

parser = blib.create_argparser("Templatize Spanish demonyms", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Italian' and has no ==Italian== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
