#!/usr/bin/env python3
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
#        [[rapsodia]], [[rapsodico]], [[dipsomane]], [[rapsodo]], [[-opsia]] with p.s. (DONE)
# FIXME: Possibly remove space when hyphenating multiword terms and terms with hyphens in them e.g. [[pera spadona]],
#        [[alveolo-palatale]], [[bosniaco-erzegovino]]. Keep primary accents in each word but don't add accents to
#        unstressed words, as in [[immagine di sé]] respelled ''immàgine di sé'', [[erba da spazzola]] respelled
#        ''èrba da spàttsola''. (DONE)
# FIXME: Convert acute to grave in pronunciation respelling. (DONE)
# FIXME: [[postdiluviano]] hyphenated incorrectly as pos.tdi.lu.vià.no, [[lambdacismo]] hyphenated incorrectly as
#        lam.bda.cì.smo, similarly for [[postcommunio]], [[sternbergia]] (DONE)
# FIXME: Remove final *° etc. from respelling before generating rhymes. (DONE)
# FIXME: Handle + when generating rhymes. (DONE)
# FIXME: Instead of skipping page entirely when rhyme mismatches, add rhyme explicitly. (DONE)
# FIXME: If explicit num syllables given and no default or explicit hyphenation, include num syls. (DONE)
# FIXME: Lots of mismatches where explicit rhyme has ɔi/oi/ai/ɛi/ei/ui for pronunciation rhyme ɔj/oj/etc., allow this.
#        Sometimes occurs non-finally, e.g. in [[braida]], [[dispaino]], [[intuino]]. (DONE)
# FIXME: Several mismatches where explicit rhyme has sm for pronunciation rhyme zm, allow this. (DONE)
# FIXME: Several mismatches where explicit rhyme has non-final auC or au̯C for pronunciation rhyme awC, allow this. (DONE)
# FIXME: Pronunciation incorrect for sìi as /sij/. (DONE)
# FIXME: [[edui]] correctly pronounced /ɛdwi/ (as per rhyme) or /ɛduj/ (as per {{it-IPA}})?
# FIXME: Remove circumflex on final î in explicit hyphenation. (DONE)
# FIXME: Ignore pronunciation lines consisting of just the page title, possibly accented. (DONE)
# FIXME: Correctly handle {{rfap}} lines. (DONE)
# FIXME: Correctly handle {{wikipedia|lang=it}} and {{wiki|lang=it}} lines, moving below most recent numbered
#        Etymology section or moving above all sections if no numbered Etymology section. (DONE)
# FIXME: Add spaces around [,–—|!?] in the middle of text and then remove before calling normalize_bare_arg().
# FIXME: Remove pron_sign_c from text, probably including * in the middle, before calling normalize_bare_arg().
# FIXME: Remove secondary stress after syllabification but use a separate sign to indicate syllabification between
#        words. (DONE)
# FIXME: Support <hmp:> for homophones. (DONE)

import pywikibot, re, sys, argparse, unicodedata

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname, rsub_repeatedly

