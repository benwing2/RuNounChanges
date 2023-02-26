#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

blib.getData()

translation_templates = ["t", "t+", "tt", "tt+", "t-needed", "t-check", "t+check"]

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def convert_traditional_to_simplified(trad):
    trad_simp = expand_text("{{#invoke:User:Benwing2/languages/utilities|generateForms|cmn|%s}}" % trad)
    if not trad_simp:
      return trad_simp
    if "||" in trad_simp:
      trad, simp = trad_simp.split("||", 1)
      return simp
    else:
      return trad_simp

  notes = []

  if not re.search(r"^\* *Chinese:*$", text, re.M):
    return

  subsections = re.split("(^==+[^=\n]+==+\n)", text, 0, re.M)

  for k in xrange(2, len(subsections) - 2, 2):
    if re.search(r"==\s*Translations\s*==", subsections[k - 1]):
      lines = subsections[k].split("\n")
      in_chinese = False
      for j, line in enumerate(lines):
        def line_pagemsg(txt):
          msg("Page %s %s: %s: <from> %s <to> %s <end>" % (index, pagetitle, txt, line, line))
        if re.search(r"^\* *Chinese:* *[^: ]", line):
          line_pagemsg("WARNING: Chinese: line with junk after it")
          in_chinese = True
        elif re.search(r"^\* *Chinese:*$", line):
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
                  line_pagemsg("Remove unnecessary sc=%s from %s" % (sc, unicode(t)))
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

            line = unicode(parsed)
            lines[j] = line

            if lect == "Mandarin":
              parsed = blib.parse_text(line)
              must_continue = False
              prevt = None
              text_to_remove = []
              this_notes = []
              for t in parsed.filter_templates():
                def getp(param):
                  return getparam(t, param)
                tn = tname(t)
                if tn in translation_templates:
                  lang = getp("1")
                  if lang == "zh":
                    line_pagemsg("WARNING: Internal error: Unconverted 'zh' in Mandarin translation template %s" % unicode(t))
                    must_continue = True
                    break
                  elif lang != "cmn":
                    line_pagemsg("WARNING: Strange language in Mandarin translation template %s" % unicode(t))
                    must_continue = True
                    break
                  if prevt and tname(prevt) == tn:
                    trad = getparam(prevt, "2")
                    simp = getp("2")
                    trad_to_simp = convert_traditional_to_simplified(trad)
                    if trad_to_simp == simp:
                      alt = getp("alt")
                      tr = getp("tr")
                      lit = getp("lit")
                      for param in t.params:
                        pn = pname(param)
                        pv = unicode(param.value)
                        if pn not in ["1", "2", "3", "tr", "alt", "sc", "lit"]:
                          line_pagemsg("WARNING: Unrecognized parameter %s=%s in simplified translation template %s, can't combine"
                            % (pn, pv, unicode(t)))
                          break
                        if pn == "3" and pv:
                          line_pagemsg("WARNING: Gender %s=%s specified in simplified translation template %s, can't combine"
                            % (pn, pv, unicode(t)))
                          break
                      else: # no break
                        for param in prevt.params:
                          pn = pname(param)
                          pv = unicode(param.value)
                          if pn not in ["1", "2", "3", "tr", "alt", "sc", "lit"]:
                            line_pagemsg("WARNING: Unrecognized parameter %s=%s in traditional translation template %s, can't combine"
                              % (pn, pv, unicode(prevt)))
                            break
                          if pn == "3" and pv:
                            line_pagemsg("WARNING: Gender %s=%s specified in simplified translation template %s, can't combine"
                              % (pn, pv, unicode(t)))
                            break
                        else: # no break
                          prevtr = getparam(prevt, "tr")
                          if prevtr and not tr:
                            pass # leave traditional tr= alone
                          elif prevtr and prevtr != tr:
                            line_pagemsg("WARNING: Saw transliteration parameter '%s' in traditional translation template %s different from simplified transliteration '%s', can't combine"
                              % (prevtr, unicode(prevt), tr))
                            continue
                          prevlit = getparam(prevt, "lit")
                          if prevlit and not lit:
                            pass # leave traditional lit= alone
                          elif prevlit and prevlit != lit:
                            line_pagemsg("WARNING: Saw literal parameter '%s' in traditional translation template %s different from simplified literal '%s', can't combine"
                              % (prevlit, unicode(prevt), lit))
                            continue
                          prev_alt = getparam(prevt, "alt")
                          if prev_alt and not alt:
                            line_pagemsg("WARNING: Traditional translation template %s has alt= but corresponding simplified template %s doesn't, can't combine"
                              % (unicode(prevt), unicode(t)))
                            continue
                          if not prev_alt and alt:
                            line_pagemsg("WARNING: Traditional translation template %s doesn't have alt= but corresponding simplified template %s does, can't combine"
                              % (unicode(prevt), unicode(t)))
                            continue
                          if prev_alt and alt:
                            simp_alt = convert_traditional_to_simplified(prev_alt)
                            if simp_alt != alt:
                              line_pagemsg("WARNING: Traditional translation template %s has alt= which converts to %s != %s from corresponding simplified template %s, can't combine"
                                % (unicode(prevt), simp_alt, alt, unicode(t)))
                              continue
                          if tr:
                            prevt.add("tr", tr)
                            this_notes.append("move tr=%s from simplified Mandarin template to traditional equivalent" % tr)
                          if prevt.has("3"):
                            if getparam(prevt, "3"):
                              line_pagemsg("WARNING: Internal error: Non-blank gender 3= in traditional template %s" % unicode(prevt))
                              continue
                            rmparam(prevt, "3")
                            notes.append("remove blank 3= in traditional Mandarin template")
                          this_text_to_remove = ", %s" % unicode(t)
                          if this_text_to_remove not in unicode(parsed):
                            this_text_to_remove = ",%s" % unicode(t)
                          if this_text_to_remove not in unicode(parsed):
                            this_text_to_remove = " %s" % unicode(t)
                          if trad == simp:
                            # just trying to remove 'this_text_to_remove' may match twice; include the preceding traditional template in the line
                            text_to_remove.append(("%s%s" % (unicode(prevt), this_text_to_remove), unicode(prevt)))
                          else:
                            text_to_remove.append((this_text_to_remove, ""))
                          either_tr = tr or prevtr
                          either_lit = lit or prevlit
                          this_notes.append("remove redundant simplified Mandarin translation template (trad=%s, simp=%s%s%s)"
                            % (trad, simp, ", tr=%s" % either_tr if either_tr else "", ", lit=%s" % either_lit if either_lit else ""))
                prevt = t

              if must_continue:
                continue
              line = unicode(parsed)
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
