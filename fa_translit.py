#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Authors: Benwing

import re, unicodedata
import arabiclib
from arabiclib import *
from blib import remove_links, msg

# FIXME!! To do:
#
# 1. Modify Module:ar-translit to convert – (long dash) into regular -;
#  also need extra clause in has_diacritics_subs (2nd one)
# 2. alif madda should match against 'a with short a

# STATUS:
#
# NEEDS LOTS OF WORK

def uniprint(x):
  print x.encode('utf-8')
def uniout(x):
  print x.encode('utf-8'),

def rsub(text, fr, to):
  if type(to) is dict:
    def rsub_replace(m):
      try:
        g = m.group(1)
      except IndexError:
        g = m.group(0)
      if g in to:
        return to[g]
      else:
        return g
    return re.sub(fr, rsub_replace, text)
  else:
    return re.sub(fr, to, text)

def error(text):
  raise RuntimeError(text)

def nfkc_form(txt):
  return unicodedata.normalize("NFKC", unicode(txt))

def nfc_form(txt):
  return unicodedata.normalize("NFC", unicode(txt))

zwnj = u"\u200c" # zero-width non-joiner
zwj  = u"\u200d" # zero-width joiner
#lrm = u"\u200e" # left-to-right mark
#rlm = u"\u200f" # right-to-left mark

consonants_needing_vowels = u"بتثجحخدذرزسشصضطظعغفقكلمنهپچڤگڨڧأإؤئءةﷲ"
# consonants on the right side; includes alif madda
rconsonants = consonants_needing_vowels + u"ويآ"
# consonants on the left side; does not include alif madda
lconsonants = consonants_needing_vowels + u"وي"
punctuation = (u"؟،؛" # Arabic semicolon, comma, question mark
         + u"ـ" # taṭwîl
         + u".!'" # period, exclamation point, single quote for bold/italic
         )
numbers = u"١٢٣٤٥٦٧٨٩٠"


# Transliterate the word(s) in TEXT. LANG (the language) and SC (the script)
# are ignored. FORCE_TRANSLATE causes even non-vocalized text to be transliterated
# (normally the function checks for non-vocalized text and returns nil,
# since such text is ambiguous in transliteration).
def tr(text, lang=None, sc=None, force_translate=False, msgfun=msg):
  # FIXME: Implement me
  return None


############################################################################
#           Transliterate from Latin to Arabic           #
############################################################################

#########     Transliterate with unvocalized Arabic to guide     #########

silent_alif_subst = u"\ufff1"
silent_alif_maqsuura_subst = u"\ufff2"
multi_single_quote_subst = u"\ufff3"
assimilating_l_subst = u"\ufff4"
double_l_subst = u"\ufff5"
dagger_alif_subst = u"\ufff6"

hamza_match = [u"ʾ",u"ʼ",u"'",u"´",(u"`",),u"ʔ",u"’",(u"‘",),u"ˀ",
    (u"ʕ",),(u"ʿ",),u"2"]
hamza_match_or_empty = hamza_match + [u""]
hamza_match_chars = [x[0] if isinstance(x, list) or isinstance(x, tuple) else x
    for x in hamza_match]

# Special-case matching at beginning of word. Plain alif normally corresponds
# to nothing, and hamza seats might correspond to nothing (omitted hamza
# at beginning of word). We can't allow e.g. أ to have "" as one of its
# possibilities mid-word because that will screw up a word like سألة "saʾala",
# which won't match at all because the أ will match nothing directly after
# the Latin "s", and then the ʾ will never be matched.
tt_to_arabic_matching_bow = { #beginning of word
  # put empty string in list so this entry will be recognized -- a plain
  # empty string is considered logically false
  u"ا":[u""],
  u"أ":hamza_match_or_empty,
  u"إ":hamza_match_or_empty,
  u"آ":[u"ʾaâ",u"’aâ",u"'aâ",u"`aâ",u"aâ"], #ʾalif madda = \u0622
}

# Special-case matching at end of word. Some ʾiʿrâb endings may appear in
# the Arabic but not the transliteration; allow for that.
tt_to_arabic_matching_eow = { # end of word
  UN:[u"un",u""], # ḍammatân
  IN:[u"in",u""], # kasratân
  A:[u"a",u""], # fatḥa (in plurals)
  U:[u"u",u""], # ḍamma (in diptotes)
  I:[u"i",u""], # kasra (in duals)
}

# This dict maps Arabic characters to all the Latin characters that might correspond to them. The entries can be a
# string (equivalent to a one-entry list) or a list of strings or one-element lists containing strings (the latter is
# equivalent to a string but suppresses canonicalization during transliteration; see below). The ordering of elements
# in the list is important insofar as which element is first, because the default behavior when canonicalizing a
# transliteration is to substitute any string in the list with the first element of the list (this can be suppressed by
# making an element a one-entry list containing a string, as mentioned above).
#
# FIXME: Currently if string A is a substring of string B, B needs to be placed first in the list. This doesn't work
# for Arabic, where e.g. we have to list "s" first for ص but "sˤ" occurs later. We should fix this by sorting the list
# by decreasing length.
#
# If the element of a list is a one-element tuple, we canonicalize during match-canonicalization but we do not trigger
# the check for multiple possible canonicalizations during self-canonicalization; instead we indicate that this
# character occurs somewhere else and should be canonicalized at self-canonicalization according to that somewhere-else.
# (For example, ` occurs as a match for both ʿ and ʾ; in the latter's list, it is a one-element tuple, meaning during
# self-canonicalization it will get canonicalized into ʿ and not left alone, as it otherwise would due to occurring as
# a match for multiple characters.)
#
# Each string might have multiple characters, to handle things like خ=kh and ث=th.