AC = "\u0301" # acute =  ́
GR = "\u0300" # grave =  ̀
CFLEX = "\u0302" # circumflex =  ̂
TILDE = "\u0303" # tilde =  ̃
DIA = "\u0308" # diaeresis =  ̈
TIE = "\u0361" # tie =  ͡
DOTOVER = "\u0307" # dot over =  ̇ = signal unstressed word
DOTUNDER = "\u0323" # dot under =  ̣ = unstressed vowel with quality marker
LINEUNDER = "\u0331" # line under =  ̱ = secondary-stressed vowel with quality marker
SYLDIV = "\uFFF0" # used to represent a user-specific syllable divider (.) so we won't change it
WORDDIV = "\uFFF1" # used to represent a user-specific word divider (.) so we won't change it
accent = AC + GR + CFLEX + DOTOVER + DOTUNDER + LINEUNDER
accent_c = "[" + accent + "]"
stress = AC + GR
stress_c = "[" + AC + GR + "]"
ipa_stress = "ˈˌ"
ipa_stress_c = "[" + ipa_stress + "]"
separator_not_tie = accent + ipa_stress + r"# \-." + SYLDIV + WORDDIV
separator = separator_not_tie + "‿⁀'"
separator_c = "[" + separator + "]"
vowel = "aeiouyöüAEIOUYÖÜ"
vowel_not_i = "aeouyöüAEOUYÖÜ"
V = "[" + vowel + "]" # vowel class
V_NOT_I = "[" + vowel_not_i + "]" # vowel class not including i
NV = "[^" + vowel + "]" # non-vowel class
C = "[^" + vowel + separator + "]" # consonant class including h
C_OR_TIE = "[^" + vowel + separator_not_tie + "]" # consonant class including h and tie (‿⁀')
C_NOT_H = "[^" + vowel + separator + "h]" # consonant class not including h
C_NOT_SRZ = "[^" + vowel + separator + "srz]" # consonant class not including s/r/z
pron_sign = "#!*°"
pron_sign_c = "[" + pron_sign + "]"

acute_to_grave = {"á": "à", "í": "ì", "ú": "ù", "Á": "À", "Í": "Ì", "Ú": "Ù"}

recognized_suffixes = [
  # -(m)ente, -(m)ento
  ("ment([eo])", r"mént\1"), # must precede -ente/o below
  ("ent([eo])", r"ènt\1"), # must follow -mente/o above
  # verbs
  ("izzare", "iddzàre"), # must precede -are below
  ("izzarsi", "iddzàrsi"), # must precede -arsi below
  ("([ai])re", r"\1" + GR + "re"), # must follow -izzare above
  ("([ai])rsi", r"\1" + GR + "rsi"), # must follow -izzarsi above
  # nouns
  ("izzatore", "iddzatóre"), # must precede -tore below
  ("([st])ore", r"\1óre"), # must follow -izzatore above
  ("izzatrice", "iddzatrìce"), # must precede -trice below
  ("trice", "trìce"), # must follow -izzatrice above
  ("izzazione", "iddzatsióne"), # must precede -zione below
  ("zione", "tsióne"), # must precede -one below and follow -izzazione above
  ("one", "óne"), # must follow -zione above
  ("acchio", "àcchio"),
  ("acci([ao])", r"àcci\1"),
  ("([aiu])ggine", r"\1" + GR + "ggine"),
  ("aggio", "àggio"),
  ("([ai])gli([ao])", r"\1" + GR + r"gli\2"),
  ("ai([ao])", r"ài\1"),
  ("([ae])nza", r"\1" + GR + "ntsa"),
  ("ario", "àrio"),
  ("([st])orio", r"\1òrio"),
  ("astr([ao])", r"àstr\1"),
  ("ell([ao])", r"èll\1"),
  ("etta", "étta"),
  # do not include -etto, both ètto and étto are common
  ("ezza", "éttsa"),
  ("ficio", "fìcio"),
  ("ier([ao])", r"ièr\1"),
  ("ifero", "ìfero"),
  ("ismo", "ìsmo"),
  ("ista", "ìsta"),
  ("izi([ao])", r"ìtsi\1"),
  ("logia", "logìa"),
  # do not include -otto, both òtto and ótto are common
  ("tudine", "tùdine"),
  ("ura", "ùra"),
  ("([^aeo])uro", r"\1ùro"),
  # adjectives
  ("izzante", "iddzànte"), # must precede -ante below
  ("ante", "ànte"), # must follow -izzante above
  ("izzando", "iddzàndo"), # must precede -ando below
  ("([ae])ndo", r"\1" + GR + "ndo"), # must follow -izzando above
  ("([ai])bile", r"\1" + GR + "bile"),
  ("ale", "àle"),
  ("([aeiou])nico", r"\1" + GR + "nico"),
  ("([ai])stic([ao])", r"\1" + GR + r"stic\2"),
  # exceptions to the following: àbato, àcato, acròbata, àgata, apòstata, àstato, cìato, fégato, omeòpata,
  # sàb(b)ato, others?
  ("at([ao])", r"àt\1"),
  ("([ae])tic([ao])", r"\1" + GR + r"tic\2"),
  ("ense", "ènse"),
  ("esc([ao])", r"ésc\1"),
  ("evole", "évole"),
  # FIXME: Systematic exceptions to the following in 3rd plural present tense verb forms
  ("ian([ao])", r"iàn\1"),
  ("iv([ao])", r"ìv\1"),
  ("oide", "òide"),
  ("oso", "óso"),
]

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

