#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Authors: Benwing

import re, unicodedata
import arabiclib
from arabiclib import *
from blib import remove_links, msg

# FIXME!!
#
# NEEDS LOTS OF WORK
#
# Some issues to take care of:
#
# 1. o against و especially in loanwords: [THIS IS OK]
# * {{t|fa|کروآت|tr=koroât}} "Croatian"
# * {{t|fa|نوردراین-وستفالن|tr=nordrâyn-vestfâlen|sc=fa-Arab}} "North Rhine-Westphalia"
# * {{tt+|fa|هورن|tr=horn}} "horn"
# * {{t|fa|آنتلوپ|tr=ântelop}} "antelope"
# but not always:
# * {{t+|fa|هلند|tr=holand}} "Holland"
#
# 2. silent و in خو: {{t+|fa|خوابیده|tr=xâbide|sc=fa-Arab}} "asleep" [SUPPORTED]
#
# 3. missing ' against ع: {{t+|fa|عطر|tr=atr|sc=fa-Arab}} "scent" [SUPPORTED]
#
# 4. ezafe: {{t|fa|برادر ناتنی|tr=barâdar-e nâtani}} "half brother" [SUPPORTED]
#
# 5. tā' marbūṭa:
# * {{t+|fa|دایرةالمعارف|tr=dâyerat-ol-ma'âref|sc=fa-Arab}} "encyclopedia"
# * {{t|fa|دائرةالمعارف|tr=dâ'erat-ol-ma'âref|sc=fa-Arab}} "encyclopedia"
#
# 6. short Latin a against long Arabic ا: [SUPPORTED AND CANONICALIZED]
# * {{t+|fa|چمدان|tr=chamedan}} "portmanteau"
#
# 7. no Latin hyphen against ZWNJ: (QUESTION: should we add a hyphen here?) [ANSWER: YES]
# * {{t|fa|بی‌معنی|tr=bima'ni}} "nonsense"
#
# 8. final h or no h against Arabic ه: (QUESTION: should final Arabic ه be transliterated as h always, never or sometimes?)
# * With final -eh, there appears to be no consistency in whether h appears:
# *   {{t+|fa|چهارشنبه|tr=čahâr-šanbe|sc=fa-Arab}} "Wednesday" vs.
# *   {{t|fa|پنج‌شنبه|tr=panj-šanbeh|sc=fa-Arab}} "Thursday"
# * But what about single-syllable -eh? {{t+|fa|زه|tr=zeh|sc=fa-Arab}} "string", {{tt+|fa|مه|tr=meh}} "fog", {{t+|fa|ده|tr=deh}} "village" etc.
# * {{t+|fa|ماه|tr=mâh}} "month" canon-changed to mâ (RIGHT OR WRONG?)
# * {{t|fa|راه پیمایی|tr=râh-peymâyi}} "march" canon-changed to râ peymâyi (RIGHT OR WRONG?)
# * {{t+|fa|کشتارگاه|tr=koštârgâh|sc=fa-Arab}} "abattoir" canon-changed to koštârgâ (RIGHT OR WRONG?)
# * {{t+check|fa|نُه|tr=noh}} canon-changed to no (RIGHT OR WRONG?)
# * {{tt+|fa|انبوه|tr=anbuh|sc=fa-Arab}} canon-changed to anbu (RIGHT OR WRONG?)
#
# 9. Latin hyphen against Arabic space: (QUESTION: is it correct to change hyphen to space here?) [ANSWER: NO]
# * {{t+|fa|کدو حلوایی|tr=kadu-halvâyi}} "pumpkin" canon-changed to kadu halvâyi (RIGHT OR WRONG?)
# * {{t+|fa|سلاخ خانه|tr=sallâx-xâne|sc=fa-Arab} "abattoir" canon-changed to sallâx xâne (RIGHT OR WRONG?)
# * {{t|fa|اس ام اس|tr=es-em-es|sc=fa-Arab}} "SMS" canon-changed to es em es (RIGHT OR WRONG?)
# * {{t+|fa|هرج و مرج|tr=harj-o-marj}} "anarchy" canon-changed to harj o marj (RIGHT OR WRONG?)
#
# 10. Canonicalizing ō to ô and ē to ê: (QUESTION: is this OK?) [ANSWER: YES]
# * {{tt|fa|خوروران|tr=xōrvarân}} "west" canon-changed to xôrvarân (RIGHT OR WRONG?)
# * {{tt+|fa|میوه|tr=mēva}} "fruit" canon-changed to mêva (RIGHT OR WRONG?)
# * {{tt+|fa|بارو|tr=bârō}} "wall" canon-changed to bârô (RIGHT OR WRONG?)
#
# FIXME:
# 1. Support insert=, append=.
# 2. Remove final -h after e in multisyllabic words (in post-canonicalization).
# 3. Canonicalize m -> n against ن before ب. [DONE]
# 4. Canonicalize h -> x against خ. [DONE]
# 5. Handle اً against -an. [DONE]

debug_tr_matching = False

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

def rsub_repeatedly(text, fr, to):
  while True:
    result = rsub(text, fr, to)
    if result == text:
      return result
    text = result

def error(text):
  raise RuntimeError(text)

def nfkc_form(txt):
  return unicodedata.normalize("NFKC", unicode(txt))

def nfc_form(txt):
  return unicodedata.normalize("NFC", unicode(txt))

ZWNJ = u"\u200c" # zero-width non-joiner
ZWJ = u"\u200d" # zero-width joiner
AC = u"\u0301" # acute accent
GR = u"\u0300" # grave accent
#LRM = u"\u200e" # left-to-right mark
#RLM = u"\u200f" # right-to-left mark

sun_letters = u"تثدذرزسشصضطظلن"
# Characters signifying the beginning of a word of part of a compound, meant to go inside [] in a regex.
boc_chars = r" \[|" + ZWNJ
# FIXME, do we still want ə here?
vowel_chars = u"aeiouâêîôûə"

consonants_needing_vowels = u"بتثجحخدذرزسشصضطظعغفقكلمنهپچڤگڨڧأإؤئءةﷲ"
# consonants on the right side; includes alif madda
rconsonants = consonants_needing_vowels + u"ویآ"
# consonants on the left side; does not include alif madda
lconsonants = consonants_needing_vowels + u"وی"
punctuation = (u"؟،؛" # Arabic semicolon, comma, question mark
         + u"ـ" # tatweel
         + ".!'" # period, exclamation point, single quote for bold/italic
         )
numbers = u"۱۲۳۴۵۶۷۸۹۰"


# Transliterate the word(s) in TEXT. LANG (the language) and SC (the script)
# are ignored. FORCE_TRANSLATE causes even non-vocalized text to be transliterated
# (normally the function checks for non-vocalized text and returns nil,
# since such text is ambiguous in transliteration).
def tr(text, lang=None, sc=None, force_translate=False, msgfun=msg):
  # FIXME: Implement me
  return None


############################################################################
#                    Transliterate from Latin to Arabic                    #
############################################################################

#########     Transliterate with unvocalized Arabic to guide     #########

silent_alif_subst = u"\ufff1"
silent_alif_maqsuura_subst = u"\ufff2"
multi_single_quote_subst = u"\ufff3"
assimilating_l_subst = u"\ufff4"
double_l_subst = u"\ufff5"
dagger_alif_subst = u"\ufff6"

hamza_match = ["'",u"ʾ",u"ʼ",u"´",("`",),u"ʔ",u"’",(u"‘",),u"ˀ",(u"ʕ",),(u"ʿ",),"2"]
hamza_match_or_empty = hamza_match + [""]
hamza_match_chars = [x[0] if isinstance(x, (list, tuple)) else x for x in hamza_match]

class LatinMatch(object):
  def __init__(self, match, canon_to=None, when=None, insert=None, append=None):
    self.match = match
    self.canon_to = canon_to
    self.when = when
    self.insert = insert
    self.append = append

