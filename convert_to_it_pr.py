#!/usr/bin/env python
# -*- coding: utf-8 -*-

# FIXME: Lowercase pronunciations for capitalized lemmas (DONE)
# FIXME: Lowercase hyphenations for capitalized lemmas (DONE)
# FIXME: V.sCV or Vs.CV? (DONE)
# FIXME: Handle [s] (DONE)
# FIXME: Handle underbar for trailing secondary stress (DONE)
# FIXME: Consider removing secondary stress as in mèrcoledì and òligonucleotìde? (DONE)
# FIXME: Handle pronunciations without stress such as 'fatto' and 'kaf', those defaulted
#        completely, those with + and those using ^ò and such
# FIXME: Explicit hyphenations like co.lo.nìa for colonìa and cà.vea for càvea; is this correct? (DONE)
# FIXME: Explicit hyphenations like u.ra.gá.no with acute accent on aiu (DONE)
# FIXME: Remove ''' in explicit hyphenation (DONE)
# FIXME: Handle ỳ in kỳrie (DONE)
# FIXME: Don't remove secondary stress before hyphenation or we hyphenate bìobibliografìa bio. instead of
#        bi.o., as correct. (DONE)
# FIXME: When looking for missing syllable markers in explicit hyphenation, collect set of indices of
#        explicit hyphenation markers and see if subset of syllable markers in auto-hyphenation. (DONE)
# FIXME: Look for cases of mismatched initial case in both directions, cf. [[hawaiano]] with explicit
#        hyphenation Ha.wa.ià.no, [[mesopotamico]] with explicit hyphenation Me.so.po.tà.mi.co, [[pliocenico]]
#        with explicit hyphenation Plio.cè.ni.co, [[aonio]] with explicit hyphenation A.ò.nio, [[avicennia]]
#        with explicit hyphenation A.vi.cèn.nia. (DONE)
# FIXME: Possibly divide -ps- as .ps, many examples of this e.g. [[autopsia]], [[ypsilon]], [[stipsi]], [[ipsilon]],
#        [[capsa]], [[necropsia]], [[oligopsonistico]], [[relapso]], [[stereopsia]], [[ipsilofo]], [[ipsolofo]],
#        [[ipsiconchia]], [[ipsiconco]], [[Scindapso]], [[scindapso]], [[Tapso]] with .ps, vs. [[dipsomania]],
#        [[rapsodia]], [[rapsodico]], [[dipsomane]], [[rapsodo]], [[-opsia]] with p.s. (WON'T DO)
# FIXME: Possibly remove space when hyphenating multiword terms and terms with hyphens in them e.g. [[pera spadona]],
#        [[alveolo-palatale]], [[bosniaco-erzegovino]]. Keep primary accents in each word but don't add accents to
#        unstressed words, as in [[immagine di sé]] respelled ''immàgine di sé'', [[erba da spazzola]] respelled
#        ''èrba da spàttsola''.
# FIXME: Convert acute to grave in pronunciation respelling.
# FIXME: [[postdiluviano]] hyphenated incorrectly as pos.tdi.lu.vià.no, [[lambdacismo]] hyphenated incorrectly as
#        lam.bda.cì.smo, similarly for [[postcommunio]], [[sternbergia]]
# FIXME: Remove final *° etc. from respelling before generating rhymes. (DONE)
# FIXME: Handle + when generating rhymes. (DONE PARTLY; NEED TO HANDLE AUTO-STRESSED CASES LIKE 'fatto')
# FIXME: Instead of skipping page entirely when rhyme mismatches, add rhyme explicitly. (DONE)
# FIXME: If explicit num syllables given and no default or explicit hyphenation, include num syls. (DONE)
# FIXME: Lots of mismatches where explicit rhyme has ɔi/oi/ai/ɛi/ei/ui for pronunciation rhyme ɔj/oj/etc., allow this.
#        Sometimes occurs non-finally, e.g. in [[braida]], [[dispaino]], [[intuino]]. (DONE)
# FIXME: Several mismatches where explicit rhyme has sm for pronunciation rhyme zm, allow this. (DONE)
# FIXME: Several mismatches where explicit rhyme has non-final auC or au̯C for pronunciation rhyme awC, allow this. (DONE)
# FIXME: Pronunciation incorrect for sìi as /sij/.
# FIXME: [[edui]] correctly pronounced /ɛdwi/ (as per rhyme) or /ɛduj/ (as per {{it-IPA}})?
# FIXME: Remove circumflex on final î in explicit hyphenation. (DONE)
# FIXME: Ignore pronunciation lines consisting of just the page title, possibly accented. (DONE)
# FIXME: Correctly handle {{rfap}} lines. (DONE)
# FIXME: Correctly handle {{wikipedia|lang=it}} and {{wiki|lang=it}} lines, moving below most recent numbered
#        Etymology section or moving above all sections if no numbered Etymology section.