tt_to_arabic_matching = {
  # consonants
  u"ب":["b",["p"]],
  u"ت":u"t",
  u"ث":["s",u"ṯ",u"ŧ",u"θ","th",u"s̱",u"s̄"],
  # FIXME! We should canonicalize ʒ to ž
  u"ج":["j",u"ǧ",u"ğ",u"ǰ","dj",u"dǧ",u"dğ",u"dǰ",u"dž",u"dʒ",[u"ʒ"],[u"ž"],["g"]],
  u"چ":[u"č","ch","c"],
  # Allow what would normally be capital H, but we lowercase all text
  # before processing; always put the plain letters last so previous longer
  # sequences match (which may be letter + combining char).
  # I feel a bit uncomfortable allowing kh to match against ح like this,
  # but generally I trust the Arabic more.
  u"ح":["h",u"ḥ",u"ħ",u"ẖ",u"ḩ","7",("kh",)],
  # I feel a bit uncomfortable allowing ḥ to match against خ like this,
  # but generally I trust the Arabic more.
  u"خ":["x",u"k͟h",u"ḵ",u"kh",u"ḫ",u"ḳ",u"ẖ",u"χ",(u"ḥ",)],
  u"د":"d",
  # always put the plain letters last so previous longer sequences match
  # (which may be letter + combining char)
  u"ذ":["z",u"d͟h",u"ḏ",u"đ",u"ð",u"dh",u"ḍ",u"ẕ",u"d"],
  u"ر":"r",
  u"ز":"z",
  u"ژ":[u"ž",u"z͟h","zh"],
  # I feel a bit uncomfortable allowing emphatic variants of s to match
  # against س like this, but generally I trust the Arabic more.
  u"س":["s",(u"ṣ",),(u"sʿ",),(u"sˤ",),(u"sˁ",),(u"sʕ",),(u"ʂ",),(u"ṡ",)],
  u"ش":[u"š",u"s͟h","sh",u"ʃ"],
  u"ص":["s",u"ṣ",u"sʿ",u"sˤ",u"sˁ",u"sʕ",u"ʂ",u"ṡ"],
  u"ض":["z",u"ḍ",u"dʿ",u"dˤ"u"dˁ",u"dʕ",u"ẓ",u"ż",u"ẕ",u"ɖ",u"ḋ",u"d"],
  u"ط":["t",u"ṭ",u"tʿ",u"tˤ",u"tˁ",u"tʕ",u"ṫ",u"ţ",u"ŧ",u"ʈ",u"t̤"],
  u"ظ":["z",u"ẓ",u"ðʿ",u"ðˤ",u"ðˁ",u"ðʕ",u"ð̣",u"đʿ",u"đˤ",u"đˁ",u"đʕ",u"đ̣",
    u"ż",u"z̧",u"ʐ",u"dh"],
  # FIXME! Seems this can map to any of ' a e o. Need to account for this.
  #u"ع":["'", u"ʿ",u"ʕ",u"`",u"‘",u"ʻ",u"3",u"ˤ",u"ˁ",(u"'",),(u"ʾ",),u"῾",(u"’",)],
  u"غ":[u"ğ",u"ḡ",u"ġ",u"gh",[u"g"],(u"`",),"q",u"g͟h"],
  u"ف":[u"f",[u"v"]],
  # I feel a bit uncomfortable allowing k to match against q like this,
  # but generally I trust the Arabic more
  u"ق":[u"q",u"ḳ",[u"g"],"gh",u"g͟h",u"k"],
  u"ك":[u"k",[u"g"]],
  u"ک":[u"k",[u"g"]],
  u"گ":"g",
  u"ل":"l",
  u"م":"m",
  u"ن":"n",
  # FIXME! Seems this can map to any of h e. Need to account for this. Dispreferred sequences
  # are eh, a, ah.
  #u"ه":"h",
  # We have special handling for the following in the canonicalized Latin,
  # so that we have -a but -âh and -at-.
  u"ة":[u"h",[u"t"],[u"(t)"],u""],
  # control characters
  # The following are unnecessary because we handle them specially in
  # check_against_hyphen() and other_arabic_chars.
  #zwnj:[u"-"],#,u""], # ZWNJ (zero-width non-joiner)
  #zwj:[u"-"],#,u""], # ZWJ (zero-width joiner)
  # rare letters
  u"پ":u"p",
  u"چ":[u"č",u"ch"],
  u"ڤ":u"v",
  u"ڨ":u"g",
  u"ڧ":u"q",
  # semivowels or long vowels, alif, hamza, special letters
  u"ا":u"â", # ʾalif = \u0627
  # put empty string in list so not considered logically false, which can
  # mess with the logic
  silent_alif_subst:[u""],
  silent_alif_maqsuura_subst:[u""],
  # hamzated letters
  u"أ":hamza_match,
  u"إ":hamza_match,
  u"ؤ":hamza_match,
  u"ئ":hamza_match,
  u"ء":hamza_match,
  u"و":[[u"w"],[u"û"],[u"ô"], u"v"],
  # Adding j here creates problems with e.g. an-nijir vs. النيجر
  u"ي":[[u"y"],[u"î"],[u"ê"]], #u"j",
  u"ى":u"â", # ʾalif maqṣûra = \u0649
  u"آ":[u"ʾaâ",u"’aâ",u"'aâ",u"`aâ"], # ʾalif madda = \u0622
  # put empty string in list so not considered logically false, which can
  # mess with the logic
  u"ٱ":[u""], # hamzatu l-waṣl = \u0671
  u"\u0670":u"aâ", # ʾalif xanjariyya = dagger ʾalif (Koranic diacritic)
  # short vowels, šadda and sukûn
  u"\u064B":u"an", # fatḥatân
  u"\u064C":u"un", # ḍammatân
  u"\u064D":u"in", # kasratân
  u"\u064E":u"a", # fatḥa
  u"\u064F":[[u"u"],[u"o"]], # ḍamma
  u"\u0650":[[u"i"],[u"e"]], # kasra
  u"\u0651":u"\u0651", # šadda - handled specially when matching Latin šadda
  double_l_subst:u"\u0651", # handled specially when matching šadda in Latin
  u"\u0652":u"", #sukûn - no vowel
  # ligatures
  u"ﻻ":u"lâ",
  u"ﷲ":u"llâh",
  # put empty string in list so not considered logically false, which can
  # mess with the logic
  u"ـ":[u""], # taṭwîl, no sound
  # numerals
  u"١":u"1", u"٢":u"2", u"٣":u"3", u"٤":u"4", u"٥":u"5",
  u"٦":u"6", u"٧":u"7", u"٨":u"8", u"٩":u"9", u"٠":u"0",
  # punctuation (leave on separate lines)
  u"؟":u"?", # question mark
  u"،":u",", # comma
  u"؛":u";", # semicolon
  u".":u".", # period
  u"!":u"!", # exclamation point
  u"'":[(u"'",)], # single quote, for bold/italic
  u" ":u" ",
  u"[":u"",
  u"]":u"",
  # The following are unnecessary because we handle them specially in
  # check_against_hyphen() and other_arabic_chars.
  #u"-":u"-",
  #u"–":u"-",
}

# exclude consonants like h ʿ ʕ ʕ that can occur second in a two-charcter
# sequence, because of cases like u"múdhhil" vs. u"مذهل"
latin_consonants_no_double_after_cons = u"bcdfgjklmnpqrstvwxyzʾʔḍḥḳḷṃṇṛṣṭṿẉỵẓḃċḋḟġḣṁṅṗṙṡṫẇẋẏżčǧȟǰňřšžḇḏẖḵḻṉṟṯẕḡs̄z̄çḑģḩķļņŗşţz̧ćǵḱĺḿńṕŕśẃźďľťƀđǥħłŧƶğḫʃɖʈt̤ð"
latin_consonants_no_double_after_cons_re = "[%s]" % (
    latin_consonants_no_double_after_cons)

# Characters that aren't in tt_to_arabic_matching but which are valid
# Arabic characters in some circumstances (in particular, opposite a hyphen,
# where they are matched in check_against_hyphen()). We need to tell
# get_matches() about this so it doesn't throw an "Encountered non-Arabic"
# error, but instead just returns an empty list of matches so match() will
# properly fail.
other_arabic_chars = [zwj, zwnj, "-", u"–"]

word_interrupting_chars = u"ـ[]"

build_canonicalize_latin = {}
for ch in u"abcdefghijklmnopqrstuvwyz3": # x not in this list! canoned to ḵ
  build_canonicalize_latin[ch] = "multiple"
build_canonicalize_latin[""] = "multiple"

# Make sure we don't canonicalize any canonical letter to any other one;
# e.g. could happen with ʾ, an alternative for ʿ.
for arabic in tt_to_arabic_matching:
  alts = tt_to_arabic_matching[arabic]
  if isinstance(alts, basestring):
    build_canonicalize_latin[alts] = "multiple"
  else:
    canon = alts[0]
    if isinstance(canon, tuple):
      pass
    if isinstance(canon, list):
      build_canonicalize_latin[canon[0]] = "multiple"
    else:
      build_canonicalize_latin[canon] = "multiple"

for arabic in tt_to_arabic_matching:
  alts = tt_to_arabic_matching[arabic]
  if isinstance(alts, basestring):
    continue
  canon = alts[0]
  if isinstance(canon, list):
    continue
  for alt in alts[1:]:
    if isinstance(alt, list) or isinstance(alt, tuple):
      continue
    if alt in build_canonicalize_latin and build_canonicalize_latin[alt] != canon:
      build_canonicalize_latin[alt] = "multiple"
    else:
      build_canonicalize_latin[alt] = canon
tt_canonicalize_latin = {}
for alt in build_canonicalize_latin:
  canon = build_canonicalize_latin[alt]
  if canon != "multiple":
    tt_canonicalize_latin[alt] = canon

# A list of Latin characters that are allowed to have particular unmatched
# Arabic characters following. This is used to allow short Latin vowels
# to correspond to long Arabic vowels. The value is the list of possible
# unmatching Arabic characters.
tt_skip_unmatching = {
  u"a":[u"ا"],
  u"u":[u"و"],
  u"o":[u"و"],
  u"i":[u"ي"],
  u"e":[u"ي"],
}

# A list of Latin characters that are allowed to be unmatched in the
# Arabic. The value is the corresponding Arabic character to insert.
tt_to_arabic_unmatching = {
  u"a":u"\u064E",
  u"o":u"\u064F",
  u"e":u"\u0650",
  u"\u0651":u"\u0651",
  u"-":u"",
}