class State(object):
  def __init__(self, ar, aind, alen, la, lind, llen, res, lres, classical):
    self.ar = ar
    self.aind = aind
    self.alen = alen
    self.la = la
    self.lind = lind
    self.llen = llen
    self.res = res
    self.lres = lres
    self.classical = classical

  def nextar(self, howmany=1):
    if self.aind[0] + howmany >= self.alen:
      return None
    return self.ar[self.aind[0] + howmany]

  def nextla(self, howmany=1):
    if self.lind[0] + howmany >= self.llen:
      return None
    return self.la[self.lind[0] + howmany]

  def prevar(self, howmany=1):
    if self.aind[0] - howmany < 0:
      return None
    return self.ar[self.aind[0] - howmany]

  def prevla(self, howmany=1):
    if self.lind[0] - howmany < 0:
      return None
    return self.la[self.lind[0] - howmany]

  def thisar(self):
    return self.nextar(0)

  def thisla(self):
    return self.nextla(0)


# Special-case matching at beginning of word. Plain alif normally corresponds
# to nothing, and hamza seats might correspond to nothing (omitted hamza
# at beginning of word). We can't allow e.g. أ to have "" as one of its
# possibilities mid-word because that will screw up a word like سألة "saʾala",
# which won't match at all because the أ will match nothing directly after
# the Latin "s", and then the ʾ will never be matched.
tt_to_arabic_matching_bow = { #beginning of word
  u"ا":"",
  # These don't occur word-initially in Persian
  #u"أ":hamza_match_or_empty,
  #u"إ":hamza_match_or_empty,
  u"آ":[u"â"], #ʾalif madda = \u0622
}

tt_to_arabic_matching_boc = { #beginning of later part of a compound
  u"ا":[
    u"\uFFFE", # shouldn't match; just a placeholder; all possible matches follow
    LatinMatch("a", canon_to="a", append=A),
    LatinMatch("o", canon_to="o", append=U),
    LatinMatch("u", canon_to=lambda st: "u" if st.classical else "o", append=U,
      # don't consume u in او
      when=lambda st: st.nextar() != u"و"),
    LatinMatch("e", canon_to="e", append=I),
    LatinMatch("i", canon_to=lambda st: "i" if st.classical else "e", append=I,
      # don't consume i in ای
      when=lambda st: st.nextar() != u"ی"),
    ["'"],
    [""]
  ],
  # These don't occur word-initially in Persian
  #u"أ":hamza_match_or_empty,
  #u"إ":hamza_match_or_empty,
  u"آ":[u"â"], #ʾalif madda = \u0622
}

# Special-case matching at end of word.
tt_to_arabic_matching_eow = { # end of word
  u"ه": ["h", [""]],
  # These don't occur word-finally in Persian
  #UN:["un",""], # dammatân
  #IN:["in",""], # kasratân
}

# This dict maps Arabic characters to all the Latin characters that might correspond to them. The entries can be a
# string (equivalent to a one-entry list) or a list of strings or one-element lists containing strings (the latter is
# equivalent to a string but suppresses canonicalization during transliteration; see below). The ordering of elements
# in the list is important insofar as which element is first, because the default behavior when canonicalizing a
# transliteration is to substitute any string in the list with the first element of the list (this can be suppressed by
# making an element a one-entry list containing a string, as mentioned above).
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
  u"ت":"t",
  u"ث":["s",u"ṯ",u"ŧ",u"θ","th",u"s̱",u"s̄"],
  # FIXME! We should canonicalize ʒ to ž
  u"ج":["j",u"ǧ",u"ğ",u"ǰ","dj",u"dǧ",u"dğ",u"dǰ",u"dž",u"dʒ",[u"ʒ"],[u"ž"],["g"]],
  u"چ":[u"č","ch","c"],
  # Allow what would normally be capital H, but we lowercase all text
  # before processing.
  # I feel a bit uncomfortable allowing kh to match against ح like this,
  # but generally I trust the Arabic more.
  u"ح":["h",u"ḥ",u"ħ",u"ẖ",u"ḩ","7",("kh",)],
  # I feel a bit uncomfortable allowing ḥ to match against خ like this,
  # but generally I trust the Arabic more.
  u"خ":["x",u"k͟h",u"ḵ","kh",u"ḫ",u"ḳ",u"ẖ",u"χ",(u"ḥ",),"h"],
  u"د":"d",
  u"ذ":["z",u"d͟h",u"ḏ",u"đ",u"ð","dh",u"ḍ",u"ẕ","d"],
  u"ر":"r",
  u"ز":"z",
  u"ژ":[u"ž",u"z͟h","zh"],
  # I feel a bit uncomfortable allowing emphatic variants of s to match
  # against س like this, but generally I trust the Arabic more.
  u"س":["s",(u"ṣ",),(u"sʿ",),(u"sˤ",),(u"sˁ",),(u"sʕ",),(u"ʂ",),(u"ṡ",)],
  u"ش":[u"š",u"s͟h","sh",u"ʃ"],
  u"ص":["s",u"ṣ",u"sʿ",u"sˤ",u"sˁ",u"sʕ",u"ʂ",u"ṡ"],
  u"ض":["z",u"ḍ",u"dʿ",u"dˤ"u"dˁ",u"dʕ",u"ẓ",u"ż",u"ẕ",u"ɖ",u"ḋ","d"],
  u"ط":["t",u"ṭ",u"tʿ",u"tˤ",u"tˁ",u"tʕ",u"ṫ",u"ţ",u"ŧ",u"ʈ",u"t̤"],
  u"ظ":["z",u"ẓ",u"ðʿ",u"ðˤ",u"ðˁ",u"ðʕ",u"ð̣",u"đʿ",u"đˤ",u"đˁ",u"đʕ",u"đ̣",
    u"ż",u"z̧",u"ʐ","dh"],
  u"ع":["'", u"ʿ",u"ʕ","`",u"‘",u"ʻ","3",u"ˤ",u"ˁ",(u"ʾ",),u"῾",(u"’",),""],
  u"غ":[u"ğ",u"ḡ",u"ġ","gh",["g"],("`",),"q",u"g͟h"],
  u"ف":["f",["v"]],
  # I feel a bit uncomfortable allowing k to match against q like this,
  # but generally I trust the Arabic more
  u"ق":["q",u"ḳ",["g"],"gh",u"g͟h","k"],
  u"ك":["k",["g"]],
  u"ک":["k",["g"]],
  u"گ":"g",
  u"ل":"l",
  u"م":"m",
  u"ن":["n", LatinMatch("m", canon_to="n", when=lambda st: st.nextla() == "b")],
  u"ه":"h",
  u"ۀ":"y",
  # [We have special handling for the following in the canonicalized Latin,
  # so that we have -a but -âh and -at-.] -- I think this is no longer true.
  u"ة":["h",["t"],["(t)"],""],
  # control characters
  # We handle hyphen against ZWNJ specially in check_against_hyphen() and other_arabic_chars, but we still need the
  # following for the case where ZWNJ is unmatched on the Latin side.
  ZWNJ:["-",""], # ZWNJ (zero-width non-joiner)
  #ZWJ:["-"],#,""], # ZWJ (zero-width joiner)
  # rare letters
  u"پ":"p",
  u"چ":[u"č","ch"],
  u"ڤ":"v",
  u"ڨ":"g",
  u"ڧ":"q",
  # semivowels or long vowels, alif, hamza, special letters
  # Note, the following ensures that short a against ا gets canonicalized to â, except in اً = -an.
  u"ا":[u"â",LatinMatch("a", canon_to=lambda st: "a" if st.nextar() == AN else u"â")], # ʾalif = \u0627
  silent_alif_subst:[[""]],
  silent_alif_maqsuura_subst:[[""]],
  # hamzated letters
  u"أ":hamza_match_or_empty,
  u"إ":hamza_match_or_empty,
  u"ؤ":hamza_match_or_empty,
  u"ئ":hamza_match_or_empty,
  u"ء":hamza_match_or_empty,
  # Note, w before a vowel not after k/g/x is post-canonicalized to v.
  u"و":["v",["w"],LatinMatch("ow", canon_to="ow", insert=U),
      # not currently needed as we pre-canonicalize ou to ow
      #LatinMatch("ou", canon_to="ow",insert=U),
      LatinMatch("ov", canon_to="ov",insert=U),
      ["u"],[u"ô"],["o"],
      LatinMatch(u"û", canon_to=lambda st: u"û" if st.classical else "u"),
      # allow for silent و in خوا
      LatinMatch("", canon_to="", when=lambda st: st.prevar() == u"خ" and st.nextar() == u"ا")],
  # Adding j here creates problems with e.g. an-nijir vs. النیجر
  u"ی":[["y"],["iy"],["ey"],
      # not currently needed as we pre-canonicalize ei to ey 
      #LatinMatch("ei", canon_to="ey",insert=I),
      LatinMatch("ey", canon_to="ey",insert=I),
      ["i"],[u"ê"], # no e; short e opposite ی doesn't normally occur
      LatinMatch(u"î", canon_to=lambda st: u"î" if st.classical else "i")], #"j",
  u"ى":u"â", # alif maqsuura = \u0649
  u"آ":[u"'â",u"ʾâ",u"’â",u"'â",u"`â"], # ʾalif madda = \u0622
  u"ٱ":[[""]], # hamzatu l-waṣl = \u0671
  u"\u0670":u"â", # alif xanjariyya = dagger alif (Koranic diacritic)
  # short vowels, shadda and sukuun
  AN:"n", # fatḥatân
  # These don't normally occur in Persian.
  #u"\u064C":"un", # dammatan
  #u"\u064D":"in", # kasratan
  u"\u064E":"a", # fatḥa
  u"\u064F":[["o"], LatinMatch("u", canon_to=lambda st:"u" if st.classical else "o")], # damma
  u"\u0650":[["e"], LatinMatch("i", canon_to=lambda st:"i" if st.classical else "e")], # kasra
  SH:SH, # shadda - handled specially when matching Latin shadda
  double_l_subst:SH, # handled specially when matching shadda in Latin
  SK:"", #sukuun - no vowel
  # ligatures
  u"ﻻ":u"lâ",
  u"ﷲ":u"llâh",
  u"ـ":"", # tatweel, no sound
  # numerals
  u"۱":"1", u"۲":"2", u"۳":"3", u"۴":"4", u"۵":"5",
  u"۶":"6", u"۷":"7", u"۸":"8", u"۹":"9", u"۰":"0",
  # punctuation (leave on separate lines)
  u"؟":"?", # question mark
  u"،":",", # comma
  u"؛":";", # semicolon
  ".":".", # period
  "!":"!", # exclamation point
  "'":[("'",)], # single quote, for bold/italic
  " ":" ",
  "[":"",
  "]":"",
  # The following are unnecessary because we handle them specially in
  # check_against_hyphen() and other_arabic_chars.
  #"-":"-",
  #u"–":"-",
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
other_arabic_chars = [ZWJ, ZWNJ, "-", u"–"]