import pywikibot, re, sys, codecs, argparse, unicodedata

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname, rsub_repeatedly

AC = u"\u0301" # acute =  ́
GR = u"\u0300" # grave =  ̀
CFLEX = u"\u0302" # circumflex =  ̂
TILDE = u"\u0303" # tilde =  ̃
DIA = u"\u0308" # diaeresis =  ̈
TIE = u"\u0361" # tie =  ͡
LINEUNDER = u"\u0331" # line under =  ̱
SYLDIV = u"\uFFF0" # used to represent a user-specific syllable divider (.) so we won't change it
accent = AC + GR + CFLEX + LINEUNDER
accent_c = "[" + accent + "]"
stress = AC + GR
stress_c = "[" + AC + GR + "]"
ipa_stress = u"ˈˌ"
ipa_stress_c = "[" + ipa_stress + "]"
separator = accent + ipa_stress + r"# \-." + SYLDIV
separator_c = "[" + separator + "]"
vowel = u"aeiouyöüAEIOUYÖÜ"
V = "[" + vowel + "]" # vowel class
C = "[^" + vowel + separator + "]" # consonant class including h
pron_sign = u"#!*°"
pron_sign_c = "[" + pron_sign + "]"

acute_to_grave = {u"á": u"à", u"í": u"ì", u"ú": u"ù", u"Á": u"À", u"Í": u"Ì", u"Ú": u"Ù"}


def decompose(text):
  # decompose everything but ö and ü
  text = unicodedata.normalize("NFD", text)
  text = text.replace("o" + DIA, u"ö")
  text = text.replace("O" + DIA, u"Ö")
  text = text.replace("u" + DIA, u"ü")
  text = text.replace("U" + DIA, u"Ü")
  return text

def recompose(text):
  return unicodedata.normalize("NFC", text)

def remove_secondary_stress(text):
  words = decompose(text).split(" ")
  # Remove secondary stresses marked with LINEUNDER if there's a previously stressed vowel. Otherwise, just remove the
  # LINEUNDER, leaving the accent mark, which will be removed below if there's a following stressed vowel.
  words = [re.sub("(" + stress_c + ".*)" + LINEUNDER + stress_c, r"\1",
    re.sub("(" + stress_c + ".*)" + stress_c + LINEUNDER, r"\1", word)) for word in words]
  words = [word.replace(LINEUNDER, "") for word in words]
  words = [rsub_repeatedly(stress_c + "(.*" + stress_c + ")", r"\1", word) for word in words]
  return recompose(" ".join(words))

def remove_accents(text):
  words = decompose(text).split(" ")
  words = [re.sub(accent_c, "", word) for word in words]
  return recompose(" ".join(words))

def remove_non_final_accents(text):
  words = decompose(text).split(" ")
  words = [rsub_repeatedly(accent_c + "(.)", r"\1", word) for word in words]
  return recompose(" ".join(words))

def remove_final_monosyllabic_accents(text):
  words = decompose(text).split(" ")
  words = [re.sub(u"^([^" + vowel + "]*[" + vowel + "])" + accent_c + "$", r"\1", word) for word in words]
  return recompose(" ".join(words))