# Pre-canonicalize Latin, and Arabic if supplied. If Arabic is supplied,
# it should be the corresponding Arabic (after pre-pre-canonicalization),
# and is used to do extra canonicalizations.
def pre_canonicalize_latin(text, arabic=None, msgfun=msg):
  # Map to canonical composed form, eliminate presentation variants etc.
  text = nfkc_form(text)
  # remove L2R, R2L markers
  text = rsub(text, u"[\u200E\u200F]", "")
  # remove embedded comments
  text = rsub(text, u"<!--.*?-->", "")
  # remove embedded IPAchar templates
  text = rsub(text, r"\{\{IPAchar\|(.*?)\}\}", r"\1")
  # lowercase and remove leading/trailing spaces
  text = text.lower().strip()
  # canonicalize interior whitespace
  text = rsub(text, r"\s+", " ")
  # FIXME: Still needed with Persian text?
  # eliminate ' after space or - and before non-vowel, indicating elided /a/
  # text = rsub(text, r"([ -])'([^'aeiouəâêîôû])", r"\1\2")
  # eliminate accents
  text = rsub(text, u".",
    {u"á":u"a", u"é":u"e", u"í":u"i", u"ó":u"o", u"ú":u"u",
     u"à":u"a", u"è":u"e", u"ì":u"i", u"ò":u"o", u"ù":u"u",
     u"ă":u"a", u"ĕ":u"e", u"ĭ":u"i", u"ŏ":u"o", u"ŭ":u"u",
     u"ā́":u"â", u"ḗ":u"ê", u"ī́":u"î", u"ṓ":u"ô", u"ū́":u"û",
     u"ä":u"a", u"ë":u"e", u"ï":u"i", u"ö":u"o", u"ü":u"u"})
  # some accented macron letters have the accent as a separate Unicode char
  text = rsub(text, u".́",
    {u"ā́":u"â", u"ḗ":u"ê", u"ī́":u"î", u"ṓ":u"ô", u"ū́":u"û"})
  # canonicalize weird vowels
  text = text.replace(u"ɪ", "i")
  text = text.replace(u"ɑ", u"â")
  text = text.replace(u"æ", "a")
  text = text.replace(u"а", "a") # Cyrillic a
  # eliminate doubled vowels = long vowels
  text = rsub(text, u"([aeiou])\\1", {u"a":u"â", u"e":u"ê", u"i":u"î", u"o":u"ô", u"u":u"û"})
  # eliminate vowels followed by colon = long vowels
  text = rsub(text, u"([aeiou])[:ː]", {u"a":u"â", u"e":u"ê", u"i":u"î", u"o":u"ô", u"u":u"û"})
  # convert macrons to circumflexed vowels
  text = rsub(text, u".",
    {u"â":u"â", u"ê":u"ê", u"î":u"î", u"ô":u"ô", u"û":u"û"})

  # FIXME: We probably don't want this.
  # eliminate - or ' separating t-h, t'h, etc. in transliteration style
  # that uses th to indicate ث
  # text = rsub(text, u"([dtgkcs])[-']h", u"\\1h")

  # FIXME the following seem unnecessary.
  # substitute geminated digraphs, possibly with a hyphen in the middle
  #text = rsub(text, u"dh(-?)dh", ur"ḏ\1ḏ")
  #text = rsub(text, u"sh(-?)sh", ur"š\1š")
  #text = rsub(text, u"th(-?)th", ur"ṯ\1ṯ")
  #text = rsub(text, u"kh(-?)kh", ur"ḵ\1ḵ")
  #text = rsub(text, u"gh(-?)gh", ur"ḡ\1ḡ")

  # FIXME the following seem unnecessary.
  # misc substitutions
  #text = rsub(text, u"ẗ$", "")
  ## cases like fi 'l-ḡad(i) -> eventually fi l-ḡad
  #text = rsub(text, r"\([aiu]\)($|[ |\[\]])", r"\1")
  #text = rsub(text, r"\(tun\)$", "")
  #text = rsub(text, r"\(un\)$", "")

  #### vowel/diphthong canonicalizations
  # FIXME: review with Anatoli
  text = rsub(text, u"([aeoə])u", r"\1w")
  text = rsub(text, u"([aeoə])i", r"\1y")

  # FIXME: the following are probably wrong or unnecessary
  ## Convert -iy- not followed by a vowel or y to long -î-
  #text = rsub(text, u"iy($|[^aeiouəyâêîôû])", ur"î\1")
  ## Same for -uw- -> -û-
  #text = rsub(text, u"uw($|[^aeiouəwâêîôû])", ur"û\1")
  ## Insert y between i and a
  #text = rsub(text, u"([iî])([aâ])", r"\1y\2")
  ## Insert w between u and a
  #text = rsub(text, u"([uû])([aâ])", r"\1w\2")
  #text = rsub(text, u"îy", u"iyy")
  #text = rsub(text, u"ûw", u"uww")
  ## Reduce cases of three characters in a row (e.g. from îyy -> iyyy -> iyy);
  ## but not ''', which stands for boldface, or ..., which is legitimate
  #text = rsub(text, r"([^'.])\1\1", r"\1\1")
  ## Remove double consonant following another consonant, but only at
  ## word boundaries, since that's the only time when these cases seem to
  ## legitimately occur
  #text = re.sub(ur"([^aeiouəâêîôû\W])(%s)\2\b" % (
  ##  latin_consonants_no_double_after_cons_re), r"\1\2", text, 0, re.U)
  ## Remove double consonant preceding another consonant but special-case
  ## a known example that shouldn't be touched.
  #if text != u"dunḡḡwân":
  #  text = re.sub(ur"([^aeiouəâêîôû\W])\1(%s)" % (
  #    latin_consonants_no_double_after_cons_re), r"\1\2", text, 0, re.U)

  # FIXME: Probably unnecessary, needs reviewing.
  #if arabic:
  #  # Remove links from Arabic to simplify the following code
  #  arabic = remove_links(arabic)
  #  # If Arabic ends with -un, remove it from the Latin (it will be
  #  # removed from Arabic in pre-canonicalization). But not if the
  #  # Arabic has a space in it (may be legitimate, in Koranic quotes or
  #  # whatever).
  #  if arabic.endswith(u"\u064C") and " " not in arabic:
  #    newtext = rsub(text, "un$", "")
  #    if newtext != text:
  #      msgfun("Removing final -un from Latin %s" % text)
  #      text = newtext
  #    # Now remove -un from the Arabic.
  #    arabic = rsub(arabic, u"\u064C$", "")
  #  # If Arabic ends with tâʾ marbûṭa, canonicalize some Latin endings
  #  # right now. Only do this at the end of the text, not at the end
  #  # of each word, since an Arabic word in the middle might be in the
  #  # construct state.
  #  if arabic.endswith(u"اة"):
  #    text = rsub(text, ur"â(\(t\)|t)$", u"âh")
  #  elif arabic.endswith(u"ة"):
  #    text = rsub(text, r"[ae](\(t\)|t)$", "a")
  #  # Do certain end-of-word changes on each word, comparing corresponding
  #  # Latin and Arabic words ...
  #  arabicwords = re.split(u" +", arabic)
  #  latinwords = re.split(u" +", text)
  #  # ... but only if the number of words in both is the same.
  #  if len(arabicwords) == len(latinwords):
  #    for i in xrange(len(latinwords)):
  #      aword = arabicwords[i]
  #      lword = latinwords[i]
  #      # If Arabic word ends with long alif or alif maqṣûra, not
  #      # preceded by fatḥatân, convert short -a to long -â.
  #      if (re.search(u"[اى]$", aword) and not
  #          re.search(u"\u064B[اى]$", aword)):
  #        lword = rsub(lword, r"a$", u"â")
  #      # If Arabic word ends in -yy, convert Latin -i/-î to -iyy
  #      # If the Arabic actually ends in -ayy or similar, this should
  #      # have no effect because in any vowel+i combination, we
  #      # changed i->y
  #      if re.search(u"يّ$", aword):
  #        lword = rsub(lword, u"[iî]$", "iyy")
  #      # If Arabic word ends in -y preceded by sukûn, assume
  #      # correct and convert final Latin -i/î to -y.
  #      if re.search(u"\u0652ي$", aword):
  #        lword = rsub(lword, u"[iî]$", "y")
  #      # Otherwise, if Arabic word ends in -y, convert Latin -i to -î
  #      # WARNING: Many of these should legitimately be converted
  #      # to -iyy or perhaps (sukûn+)-y both in Arabic and Latin, but
  #      # it's impossible for us to know this.
  #      elif re.search(u"ي$", aword):
  #        lword = rsub(lword, "i$", u"î")
  #      # Except same logic, but for u/w vs. i/y
  #      if re.search(u"وّ$", aword):
  #        lword = rsub(lword, u"[uû]$", "uww")
  #      if re.search(u"\u0652و$", aword):
  #        lword = rsub(lword, u"[uû]$", "w")
  #      elif re.search(u"و$", aword):
  #        lword = rsub(lword, "u$", u"û")
  #      # Echo a final exclamation point in the Latin
  #      if re.search("!$", aword) and not re.search("!$", lword):
  #        lword += "!"
  #      # Same for a final question mark
  #      if re.search(u"؟$", aword) and not re.search(u"\?$", lword):
  #        lword += "?"
  #      latinwords[i] = lword
  #    text = " ".join(latinwords)
  ##text = rsub(text, u"[-]", u"") # eliminate stray hyphens (e.g. in al-)

  # FIXME: Think about this.
  ## add short vowel before long vowel since corresponding Arabic has it
  #text = rsub(text, u".",
  #  {u"â":u"aâ", u"ê":u"eê", u"î":u"iî", u"ô":u"oô", u"û":u"uû"})
  return text