word_interrupting_chars = u"ـ[]"

build_canonicalize_latin = {}
for ch in "abcdefghijklmnopqrstuvwxyz3":
  build_canonicalize_latin[ch] = "multiple"
build_canonicalize_latin[""] = "multiple"

def sort_tt_to_arabic_matching(table):
  def canonicalize_entry(entries):
    if not isinstance(entries, list):
      entries = [entries]
    canon = entries[0]
    def element_length(el):
      if isinstance(el, (list, tuple)):
        el = el[0]
      elif isinstance(el, LatinMatch):
        el = el.match
      return len(el)
    return (canon, sorted(entries, key=lambda el: -element_length(el)))
  return {k: canonicalize_entry(v) for k, v in table.iteritems()}

tt_to_arabic_matching = sort_tt_to_arabic_matching(tt_to_arabic_matching)
tt_to_arabic_matching_bow = sort_tt_to_arabic_matching(tt_to_arabic_matching_bow)
tt_to_arabic_matching_boc = sort_tt_to_arabic_matching(tt_to_arabic_matching_boc)
tt_to_arabic_matching_eow = sort_tt_to_arabic_matching(tt_to_arabic_matching_eow)

# Make sure we don't canonicalize any canonical letter to any other one;
# e.g. could happen with ʾ, an alternative for ʿ.
for key, (canon, alts) in tt_to_arabic_matching.iteritems():
  if isinstance(canon, tuple):
    # FIXME: Is this correct?
    pass
  elif isinstance(canon, list):
    build_canonicalize_latin[canon[0]] = "multiple"
  elif isinstance(canon, LatinMatch):
    if callable(canon.match):
      # FIXME! Deal with this.
      pass
    else:
      build_canonicalize_latin[canon.match] = "multiple"
  else:
    build_canonicalize_latin[canon] = "multiple"

for key, (canon, alts) in tt_to_arabic_matching.iteritems():
  if isinstance(canon, list):
    # FIXME: What about if canon is tuple?
    continue
  for alt in alts:
    this_canon = canon
    if isinstance(alt, LatinMatch):
      this_canon = alt.canon_to
      if callable(this_canon):
        # FIXME! Deal with this.
        continue
      alt = alt.match
      if callable(alt):
        # FIXME! Deal with this.
        continue
    elif isinstance(alt, (list, tuple)):
      continue
    if alt == this_canon:
      continue
    if alt in build_canonicalize_latin and build_canonicalize_latin[alt] != this_canon:
      build_canonicalize_latin[alt] = "multiple"
    else:
      build_canonicalize_latin[alt] = this_canon

tt_canonicalize_latin = {}
for alt in build_canonicalize_latin:
  canon = build_canonicalize_latin[alt]
  if canon != "multiple":
    tt_canonicalize_latin[alt] = canon

# A list of Latin characters that are allowed to have particular unmatched
# Arabic characters following. This is used to allow short Latin vowels
# to correspond to long Arabic vowels. The value is the list of possible
# unmatching Arabic characters.
# FIXME: Doesn't seem to make sense for Persian.
#tt_skip_unmatching = {
#  "a":[u"ا"],
#  "u":[u"و"],
#  "o":[u"و"],
#  "i":[u"ی"],
#  "e":[u"ی"],
#}

