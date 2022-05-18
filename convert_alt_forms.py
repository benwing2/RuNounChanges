#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_text_in_section(sectext, pagemsg):
  notes = []

  retval = blib.find_modifiable_lang_section(sectext, None, pagemsg)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split(r"(^===+[^=\n]+===+[ \t]*\n)", secbody, 0, re.M)
  for k in xrange(1, len(subsections), 2):
    if re.search(r"==\s*Alternative forms\s*==", subsections[k]):
      subsectext = subsections[k + 1]
      parsed = blib.parse_text(subsectext)
      for t in parsed.filter_templates():
        def getp(param):
          return getparam(t, param)
        tn = tname(t)
        if tn == "alter":
          lang = getparam(t, "1")
          blib.set_template_name(t, "alt")
          notes.append("rename {{alter|%s}} to {{alt|%s}}" % (lang, lang))
        if tn in ["l", "m"]:
          must_continue = False
          for param in t.params:
            pn = pname(param)
            pv = unicode(param.value)
            if (pn not in ["1", "2", "3", "4", "gloss", "id", "lit", "pos", "t", "tr", "ts", "sc"]
                and not re.search("^g[0-9]*$", pn)):
              pagemsg("WARNING: Unrecognized param %s=%s in %s" % (pn, pv, unicode(t)))
              must_continue = True
              break
          if must_continue:
            continue
          lang = getparam(t, "1")
          blib.set_template_name(t, "alt")
          def moveparam(fr, to):
            val = getp(fr)
            if val:
              t.add(to, val, before=fr)
            rmparam(t, fr)
          moveparam("3", "alt1")
          moveparam("alt", "alt1")
          moveparam("4", "t1")
          moveparam("t", "t1")
          moveparam("gloss", "t1")
          moveparam("tr", "tr1")
          moveparam("ts", "ts1")
          moveparam("sc", "sc1")
          moveparam("pos", "pos1")
          moveparam("lit", "lit1")
          moveparam("id", "id1")
          # Gather all genders
          genders = []
          first_gender_param = None
          for i in xrange(0, 30):
            if i == 0:
              pn = "g"
            else:
              pn = "g%s" % i
            val = getp(pn)
            if val:
              genders.append(val)
              if not first_gender_param:
                first_gender_param = pn
          # Add as name ggg1= in case first gender param is g1=
          if genders:
            # Hack
            t.add("ggg1", ",".join(genders), before=first_gender_param)
          # Remove all gender params
          for i in xrange(0, 30):
            if i == 0:
              pn = "g"
            else:
              pn = "g%s" % i
            rmparam(t, pn)
          # Move ggg1= to g1=
          ggg1 = getp("ggg1")
          if ggg1:
            t.add("g1", ggg1)
            rmparam(t, "ggg1")
          notes.append("convert {{%s|%s}} to {{alt|%s}}" % (tn, lang, lang))

      subsectext = unicode(parsed)

      could_parse = [False]

      def merge_alt(m):
        mergedt = list(blib.parse_text("{{alt|foo}}").filter_templates())[0]
        preceding_space, before, orig_altforms, after = m.groups()
        altforms = orig_altforms.strip()
        altforms = re.split(r"(\{\{alt\|(?:\{\{[^{}]*\}\}|[^{}]*)*\}\})", altforms)
        thislang = None
        index = 1
        qualifiers = []

        if before:
          mm = re.search(r"^\{\{(?:s|sense|q|i|qual|qualifier|qf|gloss|gl)\|(?:\{\{[^{}]*\}\}|[^{}]*)*\}\}$", before)
          if mm:
            qual = list(blib.parse_text(before).filter_templates())[0]
            qualifiers.extend(blib.fetch_param_chain(qual, "1"))
          else:
            mm = re.search(r"^''\((.*?)\)''$", before)
            if not mm:
              mm = re.search(r"^''(.*?)''$", before)
            if mm:
              raw_qual_parts = re.split(r"([^ ,](?:\{\{[^{}]*\}\}|[^{},]*)*)", before)
              for i in xrange(1, len(raw_qual_parts), 2):
                qualifiers.append(raw_qual_parts[i])
            else:
              pagemsg("Unrecognized before-portion on {{alt}} line: %s" % m.group(0))
              return m.group(0)

        for i in xrange(1, len(altforms), 2):
          altt = list(blib.parse_text(altforms[i]).filter_templates())[0]

          # Copy lang or verify it's same as previously observed
          lang = getparam(altt, "1")
          if i == 1:
            mergedt.add("1", lang)
            thislang = lang
          elif thislang != lang:
            pagemsg("WARNING: Saw different language %s on line from first language %s: %s" %
              (lang, thislang, m.group(0)))
            return m.group(0)

          # Copy terms, moving number of named params and finding maximum term index
          maxparam = 0
          saw_qualifier_gap = False
          for param in altt.params:
            pn = pname(param)
            pv = unicode(param.value)
            mm = re.search("(^[a-z]+)([0-9]*)$", pn)
            if mm:
              pbase = mm.group(1)
              pind = int(mm.group(2) or "1")
              maxparam = max(maxparam, pind)
              mergedt.add("%s%s" % (pbase, pind + index - 1), pv)
            elif pn == "1":
              pass
            elif re.search("^[0-9]+$", pn):
              if saw_qualifier_gap:
                qualifiers.append(pv)
              elif not pv:
                saw_qualifier_gap = True
              else:
                pind = int(pn) - 1
                maxparam = max(maxparam, pind)
                mergedt.add(str(pind + index), pv)
            else:
              pagemsg("WARNING: Unrecognized param %s=%s: %s" % (pn, pv, unicode(altt)))
              return m.group(0)
          index += maxparam

        if after:
          mm = re.search(r"^\{\{(?:sense|s|q|i|qual|qualifier|qf|gloss|gl)\|(?:\{\{[^{}]*\}\}|[^{}]*)*\}\}$", after)
          if mm:
            qual = list(blib.parse_text(after).filter_templates())[0]
            qualifiers.extend(blib.fetch_param_chain(qual, "1"))
          if not mm:
            mm = re.search(r"^\{\{lb\|%s\|(?:\{\{[^{}]*\}\}|[^{}]*)*\}\}$" % thislang, after)
            if mm:
              qual = list(blib.parse_text(after).filter_templates())[0]
              qualifiers.extend(blib.fetch_param_chain(qual, "2"))
          if not mm:
            mm = re.search(r"^''\((.*?)\)''$", after)
            if not mm:
              mm = re.search(r"^''(.*?)''$", after)
            if not mm:
              mm = re.search(r"^\((.*?)\)$", after)
            if mm:
              raw_qual_parts = re.split(r"([^ ,](?:\{\{[^{}]*\}\}|[^{},]*)*)", after)
              for i in xrange(1, len(raw_qual_parts), 2):
                qualifiers.append(raw_qual_parts[i])
            elif after in ["{{T-V}}", "{{TV}}", "{{T-V distinction}}"]:
              qualifiers.append("T-V")
            else:
              pagemsg("Unrecognized after-portion on {{alt}} line: %s" % m.group(0))
              return m.group(0)

        if qualifiers:
          index += 1
          mergedt.add(str(index), "")
          for qualifier in qualifiers:
            index += 1
            mergedt.add(str(index), qualifier)

        if len(altforms) > 3:
          notes.append("merge multiple {{alt|%s}} into one" % thislang)
        if before:
          notes.append("merge separate leading qualifiers into {{alt|%s}}" % thislang)
        if after:
          notes.append("merge separate trailing qualifiers into {{alt|%s}}" % thislang)
        if len(altforms) <= 3 and not after and orig_altforms != unicode(mergedt):
          if orig_altforms.strip() == unicode(mergedt):
            notes.append("remove trailing space in ==Alternative forms==")
          else:
            notes.append("clean up params in {{alt|%s}}" % thislang)
        if preceding_space != " ":
          notes.append("add missing space after * in ==Alternative forms==")
        could_parse[0] = True
        return "* " + unicode(mergedt)

      lines = subsectext.split("\n")
      for lineind, line in enumerate(lines):
        if not line:
          continue
        could_parse[0] = False
        newline = re.sub(r"^\*?(\s*)(.*?)\s*((?:\{\{alt\|(?:\{\{[^{}]*\}\}|[^{}]*)*\}\},*\s*)+)(.*?)$", merge_alt, line,
            0, re.UNICODE)
        if newline == line and not could_parse[0]:
          pagemsg("WARNING: Unable to parse ==Alternative forms== line: %s" % line)
        else:
          lines[lineind] = newline
      subsectext = "\n".join(lines)

      subsections[k + 1] = subsectext

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  sectext = "".join(sections)
  return sectext, notes


def process_text_on_page(index, pagetitle, text):
  m = re.search(r"\A(.*?)(\n*)\Z", text, re.S)
  text, text_finalnl = m.groups()
  text += "\n\n"

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  if args.partial_page:
    if re.search("^==[^\n=]*==$", text, re.M):
      pagemsg("WARNING: --partial-page specified but saw an L2 header, skipping")
      return
    newtext, notes = process_text_in_section(text, pagemsg)
    return newtext.rstrip("\n") + text_finalnl, notes

  notes = []
  sections = re.split("(^==[^\n=]*==[ \t]*\n)", text, 0, re.M)

  # Correct extraneous spaces in L2 headers and prepare for sorting by language.
  sections_for_sorting = []
  for j in xrange(2, len(sections), 2):
    newsection, this_notes = check_for_bad_subsections(sections[j], pagemsg)
    sections[j] = newsection
    notes.extend(this_notes)
  return "".join(sections).rstrip("\n") + text_finalnl, notes


parser = blib.create_argparser("Convert {{l}}/{{alter}} etc. in ==Alternative forms== sections to {{alt}}",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
