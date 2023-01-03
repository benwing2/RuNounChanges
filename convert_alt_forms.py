#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

change_alter_to_alt = True

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
      # Don't recurse into templates or we will change {{m}} to {{alt}} inside a param
      for t in parsed.filter_templates(recursive=False):
        def getp(param):
          return getparam(t, param)
        tn = tname(t)
        if tn == "alter" and change_alter_to_alt:
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

      def split_on_comma_not_in_template(txt):
        retval = []
        parts = re.split(r"((?:\{\{[^{}]*\}\}|[^{},])*)", txt)
        parts = [x.strip() for x in parts]
        for i in xrange(1, len(parts), 2):
          retval.append(parts[i])
        return retval

      def merge_alt(m, could_parse):
        mergedt = None
        altt_name = "alt"
        origline = m.group(0)
        preceding_space, before, orig_altforms, after = m.groups()
        altforms = orig_altforms.strip()
        altforms = re.split(r"(\{\{(?:alt|alter)\|(?:\{\{[^{}]*\}\}|[^{}])*\}\})", altforms)
        thislang = None
        index = 1
        alt_qualifiers = []
        before_qualifiers = []
        after_qualifiers = []

        def extract_qualifiers_from_before_after(text_to_parse, lang):
          returned_qualifiers = []
          mm = re.search(r"^\{\{(?:sense|s|q|i|qual|qualifier|qf|gloss|gl)\|(?:\{\{[^{}]*\}\}|[^{}])*\}\}$", text_to_parse)
          if mm:
            qual = list(blib.parse_text(text_to_parse).filter_templates())[0]
            returned_qualifiers.extend(blib.fetch_param_chain(qual, "1"))
          if not mm:
            mm = re.search(r"^\{\{lb\|%s\|(?:\{\{[^{}]*\}\}|[^{}])*\}\}$" % thislang, text_to_parse)
            if mm:
              qual = list(blib.parse_text(text_to_parse).filter_templates())[0]
              returned_qualifiers.extend(blib.fetch_param_chain(qual, "2"))
          if not mm:
            mm = re.search(r"^''\((.*?)\)''$", text_to_parse)
            if not mm:
              mm = re.search(r"^\(''(.*?)''\)$", text_to_parse)
            if not mm:
              mm = re.search(r"^''(.*?)''$", text_to_parse)
            if not mm:
              mm = re.search(r"^\((.*?)\)$", text_to_parse)
            if mm:
              returned_qualifiers.extend(split_on_comma_not_in_template(mm.group(1)))
            elif text_to_parse in ["{{T-V}}", "{{TV}}", "{{T-V distinction}}"]:
              returned_qualifiers.append("T-V")
            else:
              return None
          return returned_qualifiers

        for i in xrange(1, len(altforms), 2):
          altt = list(blib.parse_text(altforms[i]).filter_templates())[0]

          # Copy lang or verify it's same as previously observed
          lang = getparam(altt, "1")
          if i == 1:
            altt_name = tname(altt)
            mergedt = list(blib.parse_text("{{%s|foo}}" % altt_name).filter_templates())[0]
            mergedt.add("1", lang)
            thislang = lang
          elif thislang != lang:
            pagemsg("WARNING: Saw different language %s on line from first language %s: %s" %
              (lang, thislang, origline))
            return origline

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
              paramno = pind + index - 1
              mergedt.add("%s%s" % (pbase, "" if paramno == 1 else paramno), pv)
            elif pn == "1":
              pass
            elif re.search("^[0-9]+$", pn):
              if saw_qualifier_gap:
                alt_qualifiers.append(pv)
              elif not pv:
                saw_qualifier_gap = True
              else:
                pind = int(pn) - 1
                maxparam = max(maxparam, pind)
                mergedt.add(str(pind + index), pv)
            else:
              pagemsg("WARNING: Unrecognized param %s=%s: %s" % (pn, pv, unicode(altt)))
              return origline
          index += maxparam

        if before:
          before_qualifiers = extract_qualifiers_from_before_after(before, thislang)
          if before_qualifiers is None:
            pagemsg("Unrecognized before-portion '%s' on {{%s}} line: %s" % (before, altt_name, origline))
            return origline

        if after:
          after_qualifiers = extract_qualifiers_from_before_after(after, thislang)
          if after_qualifiers is None:
            pagemsg("Unrecognized after-portion '%s' on {{%s}} line: %s" % (after, altt_name, origline))
            return origline

        qualifiers = before_qualifiers + alt_qualifiers + after_qualifiers
        if qualifiers:
          index += 1
          mergedt.add(str(index), "")
          for qualifier in qualifiers:
            index += 1
            mergedt.add(str(index), qualifier)

        if len(altforms) > 3:
          notes.append("merge multiple {{%s|%s}} into one" % (altt_name, thislang))
        if before:
          notes.append("merge separate leading qualifiers into {{%s|%s}}" % (altt_name, thislang))
        if after:
          notes.append("merge separate trailing qualifiers into {{%s|%s}}" % (altt_name, thislang))
        if len(altforms) <= 3 and not after and orig_altforms != unicode(mergedt):
          if orig_altforms.strip() == unicode(mergedt):
            notes.append("remove trailing space in ==Alternative forms==")
          else:
            notes.append("clean up params in {{%s|%s}}" % (altt_name, thislang))
        if preceding_space != " ":
          notes.append("add missing space after * in ==Alternative forms==")
        could_parse[0] = True
        if mergedt is None:
          pagemsg("WARNING: Internal error: Didn't find any {{alt}}/{{alter}} templates in line: %s" %
              origline)
          return origline
        return "* " + unicode(mergedt)

      lines = subsectext.split("\n")

      def merge_alts_in_line(line):
        could_parse = [False]
        def do_merge_alt(m):
          return merge_alt(m, could_parse)
        could_parse[0] = False
        line = re.sub(r"^\*?(\s*)(.*?):*\s*((?:\{\{(?:alt|alter)\|(?:\{\{[^{}]*\}\}|[^{}])*\}\},*\s*)+):*\s*(.*?)$", do_merge_alt,
            line, 0, re.UNICODE)
        return line, could_parse[0]

      for lineind, line in enumerate(lines):
        if not line:
          continue

        def warning(txt):
          pagemsg("Line %s: WARNING: %s" % (lineind + 1, txt))

        newline, could_parse = merge_alts_in_line(line)
        if newline == line and not could_parse:
          # Unable to parse; try splitting on comma and parsing as multiple separate lines
          line_parts = split_on_comma_not_in_template(line)
          if len(line_parts) == 1:
            warning("Unable to parse ==Alternative forms== line: %s" % line)
          elif len(line_parts) < 1:
            pagemsg("Internal error: split_on_comma_not_in_template() returned an empty list: %s" % line)
          else:
            for partno, line_part in enumerate(line_parts):
              if partno > 0:
                line_part = "* " + line_part
              new_line_part, could_parse = merge_alts_in_line(line_part)
              if new_line_part == line_part and not could_parse:
                warning("Part %s: Unable to parse ==Alternative forms== line part: %s" % (partno + 1, line_part))
                break
              line_parts[partno] = new_line_part
            else: # no break
              lines[lineind] = "\n".join(line_parts)
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