# A list of Latin characters that are allowed to be unmatched in the Arabic. The value is the corresponding Arabic
# character to insert, or a tuple of the Arabic character to insert, the Latin character to replace the existing
# Latin character with, and a function checking that processing is OK.
tt_latin_to_unmatched_arabic = {
  "a":u"\u064E",
  "o":u"\u064F",
  # not if we're opposite ا; this occurs at boc with او
  "u":(u"\u064F", lambda st: "u" if st.classical else "o", lambda st: st.thisar() != u"ا"),
  "e":u"\u0650",
  # not if we're opposite ا; this occurs at boc with ای
  "i":(u"\u0650", lambda st: "i" if st.classical else "e", lambda st: st.thisar() != u"ا"),
  # Shadda because we pre-canonicalize doubled Latin letters to include a shadda.
  SH:SH,
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
  text = rsub(text, "<!--.*?-->", "")
  # remove embedded IPAchar templates
  text = rsub(text, r"\{\{IPAchar\|(.*?)\}\}", r"\1")
  # lowercase and remove leading/trailing spaces
  text = text.lower().strip()
  # canonicalize interior whitespace
  text = rsub(text, r"\s+", " ")
  # convert macrons to circumflexed vowels
  text = rsub(text, ".",
    {u"ā":u"â", u"ē":u"ê", u"ī":u"î", u"ō":u"ô", u"ū":u"û"})
  # FIXME: Still needed with Persian text?
  # eliminate ' after space or - and before non-vowel, indicating elided /a/
  # text = rsub(text, r"([ -])'([^'" + vowel_chars + "])", r"\1\2")
  # eliminate accents
  text = rsub(text, ".",
    {u"á":"a", u"é":"e", u"í":"i", u"ó":"o", u"ú":"u",
     u"à":"a", u"è":"e", u"ì":"i", u"ò":"o", u"ù":"u",
     u"ă":"a", u"ĕ":"e", u"ĭ":"i", u"ŏ":"o", u"ŭ":"u",
     u"ḗ":u"ê", u"ṓ":u"ô", # only these two vowels have a single Unicode char for macron+acute
     u"ä":"a", u"ë":"e", u"ï":"i", u"ö":"o", u"ü":"u"})
  # Eliminate miscellaneous acute/grave (e.g. if over ā ī ū)
  text = text.replace(AC, "")
  text = text.replace(GR, "")
  # canonicalize weird vowels
  text = text.replace(u"ɪ", "i")
  text = text.replace(u"ɑ", "a")
  text = text.replace(u"æ", "a")
  text = text.replace(u"а", "a") # Cyrillic a
  # eliminate doubled vowels = long vowels
  text = rsub(text, "([aeiou])\\1", {"a":u"â", "e":u"ê", "i":u"î", "o":u"ô", "u":u"û"})
  # eliminate vowels followed by colon = long vowels
  text = rsub(text, u"([aeiou])[:ː]", {"a":u"â", "e":u"ê", "i":u"î", "o":u"ô", "u":u"û"})

  # FIXME: We probably don't want this.
  # eliminate - or ' separating t-h, t'h, etc. in transliteration style
  # that uses th to indicate ث
  # text = rsub(text, "([dtgkcs])[-']h", "\\1h")

  # FIXME the following seem unnecessary.
  # substitute geminated digraphs, possibly with a hyphen in the middle
  #text = rsub(text, "dh(-?)dh", ur"ḏ\1ḏ")
  #text = rsub(text, "sh(-?)sh", ur"š\1š")
  #text = rsub(text, "th(-?)th", ur"ṯ\1ṯ")
  #text = rsub(text, "kh(-?)kh", ur"ḵ\1ḵ")
  #text = rsub(text, "gh(-?)gh", ur"ḡ\1ḡ")

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
  #text = rsub(text, u"iy($|[^y" + vowel_chars + "])", ur"î\1")
  ## Same for -uw- -> -û-
  #text = rsub(text, u"uw($|[^w" + vowel_chars + "])", ur"û\1")
  ## Insert y between i and a
  #text = rsub(text, u"([iî])([aâ])", r"\1y\2")
  ## Insert w between u and a
  #text = rsub(text, u"([uû])([aâ])", r"\1w\2")
  #text = rsub(text, u"îy", "iyy")
  #text = rsub(text, u"ûw", "uww")
  ## Reduce cases of three characters in a row (e.g. from îyy -> iyyy -> iyy);
  ## but not ''', which stands for boldface, or ..., which is legitimate
  #text = rsub(text, r"([^'.])\1\1", r"\1\1")
  ## Remove double consonant following another consonant, but only at
  ## word boundaries, since that's the only time when these cases seem to
  ## legitimately occur
  #text = re.sub(ur"([^\W" + vowel_chars + r"])(%s)\2\b" % (
  ##  latin_consonants_no_double_after_cons_re), r"\1\2", text, 0, re.U)
  ## Remove double consonant preceding another consonant but special-case
  ## a known example that shouldn't be touched.
  #if text != u"dunḡḡwân":
  #  text = re.sub(ur"([^\W" + vowel_chars + r"])\1(%s)" % (
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
  #  arabicwords = re.split(" +", arabic)
  #  latinwords = re.split(" +", text)
  #  # ... but only if the number of words in both is the same.
  #  if len(arabicwords) == len(latinwords):
  #    for i in xrange(len(latinwords)):
  #      aword = arabicwords[i]
  #      lword = latinwords[i]
  #      # If Arabic word ends with long alif or alif maqsuura, not
  #      # preceded by fatḥatân, convert short -a to long -â.
  #      if (re.search(u"[اى]$", aword) and not
  #          re.search(AN + u"[اى]$", aword)):
  #        lword = rsub(lword, r"a$", u"â")
  #      # If Arabic word ends in -yy, convert Latin -i/-î to -iyy
  #      # If the Arabic actually ends in -ayy or similar, this should
  #      # have no effect because in any vowel+i combination, we
  #      # changed i->y
  #      if re.search(u"يّ$", aword):
  #        lword = rsub(lword, u"[iî]$", "iyy")
  #      # If Arabic word ends in -y preceded by sukuun, assume
  #      # correct and convert final Latin -i/î to -y.
  #      if re.search(SK + u"ی$", aword):
  #        lword = rsub(lword, u"[iî]$", "y")
  #      # Otherwise, if Arabic word ends in -y, convert Latin -i to -î
  #      # WARNING: Many of these should legitimately be converted
  #      # to -iyy or perhaps (sukuun+)-y both in Arabic and Latin, but
  #      # it's impossible for us to know this.
  #      elif re.search(u"ی$", aword):
  #        lword = rsub(lword, "i$", u"î")
  #      # Except same logic, but for u/w vs. i/y
  #      if re.search(u"وّ$", aword):
  #        lword = rsub(lword, u"[uû]$", "uww")
  #      if re.search(SK + u"و$", aword):
  #        lword = rsub(lword, u"[uû]$", "w")
  #      elif re.search(u"و$", aword):
  #        lword = rsub(lword, "u$", u"û")
  #      # Echo a final exclamation point in the Latin
  #      if re.search("!$", aword) and not re.search("!$", lword):
  #        lword += "!"
  #      # Same for a final question mark
  #      if re.search(u"؟$", aword) and not re.search("\?$", lword):
  #        lword += "?"
  #      latinwords[i] = lword
  #    text = " ".join(latinwords)
  ##text = rsub(text, "[-]", "") # eliminate stray hyphens (e.g. in al-)
  return text

def post_canonicalize_latin(text):
  # iy + V may have been canonicalized to eyV; put it back.
  text = rsub(text, u"ey([" + vowel_chars + "])", r"iy\1")
  # w before a vowel becomes v except in kw-, xw-, gw-, where we leave it alone
  text = rsub(text, "(?<![kxg])w([" + vowel_chars + "])", r"v\1")
  # v after a vowel not before a vowel becomes w? (FIXME: not currently implemented)
  # Convert shadda back to double letter
  text = rsub(text, u"(.)" + SH, r"\1\1")
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
    latin = rsub(latin, ".", tt_canonicalize_latin)
    latin_chars = u"[a-zA-Zâêîôûčḍḏḡḥḵṣšṭṯẓžʿʾ]"
    # Convert 3 to ʿ if next to a letter or letter symbol. This tries
    # to avoid converting 3 in numbers.
    latin = rsub(latin, "(%s)3" % latin_chars, u"\\1ʿ")
    latin = rsub(latin, "3(%s)" % latin_chars, u"ʿ\\1")
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
  # replace Arabic, etc. characters with corresponding Farsi characters
  text = text.replace(u"ي", u"ی") # FARSI YEH
  text = text.replace(u"ك", u"ک") # ARABIC LETTER KEHEH (06A9)
  # convert llh for allâh into ll+shadda+dagger-alif+h
  text = rsub(text, u"لله", u"للّٰه")
  # uniprint("text enter: %s" % text)
  # shadda+short-vowel (including tanwîn vowels, i.e. -an -in -un) gets
  # replaced with short-vowel+shadda during NFC normalisation, which
  # MediaWiki does for all Unicode strings; however, it makes the
  # transliteration process inconvenient, so undo it.
  text = rsub(text,
    u"([\u064B\u064C\u064D\u064E\u064F\u0650\u0670])" + SH, SH + "\\1")
  # tāʾ marbūṭa should always be preceded by fatḥa, alif, alif madda or
  # dagger alif; infer fatḥa if not. This fatḥa will force a match to an "a"
  # in the Latin, so we can safely have tāʾ marbūṭa itself match "h", "t"
  # or "", making it work correctly with alif + tâʾ marbūṭa where
  # e.g. اة = ā and still correctly allow e.g. رة = ra but disallow رة = r.
  # FIXME: tāʾ marbūṭa doesn't exist in Farsi.
  #text = rsub(text, u"([^\u064E\u0627\u0622\u0670])\u0629",
  #  u"\\1\u064E\u0629")
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
  # similarly for sukuun + consonant + shadda.
  newtext = rsub(text, SK + "(.)" + SH, SK + r"\1")
  if text != newtext:
    msgfun(u"Removing shadda after sukuun + consonant in %s" % text)
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
        lconsonants + u"])" + SH, "\\1\\2")
    # same for hamzat al-waṣl + l + consonant + shadda, anywhere
    text = rsub(text,
        u"(\u0671\u064E?\u0644[" + lconsonants + u"])" + SH, "\\1")
    # word-initial al + l + dagger-alif + h (allâh): convert second l
    # to double_l_subst; will match shadda in Latin allâh during
    # tr_matching(), will be converted back during post-canonicalization
    text = rsub(text, u"(^|\\s|\[\[|\|)(\u0627\u064E?\u0644)\u0644(\u0670?ه)",
      "\\1\\2" + double_l_subst + "\\3")
    # same for hamzat al-waṣl + l + l + dagger-alif + h occurring anywhere.
    text = rsub(text, u"(\u0671\u064E?\u0644)\u0644(\u0670?ه)",
      "\\1" + double_l_subst + "\\2")
    # word-initial al + sun letter: convert l to assimilating_l_subst; will
    # convert back during post-canonicalization; during tr_matching(),
    # assimilating_l_subst will match the appropriate character, or "l"
    text = rsub(text, u"(^|\\s|\[\[|\|)(\u0627\u064E?)\u0644([" +
        sun_letters + "])", "\\1\\2" + assimilating_l_subst + "\\3")
    # same for hamzat al-waṣl + l + sun letter occurring anywhere.
    text = rsub(text, u"(\u0671\u064E?)\u0644([" + sun_letters + "])",
      "\\1" + assimilating_l_subst + "\\2")
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

    # FIXME: Unlikely we want this for Persian.
    # add sukuun between adjacent consonants, but not in the first part of
    # a link of the sort [[foo|bar]], which we don't vocalize
    #splitparts = []
    #index = 0
    #for part in re.split(r'(\[\[[^]]*\|)', text):
    #  if (index % 2) == 0:
    #    # do this twice because a sequence of three consonants won't be
    #    # matched by the initial one, since the replacement does
    #    # non-overlapping subs
    #    part = rsub_repeatedly(part,
    #        "([" + lconsonants + "])([" + rconsonants + "])",
    #        r"\1" + SK + r"\2")
    #  splitparts.append(part)
    #  index += 1
    #text = ''.join(splitparts)

  # remove sukuun after damma + wâw
  text = rsub(text, u"\u064F\u0648" + SK, u"\u064F\u0648")
  # remove sukuun after kasra + yâ'
  text = rsub(text, u"\u0650\u064A" + SK, u"\u0650\u064A")
  # initial al + consonant + sukuun + sun letter: convert to shadda
  text = rsub(text, u"(^|\\s|\[\[|\|)(\u0627\u064E?\u0644)" + SK + "([" + sun_letters + "])",
     "\\1\\2\\3" + SH)
  # same for hamzat al-waṣl + l + consonant + sukuun + sun letters anywhere
  text = rsub(text, u"(\u0671\u064E?\u0644)" + SK + "([" + sun_letters + "])",
     "\\1\\2" + SH)
  # Undo shadda+short-vowel reversal in pre_pre_canonicalize_arabic.
  # Not strictly necessary as MediaWiki will automatically do this
  # reversal but ensures that e.g. we don't keep trying to revocalize and
  # save a page with a shadda in it. Don't undo shadda+dagger-alif because
  # that sequence may not get reversed to begin with.
  text = rsub(text,
    SH + u"([\u064B\u064C\u064D\u064E\u064F\u0650])", "\\1" + SH)
  return text

