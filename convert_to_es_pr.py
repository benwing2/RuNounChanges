#!/usr/bin/env python3
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
vowel = u"aeiouüyAEIOUÜY"
V = "[" + vowel + "]" # vowel class
W = "[jw]" # glide
accent = AC + GR + CFLEX
accent_c = "[" + accent + "]"
stress = AC + GR
stress_c = "[" + AC + GR + "]"
ipa_stress = u"ˈˌ"
ipa_stress_c = "[" + ipa_stress + "]"
separator = accent + ipa_stress + r"# \-." + SYLDIV # hyphen included for syllabifying from spelling
separator_c = "[" + separator + "]"
C = "[^" + vowel + separator + "]" # consonant class including h
C_NOT_H = "[^" + vowel + separator + "h]" # consonant class not including h

def decompose(text):
  # decompose everything but ñ and ü
  text = unicodedata.normalize("NFD", text)
  text = text.replace("n" + TILDE, u"ñ")
  text = text.replace("N" + TILDE, u"Ñ")
  text = text.replace("u" + DIA, u"ü")
  text = text.replace("U" + DIA, u"Ü")
  return text

def syllabify_from_spelling(text):
  text = decompose(text)
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
  # Change user-specified . into SYLDIV so we don't shuffle it around when dividing into syllables.
  text = text.replace(".", SYLDIV)
  text = re.sub("y(" + V + ")", TEMP_Y_CONS + r"\1", text)
  text = text.replace("ch", TEMP_CH)
  # We don't want to break -sh- except in desh-, e.g. [[deshuesar]], [[deshonra]], [[deshecho]].
  text = re.sub("(^|[ -])([Dd])esh", r"\1\2" + TEMP_DESH, text)
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
  # i and u between vowels -> consonant-like substitutions: [[paranoia]], [[baiano]], [[abreuense]], [[alauita]],
  # [[Malaui]], etc.; also with h, as in [[marihuana]], [[parihuela]], [[antihielo]], [[pelluhuano]], [[náhuatl]],
  # etc.
  text = rsub_repeatedly("(" + V + accent_c + "*h?)([iu])(" + V + ")",
      lambda m: m.group(1) + vowel_to_glide[m.group(2)] + m.group(3), text)
  # Divide before the last consonant (possibly followed by a glide). We then move the syllable division marker
  # leftwards over clusters that can form onsets.
  # Divide VCV as V.CV; but don't divide if C == h, e.g. [[prohibir]] should be prohi.bir.
  text = rsub_repeatedly("(" + V + accent_c + "*)(" + C_NOT_H + V + ")", r"\1.\2", text)
  text = rsub_repeatedly("(" + V + accent_c + "*" + C + "+)(" + C + V + ")", r"\1.\2", text)
  # Puerto Rico + most of Spain divide tl as t.l. Mexico and the Canary Islands have .tl. Unclear what other regions
  # do. Here we choose to go with .tl. See https://catalog.ldc.upenn.edu/docs/LDC2019S07/Syllabification_Rules_in_Spanish.pdf
  # and https://www.spanishdict.com/guide/spanish-syllables-and-syllabification-rules.
  cluster_r = u"rɾ"
  text = re.sub(r"([pbfvkctg])\.([l" + cluster_r + "])", r".\1\2", text)
  text = re.sub(r"d\.([" + cluster_r + "])", r".d\1", text)
  text = text.replace("d.r", ".dr")
  # Per https://catalog.ldc.upenn.edu/docs/LDC2019S07/Syllabification_Rules_in_Spanish.pdf, tl at the end of a word
  # (as in nahuatl, Popocatepetl etc.) is divided .tl from the previous vowel.
  text = re.sub("([^. -])tl([ -]|$)", r"\1.tl\2", text)
  # Any aeo, or stressed iuüy, should be syllabically divided from a following aeo or stressed iuüy.
  text = rsub_repeatedly("([aeoAEO]" + accent_c + "*)(h?[aeo])", r"\1.\2", text)
  text = rsub_repeatedly("([aeoAEO]" + accent_c + "*)(h?" + V + stress_c + ")", r"\1.\2", text)
  text = re.sub(u"([iuüyIUÜY]" + stress_c + ")(h?[aeo])", r"\1.\2", text)
  text = rsub_repeatedly(u"([iuüyIUÜY]" + stress_c + ")(h?" + V + stress_c + ")", r"\1.\2", text)
  text = rsub_repeatedly("([iI]" + accent_c + "*)(h?i)", r"\1.\2", text)
  text = rsub_repeatedly("([uU]" + accent_c + "*)(h?u)", r"\1.\2", text)
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