def generate_hyphenation_from_spelling(text):
  text = decompose(text)
  TEMP_I = u"\uFFF1"
  TEMP_U = u"\uFFF2"
  TEMP_Y_CONS = u"\uFFF3"
  TEMP_CH = u"\uFFF4"
  TEMP_SC = u"\uFFF5"
  TEMP_GN = u"\uFFF6"
  TEMP_QU = u"\uFFF7"
  TEMP_QU_CAPS = u"\uFFF8"
  TEMP_GU = u"\uFFF9"
  TEMP_GU_CAPS = u"\uFFFA"
  TEMP_SH = u"\uFFFB"
  TEMP_GL = u"\uFFFC"
  TEMP_GH = u"\uFFFD"
  C_NOT_H = "[^" + vowel + separator + "h]" # consonant class not including h
  C_NOT_SRZ = "[^" + vowel + separator + "srz]" # consonant class not including s/r/z
  # Change user-specified . into SYLDIV so we don't shuffle it around when dividing into syllables.
  text = text.replace(".", SYLDIV)
  text = re.sub("y(" + V + ")", TEMP_Y_CONS + r"\1", text)
  text = text.replace("ch", TEMP_CH)
  text = text.replace("gh", TEMP_GH)
  text = text.replace("gn", TEMP_GN)
  text = text.replace("gl", TEMP_GL)
  text = text.replace("sh", TEMP_SH)
  text = re.sub(u"sc([ei])", TEMP_SC + r"\1", text)
  # qu mostly handled correctly automatically, but not in quieto etc.
  text = re.sub("qu(" + V + ")", TEMP_QU + r"\1", text)
  text = re.sub("Qu(" + V + ")", TEMP_QU_CAPS + r"\1", text)
  text = re.sub("gu(" + V + ")", TEMP_GU + r"\1", text)
  text = re.sub("Gu(" + V + ")", TEMP_GU_CAPS + r"\1", text)
  vowel_to_glide = { "i": TEMP_I, "u": TEMP_U }
  # i and u between vowels -> consonant-like substitutions: [[paranoia]], [[febbraio]], [[abbaiare]], [[aiutare]],
  # [[portauovo]], [[schopenhaueriano]], [[Malaui]], etc.; also with h, as in [[nahuatl]], [[ahia]], etc.
  # FIXME: [[figliuolo]], [[begliuomini]], [[feuilleton]], [[giuoco]], [[nocciuola]], [[stacciuolo]],
  # [[rousseauiano]], [[oriuolo]], [[guerricciuola]], [[ghiaggiuolo]], etc.
  #
  # With h not dividing diphthongs: [[ahi]], [[ehi]], [[ahimè]], [[ehilà]], [[ohimè]], [[ohilà]], etc.
  # 
  text = rsub_repeatedly("(" + V + accent_c + "*h?)([iu])(" + V + ")",
      lambda m: m.group(1) + vowel_to_glide[m.group(2)] + m.group(3), text)
  # Divide VCV as V.CV; but don't divide if C == h, e.g. [[prohibir]] should be prohi.bir.
  text = rsub_repeatedly("(" + V + accent_c + "*)(" + C_NOT_H + V + ")", r"\1.\2", text)
  text = rsub_repeatedly("(" + V + accent_c + "*" + C + ")(" + C + V + ")", r"\1.\2", text)
  text = rsub_repeatedly("(" + V + accent_c + "*" + C + "+)(" + C + C + V + ")", r"\1.\2", text)
  # Existing hyphenations of [[atlante]], [[Betlemme]], [[genetliaco]], [[betlemita]] all divide as .tl,
  # and none divide as t.l. No examples of -dl- but it should be the same per
  # http://www.italianlanguageguide.com/pronunciation/syllabication.asp.
  text = re.sub(r"([pbfvkcgqtd])\.([lr])", r".\1\2", text)
  # Italian appears to divide VsCV as V.sCV e.g. pé.sca for [[pesca]]. Exceptions are ss, sr, sz and possibly others.
  text = re.sub(r"s\.(" + C_NOT_SRZ + V + ")", r".s\1", text)
  # Also V.sCrV, C.sCrV and similarly V.sClV, V.sClV e.g. in.stru.mén.to for [[instrumento]], fi.nè.stra for
  # [[finestra]].
  text = re.sub(r"s\.(" + C + "[lr])", r".s\1", text)
  # Any aeo, or stressed iuüy, should be syllabically divided from a following aeo or stressed iuüy.
  # A stressed vowel might be preceded by LINEUNDER; normalized decomposition puts LINEUNDER before acute/grave.
  text = rsub_repeatedly(u"([aeoöAEOÖ]" + accent_c + u"*)(h?[aeoö])", r"\1.\2", text)
  text = rsub_repeatedly(u"([aeoöAEOÖ]" + accent_c + "*)(h?" + V + accent_c + "*" + stress_c + ")", r"\1.\2", text)
  text = re.sub(u"([iuüyIUÜY]" + accent_c + "*" + stress_c + u")(h?[aeoö])", r"\1.\2", text)
  text = rsub_repeatedly(u"([iuüyIUÜY]" + accent_c + "*" + stress_c + ")(h?" + V + accent_c + "*" + stress_c + ")", r"\1.\2", text)
  text = rsub_repeatedly("([iI]" + accent_c + "*)(h?i)", r"\1.\2", text)
  text = rsub_repeatedly(u"([uüUÜ]" + accent_c + u"*)(h?[uü])", r"\1.\2", text)
  text = text.replace(SYLDIV, ".")
  text = text.replace(TEMP_I, "i")
  text = text.replace(TEMP_U, "u")
  text = text.replace(TEMP_Y_CONS, "y")
  text = text.replace(TEMP_CH, "ch")
  text = text.replace(TEMP_GH, "gh")
  text = text.replace(TEMP_GN, "gn")
  text = text.replace(TEMP_GL, "gl")
  text = text.replace(TEMP_SH, "sh")
  text = text.replace(TEMP_SC, "sc")
  text = text.replace(TEMP_QU, "qu")
  text = text.replace(TEMP_QU_CAPS, "Qu")
  text = text.replace(TEMP_GU, "gu")
  text = text.replace(TEMP_GU_CAPS, "Gu")
  return recompose(text)