# Vocalize Persian Arabic-script text based on transliterated Latin, and canonicalize the transliteration based on
# the Arabic script.  This works by matching the Latin to the unvocalized Arabic script and inserting the appropriate
# diacritics in the right places, so that ambiguities of Latin transliteration can be correctly handled. Returns a
# tuple of Arabic, Latin. If unable to match, throw an error if ERR, else return None.
def tr_matching(obj, arabic, latin, err=False, msgfun=msg):
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
  latin = re.sub(ur"(^|[\W" + vowel_chars + r"])([^'.])\2", r"\1\2" + SH,
      latin, 0, re.U)

  classical = False
  if obj:
    def pagemsg(txt):
      msg("Page %s %s: %s" % (obj.index, obj.pagetitle, txt))
    m = re.search("^.*" + re.escape(unicode(obj.t)) + ".*$", obj.text, re.M)
    if not m:
      pagemsg("WARNING: Something, can't match template: %s" % unicode(obj.t))
    else:
      line = m.group(0)
      if "Dari" in line or "Classical" in line:
        pagemsg("Saw 'Dari/Classical' in line: %s" % line)
        classical = True

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

  def create_state():
    return State(ar, aind, alen, la, lind, llen, res, lres, classical)

  def is_bow(pos=None):
    if pos is None:
      pos = aind[0]
    return (pos == 0 or ar[pos - 1] in [" ", "[", "|"])

  def is_boc(pos=None):
    if pos is None:
      pos = aind[0]
    return (pos == 0 or re.search("[" + boc_chars + "]", ar[pos - 1])) or ((
      # also when we just processed a hyphen; cf. {{tt+|fa|یادآوری|tr=yâd-âvari}}
      # also when we output a hyphen even if not in the input ...
      lind[0] > 0 and la[lind[0] - 1] == "-" or len(lres) > 0 and lres[-1] == "-")
      # ... unless we just saw a tatweel, which cannot be the end of a compound part
      and not (pos > 0 and ar[pos - 1] == u"ـ"))

  # True if we are at the last character in a word.
  def is_eow(pos=None):
    if pos is None:
      pos = aind[0]
    return pos == alen - 1 or ar[pos + 1] in [" ", "]", "|", ZWNJ]

  def get_matches():
    ac = ar[aind[0]]
    debprint("get_matches: ac is %s" % ac)
    bow = is_bow()
    boc = is_boc()
    eow = is_eow()

    potential_matching_tables = []
    if is_bow():
      potential_matching_tables.append(tt_to_arabic_matching_bow)
    if is_boc():
      potential_matching_tables.append(tt_to_arabic_matching_boc)
    if is_eow():
      potential_matching_tables.append(tt_to_arabic_matching_eow)
    potential_matching_tables.append(tt_to_arabic_matching)
    matches = None
    for table in potential_matching_tables:
      matches = table.get(ac)
      if matches is not None:
        break
    debprint("get_matches: matches is %s" % (matches,))
    if matches is None:
      if ac in other_arabic_chars:
        return None, []
      if True:
        error("Encountered non-Arabic (?) character " + ac +
          " at index " + str(aind[0]))
      else:
        canon = ac
        alts = [ac]
    else:
      canon, alts = matches
    return canon, alts

  # attempt to match the current Arabic character against the current
  # Latin character(s). If no match, return False; else, increment the
  # Arabic and Latin pointers over the matched characters, add the Arabic
  # character to the result characters and return True.
  def match(allow_empty_latin):
    if not (aind[0] < alen):
      return False

    canon, alts = get_matches()

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

    for m in alts:
      this_canon = canon
      preserve_latin = False
      # If an element of the match list is a list, it means
      # "don't canonicalize".
      if isinstance(m, list):
        preserve_latin = True
        m = m[0]
      # A one-element tuple is a signal for use in self-canonicalization,
      # not here.
      elif isinstance(m, tuple):
        m = m[0]
      elif isinstance(m, LatinMatch):
        st = create_state()
        if m.when and not m.when(st):
          continue
        this_canon = m.canon_to
        if callable(this_canon):
          this_canon = this_canon(st)
          if this_canon is None:
            continue
        m = m.match

      # Don't allow matching against an empty string unless allow_empty_latin=True. This avoids problems matching the
      # empty string too soon, e.g. {{t|fa|شعله‌ور|tr=šo'levar|sc=fa-Arab}}, where ع (`ayn) can match the empty
      # string and canonicalize to ', but before that should happen, we have to consume the unmatched o.
      if not allow_empty_latin and not m:
        # Allow if we're dealing with ع and ئ between vowels. This allows us to infer ' between vowels when it's not
        # present, instead of adding the apostrophe after both vowels.
        if ac not in [u"ع", u"ئ"]:
          continue
        st = create_state()
        prevla = st.prevla()
        thisla = st.thisla()
        if not prevla or not thisla:
          continue
        #msg("prevla=%s, thisla=%s" % (prevla, thisla))
        if prevla not in vowel_chars or thisla not in vowel_chars:
          continue

      l = lind[0]
      matched = True
      debprint("m: %s" % m)
      for cp in m:
        if l < llen and la[l] == cp:
          debprint("cp: %s, l=%s, la=%s" % (cp, l, la[l]))
          l = l + 1
        else:
          debprint("cp: %s, unmatched" % cp)
          matched = False
          break
      if matched:
        res.append(ac)
        if preserve_latin:
          for cp in m:
            lres.append(cp)
        elif ac == u"ة":
          if not is_eow():
            lres.append("t")
          elif aind[0] > 0 and (ar[aind[0] - 1] == u"ا" or
              ar[aind[0] - 1] == u"آ"):
            lres.append("h")
          # else do nothing
        else:
          subst = this_canon
          if isinstance(subst, (list, tuple)):
            subst = subst[0]
          for cp in subst:
            lres.append(cp)
        lind[0] = l
        aind[0] += 1
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
  def check_latin_not_matching_arabic():
    if not (lind[0] < llen):
      return False
    # Don't allow an unmatching Latin short vowel at the beginning of a word; there should always be a alif, alif madda
    # or similar on the Arabic side.
    if is_bow():
      return False
    l = la[lind[0]]
    debprint("Unmatched Latin: %s at %s" % (l, lind[0]))
    arabic = tt_latin_to_unmatched_arabic.get(l)
    if arabic is not None:
      if isinstance(arabic, tuple):
        st = create_state()
        arabic, l, when = arabic
        if callable(l):
          l = l(st)
        if not when(st):
          return False
      res.append(arabic)
      lres.append(l)
      lind[0] += 1
      return True
    return False

  # Check for an unmatched Latin hyphen; allow.
  def check_latin_hyphen_not_matching():
    if not (lind[0] < llen):
      return False
    l = la[lind[0]]
    if l == "-":
      a = None if aind[0] >= alen else ar[aind[0]]
      debprint("check_latin_not_matching_arabic(): Saw Latin hyphen against (unmatched) %s, copying" % a)
      lres.append("-")
      lind[0] += 1
      return True
    return False

  # Check for ZWNJ unmatched; insert a hyphen.
  def check_zwnj_not_matching():
    if not (aind[0] < alen):
      return False
    a = ar[aind[0]]
    if a == ZWNJ:
      l = None if lind[0] >= llen else la[lind[0]]
      debprint("check_zwnj_not_matching(): Saw ZWNJ against (unmatched) %s, adding hyphen" % l)
      lres.append("-")
      aind[0] += 1
      return True
    return False

  # Check for an Arabic long vowel that is unmatched but following a Latin
  # short vowel. FIXME: Doesn't seem to make sense for Persian.
  #def check_skip_unmatching():
  #  if not (lind[0] > 0 and aind[0] < alen):
  #    return False
  #  skip_char_pos = lind[0] - 1
  #  # Skip back over a hyphen, so we match wa-l-jabal against والجبل
  #  if la[skip_char_pos] == "-" and skip_char_pos > 0:
  #    skip_char_pos -= 1
  #  skip_chars = tt_skip_unmatching.get(la[skip_char_pos])
  #  if skip_chars != None and ar[aind[0]] in skip_chars:
  #    debprint("Skip-unmatching matched %s at %s following %s at %s" % (
  #      ar[aind[0]], aind[0], la[skip_char_pos], skip_char_pos))
  #    res.append(ar[aind[0]])
  #    aind[0] += 1
  #    return True
  #  return False

  # Check for Latin hyphen and match it against -, ZWJ, ZWNJ, Arabic space or nothing. Also handle ezafe following the
  # hyphen. See the caller for some of the reasons we special-case this.
  def check_against_hyphen():
    if lind[0] < llen and la[lind[0]] == "-":
      if aind[0] >= alen:
        lres.append("-")
      elif ar[aind[0]] in ["-", u"–", ZWJ, ZWNJ]:
        lres.append("-")
        res.append(ar[aind[0]])
        aind[0] += 1
      elif ar[aind[0]] == " ":
        if lind[0] + 2 < llen and la[lind[0] + 1] == "e" and la[lind[0] + 2] in [" ", "-"]:
          # ezafe construction, normally unmatched.
          lres.append("-e ")
          lind[0] += 2 # it will get incremented once more below
          res.append(I) # kasra marking the ezafe
          res.append(" ")
          aind[0] += 1
        elif lind[0] + 3 < llen and la[lind[0] + 1] == "y" and la[lind[0] + 2] == "e" and la[lind[0] + 3] in [" ", "-"]:
          # ezafe construction with -ye, often unmatched.
          lres.append("-ye ")
          lind[0] += 3 # it will get incremented once more below
          res.append(I) # kasra marking the ezafe
          res.append(" ")
          aind[0] += 1
        else:
          # Allow Latin hyphen against Arabic space.
          lres.append("-")
          res.append(" ")
          aind[0] += 1
      else:
        return False
      lind[0] += 1
      return True
    return False

  # Check for plain alif matching hamza and canonicalize.
  #def check_bow_alif():
  #  if not (is_bow() and aind[0] < alen and ar[aind[0]] == u"ا"):
  #    return False
  #  # Check for hamza + vowel.
  #  if not (lind[0] < llen - 1 and la[lind[0]] in hamza_match_chars and
  #      la[lind[0] + 1] in vowel_chars):
  #    return False
  #  if la[lind[0] + 1] in "ei":
  #    canonalif = u"إ"
  #  else:
  #    canonalif = u"أ"
  #  msgfun("Canonicalized alif to %s in %s (%s)" % (
  #    canonalif, origarabic, origlatin))
  #  res.append(canonalif)
  #  aind[0] += 1
  #  lres.append(u"'")
  #  lind[0] += 1
  #  return True

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
    # Infer fatḥatân before EOW alif/alif maqsuura
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
  # allowed unmatching Latin characters in tt_latin_to_unmatched_arabic, which
  # handles short vowels and shadda. If this doesn't match either, and we
  # have left-over Arabic or Latin characters, we reject the whole match,
  # either returning False or signaling an error.

  while aind[0] < alen or lind[0] < llen:
    matched = False
    # The first clause ensures that shadda always gets processed first;
    # necessary in the case of the qiṭṭun example below, which otherwise
    # would be rendered as qiṭunn.
    if lind[0] < llen and la[lind[0]] == SH:
      debprint("Matched: Clause shadda")
      lind[0] += 1
      lres.append(SH)
      if aind[0] < alen and (
          ar[aind[0]] == SH or ar[aind[0]] == double_l_subst):
        res.append(ar[aind[0]])
        aind[0] += 1
      else:
        res.append(SH)
      matched = True
    # The effect of the next clause is to handle cases where the
    # Arabic has a right bracket or similar character and the Latin has
    # a short vowel or shadda that doesn't match and needs to go before
    # the right bracket. The is_bow() check is necessary because
    # left-bracket is part of word_interrupting_chars and when the
    # left bracket is word-initial opposite a short vowel, the bracket
    # needs to be handled first. Similarly for word-initial tatweel, etc.
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
        check_latin_not_matching_arabic()):
      debprint("Matched: Clause 1")
      matched = True
    #elif check_bow_alif():
    #  debprint("Matched: Clause check_bow_alif()")
    #  matched = True
    elif match(allow_empty_latin=False):
      debprint("Matched: Clause match(allow_empty_latin=False)")
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
    elif check_eow_tanwin():
      debprint("Matched: Clause check_eow_tanwin()")
      matched = True
    elif check_latin_not_matching_arabic():
      debprint("Matched: Clause check_latin_not_matching_arabic()")
      matched = True
    elif match(allow_empty_latin=True):
      debprint("Matched: Clause match(allow_empty_latin=True)")
      matched = True
    elif check_latin_hyphen_not_matching():
      debprint("Matched: Clause check_latin_hyphen_not_matching()")
      matched = True
    #  debprint("Matched: Clause check_zwnj_not_matching()")
    #  matched = True
    #elif check_skip_unmatching():
    #  debprint("Matched: Clause check_skip_unmatching()")
    #  matched = True
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