# Apply canonical Unicode decomposition to text, e.g. è → e + ◌̀. But recompose ö and ü so we can treat them as single
# vowels, and put LINEUNDER/DOTUNDER/DOTOVER after acute/grave (canonical decomposition puts LINEUNDER and DOTUNDER
# first).
def decompose(text):
  # decompose everything but ö and ü
  text = unicodedata.normalize("NFD", text)
  text = text.replace("o" + DIA, "ö")
  text = text.replace("O" + DIA, "Ö")
  text = text.replace("u" + DIA, "ü")
  text = text.replace("U" + DIA, "Ü")
  text = re.sub("([" + LINEUNDER + DOTUNDER + DOTOVER + "])(" + stress_c + ")", r"\2\1", text)
  return text

def recompose(text):
  return unicodedata.normalize("NFC", text)

# Split into words. Hyphens separate words but not when used to denote affixes, i.e. hyphens between non-spaces
# separate words. Return value includes alternating words and separators. Use "".join(words) to reconstruct
# the initial text.
def split_but_rejoin_affixes(text):
  if not re.search(r"[\s\-]", text):
    return [text]
  end
  # First replace hyphens separating words with a special character. Remaining hyphens denote affixes and don't
  # get split. After splitting, replace the special character with a hyphen again.
  TEMP_HYPH = "\uFFF0"
  text = rsub_repeatedly(r"([^\s])-([^\s])", r"\1" + TEMP_HYPH + r"\2", text)
  words = re.split(r"([\s" + TEMP_HYPH + "]+)", text)
  return ["-" if word == TEMP_HYPH else word for word in words]

def remove_secondary_stress(text):
  words = split_but_rejoin_affixes(decompose(text))
  for i, word in enumerate(words):
    if i % 2 == 1: # a separator
      continue
    # Remove unstressed quality marks.
    word = re.sub(stress_c + DOTUNDER, "", word)
    # Remove secondary stresses. Specifically:
    # (1) Remove secondary stresses marked with LINEUNDER if there's a previously stressed vowel.
    # (2) Otherwise, just remove the LINEUNDER, leaving the accent mark, which will then be removed if there's
    #     a following stressed vowel, but left if it's the only stress in the word, as in có̱lle = con le.
    #     (In the process, we remove other non-stress marks.)
    # (3) Remove stress mark if there's a following stressed vowel.
    word = rsub_repeatedly("(" + stress_c + ".*)" + stress_c + LINEUNDER, r"\1", word)
    word = re.sub("[" + CFLEX + DOTOVER + DOTUNDER + LINEUNDER + "]", "", word)
    word = rsub_repeatedly(stress_c + "(.*" + stress_c + ")", r"\1", word)
    words[i] = word
  return recompose("".join(words))

def remove_accents(text):
  return recompose(re.sub(accent_c, "", decompose(text)))

def remove_non_final_accents(text):
  words = split_but_rejoin_affixes(decompose(text))
  # There should be no accents in separators.
  words = [rsub_repeatedly(accent_c + "(.)", r"\1", word) for word in words]
  return recompose("".join(words))

def remove_final_monosyllabic_accents(text):
  words = split_but_rejoin_affixes(decompose(text))
  # There should be no accents in separators.
  words = [re.sub("^([^" + vowel + "]*[" + vowel + "])" + accent_c + "$", r"\1", word) for word in words]
  return recompose("".join(words))

