#!/usr/bin/env python
# -*- coding: utf-8 -*-

# FIXME: Lowercase pronunciations for capitalized lemmas (DONE)
# FIXME: Lowercase hyphenations for capitalized lemmas (DONE)
# FIXME: V.sCV or Vs.CV? (DONE)
# FIXME: Handle [s] (DONE)
# FIXME: Handle underbar for trailing secondary stress (DONE)
# FIXME: Consider removing secondary stress as in mèrcoledì and òligonucleotìde? (DONE)
# FIXME: Handle pronunciations without stress such as 'fatto' and 'kaf', those defaulted
#        completely, those with + and those using ^ò and such (DONE)
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
# FIXME: Convert acute to grave in pronunciation respelling. (DONE)
# FIXME: [[postdiluviano]] hyphenated incorrectly as pos.tdi.lu.vià.no, [[lambdacismo]] hyphenated incorrectly as
#        lam.bda.cì.smo, similarly for [[postcommunio]], [[sternbergia]]
# FIXME: Remove final *° etc. from respelling before generating rhymes. (DONE)
# FIXME: Handle + when generating rhymes. (DONE)
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
#        Etymology section or moving above all sections if no numbered Etymology section. (DONE)

import pywikibot, re, sys, codecs, argparse, unicodedata

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname, rsub_repeatedly

AC = u"\u0301" # acute =  ́
GR = u"\u0300" # grave =  ̀
CFLEX = u"\u0302" # circumflex =  ̂
TILDE = u"\u0303" # tilde =  ̃
DIA = u"\u0308" # diaeresis =  ̈
TIE = u"\u0361" # tie =  ͡
DOTOVER = u"\u0307" # dot over =  ̇ = signal unstressed word
DOTUNDER = u"\u0323" # dot under =  ̣ = unstressed vowel with quality marker
LINEUNDER = u"\u0331" # line under =  ̱ = secondary-stressed vowel with quality marker
SYLDIV = u"\uFFF0" # used to represent a user-specific syllable divider (.) so we won't change it
accent = AC + GR + CFLEX + DOTOVER + DOTUNDER + LINEUNDER
accent_c = "[" + accent + "]"
stress = AC + GR
stress_c = "[" + AC + GR + "]"
ipa_stress = u"ˈˌ"
ipa_stress_c = "[" + ipa_stress + "]"
separator = accent + ipa_stress + r"# \-." + SYLDIV
separator_c = "[" + separator + "]"
vowel = u"aeiouyöüAEIOUYÖÜ"
V = "[" + vowel + "]" # vowel class
NV = "[^" + vowel + "]" # non-vowel class
C = "[^" + vowel + separator + "]" # consonant class including h
pron_sign = u"#!*°"
pron_sign_c = "[" + pron_sign + "]"

acute_to_grave = {u"á": u"à", u"í": u"ì", u"ú": u"ù", u"Á": u"À", u"Í": u"Ì", u"Ú": u"Ù"}

recognized_suffixes = {
  # -(m)ente, -(m)ento
  ("ment([eo])", ur"mént\1"), # must precede -ente/o below
  ("ent([eo])", ur"ènt\1"), # must follow -mente/o above
  # verbs
  ("izzare", u"iddzàre"), # must precede -are below
  ("izzarsi", u"iddzàrsi"), # must precede -arsi below
  ("([ai])re", r"\1" + GR + "re"), # must follow -izzare above
  ("([ai])rsi", r"\1" + GR + "rsi"), # must follow -izzarsi above
  # nouns
  ("izzatore", u"iddzatóre"), # must precede -tore below
  ("([st])ore", ur"\1óre"), # must follow -izzatore above
  ("izzatrice", u"iddzatrìce"), # must precede -trice below
  ("trice", u"trìce"), # must follow -izzatrice above
  ("izzazione", u"iddzatsióne"), # must precede -zione below
  ("zione", u"tsióne"), # must precede -one below and follow -izzazione above
  ("one", u"óne"), # must follow -zione above
  ("acchio", u"àcchio"),
  ("acci([ao])", ur"àcci\1"),
  ("([aiu])ggine", r"\1" + GR + "ggine"),
  ("aggio", u"àggio"),
  ("([ai])gli([ao])", r"\1" + GR + r"gli\2"),
  ("ai([ao])", ur"ài\1"),
  ("([ae])nza", r"\1" + GR + "ntsa"),
  ("ario", u"àrio"),
  ("([st])orio", ur"\1òrio"),
  ("astr([ao])", ur"àstr\1"),
  ("ell([ao])", ur"èll\1"),
  ("etta", u"étta"),
  # do not include -etto, both ètto and étto are common
  ("ezza", u"éttsa"),
  ("ficio", u"fìcio"),
  ("ier([ao])", ur"ièr\1"),
  ("ifero", u"ìfero"),
  ("ismo", u"ìsmo"),
  ("ista", u"ìsta"),
  ("izi([ao])", ur"ìtsi\1"),
  ("logia", u"logìa"),
  # do not include -otto, both òtto and ótto are common
  ("tudine", u"tùdine"),
  ("ura", u"ùra"),
  ("([^aeo])uro", ur"\1ùro"),
  # adjectives
  ("izzante", u"iddzànte"), # must precede -ante below
  ("ante", u"ànte"), # must follow -izzante above
  ("izzando", u"iddzàndo"), # must precede -ando below
  ("([ae])ndo", r"\1" + GR + "ndo"), # must follow -izzando above
  ("([ai])bile", r"\1" + GR + "bile"),
  ("ale", u"àle"),
  ("([aeiou])nico", r"\1" + GR + "nico"),
  ("([ai])stic([ao])", r"\1" + GR + r"stic\2"),
  # exceptions to the following: àbato, àcato, acròbata, àgata, apòstata, àstato, cìato, fégato, omeòpata,
  # sàb(b)ato, others?
  ("at([ao])", ur"àt\1"),
  ("([ae])tic([ao])", r"\1" + GR + r"tic\2"),
  ("ense", u"ènse"),
  ("esc([ao])", ur"ésc\1"),
  ("evole", u"évole"),
  # FIXME: Systematic exceptions to the following in 3rd plural present tense verb forms
  ("ian([ao])", ur"iàn\1"),
  ("iv([ao])", ur"ìv\1"),
  ("oide", u"òide"),
  ("oso", u"óso"),
}