################################ Test code ##########################

num_failed = 0
num_succeeded = 0

def test_with_obj(obj, latin, arabic, should_outcome, should_latin=None):
  global num_succeeded, num_failed
  try:
    result = tr_matching(obj, arabic, latin, True)
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
    canon_changed = "" if latin == canonlatin else " CANON-CHANGED"
    if trlatin == canonlatin:
      uniprint("tr() MATCHED" + canon_changed)
      outcome = "matched"
    elif trlatin is None:
      uniprint("tr() SKIPPED" + canon_changed)
      outcome = "matched"
    else:
      uniprint("tr() UNMATCHED (= %s)" % trlatin + canon_changed)
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

def test(obj, latin, arabic, should_outcome, should_latin=None):
  test_with_obj(None, latin, arabic, should_outcome, should_latin=should_latin)

def run_tests():
  global num_succeeded, num_failed
  num_succeeded = 0
  num_failed = 0
  test(u"loğat-nâme", u"لغت‌نامه", "matched", u"loğat-nâme")
  test("farhang", u"فرهنگ", "matched", "farhang")
  test(u"vâže-nâme", u"واژه‌نامه", "matched", u"vâže-nâme")
  test(u"chamedan", u"چمدان", "matched", u"čamedân")
  test(u"žu’an", u"ژوئن‌", "matched", "žu'an")
  test("bima'ni", u"بی‌معنی", "matched", "bi-ma'ni")
  test("yekšanbe", "یک‌شنبه", "matched", "yek-šanbe")
  test("elm-e ešteqâq", "علم اشتقاق", "matched", "'elm-e ešteqâq")
  test("āb", "آب", "matched", "âb")
  test("šo'levar", "شعله‌ور", "matched", "šo'le-var")
  test("qeyre âddi", "غیر عادی", "matched", "ğeyre 'âddi")
  test("hezaareye sevvom", "هزاره‌ی سوم", "matched", "hezâre-ye sevvom")