def adjust_initial_capital(arg, pagetitle, pagemsg, origline):
  arg_words = arg.split(" ")
  pagetitle_words = pagetitle.split(" ")
  new_arg = arg
  if len(arg_words) == len(pagetitle_words):
    new_arg_words = []
    for arg_word, pagetitle_word in zip(arg_words, pagetitle_words):
      new_arg_word = arg_word
      m = re.search(u"^(" + pron_sign_c + "*)(.*)$", arg_word)
      arg_word_prefix, arg_word = m.groups()
      if len(arg_word) > 0 and len(pagetitle_word) > 0 and arg_word[0] != pagetitle_word[0]:
        if arg_word[0].upper() == pagetitle_word[0] or remove_accents(arg_word[0]).upper() == pagetitle_word[0]:
          new_arg_word = arg_word_prefix + arg_word[0].upper() + arg_word[1:]
        elif arg_word[0].lower() == pagetitle_word[0] or remove_accents(arg_word[0]).lower() == pagetitle_word[0]:
          new_arg_word = arg_word_prefix + arg_word[0].lower() + arg_word[1:]
      new_arg_words.append(new_arg_word)
    new_arg = " ".join(new_arg_words)
    if new_arg != arg:
      pagemsg("Replacing respelling %s with case-adjusted equivalent %s based on page title: %s" %
          (arg, new_arg, origline))
      arg = new_arg
  return arg

