#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, unicodedata

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname, rsub_repeatedly

AC = u"\u0301" # acute =  ́
GR = u"\u0300" # grave =  ̀
CFLEX = u"\u0302" # circumflex =  ̂
TILDE = u"\u0303" # tilde =  ̃
DIA = u"\u0308" # diaeresis =  ̈

SYLDIV = u"\uFFF0" # used to represent a user-specific syllable divider (.) so we won't change it
accent = AC + GR + CFLEX
accent_c = "[" + accent + "]"
stress = AC + GR
stress_c = "[" + AC + GR + "]"
ipa_stress = u"ˈˌ"
ipa_stress_c = "[" + ipa_stress + "]"
separator = accent + ipa_stress + "# ." + SYLDIV
separator_c = "[" + separator + "]"

def divide_syllables_on_spelling(text):
  # decompose everything but ñ and ü
  text = unicodedata.normalize("NFD", text)
  text = text.replace("n" + TILDE, u"ñ")
  text = text.replace("N" + TILDE, u"Ñ")
  text = text.replace("u" + DIA, u"ü")
  text = text.replace("U" + DIA, u"Ü")
  TEMP_I = u"\uFFF1"
  TEMP_U = u"\uFFF2"
  TEMP_Y_CONS = u"\uFFF3"
  TEMP_CH = u"\uFFF4"
  TEMP_LL = u"\uFFF5"
  TEMP_RR = u"\uFFF6"
  TEMP_QU = u"\uFFF7"
  TEMP_QU_CAPS = u"\uFFF8"
  TEMP_GU = u"\uFFF9"
  TEMP_GU_CAPS = u"\uFFFA"
  TEMP_SH = u"\uFFFB"
  TEMP_DESH = u"\uFFFC"
  vowel = u"aeiouüyAEIOUÜY"
  V = "[" + vowel + "]" # vowel class
  C = "[^" + vowel + separator + "]" # consonant class
  # Change user-specified . into SYLDIV so we don't shuffle it around when dividing into syllables.
  text = text.replace(".", SYLDIV)
  text = re.sub("y(" + V + ")", TEMP_Y_CONS + r"\1", text)
  text = text.replace("ch", TEMP_CH)
  # We don't want to break -sh- except in desh-, e.g. [[deshuesar]], [[deshonra]], [[deshecho]].
  text = re.sub("(^| )([Dd])esh", r"\1\2" + TEMP_DESH, text)
  text = text.replace("sh", TEMP_SH)
  text = text.replace(TEMP_DESH, "esh")
  text = text.replace("ll", TEMP_LL)
  text = text.replace("rr", TEMP_RR)
  # qu mostly handled correctly automatically, but not in quietud
  text = re.sub("qu(" + V + ")", TEMP_QU + r"\1", text)
  text = re.sub("Qu(" + V + ")", TEMP_QU_CAPS + r"\1", text)
  text = re.sub("gu(" + V + ")", TEMP_GU + r"\1", text)
  text = re.sub("Gu(" + V + ")", TEMP_GU_CAPS + r"\1", text)
  vowel_to_glide = { "i": TEMP_I, "u": TEMP_U }
  # i and u between vowels -> consonant-like substitutions ([[paranoia]], [[baiano]], [[abreuense]], [[alauita]],
  # [[Malaui]], etc.)
  text = rsub_repeatedly("(" + V + accent_c + "*)([iu])(" + V + ")",
      lambda m: m.group(1) + vowel_to_glide[m.group(2)] + m.group(3), text)
  text = rsub_repeatedly("(" + V + accent_c + "*)(" + C + V + ")", r"\1.\2", text)
  text = rsub_repeatedly("(" + V + accent_c + "*" + C + ")(" + C + V + ")", r"\1.\2", text)
  text = rsub_repeatedly("(" + V + accent_c + "*" + C + "+)(" + C + C + V + ")", r"\1.\2", text)
  # Puerto Rico + most of Spain divide tl as t.l. Mexico and the Canary Islands have .tl. Unclear what other regions
  # do. Here we choose to go with .tl. See https://catalog.ldc.upenn.edu/docs/LDC2019S07/Syllabification_Rules_in_Spanish.pdf
  # and https://www.spanishdict.com/guide/spanish-syllables-and-syllabification-rules.
  text = re.sub(r"([pbfvkctg])\.([lr])", r".\1\2", text)
  text = text.replace("d.r", ".dr")
  # Per https://catalog.ldc.upenn.edu/docs/LDC2019S07/Syllabification_Rules_in_Spanish.pdf, tl at the end of a word
  # (as in nahuatl, Popocatepetl etc.) is divided .tl from the previous vowel.
  text = re.sub("([^. ])tl( |$)", r"\1.tl\2", text)
  text = rsub_repeatedly(r"(" + C + ")\.s(" + C + ")", r"\1s.\2", text)
  # Any aeo, or stressed iuüy, should be syllabically divided from a following aeo or stressed iuüy.
  text = rsub_repeatedly("([aeoAEO]" + accent_c + "*)([aeo])", r"\1.\2", text)
  text = rsub_repeatedly("([aeoAEO]" + accent_c + "*)(" + V + stress_c + ")", r"\1.\2", text)
  text = re.sub(u"([iuüyIUÜY]" + stress_c + ")([aeo])", r"\1.\2", text)
  text = rsub_repeatedly(u"([iuüyIUÜY]" + stress_c + ")(" + V + stress_c + ")", r"\1.\2", text)
  text = rsub_repeatedly("[iI](" + accent_c + "*)i", r"i\1.i", text)
  text = rsub_repeatedly("[uU](" + accent_c + "*)u", r"u\1.u", text)
  text = text.replace(SYLDIV, ".")
  text = text.replace(TEMP_I, "i")
  text = text.replace(TEMP_U, "u")
  text = text.replace(TEMP_Y_CONS, "y")
  text = text.replace(TEMP_CH, "ch")
  text = text.replace(TEMP_SH, "sh")
  text = text.replace(TEMP_LL, "ll")
  text = text.replace(TEMP_RR, "rr")
  text = text.replace(TEMP_QU, "qu")
  text = text.replace(TEMP_QU_CAPS, "Qu")
  text = text.replace(TEMP_GU, "gu")
  text = text.replace(TEMP_GU_CAPS, "Gu")
  return unicodedata.normalize("NFC", text)

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def verify_template_is_full_line(tn, line):
    templates = list(blib.parse_text(line).filter_templates())
    if type(tn) is list:
      tns = tn
    else:
      tns = [tn]
    tntext = "/".join(tns)
    if len(templates) == 0:
      pagemsg("WARNING: No templates on {{%s}} line?, skipping: %s" % (tntext, line))
      return None
    t = templates[0]
    if tname(t) not in tns:
      pagemsg("WARNING: Putative {{%s}} line doesn't have {{%s...}} as the first template, skipping: %s" %
          (tntext, tntext, line))
      return None
    if unicode(t) != line:
      pagemsg("WARNING: {{%s}} line has text other than {{%s...}}, skipping: %s" % (tntext, tntext, line))
      return None
    return t

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Spanish", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in xrange(1, len(subsections), 2):
    if re.search(r"==\s*Pronunciation\s*==", subsections[k]):
      secheader = re.sub(r"\s*Pronunciation\s*", "Pronunciation", subsections[k])
      if secheader != subsections[k]:
        subsections[k] = secheader
        notes.append("remove extraneous spaces in ==Pronunciation== header")
      extra_notes = []
      parsed = blib.parse_text(subsections[k + 1])
      num_es_IPA = 0
      saw_es_pr = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn in ["es-pr", "es-pronunciation"]:
          saw_es_pr = True
          break
        if tn == "es-IPA":
          num_es_IPA += 1
      if saw_es_pr:
        pagemsg("Already saw {{es-pr}}, skipping: %s" % unicode(t))
        continue
      if num_es_IPA == 0:
        pagemsg("WARNING: Didn't see {{es-IPA}} in Pronunciation section, skipping")
        continue
      if num_es_IPA > 1:
        pagemsg("WARNING: Saw multiple {{es-IPA}} in Pronunciation section, skipping")
        continue
      lines = subsections[k + 1].strip().split("\n")
      # Remove blank lines.
      lines = [line for line in lines if line]
      hyph_lines = []
      homophone_lines = []
      rhyme_lines = []
      must_continue = False
      audioarg = ""
      arg = ""
      bare_arg = ""
      hyphenation = False
      default_hyphenation = False
      for line in lines:
        origline = line
        # In case of "* {{es-IPA|...}}", chop off the "* ".
        line = re.sub(r"^\*\s*(\{\{es-IPA)", r"\1", line)
        if line.startswith("{{es-IPA"):
          if arg:
            pagemsg("WARNING: Something wrong, already saw {{es-IPA}}?: %s" % origline)
            must_continue = True
            break
          ipat = verify_template_is_full_line("es-IPA", line)
          if ipat is None:
            must_continue = True
            break
          arg = getparam(ipat, "1") or "+"
          bare_arg = arg
          default_hyphenation = arg == "+" or arg.replace(".", "") == pagetitle
          hyphenation = divide_syllables_on_spelling(pagetitle)
          for param in ipat.params:
            pn = pname(param)
            pv = unicode(param.value)
            if pn == "1":
              continue
            if pn in ["pre", "post", "bullets", "ref", "style"]:
              arg += "<%s:%s>" % (pn, pv)
            else:
              pagemsg("WARNING: Unrecognized param %s=%s in {{es-IPA}}, skipping: %s" % (
                pn, pv, origline))
              must_continue = True
              break
          if must_continue:
            break
          continue
        if not line.startswith("* ") and not line.startswith("*{"):
          pagemsg("WARNING: Pronunciation section line doesn't start with '* ', skipping: %s"
              % origline)
          must_continue = True
          break
        if line.startswith("* "):
          line = line[2:]
        else:
          line = line[1:]
        if line.startswith("{{hyph"):
          hyph_lines.append("* " + line)
        elif line.startswith("{{homophone"):
          homophone_lines.append("* " + line)
        elif line.startswith("{{audio"):
          audiot = verify_template_is_full_line("audio", line)
          if audiot is None:
            must_continue = True
            break
          if getparam(audiot, "1") != "es":
            pagemsg("WARNING: Wrong language in {{audio}}, skipping: %s" % origline)
            must_continue = True
            break
          audiofile = getparam(audiot, "2")
          audiogloss = getparam(audiot, "3")
          for param in audiot.params:
            pn = pname(param)
            pv = unicode(param.value)
            if pn not in ["1", "2", "3"]:
              pagemsg("WARNING: Unrecognized param %s=%s in {{audio}}, skipping: %s" % (
                pn, pv, origline))
              must_continue = True
              break
          if must_continue:
            break
          if audiogloss in ["Audio", "audio"]:
            audiogloss = ""
          if audiogloss:
            audiogloss = ";%s" % audiogloss
          audioarg += "<audio:%s%s>" % (audiofile, audiogloss)
          pagemsg("Replacing %s with argument %s" % (unicode(audiot), arg))
          extra_notes.append("incorporate %s into {{es-pr}}" % unicode(audiot))
        elif line.startswith("{{rhyme"):
          rhyme_lines.append(line)
        else:
          pagemsg("WARNING: Unrecognized Pronunciation section line, skipping: %s" % origline)
          must_continue = True
          break
      if must_continue:
        continue
      if rhyme_lines:
        # FIXME, verify specified rhymes are subset of actual rhymes
        pass
      if not arg:
        pagemsg("WARNING: Something wrong, didn't see {{es-IPA}}?")
        continue
      arg += audioarg

      if hyph_lines:
        if len(hyph_lines) > 1:
          pagemsg("WARNING: Multiple hyphenation lines, not removing: %s" % ", ".join(hyph_lines))
        else:
          assert hyph_lines[0].startswith("* ")
          hyph_line = hyph_lines[0][2:]
          hypht = verify_template_is_full_line(["hyph", "hyphenation"], hyph_line)
          if hypht:
            syls = []
            if getparam(hypht, "1") != "es":
              pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(hypht), hyph_line))
            else:
              for param in hypht.params:
                pn = pname(param)
                pv = unicode(param.value)
                if not re.search("^[0-9]+$", pn):
                  pagemsg("WARNING: Unrecognized param %s=%s in {{%s}} not removing: %s" %
                      (pn, pv, tname(hypht), hyph_line))
                  break
                if int(pn) > 1:
                  syls.append(pv)
              else: # no break
                specified_hyphenation = ".".join(syls)
                if specified_hyphenation != hyphenation:
                  if default_hyphenation:
                    pagemsg("WARNING: Specified hyphenation %s not equal to auto-hyphenation %s, adding explicitly: %s" %
                        (specified_hyphenation, hyphenation, hyph_line))
                  else:
                    pagemsg("WARNING: Non-default pronunciation %s and specified hyphenation %s not equal to auto-hyphenation %s, adding explicitly: %s" %
                        (bare_arg, specified_hyphenation, hyphenation, hyph_line))
                  arg += "<hyph:%s>" % specified_hyphenation
                elif default_hyphenation:
                  pagemsg("Removed explicit hyphenation same as auto-hyphenation: %s" % hyph_line)
                else:
                  pagemsg("Non-default pronunciation %s, explicit hyphenation same as auto-hyphenation, replacing with <hyph:+>: %s" % (
                    bare_arg, hyph_line))
                  arg += "<hyph:+>"
                hyph_lines = []

      if arg == "+":
        es_pr = "{{es-pr}}"
      else:
        es_pr = "{{es-pr|%s}}" % arg
      pagemsg("Replaced %s with %s" % (unicode(ipat), es_pr))

      all_lines = "\n".join([es_pr] + hyph_lines + homophone_lines)
      newsubsec = "%s\n\n" % all_lines
      if subsections[k + 1] != newsubsec:
        this_notes = ["convert {{es-IPA}} to {{es-pr}}"] + extra_notes
        notes.extend(this_notes)
      subsections[k + 1] = newsubsec

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Convert {{es-IPA}} to {{es-pr}}", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