# FIXME, ask about the following (trailing ZWNJ)
# FIXME, the following is currently wrong
  test("fehrest-e peygiri", "فهرست پی‌گیری‌", "matched", "fehrest-e pey-giri")
  test("addasi", "عدسی", "matched", "'addasi")
  test("Edvârd", "ادوارد", "matched", "edvârd")
  test("barâye inke", "برای این‌که", "matched", "barâye in-ke")
  test("mēva", "میوه", "matched", "mêva")
# FIXME, the following should probably be implemented during matching so that ou matches و but converts to ow
  test("zouj", "زوج", "matched", "zowj")
  test("bârō", "بارو", "matched", "bârô")
  test("âðarbâdgân", "آذربادگان", "matched", "âzarbâdgân")
# FIXME, ask about the following
  test("espâniya", "اسپانیا", "matched", "espâniyâ", gloss="Spain")
# FIXME, the following should probably be implemented during matching so that ei matches ی but converts to ey
  test("koveit", "کویت", "matched", "koveyt", gloss="Kuwait")
# FIXME, ask about the following
  test("trinidad ve tobago", "ترینیداد و توباگو", "matched", "trinidâd ve tobâgo", gloss="Trinidad and Tobago")
# FIXME, the following is currently wrong
  test("anbareh", "انباره", "matched", "anbâre")
  test("lâqar", "لاغر", "matched", "lâğar")
  test("šenāxtæn", "شناختن", "matched", "šenâxtan")
# FIXME, ask about the following; should the -h be deleted?
  test("yāzdah", "یازده", "matched", "yâzdah")
  test("saranjâm", "سرانجام", "matched", "sarânjâm")
# FIXME, ask about the following
  test("zabân havayi", "زبان هاوایی", "matched", "zabân hâvâyi", gloss="Hawaiian")
# FIXME, ask about the following
  test("ebrani", "عبرانی", "matched", "'ebrâni", gloss="Hebrew")
# FIXME, ask about the following
  test("volapuk", "ولاپوک", "matched", "volâpuk", gloss="Volapük")
# FIXME, ask about the following
  test("tailandi", "تایلندی", "matched", "tâylandi", gloss="Thai")
# FIXME, ask about the following
  test("piš-afkand", "پیش‌افکند", "matched", "piš-âfkand", gloss="project")
  test("faʿʿāl kardan", "فعال کردن", "matched", "fa''âl kardan")
# FIXME, ask about the following
  test("tundra", "توندرا", "matched", "tundrâ", gloss="tundra")
# FIXME, the following is currently wrong
  test("gom", "گم‌", "matched", "gom")
# FIXME, ask about the following
  test("raij", "رایج", "matched", "râyj", gloss="common")
  test("kam-omq", "کم عمق", "matched", "kam-'omq")
# FIXME, ask about the following
  test("negah dāštan", "نگه داشتن", "matched", "negah dâštan", gloss="stop")
# FIXME, ask about the following
  test("zabân kanara", "زبان کانارا", "matched", "zabân kânârâ", gloss="Kannada")
# FIXME, the following is currently wrong, produces dâla-'das
  test("dâladas", "دال‌عدس", "matched", "dâl-'adas")
# FIXME, ask about the following
  test("radiyom", "رادیوم", "matched", "râdiyom", gloss="radium")
# FIXME, ask about the following
  test("bretayn", "برتاین", "matched", "bretâyn", gloss="Brittany")
# FIXME, ask about the following
  test("asetaldehid", "استالدهید", "matched", "asetâldehid", gloss="acetaldehyde")
  test("motâd", "معتاد", "matched", "mo'tâd")
# FIXME, ask about the following
  test("filadelfia", "فیلادلفیا", "matched", "filâdelfiâ", gloss="Philadelphia")
# FIXME, ask about the following
  test("kola", "کولا", "matched", "kolâ", gloss="cola")
# FIXME, the following is currently wrong, produces 'alâmati-e ta'ajjob
  test("'alâmat-e ta'ajjob", "عَلامَتِ تَعَجُّب", "matched", "'alâmat-e ta'ajjob")
# FIXME, the following is currently wrong
  # tr_matching(پدرِ مادربزرگ, pedar-e mādar-bozorg) = پِدَرِِ مادَربُزُرگ pedari-e mâdar-bozorg, tr() SKIPPED CANON-CHANGED
  test("kârgar-e madan", "کارگر معدن", "matched", "kârgar-e ma'dan")
  test("manba", "منبع", "matched", "manba'")
# FIXME, ask about the following
  test("marâti", "ماراتی", "matched", "mârâti", gloss="Marathi")
# FIXME, ask about the following
  test("kamyon", "کامیون", "matched", "kâmyon", gloss="truck")
  test("bi-adab", "بی‌ادب", "matched", "bi-adab", gloss="rude")
# FIXME, ask about the following
  test("maleziyayi", "مالزیایی", "matched", "mâleziyâyi", gloss="Malay")
  test("salâm aleykom", "سلام علیکم", "matched", "salâm 'aleykom")
# FIXME, ask about the following
  test("beratislâvâ", "براتیسلاوا", "matched", "berâtislâvâ", gloss="Bratislava")
# FIXME, ask about the following
  test("kwart", "کوارت", "matched", "kwârt", gloss="quart")
  test("sigâr kashidan memnu ast", "سیگار کشیدن ممنوع است", "matched", "sigâr kašidan memnu' ast")
# FIXME, ask about the following
  test("pâsta", "پاستا", "matched", "pâstâ", gloss="pasta")
# FIXME, ask about the following
  test("makrofāž", "ماکروفاژ", "matched", "mâkrofâž", gloss="macrophage")
  test("vaz'-e fe'li", "وضع فعلی", "matched", "vaz'-e fe'li")