def normalize_bare_arg(arg, pagetitle):
  # FIXME, handle auto-stressing and such.
  if arg == "+":
    return pagetitle
  return arg

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, program_args.verbose)
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

  retval = blib.find_modifiable_lang_section(text, None if program_args.partial_page else "Italian", pagemsg,
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
      num_it_IPA = 0
      saw_it_pr = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn in ["it-pr", "it-pronunciation"]:
          saw_it_pr = True
          break
        if tn == "it-IPA":
          num_it_IPA += 1
      if saw_it_pr:
        pagemsg("Already saw {{it-pr}}, skipping: %s" % unicode(t))
        continue
      if num_it_IPA == 0:
        pagemsg("WARNING: Didn't see {{it-IPA}} in Pronunciation section, skipping")
        continue
      if num_it_IPA > 1:
        pagemsg("WARNING: Saw multiple {{it-IPA}} in Pronunciation section, skipping")
        continue
      lines = subsections[k + 1].strip().split("\n")
      # Remove blank lines.
      lines = [line for line in lines if line]
      hyph_lines = []
      homophone_lines = []
      rfap_lines = []
      rhyme_lines = []
      must_continue = False
      audioarg = ""
      args = []
      bare_args = []
      args_for_hyph = []
      for line in lines:
        origline = line
        # In case of "* {{it-IPA|...}}", chop off the "* ".
        line = re.sub(r"^\*\s*(\{\{it-IPA)", r"\1", line)
        if line.startswith("{{it-IPA"):
          if args:
            pagemsg("WARNING: Something wrong, already saw {{it-IPA}}?: %s" % origline)
            must_continue = True
            break
          ipat = verify_template_is_full_line("it-IPA", line)
          if ipat is None:
            must_continue = True
            break
          bare_args = blib.fetch_param_chain(ipat, "1") or [u"+"]
          bare_args = [u"+" if arg == pagetitle else arg for arg in bare_args]
          bare_args = [adjust_initial_capital(arg, pagetitle, pagemsg, origline) for arg in bare_args]
          normalized_bare_args = [normalize_bare_arg(arg, pagetitle) for arg in bare_args]
          args = [x for x in bare_args]

          args_for_hyph = []
          for arg in normalized_bare_args:
            hypharg = (
              arg.replace("ddz", "zz").replace("tts", "zz").replace("dz", "z").replace("ts", "z")
              .replace("Dz", "Z").replace("Ts", "Z").replace("[s]", "s").replace("[z]", "z")
            )
            hypharg = re.sub(pron_sign_c, "", hypharg)
            putative_pagetitle = remove_secondary_stress(hypharg.replace(".", ""))
            putative_pagetitle = remove_non_final_accents(putative_pagetitle)
            # Check if the normalized pronunciation is the same as the page title, if so use the semi-normalized
            # pronunciation for hyphenation. If a word in the page title is a single syllable, it may or may not
            # have an accent on it, so also remove final monosyllabic accents from the normalized pronunciation
            # when comparing. (Don't remove from both normalized pronunciation and page title because we don't want
            # pronunciation rè to match page title ré or vice versa.)
            if putative_pagetitle == pagetitle or remove_final_monosyllabic_accents(putative_pagetitle) == pagetitle:
              args_for_hyph.append(hypharg)

          for param in ipat.params:
            pn = pname(param)
            pv = unicode(param.value)
            if re.search("^[0-9]+$", pn):
              continue
            m = re.search("^(ref|qual)([0-9]*)$", pn)
            if m:
              parampref, argnum = m.groups()
              argnum = int(argnum or "1") - 1
              if argnum >= len(args):
                pagemsg("WARNING: Argument %s=%s specifies nonexistent pronun, skipping: %s" % (
                  pn, pv, origline))
                must_continue = True
                break
              args[argnum] += "<%s:%s>" % (parampref, pv)
            else:
              pagemsg("WARNING: Unrecognized param %s=%s in {{it-IPA}}, skipping: %s" % (
                pn, pv, origline))
              must_continue = True
              break
          if must_continue:
            break
          continue
        if line.startswith("{{rfap"):
          line = "* " + line
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
        elif line.startswith("{{rfap"):
          rfap_lines.append(line)
        elif line.startswith("{{audio"):
          audiot = verify_template_is_full_line("audio", line)
          if audiot is None:
            must_continue = True
            break
          if getparam(audiot, "1") != "it":
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
          audiopart = "<audio:%s%s>" % (audiofile, audiogloss)
          audioarg += audiopart
          pagemsg("Replacing %s with argument part %s" % (unicode(audiot), audiopart))
          extra_notes.append("incorporate %s into {{it-pr}}" % unicode(audiot))
        elif line.startswith("{{rhyme"):
          rhyme_lines.append(line)
        elif remove_accents(line) == remove_accents(pagetitle):
          pagemsg("Ignoring Pronunciation section line that looks like a possibly-accented page title: %s" % origline)
        else:
          pagemsg("WARNING: Unrecognized Pronunciation section line, skipping: %s" % origline)
          must_continue = True
          break
      if must_continue:
        continue

      if rhyme_lines:
        rhyme_error = False
        rhyme_pronuns = []
        for bare_arg in normalized_bare_args:
          pronun = expand_text(u"{{#invoke:it-pronunciation|to_phonemic_bot|%s}}" % re.sub(pron_sign_c, "", bare_arg))
          if not pronun:
            rhyme_error = True
            break
          rhyme_pronun = (
            re.sub(u"^[^aeiouɛɔ]*", "", re.sub(u".*[ˌˈ]", "", pronun)).replace(TIE, "")
            .replace(".", ""))
          if rhyme_pronun not in rhyme_pronuns:
            rhyme_pronuns.append(rhyme_pronun)
        if not rhyme_error:
          saw_non_matching_rhyme = False
          normalized_rhymes = []
          rhyme_line_text = ", ".join(rhyme_lines)
          normalized_bare_arg_text = ",".join(normalized_bare_args)
          rhyme_pronun_text = ",".join(rhyme_pronuns)
          for rhyme_line in rhyme_lines:
            rhymet = verify_template_is_full_line(["rhyme", "rhymes"], rhyme_line)
            if not rhymet:
              break
            if getparam(rhymet, "1") != "it":
              pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(rhymet), rhyme_line))
              break
            rhymes = []
            must_break = False
            num_syl = ""
            rhyme_specific_num_syl = []
            for param in rhymet.params:
              pn = pname(param)
              pv = unicode(param.value)
              if not re.search("^s?[0-9]*$", pn):
                pagemsg("WARNING: Unrecognized param %s=%s in {{%s}}, not removing: %s" %
                    (pn, pv, tname(rhymet), rhyme_line))
                must_break = True
                break
              if pn == "s":
                num_syl = "<%s>" % pv
              elif pn.startswith("s"):
                rhyme_no = int(pn[1:]) - 1
                rhyme_specific_num_syl.append((rhyme_no, pv))
              elif int(pn) > 1:
                if pv:
                  rhymes.append([pv, ""])
            if must_break:
              break
            for rhyme_no, this_num_syl in rhyme_specific_num_syl:
              if rhyme_no >= len(rhymes):
                pagemsg("WARNING: Argument s%s=%s specifies nonexistent rhyme, skipping: %s" % (
                  rhyme_no + 1, this_num_syl, rhyme_line))
                must_break = True
                break
              rhymes[rhyme_no][1] = "<%s>" % this_num_syl
            if must_break:
              break
            for rhyme, this_num_syl in rhymes:
              normalized_rhyme = re.sub(u"([aeɛoɔu])i", r"\1j", rhyme).replace("sm", "zm")
              normalized_rhyme = re.sub(u"a[uu̯](" + C + ")", r"aw\1", normalized_rhyme)
              this_num_syl = this_num_syl or num_syl
              if this_num_syl and not args_for_hyph and not hyph_lines:
                pagemsg("WARNING: Explicit number of syllables %s given for explicit rhyme %s and no default or explicit hyphenation: %s"
                    % (this_num_syl, rhyme, rhyme_line_text))
                saw_non_matching_rhyme = True
                normalized_rhymes.append(normalized_rhyme + this_num_syl)
              else:
                normalized_rhymes.append(normalized_rhyme)
                if rhyme in rhyme_pronuns:
                  pagemsg("Removing explicit rhyme %s, same as pronunciation-based rhyme for spelling(s) '%s': %s"
                      % (rhyme, normalized_bare_arg_text, rhyme_line_text))
                elif normalized_rhyme in rhyme_pronuns:
                  pagemsg("Removing explicit rhyme %s normalized to %s, same as pronunciation-based rhyme for spelling(s) '%s': %s"
                      % (rhyme, normalized_rhyme, normalized_bare_arg_text, rhyme_line_text))
                elif rhyme != normalized_rhyme:
                  pagemsg("WARNING: Explicit rhyme %s normalized to %s not same as pronunciation-based rhyme(s) (%s) for spelling(s) '%s': %s"
                      % (rhyme, normalized_rhyme, rhyme_pronun_text, normalized_bare_arg_text, rhyme_line_text))
                  saw_non_matching_rhyme = True
                else:
                  pagemsg("WARNING: Explicit rhyme %s not same as pronunciation-based rhyme(s) (%s) for spelling(s) '%s': %s"
                      % (rhyme, rhyme_pronun_text, normalized_bare_arg_text, rhyme_line_text))
                  saw_non_matching_rhyme = True
          else: # no break
            if saw_non_matching_rhyme:
              pagemsg("Not all explicit rhymes (%s) could be matched against pronunciation-based rhyme(s) (%s) for spelling(s) '%s', adding explicitly: %s"
                  % (",".join(normalized_rhymes), rhyme_pronun_text, normalized_bare_arg_text, rhyme_line_text))
              args[-1] += "<rhyme:%s>" % ",".join(normalized_rhymes)
            rhyme_lines = []

      if not args:
        pagemsg("WARNING: Something wrong, didn't see {{it-IPA}}?")
        continue
      args[-1] += audioarg

      if hyph_lines:
        if len(hyph_lines) > 1:
          pagemsg("WARNING: Multiple hyphenation lines, not removing: %s" % ", ".join(hyph_lines))
        else:
          assert hyph_lines[0].startswith("* ")
          hyph_line = hyph_lines[0][2:]
          hyph_templates = re.split(", *", hyph_line)
          hyphs = []
          for hyph_template in hyph_templates:
            hypht = verify_template_is_full_line(["hyph", "hyphenation"], hyph_template)
            if not hypht:
              break
            syls = []
            if getparam(hypht, "1") != "it":
              pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(hypht), hyph_line))
              break
            else:
              must_break = False
              for param in hypht.params:
                pn = pname(param)
                pv = unicode(param.value)
                if not re.search("^[0-9]+$", pn) and pn != "nocaption":
                  pagemsg("WARNING: Unrecognized param %s=%s in {{%s}}, not removing: %s" %
                      (pn, pv, tname(hypht), hyph_line))
                  must_break = True
                  break
                if pn != "nocaption" and int(pn) > 1:
                  if not pv:
                    hyphs.append(syls)
                    syls = []
                  else:
                    syls.append(pv)
              if must_break:
                break
              if syls:
                hyphs.append(syls)
          else: # no break
            if hyphs:
              specified_hyphenations = [".".join(syls) for syls in hyphs]
              specified_hyphenations = [
                re.sub(u"([áíúÁÍÚ])", lambda m: acute_to_grave[m.group(1)], hyph) for hyph in specified_hyphenations]
              specified_hyphenations = [re.sub("''+", "", hyph) for hyph in specified_hyphenations]
              specified_hyphenations = [
                adjust_initial_capital(hyph, pagetitle, pagemsg, hyph_line) for hyph in specified_hyphenations]
              specified_hyphenations = [re.sub(u"î([ -]|$)", r"i\1", hyph) for hyph in specified_hyphenations]
              hyphenations = [remove_secondary_stress(generate_hyphenation_from_spelling(arg)) for arg in args_for_hyph]
              if set(specified_hyphenations) < set(hyphenations):
                pagemsg("Removing explicit hyphenation(s) %s that are a subset of auto-hyphenation(s) %s: %s" %
                    (",".join(specified_hyphenations), ",".join(hyphenations), hyph_line))
              elif set(specified_hyphenations) != set(hyphenations):
                hyphenations_without_accents = [remove_accents(hyph) for hyph in hyphenations]
                rehyphenated_specified_hyphenations = [
                  generate_hyphenation_from_spelling(hyph) for hyph in specified_hyphenations
                ]
                def indices_of_syllable_markers(hyph):
                  # Get the character indices of the syllable markers, but not counting the syllable markers themselves
                  # (i.e. return the number of characters preceding the syllable marker).
                  raw_indices = [ind for ind, ch in enumerate(hyph) if ch == "."]
                  adjusted_indices = [ind - offset for offset, ind in enumerate(raw_indices)]
                  return set(adjusted_indices)
                if set(specified_hyphenations) == set(hyphenations_without_accents):
                  pagemsg("Removing explicit hyphenation(s) %s that are missing accents but otherwise same as auto-hyphenation(s) %s: %s" %
                    (",".join(specified_hyphenations), ",".join(hyphenations), hyph_line))
                elif set(rehyphenated_specified_hyphenations) == set(hyphenations):
                  pagemsg("Removing explicit hyphenation(s) %s that are missing syllable breaks but otherwise same as auto-hyphenation(s) %s (verified by rehyphenation): %s" %
                    (",".join(specified_hyphenations), ",".join(hyphenations), hyph_line))
                elif (len(specified_hyphenations) == 1 and len(hyphenations) == 1
                    and specified_hyphenations[0].replace(".", "") == hyphenations[0].replace(".", "")
                    and indices_of_syllable_markers(specified_hyphenations[0]) < indices_of_syllable_markers(hyphenations[0])):
                  pagemsg("Removing explicit hyphenation(s) %s that are missing syllable breaks but otherwise same as auto-hyphenation(s) %s (verified that explicit hyphenation indices are subset of auto-hyphenation indices): %s" %
                    (",".join(specified_hyphenations), ",".join(hyphenations), hyph_line))
                else:
                  if not hyphenations:
                    pagemsg("WARNING: Explicit hyphenation(s) %s but no auto-hyphenations, adding explicitly: %s" %
                        (",".join(specified_hyphenations), hyph_line))
                  else:
                    pagemsg("WARNING: Explicit hyphenation(s) %s not equal to auto-hyphenation(s) %s, adding explicitly: %s" %
                        (",".join(specified_hyphenations), ",".join(hyphenations), hyph_line))
                  args[-1] += "<hyph:%s>" % ",".join(specified_hyphenations)
              else:
                pagemsg("Removed explicit hyphenation(s) same as auto-hyphenation(s): %s" % hyph_line)
              hyph_lines = []

      if args == ["+"]:
        it_pr = "{{it-pr}}"
      else:
        it_pr = "{{it-pr|%s}}" % ",".join(args)
      pagemsg("Replaced %s with %s" % (unicode(ipat), it_pr))

      all_lines = "\n".join([it_pr] + rhyme_lines + rfap_lines + hyph_lines + homophone_lines)
      newsubsec = "%s\n\n" % all_lines
      if subsections[k + 1] != newsubsec:
        this_notes = ["convert {{it-IPA}} to {{it-pr}}"] + extra_notes
        notes.extend(this_notes)
      subsections[k + 1] = newsubsec

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Convert {{it-IPA}} to {{it-pr}}", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
program_args = parser.parse_args()
start, end = blib.parse_start_end(program_args.start, program_args.end)

blib.do_pagefile_cats_refs(program_args, start, end, process_text_on_page, edit=True, stdin=True)