def syllabify_from_spelling(text):
  text = decompose(text)
  # Convert spaces and word-separating hyphens into syllable divisions.
  words = split_but_rejoin_affixes(text)
  for i, word in enumerate(words):
    if (i % 2) == 1: # a separator
      words[i] = WORDDIV
  text = "".join(words)
  TEMP_I = "\uFFF2"
  TEMP_I_CAPS = "\uFFF3"
  TEMP_U = "\uFFF4"
  TEMP_U_CAPS = "\uFFF5"
  TEMP_Y = "\uFFF6"
  TEMP_Y_CAPS = "\uFFF7"
  TEMP_G = "\uFFF8"
  TEMP_G_CAPS = "\uFFF9"
  # Change user-specified . into SYLDIV so we don't shuffle it around when dividing into syllables.
  text = text.replace(".", SYLDIV)
  # We propagate underscore this far specifically so we can distinguish g_n ([[wagneriano]]) from gn.
  # g_n should end up as g.n but gn should end up as .gn.
  g_to_temp_g = {"g": TEMP_G, "G": TEMP_G_CAPS}
  text = re.sub("([gG])('?)_('?[nN])", lambda m: g_to_temp_g[m.group(1)] + m.group(2) + m.group(3), text)
  # Now remove underscores before any further processing.
  text = text.replace("_", "")
  # i, u, y between vowels -> consonant-like substitutions:
  # With i: [[paranoia]], [[febbraio]], [[abbaiare]], [[aiutare]], etc.
  # With u: [[portauovo]], [[schopenhaueriano]], [[Malaui]], [[oltreuomo]], [[palauano]], [[tauone]], etc.
  # With y: [[ayatollah]], [[coyote]], [[hathayoga]], [[kayak]], [[uruguayano]], etc. [[kefiyyah]] needs special
  # handling.
  # Also with h, as in [[nahuatl]], [[ahia]], etc.
  # With h not dividing diphthongs: [[ahi]], [[ehi]], [[ahimè]], [[ehilà]], [[ohimè]], [[ohilà]], etc.
  # But in the common sequence -Ciuo- ([[figliuolo]], [[begliuomini]], [[giuoco]], [[nocciuola]], [[stacciuolo]],
  # [[oriuolo]], [[guerricciuola]], [[ghiaggiuolo]], etc.), both i and u are glides. In the sequence -quiV-
  # ([[quieto]], [[reliquia]], etc.), both u and i are glides, and probably also in -guiV-, but not in other -CuiV-
  # sequences such as [[buio]], [[abbuiamento]], [[gianduia]], [[cuiusso]], [[alleluia]], etc.). Special cases are
  # French-origin words like [[feuilleton]], [[rousseauiano]], [[gargouille]]; it's unlikely we can handle these
  # correctly automatically.
  #
  # We handle these cases as follows:
  # 1. q+TEMP_U etc. replace sequences of qu and gu with consonant-type codes. This allows us to distinguish
  #  -quiV-/-guiV- from other -CuiV-.
  # 2. We convert i in -ViV- sequences to consonant-type TEMP_I, but similarly for u in -VuV- sequences only if the
  #  first V isn't i, so -CiuV- remains with two vowels. The syllabification algorithm below will not divide iu
  #  or uV unless in each case the first vowel is stressed, so -CiuV- remains in a single syllable.
  # 3. As soon as we convert i to TEMP_I, we undo the u -> TEMP_U change for -quiV-/-guiV-, before u -> TEMP_U in
  #  -VuV- sequences.
  u_to_temp_u = {"u": TEMP_U, "U": TEMP_U_CAPS}
  text = re.sub("([qQgG])([uU])('?" + V + ")", lambda m: m.group(1) + u_to_temp_u[m.group(2)] + m.group(3), text)
  i_to_temp_i = {"i": TEMP_I, "I": TEMP_I_CAPS, "y": TEMP_Y, "Y": TEMP_Y_CAPS}
  text = rsub_repeatedly("(" + V + accent_c + "*[hH]?)([iIyY])(" + V + ")",
    lambda m: m.group(1) + i_to_temp_i[m.group(2)] + m.group(3), text)
  text = text.replace(TEMP_U, "u")
  text = text.replace(TEMP_U_CAPS, "U")
  text = rsub_repeatedly("(" + V_NOT_I + accent_c + "*[hH]?)([uU])(" + V + ")",
    lambda m: m.group(1) + u_to_temp_u[m.group(2)] + m.group(3), text)
  # Divide VCV as V.CV; but don't divide if C == h, e.g. [[ahimè]] should be ahi.mè.
  text = rsub_repeatedly("(" + V + accent_c + "*'?)(" + C_NOT_H + "'?" + V + ")", r"\1.\2", text)
  text = rsub_repeatedly("(" + V + accent_c + "*'?" + C + C_OR_TIE + "*)(" + C + "'?" + V + ")", r"\1.\2", text)
  # Examples in Olivetti like [[hathayoga]], [[telethon]], [[cellophane]], [[skyphos]], [[piranha]], [[bilharziosi]]
  # divide as .Ch. Exceptions are [[wahhabismo]], [[amharico]], [[kinderheim]], [[schopenhaueriano]] but the latter
  # three seem questionable as the pronunciation puts the first consonant in the following syllable and makes the h
  # silent.
  text = re.sub("(" + C_NOT_H + "'?)\.([hH])", r".\1\2", text)
  # gn represents a single sound so it should not be divided.
  text = re.sub("([gG])\.([nN])", r".\1\2", text)
  # Existing hyphenations of [[atlante]], [[Betlemme]], [[genetliaco]], [[betlemita]] all divide as .tl,
  # and none divide as t.l. No examples of -dl- but it should be the same per
  # http://www.italianlanguageguide.com/pronunciation/syllabication.asp.
  text = re.sub(r"([pbfvkcgqtdPBFVKCGQTD]'?)\.([lrLR])", r".\1\2", text)
  # Italian appears to divide sCV as .sCV e.g. pé.sca for [[pesca]], and similarly for sCh, sCl, sCr. Exceptions are
  # ss, sr, sz and possibly others.
  text = re.sub(r"([sS]'?)\.(" + C_NOT_SRZ + ")", r".\1\2", text)
  # Several existing hyphenations divide .pn and .ps and Olivetti agrees. We do this after moving across s so that
  # dispnea is divided dis.pnea. Olivetti has tec.no.lo.gì.a for [[tecnologia]], showing that cn divides as c.n, and
  # clàc.son, fuc.sì.na, ric.siò for [[clacson]], [[fucsina]], [[ricsiò]], showing that cs divides as c.s.
  text = re.sub(r"([pP]'?)\.([nsNS])", r".\1\2", text)
  # Any aeoö, or stressed iuüy, should be syllabically divided from a following aeoö or stressed iuüy.
  # A stressed vowel might be followed by another accent such as LINEUNDER (which we put after the acute/grave in
  # decompose()).
  text = rsub_repeatedly("([aeoöAEOÖ]" + accent_c + "*'?)([hH]?'?[aeoöAEOÖ])", r"\1.\2", text)
  text = rsub_repeatedly("([aeoöAEOÖ]" + accent_c + "*'?)([hH]?'?" + V + stress_c + ")", r"\1.\2", text)
  text = re.sub("([iuüyIUÜY]" + stress_c + accent_c + "*'?)([hH]?'?[aeoöAEOÖ])", r"\1.\2", text)
  text = rsub_repeatedly("([iuüyIUÜY]" + stress_c + accent_c + "*'?)([hH]?'?" + V + stress_c + ")", r"\1.\2", text)
  # We divide ii as i.i ([[sii]]), but not iy or yi, which should hopefully cause [[kefiyyah]] to be handled
  # correctly as ke.fiy.yah. Only example with Cyi is [[dandyismo]], which may be exceptional.
  text = rsub_repeatedly("([iI]" + accent_c + "*'?)([hH]?'?[iI])", r"\1.\2", text)
  text = rsub_repeatedly("([uüUÜ]" + accent_c + "*'?)([hH]?'?[uüUÜ])", r"\1.\2", text)
  text = text.replace(SYLDIV, ".")
  text = text.replace(TEMP_I, "i")
  text = text.replace(TEMP_I_CAPS, "I")
  text = text.replace(TEMP_U, "u")
  text = text.replace(TEMP_U_CAPS, "U")
  text = text.replace(TEMP_Y, "y")
  text = text.replace(TEMP_Y_CAPS, "Y")
  text = text.replace(TEMP_G, "g")
  text = text.replace(TEMP_G_CAPS, "G")
  text = recompose(text)
  # Convert word divisions into periods, but first into spaces so we can call remove_secondary_stress().
  # We have to call remove_secondary_stress() after syllabification so we correctly syllabify words like
  # bìobibliografìa.
  text = text.replace(WORDDIV, " ")
  text = remove_secondary_stress(text)
  return text.replace(" ", ".")