unstressed_words = {
  "il", "lo", "la", "i", "gli", "le", # definite articles
  "un", # indefinite articles
  "mi", "ti", "si", "ci", "vi", "li", # object pronouns
  "me", "te", "se", "ce", "ve", "ne", # conjunctive object pronouns
  "e", "ed", "o", "od", # conjunctions
  "ho", "hai", "ha", # forms of [[avere]]
  "chi", "che", "non", # misc particles
  "di", "del", "dei", # prepositions
  "a", "ad", "al", "ai",
  "da", "dal", "dai",
  "in", "nel", "nei",
  "con", "col", "coi",
  "su", "sul", "sui",
  "per", "pei",
  "tra", "fra",
}

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

def normalize_bare_arg(arg, pagetitle, pagemsg):
  origarg = arg
  if arg == "+":
    arg = pagetitle
  abbrev_text = None
  m = re.search(u"^(" + pron_sign_c + "*)(.*?)(" + pron_sign_c + "*)$", arg)
  arg_prefix, arg, arg_suffix = m.groups()
  if re.search(ur"^\^[àéèìóòù]$", arg):
    if re.search("[ %-]", pagetitle):
      pagemsg("WARNING: With abbreviated vowel spec %s, the page name should be a single word: %s" % (arg, pagetitle))
      return None
    abbrev_text = decompose(arg)
    arg = pagetitle
  origwords = re.split("([ %-]+)", arg)
  arg = decompose(arg)
  words = re.split("([ %-]+)", arg)
  for i, word in enumerate(words):
    if (i % 2) == 0: # an actual word, not a separator
      m = re.search(u"^(" + pron_sign_c + "*)(.*?)(" + pron_sign_c + "*)$", word)
      word_prefix, word, word_suffix = m.groups()
      def err(msg):
        pagemsg("WARNING: " + msg + ": " + origwords[i // 2])
      is_prefix = (
        # utterance-final followed by a hyphen, or
        i == len(words) - 3 and words[i+1] == "-" and words[i+2] == "" or
        # non-utterance-final followed by a hyphen
        i <= len(words) - 3 and words[i+1] == "- "
      )
      # First apply abbrev spec e.g. (à) or (ó) if given.
      if abbrev_text:
        vowel_count = len(re.sub(NV, "", word))
        abbrev_sub = abbrev_text[1:] # chop off initial ^
        abbrev_vowel = abbrev_sub[0]
        if vowel_count == 0:
          err("Abbreviated spec " + abbrev_text + " can't be used with nonsyllabic word")
          return None
        elif vowel_count == 1:
          m = re.search("^(.*)(" + V + ")(" + NV + "*)$", word)
          if not m:
            err("Internal error: Couldn't match monosyllabic word: " + word)
            return None
          before, vow, after = m.groups()
          if abbrev_vowel != vow:
            err("Abbreviated spec " + abbrev_text + " doesn't match vowel " + vow.lower())
            return None
          word = before + abbrev_sub + after
        else:
          m = re.search("^(.*?)(" + V + ")(" + NV + "*" + V + NV + "*)$", word)
          if not m:
            err("Internal error: Couldn't match multisyllabic word: " + word)
            return None
          before, penultimate, after = m.groups()
          m = re.search("^(.*?)(" + V + ")(" + NV + "*)$", before)
          before2, antepenultimate, after2 = m.groups()
          if abbrev_vowel != penultimate and abbrev_vowel != antepenultimate:
            err("Abbreviated spec " + abbrev_text + " doesn't match penultimate vowel " +
                penultimate.lower() + (antepenultimate and " or antepenultimate vowel " +
                  antepenultimate.lower() or ""))
            return None
          if penultimate == antepenultimate:
            err("Can't use abbreviated spec " + abbrev_text + " here because penultimate and " +
              "antepenultimate are the same")
            return None
          if abbrev_vowel == antepenultimate:
            word = before2 + abbrev_sub + after2 + penultimate + after
          elif abbrev_vowel == penultimate:
            word = before + abbrev_sub + after
          else:
            err("Internal error: abbrev_vowel from abbrev_text " + abbrev_text +
              " didn't match any vowel or glide: " + origtext)
            return None

      if not is_prefix:
        if not re.search(stress_c, word):
          # Apply suffix respellings.
          for orig, respelling in recognized_suffixes:
            newword = re.sub(orig + "$", respelling, word)
            if newword != word:
              # Decompose again because suffix replacements may have accented chars.
              word = decompose(newword)
              break

        # Auto-stress some monosyllabic and bisyllabic words.
        if word not in unstressed_words and not re.search("[" + AC + GR + DOTOVER + "]", word):
          vowel_count = len(re.sub(NV, "", word))
          if vowel_count > 2:
            err("With more than two vowels and an unrecogized suffix, stress must be explicitly given")
            return None
          else:
            m = re.search("^(.*?)(" + V + ")(.*)$", word)
            if m:
              before, vow, after = m.groups()
              if vow in ["e", "o", "E", "O"]:
                err(u"When stressed vowel is e or o, it must be marked é/è or ó/ò to indicate quality")
                return None
              word = before + vow + GR + after

      words[i] = word_prefix + word + word_suffix

  arg = recompose(arg_prefix + "".join(words) + arg_suffix)
  if arg != origarg:
    pagemsg("Normalized original argument %s to %s" % (origarg, arg))
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

  sect_for_wiki = 0
  for k in xrange(1, len(subsections), 2):
    if re.search(r"==\s*Etymology [0-9]+\s*==", subsections[k]):
      sect_for_wiki = k + 1
    elif re.search(r"==\s*Pronunciation\s*==", subsections[k]):
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
      lines_so_far = []
      for lineind, line in enumerate(lines):
        origline = line
        lines_so_far.append(line)
        # In case of "* {{it-IPA|...}}", chop off the "* ".
        line = re.sub(r"^\*\s*(\{\{it-IPA)", r"\1", line)
        if line.startswith("{{it-IPA"):
          if args:
            pagemsg("WARNING: Something wrong, already saw {{it-IPA}}?: %s" % origline)
            must_continue = True
            break
          outer_ref_arg = None
          m = re.search("^(.*?) *<ref>(.*?)</ref>$", line)
          if m:
            line, outer_ref_arg = m.groups()
          ipat = verify_template_is_full_line("it-IPA", line)
          if ipat is None:
            must_continue = True
            break
          bare_args = blib.fetch_param_chain(ipat, "1") or [u"+"]
          bare_args = [u"+" if arg == pagetitle else arg for arg in bare_args]
          bare_args = [adjust_initial_capital(arg, pagetitle, pagemsg, origline) for arg in bare_args]
          bare_args = [re.sub(u"([áíúÁÍÚ])", lambda m: acute_to_grave[m.group(1)], arg) for arg in bare_args]
          normalized_bare_args = [
            normalize_bare_arg(arg, pagetitle, lambda msg: pagemsg("%s: %s" % (msg, origline)))
            for arg in bare_args
          ]
          if None in normalized_bare_args:
            must_continue = True
            break
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
          if outer_ref_arg:
            if "<ref:" in args[-1]:
              pagemsg("WARNING: Trying to add outside ref %s into {{it-IPA}} but already has ref in arg %s, skipping: %s"
                  % (outer_ref_arg, args[-1], origline))
              must_continue = True
              break
            else:
              args[-1] += "<ref:%s>"  % outer_ref_arg
              extra_notes.append("incorporate outer <ref>...</ref> into {{it-pr}}")
          continue
        if line.startswith("{{rfap"):
          line = "* " + line
        if line.startswith("{{wiki"):
          subsections[sect_for_wiki] = line + "\n" + subsections[sect_for_wiki]
          # Remove the {{wikipedia}} line from lines seen so far. Put back the remaining lines in case we
          # run into a problem later on, so we don't end up duplicating the {{wikipedia}} line. We accumulate
          # lines like this in case for some reason we have two {{wikipedia}} lines in the Pronunciation section.
          del lines_so_far[-1]
          subsections[k + 1] = "%s\n\n" % (lines_so_far + lines[lineind + 1:])
          notes.append("move {{wikipedia}} line to top of etym section")
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
              extra_notes.append("incorporate non-default rhymes into {{it-pr}}")
            else:
              extra_notes.append("remove rhymes that are generated automatically by {{it-pr}}")
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
                  extra_notes.append("incorporate non-default hyphenations into {{it-pr}}")
              else:
                pagemsg("Removed explicit hyphenation(s) same as auto-hyphenation(s): %s" % hyph_line)
                extra_notes.append("remove hyphenations that are generated automatically by {{it-pr}}")
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
