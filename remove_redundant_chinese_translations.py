#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

blib.getData()

translation_templates = ["t", "t+", "tt", "tt+", "t-needed", "t-check", "t+check"]

lects_to_remove_redundant_translations = {
  "cdo",
  "cjy",
  "cmn",
  "cpx",
  "czh",
  "czo",
  "dng",
  "gan",
  "hak",
  "hsn",
  "mnp",
  "nan",
  "wuu",
  "wxa",
  "yue",
  "zhx-sht",
  "zhx-tai",
  "zhx-teo",
}

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def convert_traditional_to_simplified(langcode, trad):
    trad_simp = expand_text("{{#invoke:User:Benwing2/languages/utilities|generateForms|%s|%s}}" % (langcode, trad))
    if not trad_simp:
      return trad_simp
    if "||" in trad_simp:
      trad, simp = trad_simp.split("||", 1)
      return simp
    else:
      return trad_simp

  notes = []

  if not re.search(r"^\* *Chinese:*", text, re.M):
    return

  subsections = re.split(r"(^\s*==+[^=\n]+==+\s*\n)", text, 0, re.M)

  for k in range(2, len(subsections), 2):
    if re.search(r"==\s*Translations\s*==", subsections[k - 1]):
      lines = subsections[k].split("\n")
      in_chinese = False
      for j, line in enumerate(lines):
        def line_pagemsg(txt):
          msg("Page %s %s: %s: <from> %s <to> %s <end>" % (index, pagetitle, txt, line, line))
        if re.search(r"^\* *Chinese:* *[^: ]", line):
          line_pagemsg("WARNING: Chinese: line with junk after it")
          in_chinese = True
        elif re.search(r"^\* *Chinese:* *$", line):
          in_chinese = True
        elif re.search(r"^\*:", line) and in_chinese:
          m = re.search(r"^\*: *(.*?): *(.*)$", line)
          if not m:
            line_pagemsg("WARNING: Saw unrecognized line in Chinese section")
          else:
            lect, translations = m.groups()
            parsed = blib.parse_text(line)
            for t in parsed.filter_templates():
              tn = tname(t)
              if tn in translation_templates:
                sc = getparam(t, "sc")
                if sc:
                  line_pagemsg("Remove unnecessary sc=%s from %s" % (sc, str(t)))
                  rmparam(t, "sc")
                  notes.append("remove sc=%s from Chinese translation template" % sc)
                lang = getparam(t, "1")
                if lang == "zh":
                  if lect not in blib.languages_byCanonicalName:
                    line_pagemsg("WARNING: Unrecognized Chinese lect %s" % lect)
                  else:
                    langnamecode = blib.languages_byCanonicalName[lect]["code"]
                    t.add("1", langnamecode)
                    notes.append("convert 'zh' to '%s' for %s translation template {{%s}}" % (langnamecode, lect, tn))

            line = str(parsed)
            lines[j] = line

            if lect not in blib.languages_byCanonicalName:
              line_pagemsg("WARNING: Unrecognized Chinese lect %s" % lect)
              continue
            lectcode = blib.languages_byCanonicalName[lect]["code"]

            if lectcode not in lects_to_remove_redundant_translations:
              line_pagemsg("Skipping lect %s (%s) not using automatic simplification" % (lect, lectcode))
              continue

            parsed = blib.parse_text(line)
            must_continue = False
            prevt = None
            text_to_remove = []
            this_notes = []

            def combine_traditional_simplified(tradt, simpt, reversed=False):
              warnings = []
              def append_line_pagemsg(txt):
                warnings.append("Page %s %s: %s: <from> %s <to> %s <end>" % (index, pagetitle, txt, line, line))
              get = getparam
              lang = get(simpt, "1")
              if lang == "zh":
                append_line_pagemsg("WARNING: Internal error: Unconverted 'zh' in Chinese translation template %s" % str(simpt))
                return False, warnings
              if lang != lectcode:
                append_line_pagemsg("WARNING: Strange language in %s translation template %s" % (lect, str(simpt)))
                return False, warnings
              trad = get(tradt, "2")
              simp = get(simpt, "2")
              trad_to_simp = convert_traditional_to_simplified(lectcode, trad)
              if trad_to_simp == simp:
                if tname(tradt) != tname(simpt):
                  append_line_pagemsg("Traditional translation template %s and corresponding simplified translation template %s have different template names, will still combine"
                    % (str(tradt), str(simpt)))
                simp_alt = get(simpt, "alt")
                simp_tr = get(simpt, "tr")
                simp_lit = get(simpt, "lit")
                for param in simpt.params:
                  pn = pname(param)
                  pv = str(param.value)
                  if pn not in ["1", "2", "3", "tr", "alt", "sc", "lit"]:
                    append_line_pagemsg("WARNING: Unrecognized parameter %s=%s in simplified translation template %s, can't combine"
                      % (pn, pv, str(simpt)))
                    return False, warnings
                  if pn == "3" and pv:
                    append_line_pagemsg("WARNING: Gender %s=%s specified in simplified translation template %s, can't combine"
                      % (pn, pv, str(simpt)))
                    return False, warnings
                else: # no break
                  for param in tradt.params:
                    pn = pname(param)
                    pv = str(param.value)
                    if pn not in ["1", "2", "3", "tr", "alt", "sc", "lit"]:
                      append_line_pagemsg("WARNING: Unrecognized parameter %s=%s in traditional translation template %s, can't combine"
                        % (pn, pv, str(tradt)))
                      return False, warnings
                    if pn == "3" and pv:
                      append_line_pagemsg("WARNING: Gender %s=%s specified in simplified translation template %s, can't combine"
                        % (pn, pv, str(simpt)))
                      return False, warnings
                  else: # no break
                    trad_tr = get(tradt, "tr")
                    if trad_tr and not simp_tr:
                      pass # leave traditional tr= alone
                    elif trad_tr and trad_tr != simp_tr:
                      append_line_pagemsg("WARNING: Saw transliteration parameter '%s' in traditional translation template %s different from simplified transliteration '%s', can't combine"
                        % (trad_tr, str(tradt), simp_tr))
                      return False, warnings
                    trad_lit = get(tradt, "lit")
                    if trad_lit and not simp_lit:
                      pass # leave traditional lit= alone
                    elif trad_lit and trad_lit != simp_lit:
                      append_line_pagemsg("WARNING: Saw literal parameter '%s' in traditional translation template %s different from simplified literal '%s', can't combine"
                        % (trad_lit, str(tradt), simp_lit))
                      return False, warnings
                    trad_alt = get(tradt, "alt")
                    if trad_alt and not simp_alt:
                      append_line_pagemsg("WARNING: Traditional translation template %s has alt= but corresponding simplified template %s doesn't, can't combine"
                        % (str(tradt), str(simpt)))
                      return False, warnings
                    if not trad_alt and simp_alt:
                      append_line_pagemsg("WARNING: Traditional translation template %s doesn't have alt= but corresponding simplified template %s does, can't combine"
                        % (str(tradt), str(simpt)))
                      return False, warnings
                    if trad_alt and simp_alt:
                      auto_simp_alt = convert_traditional_to_simplified(lectcode, trad_alt)
                      if auto_simp_alt != simp_alt:
                        append_line_pagemsg("WARNING: Traditional translation template %s has alt= which converts to %s != %s from corresponding simplified template %s, can't combine"
                          % (str(tradt), auto_simp_alt, simp_alt, str(simpt)))
                        return False, warnings
                    if tradt.has("3"):
                      if get(tradt, "3"):
                        append_line_pagemsg("WARNING: Internal error: Non-blank gender 3= in traditional template %s" % str(tradt))
                        return False, warnings
                      rmparam(tradt, "3")
                      notes.append("remove blank 3= in traditional %s template" % lect)
                    if simp_tr:
                      tradt.add("tr", simp_tr)
                      #this_notes.append("move tr=%s from simplified %s template to traditional equivalent" % (simp_tr, lect))
                    for delim in [", ", ",", " / ", "/", " "]:
                      this_text_to_remove = "%s%s" % (str(simpt), delim) if reversed else "%s%s" % (delim, str(simpt))
                      if this_text_to_remove in str(parsed):
                        break
                    if trad == simp:
                      # just trying to remove 'this_text_to_remove' may match twice; include the preceding traditional template in the line
                      text_to_remove.append((
                        "%s%s" % (this_text_to_remove, str(tradt)) if reversed else "%s%s" % (str(tradt), this_text_to_remove),
                        str(tradt)
                      ))
                    else:
                      text_to_remove.append((this_text_to_remove, ""))
                    either_tr = simp_tr or trad_tr
                    either_lit = simp_lit or trad_lit
                    this_notes.append("remove redundant simplified %s translation template (trad=%s, simp=%s%s%s)"
                      % (lect, trad, simp, ", tr=%s" % either_tr if either_tr else "", ", lit=%s" % either_lit if either_lit else ""))
                    return True, warnings
              elif not get(tradt, "tr") and get(simpt, "tr"):
                append_line_pagemsg("WARNING: Traditional translation template %s has translation %s which simplifies to %s != %s from corresponding simplified template %s, can't combine"
                  % (str(tradt), trad, trad_to_simp, simp, str(simpt)))
                return False, warnings
              else:
                # could just be for different translations
                return None, warnings


            for t in parsed.filter_templates():
              if prevt and tname(t) in translation_templates and tname(prevt) in translation_templates:
                combinable, warnings = combine_traditional_simplified(prevt, t)
                if combinable is False:
                  line_pagemsg("Can't combine traditional template %s and simplified template %s, trying reversed"
                    % (str(prevt), str(t)))
                  rev_combinable, rev_warnings = combine_traditional_simplified(t, prevt, reversed=True)
                  if rev_combinable:
                    line_pagemsg("Able to combine simplified template %s with traditional template %s by assuming backwards order"
                      % (str(prevt), str(t)))
                    for warning in rev_warnings:
                      msg(warning)
                    prevt = t
                    continue
                for warning in warnings:
                  msg(warning)
              prevt = t

            line = str(parsed)
            for this_text_to_remove, this_repl in text_to_remove:
              newline, replaced = blib.replace_in_text(line, this_text_to_remove, this_repl, line_pagemsg, abort_if_warning=True,
                  # since when trad == simp, the replacement will already be there
                  no_found_repl_check=True)
              if not replaced:
                break
              line = newline
            else: # no break
              lines[j] = line
              notes.extend(this_notes)

        else:
          in_chinese = False
      subsections[k] = "\n".join(lines)

  text = "".join(subsections)
  return text, notes

parser = blib.create_argparser("Remove redundant Chinese translations", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