def post_canonicalize_latin(text):
  text = rsub(text, u"aâ", u"â")
  text = rsub(text, u"eê", u"ê")
  text = rsub(text, u"iî", u"î")
  text = rsub(text, u"oô", u"ô")
  text = rsub(text, u"uû", u"û")
  # Convert shadda back to double letter
  text = rsub(text, u"(.)\u0651", u"\\1\\1")
  text = text.lower().strip()
  return text

# Canonicalize a Latin transliteration and Arabic text to standard form.
# Can be done on only Latin or only Arabic (with the other one None), but
# is more reliable when both aare provided. This is less reliable than
# tr_matching() and is meant when that fails. Return value is a tuple of
# (CANONLATIN, CANONARABIC).
def canonicalize_latin_arabic(latin, arabic, msgfun=msg):
  if arabic is not None:
    arabic = pre_pre_canonicalize_arabic(arabic, msgfun=msgfun)
  if latin is not None:
    latin = pre_canonicalize_latin(latin, arabic, msgfun=msgfun)
  if arabic is not None:
    arabic = pre_canonicalize_arabic(arabic, safe=True, msgfun=msgfun)
    arabic = post_canonicalize_arabic(arabic, safe=True)
  if latin is not None:
    # Protect instances of two or more single quotes in a row so they don't
    # get converted to sequences of hamza half-rings.
    def quote_subst(m):
      return m.group(0).replace("'", multi_single_quote_subst)
    latin = re.sub(r"''+", quote_subst, latin)
    latin = rsub(latin, u".", tt_canonicalize_latin)
    latin_chars = u"[a-zA-Zâêîôûčḍḏḡḥḵṣšṭṯẓžʿʾ]"
    # Convert 3 to ʿ if next to a letter or letter symbol. This tries
    # to avoid converting 3 in numbers.
    latin = rsub(latin, u"(%s)3" % latin_chars, u"\\1ʿ")
    latin = rsub(latin, u"3(%s)" % latin_chars, u"ʿ\\1")
    latin = latin.replace(multi_single_quote_subst, "'")
    latin = post_canonicalize_latin(latin)
  return (latin, arabic)

# Special-casing for punctuation-space and diacritic-only text; don't
# pre-canonicalize.
def dont_pre_canonicalize_arabic(text):
  if u"\u2008" in text:
    return True
  rdtext = remove_diacritics(text)
  if len(rdtext) == 0:
    return True
  if rdtext == u"ـ":
    return True
  return False

# Early pre-canonicalization of Arabic, doing stuff that's safe. We split
# this from pre-canonicalization proper so we can do Latin pre-canonicalization
# between the two steps.
def pre_pre_canonicalize_arabic(text, msgfun=msg):
  if dont_pre_canonicalize_arabic(text):
    msgfun("Not pre-canonicalizing %s due to U+2008 or overly short" %
        text)
    return text
  # Map to canonical composed form, eliminate presentation variants.
  # But don't do it if word ligatures are present or length-1 words with
  # presentation variants, because we want to leave those alone.
  if (not re.search(u"[\uFDF0-\uFDFF]", text)
      and not re.search(u"(^|[\\W])[\uFB50-\uFDCF\uFE70-\uFEFF]($|[\\W])",
        text, re.U)):
    text = nfkc_form(text)
  # remove L2R, R2L markers
  text = rsub(text, u"[\u200E\u200F]", "")
  # remove leading/trailing spaces;
  text = text.strip()
  # canonicalize interior whitespace
  text = rsub(text, r"\s+", " ")
  # replace Farsi, etc. characters with corresponding Arabic characters
  text = text.replace(u"ی", u"ي") # FARSI YEH
  text = text.replace(u"ک", u"ك") # ARABIC LETTER KEHEH (06A9)
  # convert llh for allâh into ll+shadda+dagger-alif+h
  text = rsub(text, u"لله", u"للّٰه")
  # uniprint("text enter: %s" % text)
  # shadda+short-vowel (including tanwîn vowels, i.e. -an -in -un) gets
  # replaced with short-vowel+shadda during NFC normalisation, which
  # MediaWiki does for all Unicode strings; however, it makes the
  # transliteration process inconvenient, so undo it.
  text = rsub(text,
    u"([\u064B\u064C\u064D\u064E\u064F\u0650\u0670])\u0651", u"\u0651\\1")
  # tâʾ marbûṭa should always be preceded by fatḥa, alif, alif madda or
  # dagger alif; infer fatḥa if not. This fatḥa will force a match to an "a"
  # in the Latin, so we can safely have tâʾ marbûṭa itself match "h", "t"
  # or "", making it work correctly with alif + tâʾ marbûṭa where
  # e.g. اة = â and still correctly allow e.g. رة = ra but disallow رة = r.
  text = rsub(text, u"([^\u064E\u0627\u0622\u0670])\u0629",
    u"\\1\u064E\u0629")
  # some Arabic text has a shadda after the initial consonant; remove it
  newtext = rsub(text, ur"(^|[ |\[\]])(.)" + SH, r"\1\2")
  if text != newtext:
    if " " in newtext:
      # Shadda after initial consonant can legitimately occur in
      # Koranic text, standing for assimilation of the final consonant
      # of the preceding word
      msgfun("Not removing shadda after initial consonant in %s because of space in text"
          %  text)
    else:
      msgfun("Removing shadda after initial consonant in %s" % text)
      text = newtext
  # similarly for sukûn + consonant + shadda.
  newtext = rsub(text, SK + "(.)" + SH, SK + r"\1")
  if text != newtext:
    msgfun(u"Removing shadda after sukûn + consonant in %s" % text)
    text = newtext
  # fatḥa mistakenly placed after consonant + alif should go before.
  newtext = rsub(text, "([" + lconsonants + "])" + A + "?" + ALIF + A,
      r"\1" + AA)
  if text != newtext:
    msgfun(u"uFixing fatḥa after consonant + alif in %s" % text)
    text = newtext
  return text

# Pre-canonicalize the Arabic. If SAFE, only do "safe" operations appropriate
# to canonicalizing Arabic on its own, not before a tr_matching() operation.
def pre_canonicalize_arabic(text, safe=False, msgfun=msg):
  if dont_pre_canonicalize_arabic(text):
    return text
  if not safe:
    # word-initial al + consonant + shadda: remove shadda
    text = rsub(text, u"(^|\\s|\[\[|\|)(\u0627\u064E?\u0644[" +
        lconsonants + u"])\u0651", u"\\1\\2")
    # same for hamzat al-waṣl + l + consonant + shadda, anywhere
    text = rsub(text,
        u"(\u0671\u064E?\u0644[" + lconsonants + u"])\u0651", u"\\1")
    # word-initial al + l + dagger-alif + h (allâh): convert second l
    # to double_l_subst; will match shadda in Latin allâh during
    # tr_matching(), will be converted back during post-canonicalization
    text = rsub(text, u"(^|\\s|\[\[|\|)(\u0627\u064E?\u0644)\u0644(\u0670?ه)",
      u"\\1\\2" + double_l_subst + u"\\3")
    # same for hamzat al-waṣl + l + l + dagger-alif + h occurring anywhere.
    text = rsub(text, u"(\u0671\u064E?\u0644)\u0644(\u0670?ه)",
      u"\\1" + double_l_subst + u"\\2")
    # word-initial al + sun letter: convert l to assimilating_l_subst; will
    # convert back during post-canonicalization; during tr_matching(),
    # assimilating_l_subst will match the appropriate character, or "l"
    text = rsub(text, u"(^|\\s|\[\[|\|)(\u0627\u064E?)\u0644([" +
        sun_letters + "])", u"\\1\\2" + assimilating_l_subst + u"\\3")
    # same for hamzat al-waṣl + l + sun letter occurring anywhere.
    text = rsub(text, u"(\u0671\u064E?)\u0644([" + sun_letters + "])",
      u"\\1" + assimilating_l_subst + u"\\2")
  return text