def adjust_initial_capital(arg, pagetitle, pagemsg, origline):
  arg_words = arg.split(" ")
  pagetitle_words = pagetitle.split(" ")
  new_arg = arg
  if len(arg_words) == len(pagetitle_words):
    new_arg_words = []
    for arg_word, pagetitle_word in zip(arg_words, pagetitle_words):
      new_arg_word = arg_word
      m = re.search("^(" + pron_sign_c + "*)(.*)$", arg_word)
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
  m = re.search("^(" + pron_sign_c + "*)(.*?)(" + pron_sign_c + "*)$", arg)
  arg_prefix, arg, arg_suffix = m.groups()
  if re.search(r"^\^[àéèìóòù]$", arg):
    if re.search("[ %-]", pagetitle):
      pagemsg("WARNING: With abbreviated vowel spec %s, the page name should be a single word: %s" % (arg, pagetitle))
      return None
    abbrev_text = decompose(arg)
    arg = pagetitle
  arg = decompose(arg)
  words = split_but_rejoin_affixes(decompose(arg))
  for i, word in enumerate(words):
    if i % 2 == 1: # a separator
      continue
    m = re.search("^(" + pron_sign_c + "*)(.*?)(" + pron_sign_c + "*)$", word)
    word_prefix, word, word_suffix = m.groups()
    def err(msg):
      pagemsg("WARNING: " + msg + ": " + words[i])
    is_prefix = word.endswith("-")
    is_suffix = word.startswith("-")
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
        elif not is_suffix or vowel_count == 2: # don't try to stress suffixes with only one vowel
          m = re.search("^(.*?)(" + V + ")(.*)$", word)
          if m:
            before, vow, after = m.groups()
            if vow in ["e", "o", "E", "O"]:
              err("When stressed vowel is e or o, it must be marked é/è or ó/ò to indicate quality")
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
    if str(t) != line:
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
        pagemsg("Already saw {{it-pr}}, skipping: %s" % str(t))
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
          bare_args = blib.fetch_param_chain(ipat, "1") or ["+"]
          bare_args = ["+" if arg == pagetitle else arg for arg in bare_args]
          bare_args = [adjust_initial_capital(arg, pagetitle, pagemsg, origline) for arg in bare_args]
          bare_args = [re.sub("([áíúÁÍÚ])", lambda m: acute_to_grave[m.group(1)], arg) for arg in bare_args]
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
            putative_pagetitle = remove_secondary_stress(hypharg.replace(".", "").replace("_", ""))
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
            pv = str(param.value)
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
          subsections[k + 1] = "%s\n\n" % "\n".join(lines_so_far + lines[lineind + 1:])
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
          extra_notes.append("incorporate %s into {{it-pr}}" % str(audiot))
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
          pronun = expand_text("{{#invoke:it-pronunciation|to_phonemic_bot|%s}}" % re.sub(pron_sign_c, "", bare_arg))
          if not pronun:
            rhyme_error = True
            break
          rhyme_pronun = (
            re.sub("^[^aeiouɛɔ]*", "", re.sub(".*[ˌˈ]", "", pronun)).replace(TIE, "")
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
              pv = str(param.value)
              if not re.search("^s?[0-9]*$", pn):
                pagemsg("WARNING: Unrecognized param %s=%s in {{%s}}, not removing: %s" %
                    (pn, pv, tname(rhymet), rhyme_line))
                must_break = True
                break
              if pn == "s":
                num_syl = "<s:%s>" % pv
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
              rhymes[rhyme_no][1] = "<s:%s>" % this_num_syl
            if must_break:
              break
            for rhyme, this_num_syl in rhymes:
              normalized_rhyme = re.sub("([aeɛoɔu])i", r"\1j", rhyme).replace("sm", "zm")
              normalized_rhyme = re.sub("a[uu̯](" + C + ")", r"aw\1", normalized_rhyme)
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
              pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(hypht), hyph_template))
              break
            else:
              must_break = False
              for param in hypht.params:
                pn = pname(param)
                pv = str(param.value)
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
                re.sub("([áíúÁÍÚ])", lambda m: acute_to_grave[m.group(1)], hyph) for hyph in specified_hyphenations]
              specified_hyphenations = [re.sub("''+", "", hyph) for hyph in specified_hyphenations]
              specified_hyphenations = [
                adjust_initial_capital(hyph, pagetitle, pagemsg, hyph_line) for hyph in specified_hyphenations]
              specified_hyphenations = [re.sub("î([ -]|$)", r"i\1", hyph) for hyph in specified_hyphenations]
              hyphenations = [syllabify_from_spelling(arg) for arg in args_for_hyph]
              if set(specified_hyphenations) < set(hyphenations):
                pagemsg("Removing explicit hyphenation(s) %s that are a subset of auto-hyphenation(s) %s: %s" %
                    (",".join(specified_hyphenations), ",".join(hyphenations), hyph_line))
              elif set(specified_hyphenations) != set(hyphenations):
                hyphenations_without_accents = [remove_accents(hyph) for hyph in hyphenations]
                rehyphenated_specified_hyphenations = [syllabify_from_spelling(hyph) for hyph in specified_hyphenations]
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

      if homophone_lines:
        if len(homophone_lines) > 1:
          pagemsg("WARNING: Multiple homophone lines, not removing: %s" % ", ".join(homophone_lines))
        else:
          assert homophone_lines[0].startswith("* ")
          homophone_line = homophone_lines[0][2:]
          homophones = {}
          homophone_qualifiers = {}
          hmpt = verify_template_is_full_line(["hmp", "homophone", "homophones"], homophone_line)
          if hmpt:
            if getparam(hmpt, "1") != "it":
              pagemsg("WARNING: Wrong language in {{%s}}, not removing: %s" % (tname(hmpt), homophone_line))
            else:
              for param in hmpt.params:
                pn = pname(param)
                pv = str(param.value)
                if not re.search("^q?[0-9]+$", pn):
                  pagemsg("WARNING: Unrecognized param %s=%s in {{%s}}, not removing: %s" %
                      (pn, pv, tname(hmpt), homophone_line))
                  break
                if pn.startswith("q"):
                  homophone_qualifiers[int(pn[1:])] = pv
                elif int(pn) > 1:
                  homophones[int(pn) - 1] = pv
              else: # no break
                hmp_args = []
                for pn, pv in sorted(homophones.items()):
                  hmp_args.append(pv)
                  if pn in homophone_qualifiers:
                    hmp_args[-1] += "<qual:%s>" % homophone_qualifiers[pn]
                args[-1] += "<hmp:%s>" % ",".join(hmp_args)
                extra_notes.append("incorporate homophones into {{it-pr}}")
                homophone_lines = []

      if args == ["+"]:
        it_pr = "{{it-pr}}"
      else:
        it_pr = "{{it-pr|%s}}" % ",".join(args)
      pagemsg("Replaced %s with %s" % (str(ipat), it_pr))

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