def align_syllabification_to_spelling(syllab, spelling):
  result = []
  syll_chars = list(decompose(syllab))
  spelling_chars = list(decompose(spelling))
  i = 0
  j = 0
  while i < len(syll_chars) or j < len(spelling_chars):
    ci = syll_chars[i] if i < len(syll_chars) else None
    cj = spelling_chars[j] if j < len(spelling_chars) else None
    if ci == cj:
      result.append(ci)
      i += 1
      j += 1
    elif ci == ".":
      result.append(ci)
      i += 1
    elif ci in [AC, GR, CFLEX]:
      # skip character
      i += 1
    else:
      return None
  if i < len(syll_chars) or j < len(spelling_chars):
    # left-over characters on one side or the other
    return None
  return unicodedata.normalize("NFC", "".join(result))

# Return the number of syllables of a phonemic representation, which should have syllable dividers in it but no
# hyphens.
def get_num_syl_from_phonemic(phonemic):
  # Maybe we should just count vowels instead of the below code.
  phonemic = phonemic.replace("|", " ") # remove IPA foot boundaries
  words = re.split(" +", phonemic)
  for i, word in enumerate(words):
    # IPA stress marks are syllable divisions if between characters; otherwise just remove.
    word = re.sub(u"(.)[ˌˈ](.)", r"\1.\2", word)
    word = re.sub(u"[ˌˈ]", "", word)
    words[i] = word
  # There should be a syllable boundary between words.
  phonemic = ".".join(words)
  return len(re.sub("[^.]", "", phonemic)) + 1


# Get the rhyme by truncating everything up through the last stress mark + any following consonants, and remove
# syllable boundary markers.
def convert_phonemic_to_rhyme(phonemic):
  # NOTE: This works because the phonemic vowels are just [aeiou] possibly with diacritics that are separate
  # Unicode chars. If we want to handle things like ɛ or ɔ we need to add them to `vowel`.
  return re.sub("^[^" + vowel + "]*", "", re.sub(u".*[ˌˈ]", "", phonemic)).replace(".", "").replace(u"t͡ʃ", u"tʃ")