def post_canonicalize_arabic(text, safe=False):
  if dont_pre_canonicalize_arabic(text):
    return text
  if not safe:
    text = rsub(text, silent_alif_subst, u"ا")
    text = rsub(text, silent_alif_maqsuura_subst, u"ى")
    text = rsub(text, assimilating_l_subst, u"ل")
    text = rsub(text, double_l_subst, u"ل")
    text = rsub(text, A + "?" + dagger_alif_subst, DAGGER_ALIF)

    # add sukûn between adjacent consonants, but not in the first part of
    # a link of the sort [[foo|bar]], which we don't vocalize
    splitparts = []
    index = 0
    for part in re.split(r'(\[\[[^]]*\|)', text):
      if (index % 2) == 0:
        # do this twice because a sequence of three consonants won't be
        # matched by the initial one, since the replacement does
        # non-overlapping subs
        part = rsub(part,
            u"([" + lconsonants + u"])([" + rconsonants + u"])",
            u"\\1\u0652\\2")
        part = rsub(part,
            u"([" + lconsonants + u"])([" + rconsonants + u"])",
            u"\\1\u0652\\2")
      splitparts.append(part)
      index += 1
    text = ''.join(splitparts)

  # remove sukûn after ḍamma + wâw
  text = rsub(text, u"\u064F\u0648\u0652", u"\u064F\u0648")
  # remove sukûn after kasra + yâ'
  text = rsub(text, u"\u0650\u064A\u0652", u"\u0650\u064A")
  # initial al + consonant + sukûn + sun letter: convert to shadda
  text = rsub(text, u"(^|\\s|\[\[|\|)(\u0627\u064E?\u0644)\u0652([" + sun_letters + "])",
     u"\\1\\2\\3\u0651")
  # same for hamzat al-waṣl + l + consonant + sukûn + sun letters anywhere
  text = rsub(text, u"(\u0671\u064E?\u0644)\u0652([" + sun_letters + "])",
     u"\\1\\2\u0651")
  # Undo shadda+short-vowel reversal in pre_pre_canonicalize_arabic.
  # Not strictly necessary as MediaWiki will automatically do this
  # reversal but ensures that e.g. we don't keep trying to revocalize and
  # save a page with a shadda in it. Don't undo shadda+dagger-alif because
  # that sequence may not get reversed to begin with.
  text = rsub(text,
    u"\u0651([\u064B\u064C\u064D\u064E\u064F\u0650])", u"\\1\u0651")
  return text

debug_tr_matching = False