# FIXME, ask about the following, should it be kwârk?
  test("kuārk", "کوارک", "matched", "kuârk", gloss="quark")
  # FIXME, the following is wrong:
  # tr_matching(باستان‌اخترشناسی, bāstānaxtaršenāsī) = باستانَ‌اختَرشِناسی bâstâna-xtaršenâsi, tr() SKIPPED CANON-CHANGED



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
  test("al-bait", u"البیت", "matched")
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
  test("diiba", u"دیبة", "matched")
  test(u"díiba", u"دیبة", "matched")
  test("diyba", u"دیبة", "matched")
  test("di:ba", u"دیبة", "matched")
  test(u"dîba", u"دیبة", "matched")
  test(u"dī́ba", u"دیبة", "matched")
  test("diyaba", u"دیبة", "matched")

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
  test("baitu l-kuuba", u"بیت الكوبة", "matched")
  test("baitu al-kuuba", u"بیت الكوبة", "matched")
  test("baitu d-duuba", u"بیت الدوبة", "matched")
  test("baitu ad-duuba", u"بیت الدوبة", "matched")
  test("baitu l-duuba", u"بیت الدوبة", "matched")
  test("baitu al-duuba", u"بیت الدوبة", "matched")
  test("bait al-duuba", u"بیت الدوبة", "matched")
  test("bait al-Duuba", u"بیت الدوبة", "matched")
  test("bait al-kuuba", u"بیت الكوبة", "matched")
  test("baitu l-kuuba", u"بیت ٱلكوبة", "matched")

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
  test(u"arqâm hindiyya", u"[[أرقام]] [[هندیة]]", "matched")
  test(u"arqâm hindiyya", u"[[رقم|أرقام]] [[هندیة]]", "matched")
  test(u"arqâm hindiyya", u"[[رقم|أرقام]] [[هندی|هندیة]]", "matched")
  test(u"ʾufuq al-ħadaŧ", u"[[أفق]] [[حادثة|الحدث]]", "matched")

  # Test transliteration that omits initial hamza (should be inferrable)
  test(u"aṣdiqaa'", u"أَصدقاء", "matched")
  test(u"aṣdiqā́'", u"أَصدقاء", "matched")
  # Test random hamzas
  test(u"'aṣdiqā́'", u"أَصدقاء", "matched")
  # Test capital letters for emphatics
  test("aSdiqaa'", u"أَصدقاء", "matched")
  # Test final otiose alif maqsuura after fatḥatân
  test("hudan", u"هُدًى", "matched")
  # Test opposite with fatḥatân after alif otiose alif maqsuura
  test("zinan", u"زنىً", "matched")

  # Check that final short vowel is canonicalized to a long vowel in the
  # presence of a corresponding Latin long vowel.
  test("'animi", u"أنمی", "matched")
  # Also check for 'l indicating assimilation.
  test("fi 'l-marra", u"فی المرة", "matched")

  # Test cases where short Latin vowel corresponds to Long Arabic vowel
  test("diba", u"دیبة", "unmatched")
  test("tamariid", u"تمارید", "unmatched")
  test("tamuriid", u"تمارید", "failed")

  # Single quotes in Arabic
  test("man '''huwa'''", u"من '''هو'''", "matched")

  # Alif madda
  test("'aabaa'", u"آباء", "matched")
  test("mir'aah", u"مرآة", "matched")

  # Test case where close bracket occurs at end of word and an unmatched
  # vowel or shadda needs to be before it.
  test("fuuliyy", u"[[فولی]]", "matched")
  test("fuula", u"[[فول]]", "matched")
  test("wa-'uxt", u"[[و]][[أخت]]", "unmatched")
  # Here we test when an open bracket occurs in the middle of a word and
  # an unmatched vowel or shadda needs to be before it.
  test("wa-'uxt", u"و[[أخت]]", "unmatched")

  # Test hamza against non-hamza
  test("'uxt", u"اخت", "matched")
  test("uxt", u"أخت", "matched")
  test("'ixt", u"اخت", "matched")
  test("ixt", u"أخت", "matched") # FIXME: Should be "failed" or should correct hamza

  # Test alif after al-
  test(u"al-intifaaḍa", u"[[الانتفاضة]]", "matched")
  test("al-'uxt", u"الاخت", "matched")

  # Test adding ! or ؟
  test("fan", u"فن!", "matched")
  test("fan!", u"فن!", "matched")
  test("fan", u"فن؟", "matched")
  test("fan?", u"فن؟", "matched")

  # Test inferring fatḥatân
  test("hudan", u"هُدى", "matched")
  test("qafan", u"قفا", "matched")
  test("qafan qafan", u"قفا قفا", "matched")

  # Case where shadda and -un are opposite each other; need to handle
  # shadda first.
  test(u"qiṭṭ", u"قِطٌ", "matched")

  # 3 consonants in a row
  test(u"Kûlûmbîyâ", u"كولومبیا", "matched")
  test("fustra", u"فسترة", "matched")

  # Allâh
  test(u"allâh", u"الله", "matched")

  # Test dagger alif, alif maqsuura
  test(u"raḥmân", u"رَحْمٰن", "matched")
  test(u"fusḥâ", u"فسحى", "matched")
  test(u"fusḥâ", u"فُسْحَى", "matched")
  test(u"'âxir", u"آخر", "matched")

  # Real-world tests
  test(u"’ijrâ’iy", u"إجْرائِيّ", "matched")
  test(u"wuḍûʕ", u"وضوء", "matched")
  test(u"al-luḡa al-ʾingilîziyya", u"اَلْلُّغَة الْإنْجِلِیزِيّة", "unmatched")
  test(u"šamsíyya", u"شّمسيّة", "matched")
  test(u"Sirbiyâ wa-l-Jabal al-Aswad", u"صربیا والجبل الأسود", "unmatched")
  test(u"al-’imaraat", u"الإمارات", "unmatched")
  # FIXME: Should we canonicalize to al-?
  test("al'aan(a)", u"الآن", "unmatched")
  test(u"yûnânîyya", u"یونانیة", "matched")
  test("hindiy-'uruubiy", u"هندی-أوروبی", "unmatched")
  test(u"moldôva", u"مولدوفا", "unmatched")
  test(u"darà", u"درى", "matched")
  test("waraa2", u"وراء", "matched")
  test("takhaddaa", u"تحدى", "matched")
  test(u"qaránful", u"ﻗﺮﻧﻔﻞ", "matched")
  # Can't easily handle this one because ال matches against -r- in the
  # middle of a word.
  # test(u"al-sâʿa wa-'r-rubʿ", u"الساعة والربع", "matched")
  test(u"taḥṭîṭ", u"تخطیط", "matched")
  test(u"hâḏihi", u"هذه", "matched")
  test(u"ħaláːt", u"حَالاَتٌ", "unmatched")
  test(u"raqṣ šarkiyy", u"رقص شرقی", "matched")
  test(u"ibn ʾaḵ", u"[[اِبْنُ]] [[أَخٍ]]", "matched")
  test(u"al-wuṣṭâ", u"الوسطى", "matched")
  test(u"fáħmu-l-xášab", u"فحم الخشب", "matched")
  test(u"gaṡor", u"قَصُر", "unmatched")
  # Getting this to work makes it hard to get e.g. nijir vs. نیجر to work.
  # test(u"sijâq", u"سِيَاق", "matched")
  test("winipiigh", u"وینیبیغ", "unmatched")
  test(u"ʿaḏrâʿ", u"عذراء", "matched")
  test(u"ʂaʈħ", u"سطْح", "matched")
  test(u"dʒa'", u"جاء", "unmatched")
  #will split when done through canon_arabic.py, but not here
  #test(u"ʿíndak/ʿíndak", u"عندك", "matched") # should split
  test(u"fi 'l-ḡad(i)", u"فی الغد", "matched")
  test(u"ḩaythu", u"حَیثُ", "matched")
  test(u"’iʐhâr", u"إظهار", "matched")
  test(u"taħli:l riya:dˤiy", u"تَحْلِیلْ رِيَاضِی", "matched")
  test(u"al-'ingilizíyya al-'amrikíyya", u"الإنجلیزیة الأمریكیة", "unmatched")
  test(u"ḵаwḵa", u"خوخة", "matched") # this has a Cyrillic character in it
  test(u"’eħsâs", u"احساس", "unmatched")
  # Up through page 848 "sense"
  test("wayd-jaylz", u"وید–جیلز", "matched")
  test(u"finjáːn šæːy", u"فِنْجَان شَای", "matched")
  test(u"múdhhil", u"مذهل", "matched")
  test(u"ixtiâr", u"اختیار", "matched")
  test(u"miṯll", u"مثل", "matched")
  test(u"li-wajhi llâh", u"لِوَجْهِ اللهِ", "unmatched")

  # FIXME's: assimilating_l_subst only matches against canonical sun
  # letters, not against non-canonical ones like θ. We can fix that
  # by adding all the non-canonical ones to ttsun1[], or maybe just
  # matching anything that's not a vowel.
  #test(u"tišrînu θ-θâni", u"تِشرینُ الثّانِی", "matched")

  # Final results
  uniprint("RESULTS: %s SUCCEEDED, %s FAILED." % (num_succeeded, num_failed))

if __name__ == "__main__":
  run_tests()