def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
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
    if str(t) != line:
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

  sect_for_wiki = 0
  for k in range(1, len(subsections), 2):
    if re.search(r"==\s*Etymology [0-9]+\s*==", subsections[k]):
      sect_for_wiki = k + 1
    elif re.search(r"==\s*Pronunciation\s*==", subsections[k]):
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
        pagemsg("Already saw {{es-pr}}, skipping: %s" % str(t))
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
      hyphenation_from_respelling = False
      hyphenation_from_pagetitle = False
      lines_so_far = []
      for lineind, line in enumerate(lines):
        origline = line
        lines_so_far.append(line)
        if "{{wiki" in line:
          m = re.search(r"^(.*?)(\{\{wiki[^{}]*\}\})(.*?)$", line)
          if not m:
            pagemsg("WARNING: Can't match {{wikipedia}} template in supposed line containing it: %s" % line)
          else:
            prevline, wikitemp, postline = m.groups()
            subsections[sect_for_wiki] = wikitemp + "\n" + subsections[sect_for_wiki]
            # Remove the {{wikipedia}} line or template from lines seen so far. Put back the remaining lines in case we
            # run into a problem later on, so we don't end up duplicating the {{wikipedia}} line. We accumulate lines
            # like this in case for some reason we have two {{wikipedia}} lines in the Pronunciation section.
            if not prevline and not postline:
              del lines_so_far[-1]
            else:
              line = prevline + postline
              lines_so_far[-1] = line
            subsections[k + 1] = "%s\n\n" % "\n".join(lines_so_far + lines[lineind + 1:])
            notes.append("move {{wikipedia}} line to top of etym section")
            if not prevline and not postline:
              continue
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
          bare_arg = getparam(ipat, "1")
          normalized_bare_arg = bare_arg or "+"
          arg = normalized_bare_arg
          arg_for_hyph = pagetitle if arg == "+" else arg
          hyphenation_from_pagetitle = syllabify_from_spelling(pagetitle)
          hyphenation_from_respelling = align_syllabification_to_spelling(
            syllabify_from_spelling(arg_for_hyph), pagetitle
          )
          for param in ipat.params:
            pn = pname(param)
            pv = str(param.value)
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
        # Get rid of any leading * + whitespace; continue without it though.
        line = re.sub(r"^\*+\s*", "", line, 0, re.U)
        if line.startswith("{{hyph"):
          hyph_lines.append("* " + line)
        elif re.search(r"^(\{\{(q|qual|qualifier|q-lite|i|a)\|[^{}]*\}\} )?{\{(homophone|hmp)", line):
          homophone_lines.append("* " + line)
        elif re.search(r"^(Audio: *)?\{\{audio", line):
          line = re.sub("^Audio: *", "", line)
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
            pv = str(param.value)
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
          audiopart = "<audio:%s%s>" % (audiofile, audiogloss)
          audioarg += audiopart
          pagemsg("Replacing %s with argument part %s" % (str(audiot), audiopart))
          extra_notes.append("incorporate %s into {{es-pr}}" % str(audiot))
        elif line.startswith("{{rhyme"):
          rhyme_lines.append(line)
        else:
          pagemsg("WARNING: Unrecognized Pronunciation section line, skipping: %s" % origline)
          must_continue = True
          break
      if must_continue:
        continue
      if rhyme_lines:
        must_continue = False
        for rhyme_line in rhyme_lines:
          rhymet = verify_template_is_full_line(["rhyme", "rhymes", "rhymes-lite"], rhyme_line)
          if not rhymet:
            must_continue = True
            break
          if getparam(rhymet, "1") != "es":
            pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(rhymet), rhyme_line))
            must_continue = True
            break
          styles = ["distincion-yeismo", "seseo-yeismo", "distincion-lleismo", "seseo-lleismo"]
          rhyme_pronuns = {}
          rhyme_nsyl = {}
          rhymes = blib.fetch_param_chain(rhymet, "2")
          for rind, rhyme in enumerate(rhymes):
            matching_styles = []
            nsyl = (getparam(rhymet, "s%s" % (rind + 1)) or getparam(rhymet, "s")).strip()
            if nsyl:
              if not re.search("^[0-9]+$", nsyl):
                pagemsg("WARNING: Bad syllable count in rhyme template: %s" % str(rhymet))
                must_continue = True
                break
              nsyl = int(nsyl)
            else:
              nsyl = None
            for style in styles:
              if style not in rhyme_pronuns:
                pronun = expand_text(u"{{#invoke:es-pronunc|IPA_string|%s|style=%s}}" % (bare_arg, style))
                if not pronun:
                  must_continue = True
                  break
                rhyme_pronuns[style] = convert_phonemic_to_rhyme(pronun)
                rhyme_nsyl[style] = get_num_syl_from_phonemic(pronun)
              if rhyme == rhyme_pronuns[style]:
                matching_styles.append(style)
                if nsyl is None:
                  pagemsg("Removing rhyme %s, same as pronunciation-based rhyme for %s for spelling '%s': %s"
                      % (rhyme, style, bare_arg, str(rhymet)))
                  break
                elif nsyl == rhyme_nsyl[style]:
                  pagemsg("Removing rhyme %s, same as pronunciation-based rhyme for %s for spelling '%s' and syllable count %s matches: %s"
                      % (rhyme, style, bare_arg, nsyl, str(rhymet)))
                  break
                elif pagetitle in allow_mismatching_nsyl:
                  pagemsg("Removing rhyme %s, same as pronunciation-based rhyme for %s for spelling '%s'; syllable count %s mismatches pronunciation syllable count %s but is known to be incorrect so is ignored: %s"
                      % (rhyme, style, bare_arg, nsyl, rhyme_nsyl[style], str(rhymet)))
                  extra_notes.append("ignore known-incorrect syllable count %s in {{%s}}" % (nsyl, tname(rhymet)))
                  break

            else: # no break
              if matching_styles:
                pagemsg("WARNING: For spelling '%s', rhyme %s same as pronunciation-based rhyme for style(s) %s but syllable count %s doesn't match (%s): %s"
                    % (bare_arg, rhyme, ",".join(matching_styles), nsyl,
                      ", ".join("%s=%s" % (style, rhyme_nsyl[style]) for style in styles), str(rhymet)))
              else:
                pagemsg("WARNING: For spelling '%s', rhyme %s%s not same as pronunciation-based rhyme (%s): %s"
                    % (bare_arg, rhyme, " with explicit syllable count %s" % nsyl if nsyl is not None else "",
                      ", ".join("%s=%s" % (style, rhyme_pronuns[style]) for style in styles), str(rhymet)))
              must_continue = True
            if must_continue:
              break
          if must_continue:
            break
      if must_continue:
        continue
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
          hypht = verify_template_is_full_line(["hyph", "hyphenation", "hyph-lite"], hyph_line)
          if hypht:
            syls = []
            if getparam(hypht, "1") != "es":
              pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(hypht), hyph_line))
            else:
              for param in hypht.params:
                pn = pname(param)
                pv = str(param.value)
                if not re.search("^[0-9]+$", pn):
                  pagemsg("WARNING: Unrecognized param %s=%s in {{%s}}, not removing: %s" %
                      (pn, pv, tname(hypht), hyph_line))
                  break
                if not pv:
                  pagemsg("WARNING: Multiple hyphenations in a single template, not removing: %s" % hyph_line)
                  break
                if int(pn) > 1:
                  syls.append(pv)
              else: # no break
                specified_hyphenation = ".".join(syls)
                if "r.r" in specified_hyphenation:
                  pagemsg("Converting r.r into .rr in specified hyphenation '%s': %s" % (specified_hyphenation, hyph_line))
                  specified_hyphenation = specified_hyphenation.replace("r.r", ".rr")
                if "l.l" in specified_hyphenation:
                  pagemsg("Converting l.l into .ll in specified hyphenation '%s': %s" % (specified_hyphenation, hyph_line))
                  specified_hyphenation = specified_hyphenation.replace("l.l", ".ll")
                if specified_hyphenation == hyphenation_from_respelling:
                  pagemsg("Removed explicit hyphenation same as auto-hyphenation: %s" % hyph_line)
                elif specified_hyphenation == hyphenation_from_pagetitle:
                  if normalized_bare_arg == "+":
                    pagemsg("WARNING: Something wrong, {{es-IPA}} used with '+' or empty respelling but respelling auto-hyphenation %s different from pagetitle auto-hyphenation %s"
                      % (hyphenation_from_respelling, hyphenation_from_pagetitle))
                  else:
                    pagemsg("Non-default pronunciation %s, explicit hyphenation same as pagetitle auto-hyphenation, replacing with <hyph:+>: %s" %
                        (bare_arg, hyph_line))
                    arg += "<hyph:+>"
                else:
                  hyph_text = (
                    "respelling auto-hyphenation %s or pagetitle auto-hyphenation %s" % (
                      hyphenation_from_respelling, hyphenation_from_pagetitle
                    ) if hyphenation_from_respelling != hyphenation_from_pagetitle else
                    "respelling/pagetitle auto-hyphenation %s" % hyphenation_from_respelling
                  )
                  if normalized_bare_arg == "+":
                    pagemsg("WARNING: {{es-IPA}} used with '+' or empty respelling but specified hyphenation %s not equal to %s, adding explicitly: %s" %
                        (specified_hyphenation, hyph_text, hyph_line))
                  else:
                    pagemsg("WARNING: Non-default pronunciation %s and specified hyphenation %s not equal to %s, adding explicitly: %s" %
                        (bare_arg, specified_hyphenation, hyph_text, hyph_line))
                  arg += "<hyph:%s>" % specified_hyphenation
                hyph_lines = []

      if homophone_lines:
        if len(homophone_lines) > 1:
          pagemsg("WARNING: Multiple homophone lines, not removing: %s" % ", ".join(homophone_lines))
        else:
          assert homophone_lines[0].startswith("* ")
          homophone_line = homophone_lines[0][2:]
          homophones = {}
          homophone_qualifiers = {}
          homophone_qualifier_text = None
          m = re.search(r"^(\{\{(?:hmp|homophones?)\|[^{}]*\}\}) \{\{(?:q|qual|qualifier|q-lite|i|a)\|([^{}|=]*)\}\}$", homophone_line)
          if m:
            homophone_line, homophone_qualifier_text = m.groups()
          if not m:
            m = re.search(r"^\{\{(?:q|qual|qualifier|q-lite|i|a)\|([^{}|=]*)\}\} (\{\{(?:hmp|homophones?)\|[^{}]*\}\})", homophone_line)
            if m:
              homophone_qualifier_text, homophone_line = m.groups()
          if not m:
            m = re.search(r"^(\{\{(?:hmp|homophones?)\|[^{}]*\}\}) \('*([^{}|=]*?)'*\)$", homophone_line)
            if m:
              homophone_line, homophone_qualifier_text = m.groups()
          hmpt = verify_template_is_full_line(["hmp", "homophone", "homophones"], homophone_line)
          if hmpt:
            if getparam(hmpt, "1") != "es":
              pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(hmpt), homophone_line))
            else:
              for param in hmpt.params:
                pn = pname(param)
                pv = str(param.value)
                if pn == "q":
                  pn = "q1"
                if not re.search("^q?[0-9]+$", pn):
                  pagemsg("WARNING: Unrecognized param %s=%s in {{%s}}, not removing: %s" %
                      (pn, pv, tname(hmpt), homophone_line))
                  break
                if pn.startswith("q"):
                  homophone_qualifiers[int(pn[1:])] = pv
                elif int(pn) > 1:
                  homophones[int(pn) - 1] = pv
              else: # no break
                def normalize_homophone_qualifier(q):
                  q = re.sub(u"(non-Castilian|non-Iberian|seseo and ceceo|seseo|Latin-America|in dialects without distinción|in dialects without distinction between S and Z|non-\[*distinción\]*)", "Latin America", q)
                  q = re.sub(u"((?:in dialects with )?\[*yeísmo\]*)", u"[[yeísmo]]", q)
                  q = re.sub(" dialects", "", q)
                  return q
                hmp_args = []
                for pn, pv in sorted(homophones.items()):
                  hmp_args.append(pv)
                  if pn in homophone_qualifiers:
                    hmp_args[-1] += "<q:%s>" % normalize_homophone_qualifier(homophone_qualifiers[pn])
                if homophone_qualifier_text:
                  hmp_args[-1] += "<q:%s>" % normalize_homophone_qualifier(homophone_qualifier_text)
                arg += "<hmp:%s>" % ",".join(hmp_args)
                extra_notes.append("incorporate homophones into {{es-pr}}")
                homophone_lines = []

      if arg == "+":
        es_pr = "{{es-pr}}"
      else:
        es_pr = "{{es-pr|%s}}" % arg
      pagemsg("Replaced %s with %s" % (str(ipat), es_pr))

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
parser.add_argument("--allow-mismatching-nsyl", help="Comma-separated list of pages with known incorrect value for number of syllables in {{rhymes}} template.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

allow_mismatching_nsyl = set()
if args.allow_mismatching_nsyl:
  allow_mismatching_nsyl = set(blib.split_utf8_arg(args.allow_mismatching_nsyl))

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