# Vocalize Persian Arabic-script text based on transliterated Latin, and canonicalize the transliteration based on
# the Arabic script.  This works by matching the Latin to the unvocalized Arabic script and inserting the appropriate
# diacritics in the right places, so that ambiguities of Latin transliteration can be correctly handled. Returns a
# tuple of Arabic, Latin. If unable to match, throw an error if ERR, else return None.
def tr_matching(arabic, latin, err=False, msgfun=msg):
  origarabic = arabic
  origlatin = latin
  def debprint(x):
    if debug_tr_matching:
      uniprint(x)
  arabic = pre_pre_canonicalize_arabic(arabic, msgfun=msgfun)
  latin = pre_canonicalize_latin(latin, arabic, msgfun=msgfun)
  arabic = pre_canonicalize_arabic(arabic, msgfun=msgfun)
  # FIXME: Do we still need to do this with Persian text?
  # convert double consonant after non-cons to consonant + shadda,
  # but not multiple quotes or multiple periods
  latin = re.sub(ur"(^|[aeiouəâêîôû\W])([^'.])\2", u"\\1\\2\u0651",
      latin, 0, re.U)

  ar = [] # exploded Arabic characters
  la = [] # exploded Latin characters
  res = [] # result Arabic characters
  lres = [] # result Latin characters
  for cp in arabic:
    ar.append(cp)
  for cp in latin:
    la.append(cp)
  debprint("Arabic characters: %s" % ar)
  debprint("Latin characters: %s" % la)
  aind = [0] # index of next Arabic character
  alen = len(ar)
  lind = [0] # index of next Latin character
  llen = len(la)

  def is_bow(pos=None):
    if pos is None:
      pos = aind[0]
    return (pos == 0 or ar[pos - 1] in [u" ", u"[", u"|"])

  # True if we are at the last character in a word.
  def is_eow(pos=None):
    if pos is None:
      pos = aind[0]
    return pos == alen - 1 or ar[pos + 1] in [u" ", u"]", u"|"]

  def get_matches():
    ac = ar[aind[0]]
    debprint("get_matches: ac is %s" % ac)
    bow = is_bow()
    eow = is_eow()

    matches = (
      bow and tt_to_arabic_matching_bow.get(ac) or
      eow and tt_to_arabic_matching_eow.get(ac) or
      tt_to_arabic_matching.get(ac))
    debprint("get_matches: matches is %s" % matches)
    if matches == None:
      if ac in other_arabic_chars:
        return []
      if True:
        error("Encountered non-Arabic (?) character " + ac +
          " at index " + str(aind[0]))
      else:
        matches = [ac]
    if type(matches) is not list:
      matches = [matches]
    return matches

  # attempt to match the current Arabic character against the current
  # Latin character(s). If no match, return False; else, increment the
  # Arabic and Latin pointers over the matched characters, add the Arabic
  # character to the result characters and return True.
  def match():
    matches = get_matches()

    ac = ar[aind[0]]

    # Check for link of the form [[foo|bar]] and skip over the part
    # up through the vertical bar, copying it
    if ac == '[':
      newpos = aind[0]
      while newpos < alen and ar[newpos] != ']':
        if ar[newpos] == '|':
          newpos += 1
          while aind[0] < newpos:
            res.append(ar[aind[0]])
            aind[0] += 1
          return True
        newpos += 1

    debprint("match: lind=%s, la=%s" % (
      lind[0], lind[0] >= llen and "EOF" or la[lind[0]]))

    for m in matches:
      preserve_latin = False
      # If an element of the match list is a list, it means
      # "don't canonicalize".
      if type(m) is list:
        preserve_latin = True
        m = m[0]
      # A one-element tuple is a signal for use in self-canonicalization,
      # not here.
      elif type(m) is tuple:
        m = m[0]
      l = lind[0]
      matched = True
      debprint("m: %s" % m)
      for cp in m:
        if l < llen and la[l] == cp:
          debprint("cp: %s, l=%s, la=%s" % (cp, l, la[l]))
          l = l + 1
        else:
          debprint("cp: %s, unmatched")
          matched = False
          break
      if matched:
        res.append(ac)
        if preserve_latin:
          for cp in m:
            lres.append(cp)
        elif ac == u"ة":
          if not is_eow():
            lres.append(u"t")
          elif aind[0] > 0 and (ar[aind[0] - 1] == u"ا" or
              ar[aind[0] - 1] == u"آ"):
            lres.append(u"h")
          # else do nothing
        else:
          subst = matches[0]
          if type(subst) is list or type(subst) is tuple:
            subst = subst[0]
          for cp in subst:
            lres.append(cp)
        lind[0] = l
        aind[0] = aind[0] + 1
        debprint("matched; lind is %s" % lind[0])
        return True
    return False

  def cant_match():
    if aind[0] < alen and lind[0] < llen:
      error("Unable to match Arabic character %s at index %s, Latin character %s at index %s" %
        (ar[aind[0]], aind[0], la[lind[0]], lind[0]))
    elif aind[0] < alen:
      error("Unable to match trailing Arabic character %s at index %s" %
        (ar[aind[0]], aind[0]))
    else:
      error("Unable to match trailing Latin character %s at index %s" %
        (la[lind[0]], lind[0]))

  # Check for an unmatched Latin short vowel or similar; if so, insert
  # corresponding Arabic diacritic.
  def check_unmatching():
    if not (lind[0] < llen):
      return False
    debprint("Unmatched Latin: %s at %s" % (la[lind[0]], lind[0]))
    unmatched = tt_to_arabic_unmatching.get(la[lind[0]])
    if unmatched != None:
      res.append(unmatched)
      lres.append(la[lind[0]])
      lind[0] = lind[0] + 1
      return True
    return False

  # Check for an Arabic long vowel that is unmatched but following a Latin
  # short vowel.
  def check_skip_unmatching():
    if not (lind[0] > 0 and aind[0] < alen):
      return False
    skip_char_pos = lind[0] - 1
    # Skip back over a hyphen, so we match wa-l-jabal against والجبل
    if la[skip_char_pos] == "-" and skip_char_pos > 0:
      skip_char_pos -= 1
    skip_chars = tt_skip_unmatching.get(la[skip_char_pos])
    if skip_chars != None and ar[aind[0]] in skip_chars:
      debprint("Skip-unmatching matched %s at %s following %s at %s" % (
        ar[aind[0]], aind[0], la[skip_char_pos], skip_char_pos))
      res.append(ar[aind[0]])
      aind[0] = aind[0] + 1
      return True
    return False

  # Check for Latin hyphen and match it against -, zwj, zwnj, Arabic space
  # or nothing. See the caller for some of the reasons we special-case
  # this.
  def check_against_hyphen():
    if lind[0] < llen and la[lind[0]] == "-":
      if aind[0] >= alen:
        lres.append("-")
      elif ar[aind[0]] in ["-", u"–", zwj, zwnj]:
        lres.append("-")
        res.append(ar[aind[0]])
        aind[0] += 1
      elif ar[aind[0]] == " ":
        # When matching against space, convert hyphen to space.
        lres.append(" ")
        res.append(" ")
        aind[0] += 1
      else:
        lres.append("-")
      lind[0] += 1
      return True
    return False

  # Check for plain alif matching hamza and canonicalize.
  def check_bow_alif():
    if not (is_bow() and aind[0] < alen and ar[aind[0]] == u"ا"):
      return False
    # Check for hamza + vowel.
    if not (lind[0] < llen - 1 and la[lind[0]] in hamza_match_chars and
        la[lind[0] + 1] in u"aeiouəâêîôû"):
      return False
    # long vowels should have been pre-canonicalized to have the
    # corresponding short vowel before them.
    assert la[lind[0] + 1] not in u"âêîôû"
    if la[lind[0] + 1] in u"ei":
      canonalif = u"إ"
    else:
      canonalif = u"أ"
    msgfun("Canonicalized alif to %s in %s (%s)" % (
      canonalif, origarabic, origlatin))
    res.append(canonalif)
    aind[0] += 1
    lres.append(u"ʾ")
    lind[0] += 1
    return True

  # Check for inferring tanwîn
  def check_eow_tanwin():
    tanwin_mapping = {"a":AN, "i":IN, "u":UN}
    # Infer tanwîn at EOW
    if (aind[0] > 0 and is_eow(aind[0] - 1) and lind[0] < llen - 1 and
        la[lind[0]] in "aiu" and la[lind[0] + 1] == "n"):
      res.append(tanwin_mapping[la[lind[0]]])
      lres.append(la[lind[0]])
      lres.append(la[lind[0] + 1])
      lind[0] += 2
      return True
    # Infer fatḥatân before EOW alif/alif maqṣûra
    if (aind[0] < alen and is_eow() and
        ar[aind[0]] in u"اى" and lind[0] < llen - 1 and
        la[lind[0]] == "a" and la[lind[0] + 1] == "n"):
      res.append(AN)
      res.append(ar[aind[0]])
      lres.append("a")
      lres.append("n")
      aind[0] += 1
      lind[0] += 2
      return True
    return False

  # Here we go through the unvocalized Arabic letter for letter, matching
  # up the consonants we encounter with the corresponding Latin consonants
  # using the dict in tt_to_arabic_matching and copying the Arabic
  # consonants into a destination array. When we don't match, we check for
  # allowed unmatching Latin characters in tt_to_arabic_unmatching, which
  # handles short vowels and shadda. If this doesn't match either, and we
  # have left-over Arabic or Latin characters, we reject the whole match,
  # either returning False or signaling an error.

  while aind[0] < alen or lind[0] < llen:
    matched = False
    # The first clause ensures that shadda always gets processed first;
    # necessary in the case of the qiṭṭun example below, which otherwise
    # would be rendered as qiṭunn.
    if lind[0] < llen and la[lind[0]] == u"\u0651":
      debprint("Matched: Clause shadda")
      lind[0] += 1
      lres.append(u"\u0651")
      if aind[0] < alen and (
          ar[aind[0]] == u"\u0651" or ar[aind[0]] == double_l_subst):
        res.append(ar[aind[0]])
        aind[0] += 1
      else:
        res.append(u"\u0651")
      matched = True
    # We need a special clause for hyphen for various reasons. One of them
    # is that otherwise we have problems with al-ʾimârât against الإمارات,
    # where the إ is in BOW position against hyphen and is allowed to
    # match against nothing and does so, and then the hyphen matches
    # against nothing and the ʾ can't match. Another is so that we can
    # canonicalize it to space if matching against a space but keep it
    # a hyphen otherwise.
    elif check_against_hyphen():
      debprint("Matched: Clause check_against_hyphen()")
      matched = True
    # The effect of the next clause is to handle cases where the
    # Arabic has a right bracket or similar character and the Latin has
    # a short vowel or shadda that doesn't match and needs to go before
    # the right bracket. The is_bow() check is necessary because
    # left-bracket is part of word_interrupting_chars and when the
    # left bracket is word-initial opposite a short vowel, the bracket
    # needs to be handled first. Similarly for word-initial tatwil, etc.
    #
    # Note that we can't easily generalize the word_interrupting_chars
    # check. We used to do so, calling get_matches() and looking where
    # the match has only an empty string, but this messed up on words
    # like زنىً (zinan) where the silent_alif_maqsuura_subst has only
    # an empty string matching but we do want to consume it first
    # before checking for short vowels. Even earlier we had an even
    # more general check, calling get_matches() and checking that any
    # of the matches are an empty string. This had the side-effect of
    # fixing the qiṭṭun problem but made it impossible to vocalize the
    # ghurfatun al-kuuba example, among others.
    elif (not is_bow() and aind[0] < alen and
        ar[aind[0]] in word_interrupting_chars and
        check_unmatching()):
      debprint("Matched: Clause 1")
      matched = True
    elif check_bow_alif():
      debprint("Matched: Clause check_bow_alif()")
      matched = True
    elif aind[0] < alen and match():
      debprint("Matched: Clause match()")
      matched = True
    elif check_eow_tanwin():
      debprint("Matched: Clause check_eow_tanwin()")
      matched = True
    elif check_unmatching():
      debprint("Matched: Clause check_unmatching()")
      matched = True
    elif check_skip_unmatching():
      debprint("Matched: Clause check_skip_unmatching()")
      matched = True
    if not matched:
      if err:
        cant_match()
      else:
        return False

  arabic = "".join(res)
  latin = "".join(lres)
  arabic = post_canonicalize_arabic(arabic)
  latin = post_canonicalize_latin(latin)
  return arabic, latin

def remove_diacritics(word):
  return arabiclib.remove_diacritics(word)

######### Transliterate directly, without unvocalized Arabic to guide #########
#########             (NEEDS WORK)            #########

tt_to_arabic_direct = {
  # consonants
  u"b":u"ب", u"t":u"ت", u"ṯ":u"ث", u"θ":u"ث", # u"th":u"ث",
  u"j":u"ج",
  u"ḥ":u"ح", u"ħ":u"ح", u"ḵ":u"خ", u"x":u"خ", # u"kh":u"خ",
  u"d":u"د", u"ḏ":u"ذ", u"ð":u"ذ", u"đ":u"ذ", # u"dh":u"ذ",
  u"r":u"ر", u"z":u"ز", u"s":u"س", u"š":u"ش", # u"sh":u"ش",
  u"ṣ":u"ص", u"ḍ":u"ض", u"ṭ":u"ط", u"ẓ":u"ظ",
  u"ʿ":u"ع", u"ʕ":u"ع",
  u"`":u"ع",
  u"3":u"ع",
  u"ḡ":u"غ", u"ġ":u"غ", u"ğ":u"غ",  # u"gh":u"غ",
  u"f":u"ف", u"q":u"ق", u"k":u"ك", u"l":u"ل", u"m":u"م", u"n":u"ن",
  u"h":u"ه",
  # u"a":u"ة", u"ah":u"ة"
  # tâʾ marbûṭa (special) - always after a fátḥa (a), silent at the end of
  # an utterance, "t" in ʾiḍâfa or with pronounced tanwîn
  # \u0629 = tâʾ marbûṭa = ة
  # control characters
  # zwj:u"", # ZWJ (zero-width joiner)
  # rare letters
  u"p":u"پ", u"č":u"چ", u"v":u"ڤ", u"g":u"گ",
  # semivowels or long vowels, alif, hamza, special letters
  u"â":u"\u064Eا", # ʾalif = \u0627
  # u"aa":u"\u064Eا", u"a:":u"\u064Eا"
  # hamzated letters
  u"ʾ":u"ء",
  u"’":u"ء",
  u"'":u"ء",
  u"w":u"و",
  u"y":u"ي",
  u"û":u"\u064Fو", # u"uu":u"\u064Fو", u"u:":u"\u064Fو"
  u"î":u"\u0650ي", # u"ii":u"\u0650ي", u"i:":u"\u0650ي"
  # u"â":u"ى", # ʾalif maqṣûra = \u0649
  # u"an":u"\u064B" = fatḥatân
  # u"un":u"\u064C" = ḍammatân
  # u"in":u"\u064D" = kasratân
  u"a":u"\u064E", # fatḥa
  u"u":u"\u064F", # ḍamma
  u"i":u"\u0650", # kasra
  # \u0651 = šadda - doubled consonant
  # u"\u0652":u"", #sukûn - no vowel
  # ligatures
  # u"ﻻ":u"lâ",
  # u"ﷲ":u"llâh",
  # taṭwîl
  # numerals
  u"1":u"١", u"2":u"٢",# u"3":u"٣",
  u"4":u"٤", u"5":u"٥",
  u"6":u"٦", u"7":u"٧", u"8":u"٨", u"9":u"٩", u"0":u"٠",
  # punctuation (leave on separate lines)
  u"?":u"؟", # question mark
  u",":u"،", # comma
  u";":u"؛" # semicolon
}

# Transliterate any words or phrases from Latin into Arabic script.
# POS, if not None, is e.g. "noun" or "verb", controlling how to handle
# final -a.
#
# FIXME: NEEDS WORK. Works but ignores POS. Doesn't yet generate the correct
# seat for hamza (need to reuse code in Module:ar-verb to do this). Always
# transliterates final -a as fatḥa, never as tâʾ marbûṭa (should make use of
# POS for this). Doesn't (and can't) know about cases where sh, th, etc.
# stand for single letters rather than combinations.
def tr_latin_direct(text, pos, msgfun=msg):
  text = pre_canonicalize_latin(text, msgfun=msg)
  text = rsub(text, u"ah$", u"\u064Eة")
  text = rsub(text, u"âh$", u"\u064Eاة")
  text = rsub(text, u".", tt_to_arabic_direct)
  # convert double consonant to consonant + shadda
  text = rsub(text, u"([" + lconsonants + u"])\\1", u"\\1\u0651")
  text = post_canonicalize_arabic(text)

  return text

################################ Test code ##########################

num_failed = 0
num_succeeded = 0

def test(latin, arabic, should_outcome):
  global num_succeeded, num_failed
  try:
    result = tr_matching(arabic, latin, True)
  except RuntimeError as e:
    uniprint(u"%s" % e)
    result = False
  if result == False:
    uniprint("tr_matching(%s, %s) = %s" % (arabic, latin, result))
    outcome = "failed"
  else:
    canonarabic, canonlatin = result
    trlatin = tr(canonarabic)
    uniout("tr_matching(%s, %s) = %s %s," %
        (arabic, latin, canonarabic, canonlatin))
    if trlatin == canonlatin:
      uniprint("tr() MATCHED")
      outcome = "matched"
    else:
      uniprint("tr() UNMATCHED (= %s)" % trlatin)
      outcome = "unmatched"
  canonlatin, _ = canonicalize_latin_arabic(latin, None)
  uniprint("canonicalize_latin(%s) = %s" %
      (latin, canonlatin))
  if outcome == should_outcome:
    uniprint("TEST SUCCEEDED.")
    num_succeeded += 1
  else:
    uniprint("TEST FAILED.")
    num_failed += 1

def run_tests():
  global num_succeeded, num_failed
  num_succeeded = 0
  num_failed = 0
  test(u"loğat-nâme", u"لغت‌نامه", "matched")
  test("farhang", "فرهنگ", "matched")
  test(u"vâže-nâme", u"واژه‌نامه", "matched")
  test(u"qâmus", u"قاموس", "matched")
  test("katab", u"كتب", "matched")
  test("kattab", u"كتب", "matched")
  test(u"kátab", u"كتب", "matched")
  test("katab", u"كتبٌ", "matched")
  test("kat", u"كتب", "failed") # should fail
  test("katabaq", u"كتب", "failed") # should fail
  test("dakhala", u"دخل", "matched")
  test("al-dakhala", u"الدخل", "matched")
  test("ad-dakhala", u"الدخل", "matched")
  test("al-la:zim", u"اللازم", "matched")
  test("al-bait", u"البيت", "matched")
  test("wa-dakhala", u"ودخل", "unmatched")
  # The Arabic of the following consists of wâw + fatḥa + ZWJ + dâl + ḵâʾ + lâm.
  test("wa-dakhala", u"وَ‍دخل", "matched")
  # The Arabic of the following two consists of wâw + ZWJ + dâl + ḵâʾ + lâm.
  test("wa-dakhala", u"و‍دخل", "matched")
  test("wa-dakhala", u"و-دخل", "matched")
  test("wadakhala", u"و‍دخل", "failed") # should fail, ZWJ must match hyphen
  test("wadakhala", u"ودخل", "matched")
  # Six different ways of spelling a long û.
  test("duuba", u"دوبة", "matched")
  test(u"dúuba", u"دوبة", "matched")
  test("duwba", u"دوبة", "matched")
  test("du:ba", u"دوبة", "matched")
  test(u"dûba", u"دوبة", "matched")
  test(u"dū́ba", u"دوبة", "matched")
  # w definitely as a consonant, should be preserved
  test("duwaba", u"دوبة", "matched")

  # Similar but for î and y
  test("diiba", u"ديبة", "matched")
  test(u"díiba", u"ديبة", "matched")
  test("diyba", u"ديبة", "matched")
  test("di:ba", u"ديبة", "matched")
  test(u"dîba", u"ديبة", "matched")
  test(u"dī́ba", u"ديبة", "matched")
  test("diyaba", u"ديبة", "matched")

  # Test o's and e's
  test(u"dôba", u"دوبة", "unmatched")
  test(u"dôba", u"دُوبة", "unmatched")
  test(u"telefôn", u"تلفون", "unmatched")

  # Test handling of tâʾ marbûṭa
  # test of "duuba" already done above.
  test("duubah", u"دوبة", "matched") # should be reduced to -a
  test("duubaa", u"دوباة", "matched") # should become -âh
  test("duubaah", u"دوباة", "matched") # should become -âh
  test("mir'aah", u"مرآة", "matched") # should become -âh

  # Test the definite article and its rendering in Arabic
  test("al-duuba", u"اَلدّوبة", "matched")
  test("al-duuba", u"الدّوبة", "matched")
  test("al-duuba", u"الدوبة", "matched")
  test("ad-duuba", u"اَلدّوبة", "matched")
  test("ad-duuba", u"الدّوبة", "matched")
  test("ad-duuba", u"الدوبة", "matched")
  test("al-kuuba", u"اَلْكوبة", "matched")
  test("al-kuuba", u"الكوبة", "matched")
  test("baitu l-kuuba", u"بيت الكوبة", "matched")
  test("baitu al-kuuba", u"بيت الكوبة", "matched")
  test("baitu d-duuba", u"بيت الدوبة", "matched")
  test("baitu ad-duuba", u"بيت الدوبة", "matched")
  test("baitu l-duuba", u"بيت الدوبة", "matched")
  test("baitu al-duuba", u"بيت الدوبة", "matched")
  test("bait al-duuba", u"بيت الدوبة", "matched")
  test("bait al-Duuba", u"بيت الدوبة", "matched")
  test("bait al-kuuba", u"بيت الكوبة", "matched")
  test("baitu l-kuuba", u"بيت ٱلكوبة", "matched")

  test(u"ʼáwʻada", u"أوعد", "matched")
  test(u"'áwʻada", u"أوعد", "matched")
  # The following should be self-canonicalized differently.
  test(u"`áwʻada", u"أوعد", "matched")

  # Test handling of tâʾ marbûṭa when non-final
  test("ghurfatu l-kuuba", u"غرفة الكوبة", "matched")
  test("ghurfatun al-kuuba", u"غرفةٌ الكوبة", "matched")
  test("al-ghurfatu l-kuuba", u"الغرفة الكوبة", "matched")
  test("ghurfat al-kuuba", u"غرفة الكوبة", "unmatched")
  test("ghurfa l-kuuba", u"غرفة الكوبة", "unmatched")
  test("ghurfa(t) al-kuuba", u"غرفة الكوبة", "matched")
  test("ghurfatu l-kuuba", u"غرفة ٱلكوبة", "matched")
  test("ghurfa l-kuuba", u"غرفة ٱلكوبة", "unmatched")
  test("ghurfa", u"غرفةٌ", "matched")

  # Test handling of tâʾ marbûṭa when final
  test("ghurfat", u"غرفةٌ", "matched")
  test("ghurfa(t)", u"غرفةٌ", "matched")
  test("ghurfa(tun)", u"غرفةٌ", "matched")
  test("ghurfat(un)", u"غرفةٌ", "matched")

  # Test handling of embedded links
  test(u"’âlati l-fam", u"[[آلة]] [[فم|الفم]]", "matched")
  test(u"arqâm hindiyya", u"[[أرقام]] [[هندية]]", "matched")
  test(u"arqâm hindiyya", u"[[رقم|أرقام]] [[هندية]]", "matched")
  test(u"arqâm hindiyya", u"[[رقم|أرقام]] [[هندي|هندية]]", "matched")
  test(u"ʾufuq al-ħadaŧ", u"[[أفق]] [[حادثة|الحدث]]", "matched")

  # Test transliteration that omits initial hamza (should be inferrable)
  test(u"aṣdiqaa'", u"أَصدقاء", "matched")
  test(u"aṣdiqā́'", u"أَصدقاء", "matched")
  # Test random hamzas
  test(u"'aṣdiqā́'", u"أَصدقاء", "matched")
  # Test capital letters for emphatics
  test(u"aSdiqaa'", u"أَصدقاء", "matched")
  # Test final otiose alif maqṣûra after fatḥatân
  test("hudan", u"هُدًى", "matched")
  # Test opposite with fatḥatân after alif otiose alif maqṣûra
  test(u"zinan", u"زنىً", "matched")

  # Check that final short vowel is canonicalized to a long vowel in the
  # presence of a corresponding Latin long vowel.
  test("'animi", u"أنمي", "matched")
  # Also check for 'l indicating assimilation.
  test("fi 'l-marra", u"في المرة", "matched")

  # Test cases where short Latin vowel corresponds to Long Arabic vowel
  test("diba", u"ديبة", "unmatched")
  test("tamariid", u"تماريد", "unmatched")
  test("tamuriid", u"تماريد", "failed")

  # Single quotes in Arabic
  test("man '''huwa'''", u"من '''هو'''", "matched")

  # Alif madda
  test("'aabaa'", u"آباء", "matched")
  test("mir'aah", u"مرآة", "matched")

  # Test case where close bracket occurs at end of word and an unmatched
  # vowel or shadda needs to be before it.
  test(u"fuuliyy", u"[[فولي]]", "matched")
  test(u"fuula", u"[[فول]]", "matched")
  test(u"wa-'uxt", u"[[و]][[أخت]]", "unmatched")
  # Here we test when an open bracket occurs in the middle of a word and
  # an unmatched vowel or shadda needs to be before it.
  test(u"wa-'uxt", u"و[[أخت]]", "unmatched")

  # Test hamza against non-hamza
  test(u"'uxt", u"اخت", "matched")
  test(u"uxt", u"أخت", "matched")
  test(u"'ixt", u"اخت", "matched")
  test(u"ixt", u"أخت", "matched") # FIXME: Should be "failed" or should correct hamza

  # Test alif after al-
  test(u"al-intifaaḍa", u"[[الانتفاضة]]", "matched")
  test(u"al-'uxt", u"الاخت", "matched")

  # Test adding ! or ؟
  test(u"fan", u"فن!", "matched")
  test(u"fan!", u"فن!", "matched")
  test(u"fan", u"فن؟", "matched")
  test(u"fan?", u"فن؟", "matched")

  # Test inferring fatḥatân
  test("hudan", u"هُدى", "matched")
  test("qafan", u"قفا", "matched")
  test("qafan qafan", u"قفا قفا", "matched")

  # Case where shadda and -un are opposite each other; need to handle
  # shadda first.
  test(u"qiṭṭ", u"قِطٌ", "matched")

  # 3 consonants in a row
  test(u"Kûlûmbîyâ", u"كولومبيا", "matched")
  test(u"fustra", u"فسترة", "matched")

  # Allâh
  test(u"allâh", u"الله", "matched")

  # Test dagger alif, alif maqṣûra
  test(u"raḥmân", u"رَحْمٰن", "matched")
  test(u"fusḥâ", u"فسحى", "matched")
  test(u"fusḥâ", u"فُسْحَى", "matched")
  test(u"'âxir", u"آخر", "matched")

  # Real-world tests
  test(u"’ijrâ’iy", u"إجْرائِيّ", "matched")
  test(u"wuḍûʕ", u"وضوء", "matched")
  test(u"al-luḡa al-ʾingilîziyya", u"اَلْلُّغَة الْإنْجِلِيزِيّة", "unmatched")
  test(u"šamsíyya", u"شّمسيّة", "matched")
  test(u"Sirbiyâ wa-l-Jabal al-Aswad", u"صربيا والجبل الأسود", "unmatched")
  test(u"al-’imaraat", u"الإمارات", "unmatched")
  # FIXME: Should we canonicalize to al-?
  test(u"al'aan(a)", u"الآن", "unmatched")
  test(u"yûnânîyya", u"يونانية", "matched")
  test(u"hindiy-'uruubiy", u"هندي-أوروبي", "unmatched")
  test(u"moldôva", u"مولدوفا", "unmatched")
  test(u"darà", u"درى", "matched")
  test(u"waraa2", u"وراء", "matched")
  test(u"takhaddaa", u"تحدى", "matched")
  test(u"qaránful", u"ﻗﺮﻧﻔﻞ", "matched")
  # Can't easily handle this one because ال matches against -r- in the
  # middle of a word.
  # test(u"al-sâʿa wa-'r-rubʿ", u"الساعة والربع", "matched")
  test(u"taḥṭîṭ", u"تخطيط", "matched")
  test(u"hâḏihi", u"هذه", "matched")
  test(u"ħaláːt", u"حَالاَتٌ", "unmatched")
  test(u"raqṣ šarkiyy", u"رقص شرقي", "matched")
  test(u"ibn ʾaḵ", u"[[اِبْنُ]] [[أَخٍ]]", "matched")
  test(u"al-wuṣṭâ", u"الوسطى", "matched")
  test(u"fáħmu-l-xášab", u"فحم الخشب", "matched")
  test(u"gaṡor", u"قَصُر", "unmatched")
  # Getting this to work makes it hard to get e.g. nijir vs. نيجر to work.
  # test(u"sijâq", u"سِيَاق", "matched")
  test(u"winipiigh", u"وينيبيغ", "unmatched")
  test(u"ʿaḏrâʿ", u"عذراء", "matched")
  test(u"ʂaʈħ", u"سطْح", "matched")
  test(u"dʒa'", u"جاء", "unmatched")
  #will split when done through canon_arabic.py, but not here
  #test(u"ʿíndak/ʿíndak", u"عندك", "matched") # should split
  test(u"fi 'l-ḡad(i)", u"في الغد", "matched")
  test(u"ḩaythu", u"حَيثُ", "matched")
  test(u"’iʐhâr", u"إظهار", "matched")
  test(u"taħli:l riya:dˤiy", u"تَحْلِيلْ رِيَاضِي", "matched")
  test(u"al-'ingilizíyya al-'amrikíyya", u"الإنجليزية الأمريكية", "unmatched")
  test(u"ḵаwḵa", u"خوخة", "matched") # this has a Cyrillic character in it
  test(u"’eħsâs", u"احساس", "unmatched")
  # Up through page 848 "sense"
  test(u"wayd-jaylz", u"ويد–جيلز", "matched")
  test(u"finjáːn šæːy", u"فِنْجَان شَاي", "matched")
  test(u"múdhhil", u"مذهل", "matched")
  test(u"ixtiâr", u"اختيار", "matched")
  test(u"miṯll", u"مثل", "matched")
  test(u"li-wajhi llâh", u"لِوَجْهِ اللهِ", "unmatched")

  # FIXME's: assimilating_l_subst only matches against canonical sun
  # letters, not against non-canonical ones like θ. We can fix that
  # by adding all the non-canonical ones to ttsun1[], or maybe just
  # matching anything that's not a vowel.
  #test(u"tišrînu θ-θâni", u"تِشرينُ الثّانِي", "matched")

  # Final results
  uniprint("RESULTS: %s SUCCEEDED, %s FAILED." % (num_succeeded, num_failed))

if __name__ == "__main__":
  run_tests()
