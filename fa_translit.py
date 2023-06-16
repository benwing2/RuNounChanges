#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Authors: Benwing

import re, unicodedata
import arabiclib
from arabiclib import *
import blib
from blib import remove_links, msg, msgn, tname

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
# 5. tā' marbūṭa: [HANDLED IN MANY CASES]
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
# 1. Support insert=, append= for adding short vowels.
# 2. Remove final -h after e in multisyllabic words (in post-canonicalization). [DONE]
# 3. Canonicalize m -> n against ن before ب. [DONE]
# 4. Canonicalize h -> x against خ. [DONE]
# 5. Handle اً against -an. [DONE]
# 6. Support handle_empty_match_early and use when handling silent و in خوا. [DONE]
# 7. Allow â against FARSI YEH replacing alif maqsuura. [DONE]
# 8. Alif madda mid-word against â or 'â should canonicalize to -â per discussion with Anatoli. [DONE]
# 9. Correct cases of â that should be a. [DONE]
# 10. Don't correct â to a in word-initial اله- (borrowed from the Arabic word for god). [DONE]
# 11. Allow unmatched Latin apostrophe in sequences of two or more (otherwise it causes issues). [DONE]
# 12. Pre-canonicalize  ۀ to هٔ and handle correctly against y. [DONE]
# 13. Punctuation marks . ? ! and Arabic equivs plus ''' should signal eow. [DONE]
# 14. Check remaining "Encountered non-Arabic (?) character" msgs and support as many as possible. [DONE]
# 15. Support braces for {{...}}. [DONE]
# 16. Handle <br> and variants inside of Arabic. [DONE except for preceding space not matched in the Latin]
# 17. Handle /, (), *, :, ", «», etc. in Arabic. [DONE]
# 18. Pre-canonicalize weird ه variants (HEH GOAL ہ, AE ە, HEH DOACHASHMEE ھ). [DONE]
# 19. Pre-canonicalize Eastern Arabic numbers to Persian ones. [DONE]
# 20. Pre-canonicalize alif maqsuura to FARSI YEH. [DONE]
# 21. Pre-canonicalize underscore at beginning of text to tatweel, as it marks suffixes. [DONE]
# 22. Don't replace initial ال with assimilating_l_subst, which messes up all such words. [DONE]
# 23. Don't replace double {{ }} [[ ]] with shadda. [DONE]
# 24. Make sure we correctly handle short vowels already in the Arabic script (e.g. final kasra indicating ezafe). [VERIFIED]
# 25. Have an option to turn off insertion of short vowels into the canonicalized Arabic. [DONE]
# 26. Make sure kasra gets added in all ways of matching it (e.g. two-char هٔ).
# 27. Don't add hyphen to Latin when ZWNJ occurs word-finally. [DONE]
# 28. Handle unmatched fatha in fatha+alif sequences. [DONE]
# 29. Figure out how to not change æ -> a in Sistani terms, e.g. [[بەت]]. [DONE]
# 30. Don't canonicalize ARABIC LETTER AE to HEH; intentional in Sistani text. [DONE]
# 31. Don't correct â to a in الله. [DONE]
# 32. With headword templates, check for Dari or Classical several lines down. [DONE]
# 33. Check for other Dari keywords: Sistani, dialectal, regional, lowercase classical. [DONE]
# 34. Recognize semicolon-separated translits. [DONE]
# 35. When classical or dialectal, don't do certain pre-canonicalizations and post-canonicalizations. [DONE]
# 36. Move shadda -> double cons in post_canonicalize_latin() to the beginning to avoid interfering in further changes. [DONE]
# 37. Remove final h in -eh before hyphen + cons, and correct -eh-e to -e-ye. [DONE]
# 38. Reduce multiple ZWNJ's to one. [DONE]
# 39. Bug fix for canonicalizing multiple spaces to one. [DONE]


debug_tr_matching = False

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
  return unicodedata.normalize("NFKC", str(txt))

def nfc_form(txt):
  return unicodedata.normalize("NFC", str(txt))

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
cons_chars = u"bcdfghjklmnpqrstvwxyzščžğ"

consonants_needing_vowels = u"بتثجحخدذرزسشصضطظعغفقكلمنهپچڤگڨڧأإؤئءةﷲ"
# consonants on the right side; includes alif madda
rconsonants = consonants_needing_vowels + u"ویآ"
# consonants on the left side; does not include alif madda
lconsonants = consonants_needing_vowels + u"وی"
punctuation = (u"؟،؛" # Arabic semicolon, comma, question mark
  + u"ـ" # tatweel
  + ".!'" # period, exclamation point, single quote for bold/italic
)
word_final_punctuation = (u"؟،؛" # Arabic semicolon, comma, question mark
  + ".,!?:;)"
)
numbers = u"۱۲۳۴۵۶۷۸۹۰"


# Transliterate the word(s) in TEXT. LANG (the language) and SC (the script)
# are ignored. FORCE_TRANSLATE causes even non-vocalized text to be transliterated
# (normally the function checks for non-vocalized text and returns nil,
# since such text is ambiguous in transliteration).
def tr(text, lang=None, sc=None, force_translate=False, msgfun=msg):
  # FIXME: Implement me
  return NotImplemented


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
  def __init__(self, match, canon_to=None, when=None, insert=None, append=None, handle_empty_match_early=False):
    self.match = match
    self.canon_to = canon_to
    self.when = when
    self.insert = insert
    self.append = append
    self.handle_empty_match_early = handle_empty_match_early

class State(object):
  def __init__(self, ar, aind, alen, la, lind, llen, res, lres, classical, no_vocalize):
    self.ar = ar
    self.aind = aind
    self.alen = alen
    self.la = la
    self.lind = lind
    self.llen = llen
    self.res = res
    self.lres = lres
    self.classical = classical
    self.no_vocalize = no_vocalize

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

  def is_bow(self, pos=None):
    if pos is None:
      pos = self.aind[0]
    return (pos == 0 or self.ar[pos - 1] in [" ", "[", "|"])

  def is_boc(self, pos=None):
    if pos is None:
      pos = self.aind[0]
    return (pos == 0 or re.search("[" + boc_chars + "]", self.ar[pos - 1])) or ((
      # also when we just processed a hyphen; cf. {{tt+|fa|یادآوری|tr=yâd-âvari}}
      # also when we output a hyphen even if not in the input ...
      self.lind[0] > 0 and self.la[self.lind[0] - 1] == "-" or len(self.lres) > 0 and self.lres[-1] == "-")
      # ... unless we just saw a tatweel, which cannot be the end of a compound part
      and not (pos > 0 and self.ar[pos - 1] == u"ـ"))

  # True if we are at the last character in a word.
  def is_eow(self, pos=None):
    if pos is None:
      pos = self.aind[0]
    if pos == self.alen - 1:
      return True
    a = self.ar[pos + 1]
    return (a in [" ", "]", "|", ZWNJ] or a in word_final_punctuation or
      # followed by ''' (indicating end of bolded word)
      a == "'" and pos + 3 < self.alen and self.ar[pos + 2] == "'" and self.ar[pos + 3] == "'"
    )


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
  ZWNJ:"",
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
  u"پ":"p",
  u"ت":["t",u"ṯ"],
  u"ث":["s",u"ṯ",u"ŧ",u"θ","th",u"s̱",u"s̄"],
  u"ج":["j",u"ǧ",u"ğ",u"ǰ","dj",u"dǧ",u"dğ",u"dǰ",u"dž",u"dʒ",u"ʒ",u"ž","g","c"],
  # Allow what would normally be capital H, but we lowercase all text
  # before processing.
  # I feel a bit uncomfortable allowing kh to match against ح like this,
  # but generally I trust the Arabic more.
  u"ح":["h",u"ḥ",u"ħ",u"ẖ",u"ḩ","7",("kh",)],
  # I feel a bit uncomfortable allowing ḥ to match against خ like this,
  # but generally I trust the Arabic more.
  u"خ":["x",u"k͟h",u"ḵ","kh",u"ḫ",u"ḳ",u"ẖ",u"χ",(u"ḥ",),"h"],
  u"چ":[u"č","ch","c",u"ĉ",u"ç"],
  u"د":"d",
  u"ذ":["z",u"d͟h",u"ḏ",u"đ",u"ð","dh",u"ḍ",u"ẕ",u"δ","d"],
  u"ر":"r",
  u"ز":["z",u"ẕ"],
  u"ژ":[u"ž",u"z͟h","zh",u"ʒ","z"],
  # I feel a bit uncomfortable allowing emphatic variants of s to match
  # against س like this, but generally I trust the Arabic more.
  u"س":["s",(u"ṣ",),(u"sʿ",),(u"sˤ",),(u"sˁ",),(u"sʕ",),(u"ʂ",),(u"ṡ",)],
  u"ش":[u"š",u"s͟h","sh",u"ʃ",u"ŝ",u"ş",u"ś","s"],
  u"ص":["s",u"ṣ",u"sʿ",u"sˤ",u"sˁ",u"sʕ",u"ʂ",u"ṡ"],
  u"ض":["z",u"ḍ",u"dʿ",u"dˤ"u"dˁ",u"dʕ",u"ẓ",u"ż",u"ẕ",u"ɖ",u"ḋ","d"],
  u"ط":["t",u"ṭ",u"tʿ",u"tˤ",u"tˁ",u"tʕ",u"ṫ",u"ţ",u"ŧ",u"ʈ",u"t̤"],
  u"ظ":["z",u"ẓ",u"ðʿ",u"ðˤ",u"ðˁ",u"ðʕ",u"ð̣",u"đʿ",u"đˤ",u"đˁ",u"đʕ",u"đ̣",
    u"ż",u"z̧",u"ʐ","dh"],
  u"ع":["'", u"ʿ",u"ʕ","`",u"‘",u"ʻ","3",u"ˤ",u"ˁ",(u"ʾ",),u"῾",(u"’",),""],
  u"غ":[u"ğ",u"ḡ",u"ġ","gh",["g"],("`",),"q",u"g͟h",u"γ",u"ǧ",u"ɣ",u"ĝ"],
  u"ف":["f",["v"]],
  # I feel a bit uncomfortable allowing k to match against q like this,
  # but generally I trust the Arabic more
  u"ق":["q",u"ḳ",["g"],"gh",u"g͟h","k",u"ğ",u"γ"],
  u"ك":["k",["g"]],
  u"ک":["k",["g"]],
  u"گ":"g",
  u"ل":"l",
  u"م":"m",
  u"ن":["n", LatinMatch("m", canon_to="n", when=lambda st: st.nextla() == "b")],
  u"ه":[
    "h",
    # We canonicalize single-char ۀ to two-char هٔ, which is HEH + HAMZA ABOVE. This should map to y, so we check that
    # the following char is HAMZA ABOVE and then map that char to the empty string.
    LatinMatch("y", canon_to="y", when=lambda st: st.nextar() == u"\u0654")
  ],
  u"\u0654": [
    u"\uFFFE", # shouldn't match; just a placeholder; all possible matches follow
    # See above; this normally occurs after HEH and we want it skipped.
    LatinMatch("", canon_to="", handle_empty_match_early=True)
  ],
  # This char shouldn't actually occur since we canonicalize it to two-char هٔ; see above.
  u"ۀ":"y",
  # [We have special handling for the following in the canonicalized Latin,
  # so that we have -a but -âh and -at-.] -- I think this is no longer true.
  u"ة":["h",["t"],["(t)"],""],

  # control characters
  # We handle hyphen against ZWNJ specially in check_against_hyphen() and other_arabic_chars, but we still need the
  # following for the case where ZWNJ is unmatched on the Latin side.
  ZWNJ:["-", ""],
  #ZWJ:["-"],#,""], # ZWJ (zero-width joiner)

  # rare letters
  u"ڤ":"v",
  u"ڨ":"g",
  u"ڧ":"q",

  # variants of alif
  # Note, the following ensures that short a against ا gets canonicalized to â, except in اً = -an.
  u"ا":[u"â",LatinMatch("a", canon_to=lambda st: "a" if st.nextar() == AN else u"â")], # ʾalif = \u0627
  silent_alif_subst:[[""]],
  silent_alif_maqsuura_subst:[[""]],
  u"آ":[ # alif madda = \u0622
    u"\uFFFE", # shouldn't match; just a placeholder; all possible matches follow
    LatinMatch(u"â", canon_to=u"-â"),
    LatinMatch(u"'â", canon_to=u"-â")
  ],
  u"ٱ":[[""]], # hamzatu l-waṣl = \u0671
  u"\u0670":u"â", # alif xanjariyya = dagger alif (Koranic diacritic)
  # The following shouldn't occur because we canonicalize it to FARSI YEH.
  u"ى":u"â", # alif maqsuura = \u0649

  # semivowels
  # Note, w before a vowel not after k/g/x is post-canonicalized to v.
  u"و":["v",["w"],LatinMatch("ow", canon_to="ow", insert=U),
      # not currently needed as we pre-canonicalize ou to ow
      #LatinMatch("ou", canon_to="ow",insert=U),
      LatinMatch("ov", canon_to="ov",insert=U),
      ["u"],[u"ô"],["o"],
      LatinMatch(u"û", canon_to=lambda st: u"û" if st.classical else "u"),
      # allow for silent و in خوا
      LatinMatch("", canon_to="", when=lambda st: st.prevar() == u"خ" and st.nextar() == u"ا",
        handle_empty_match_early=True)],
  # Adding j here creates problems with e.g. an-nijir vs. النیجر
  u"ی":[["y"],["iy"],["ey"],
      # FARSI YEH sometimes replaces alif maqsuura in words from Arabic:
      # tr(مصلی, mosallâ); tr(خنثی, xonsâ); tr(موسی, musâ); tr(عیسی, 'isâ); tr(حتی, hattâ)
      # very occasionally word-internally: tr(علیرغم, 'alârağm-e)
      [u"â"],
      # not currently needed as we pre-canonicalize ei to ey 
      #LatinMatch("ei", canon_to="ey",insert=I),
      LatinMatch("ey", canon_to="ey",insert=I),
      ["i"],[u"ê"], # no e; short e opposite ی doesn't normally occur
      LatinMatch(u"î", canon_to=lambda st: u"î" if st.classical else "i"),
      #"j",
  ],

  # hamzated letters
  u"أ":hamza_match_or_empty,
  u"إ":hamza_match_or_empty,
  u"ؤ":hamza_match_or_empty,
  u"ئ":hamza_match_or_empty,
  u"ء":hamza_match_or_empty,

  # short vowels, shadda and sukuun
  AN:"n", # fathatan
  # These don't normally occur in Persian.
  #UN:"un", # dammatan
  #IN:"in", # kasratan
  A:["a", # fatha
    # In the sequence fatha + alif e.g. مَال, the fatha will be unmatched.
    LatinMatch("", canon_to="", when=lambda st: st.nextar() == u"ا", handle_empty_match_early=True),
  ],
  U:[["o"], LatinMatch("u", canon_to=lambda st:"u" if st.classical else "o")], # damma
  I:[["e"], LatinMatch("i", canon_to=lambda st:"i" if st.classical or st.nextar() == u"ی" else "e")], # kasra
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
  u"؟":"?", # Arabic question mark
  u"،":",", # Arabic comma
  u"٬":",", # some weird comma
  u"٫":",", # thousands separator???
  u"؛":";", # Arabic semicolon
  ",":",", # comma seems to occasionally occur
  ".":".", # period
  # These occur matching in {{...}} in both Arabic and translit. We match period just above.
  "{":"{",
  "}":"}",
  # These occasionally occur matching.
  "(":"(",
  ")":")",
  "!":"!", # exclamation point
  "'":[("'",)], # single quote, for bold/italic
  " ":" ",
  "[":"",
  "]":"",
  # Occurs in poetry.
  "/":"/",
  # Occurs in the display text in terms indicated as hypothetical?
  "*":"*",
  # Occurs especially after گفت 'goft' "he/she said".
  ":":":",
  u"«":'"',
  u"»":'"',
  '"':'"',
  u"—":u"—", # U+2014
  u"−":u"—", # U+2212 -> U+2014; occurs at least once
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
other_arabic_chars = [ZWJ, ZWNJ, "-", u"–", "<"]

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
  "a":A,
  "o":U,
  # not if we're opposite ا; this occurs at boc with او
  "u":(U, lambda st: "u" if st.classical else "o", lambda st: st.thisar() != u"ا"),
  "e":I,
  # not if we're opposite ا; this occurs at boc with ای
  "i":(I, lambda st: "i" if st.classical else "e", lambda st: st.thisar() != u"ا"),
  # corrrect unmatched â to a, but not in اله- or الله.
  u"â":(A, "a", lambda st: not (
    st.thisar() == u"ه" and st.prevar() == u"ل" and st.prevar(2) == u"ا" and st.prevar(3) in [None, " "]
  ) and not (
    st.thisar() == u"ه" and st.prevar() == double_l_subst and st.prevar(2) == u"ل" and st.prevar(3) == u"ا"
  )),
  # Shadda because we pre-canonicalize doubled Latin letters to include a shadda.
  SH:SH,
}

def check_for_classical_or_dialectal(obj, pagemsg):
  tn = tname(obj.t)
  if tn == "head" or tn.startswith("fa-"):
    # Likely head or inflection template; include up to 3 lines of text below and above so we can check for Dari/Classical labels in
    # definitions.
    regex = "^(.*\n){0,3}.*" + re.escape(obj.origt) + ".*(\n.*){0,3}"
  else:
    # Check on the same line.
    regex = "^.*" + re.escape(obj.origt) + ".*$"
  m = re.search(regex, obj.text, re.M)
  if not m:
    pagemsg("WARNING: Something wrong, can't match template: %s" % str(obj.t))
  else:
    line = m.group(0)
    # 'regional' only in {{lb|fa|regional}}; not in {{fa-regional}}.
    if re.search(r"(Dari|[Cc]lassical|Sistani|dialectal|\|regional)", line):
      pagemsg("Saw 'Dari/Classical/Sistani/dialectal/regional' in line: %s" % line)
      return True
  return False

# Pre-canonicalize Latin, and Arabic if supplied. If Arabic is supplied,
# it should be the corresponding Arabic (after pre-pre-canonicalization),
# and is used to do extra canonicalizations.
def pre_canonicalize_latin(text, arabic=None, classical=False, msgfun=msg):
  if "{{" in text:
    # Embedded templates. Don't touch the stuff inside the embedded part.
    retval = run_on_non_template_code(text,
      lambda run: pre_canonicalize_latin(run, None, classical=classical, msgfun=msgfun), msgfun)
    if retval is not None:
      return retval

  # Map to canonical composed form, eliminate presentation variants etc.
  text = nfkc_form(text)
  # remove L2R, R2L markers
  text = rsub(text, u"[\u200E\u200F]", "")
  # remove embedded comments
  text = rsub(text, "<!--.*?-->", "")
  # remove embedded IPAchar templates
  text = rsub(text, r"\{\{IPAchar\|(.*?)\}\}", r"\1")
  # lowercase and remove leading/trailing spaces; don't strip newlines at the edges, which might be intentional, e.g.
  # in a multiline {{der3}} call.
  text = text.lower().strip(" ")
  # canonicalize interior spaces (leave newlines alone)
  text = rsub(text, " +", " ")
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
     u"ḗ":u"ê", u"ṓ":u"ô", # only these two vowels have a single Unicode char for macron+acute
     u"ấ":u"â"})
  if not classical:
    # Dialectally, ĭ ö or the like may occur in translit.
    text = rsub(text, ".",
      {u"ă":"a", u"ĕ":"e", u"ĭ":"i", u"ŏ":"o", u"ŭ":"u",
       u"ä":"a", u"ë":"e", u"ï":"i", u"ö":"o", u"ü":"u",
      })
  # Eliminate miscellaneous acute/grave (e.g. if over ā ī ū)
  text = text.replace(AC, "")
  text = text.replace(GR, "")
  # canonicalize weird vowels
  text = text.replace(u"ɪ", "i")
  text = text.replace(u"ɑ", "a")
  if not classical and (not arabic or u"ە" not in arabic):
    # Don't do this if ARABIC LETTER AE occurs (in Sistani text).
    text = text.replace(u"æ", "a")
  text = text.replace(u"а", "a") # Cyrillic a
  # eliminate doubled vowels = long vowels
  text = rsub(text, r"([aeiou])\1", {"a":u"â", "e":u"ê", "i":u"î", "o":u"ô", "u":u"û"})
  # eliminate vowels followed by colon = long vowels
  text = rsub(text, u"([aeiou])[:ː]", {"a":u"â", "e":u"ê", "i":u"î", "o":u"ô", "u":u"û"})

  # FIXME: We probably don't want this.
  # eliminate - or ' separating t-h, t'h, etc. in transliteration style
  # that uses th to indicate ث
  # text = rsub(text, "([dtgkcs])[-']h", r"\1h")

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
  #    for i in range(len(latinwords)):
  #      aword = arabicwords[i]
  #      lword = latinwords[i]
  #      # If Arabic word ends with long alif or alif maqsuura, not
  #      # preceded by fathatan, convert short -a to long -â.
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

def post_canonicalize_latin(text, classical=False, msgfun=msg):
  if "{{" in text:
    # Embedded templates. Don't touch the stuff inside the embedded part.
    retval = run_on_non_template_code(text, lambda text: post_canonicalize_latin(text, classical=classical, msgfun=msgfun), msgfun)
    if retval is not None:
      return retval

  # Convert shadda back to double letter. Do this first to avoid interfering with the following checks.
  text = rsub(text, u"(.)" + SH, r"\1\1")
  # Word-final -eyâ -> -iyâ.
  text = rsub(text, u"eyâ([" + word_final_punctuation + r" |\]]|'''|$|-)", ur"iyâ\1")
  if not classical:
    # Don't do this in dialectal Persian, e.g. [[بوا]] {{fa-noun|tr=buâ, bwâ, bowâ}}.
    # w before a vowel becomes v except in kw-, xw-, gw-, where we leave it alone
    text = rsub(text, "(?<![kxg])w([" + vowel_chars + "])", r"v\1")
  # v after a vowel not before a vowel becomes w? (FIXME: not currently implemented)
  # Final -eh in multisyllabic word -> -e. Also before hyphen but only hyphen followed by consonant (farmânde-hâ but farmândeh-e,
  # which we correct to farmânde-ye in the first line below).
  text = rsub(text, "([" + vowel_chars + "][" + cons_chars + "]*)eh-e([" + word_final_punctuation + r" |\]]|'''|$])", r"\1e-ye\2")
  text = rsub(text, "([" + vowel_chars + "][" + cons_chars + "]*)eh([" + word_final_punctuation + r" |\]]|'''|$|-[" + cons_chars + "])", r"\1e\2")
  # lowercase and remove leading/trailing spaces; don't strip newlines at the edges, which might be intentional, e.g.
  # in a multiline {{der3}} call.
  text = text.lower().strip(" ")
  return text

# Canonicalize a Latin transliteration and Arabic text to standard form. Can be done on only Latin or only Arabic (with
# the other one None), but is more reliable when both are provided. This is less reliable than tr_matching() and is
# meant when that fails. Return value is a tuple of (CANONLATIN, CANONARABIC).
def canonicalize_latin_foreign(obj, latin, arabic, msgfun=msg):
  classical = check_for_classical_or_dialectal(obj, msgfun)
  if arabic is not None:
    arabic = pre_pre_canonicalize_arabic(arabic, msgfun=msgfun)
  if latin is not None:
    latin = pre_canonicalize_latin(latin, arabic, classical=classical, msgfun=msgfun)
  if arabic is not None:
    arabic = pre_canonicalize_arabic(arabic, safe=True, msgfun=msgfun)
    arabic = post_canonicalize_arabic(arabic, safe=True, msgfun=msgfun)
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
    latin = rsub(latin, "(%s)3" % latin_chars, ur"\1ʿ")
    latin = rsub(latin, "3(%s)" % latin_chars, ur"ʿ\1")
    latin = latin.replace(multi_single_quote_subst, "'")
    latin = post_canonicalize_latin(latin, classical=classical, msgfun=msgfun)
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

def run_on_non_template_code(text, fun, pagemsg):
  # Embedded templates. Don't touch the stuff inside the embedded part.
  pagemsg(u"Embedded templates in param value, not frobbing template runs: %s" % text)
  try:
    runs = blib.parse_balanced_segment_run(text, "{", "}")
  except blib.ParseException as e:
    pagemsg(u"WARNING: ParseException parsing braces in param value: %s: %s" % (text, e))
    runs = None
  if runs is not None:
    for i, run in enumerate(runs):
      if i % 2 == 0:
        runs[i] = fun(runs[i])
    return "".join(runs)
  return None

# Early pre-canonicalization of Arabic, doing stuff that's safe. We split
# this from pre-canonicalization proper so we can do Latin pre-canonicalization
# between the two steps.
def pre_pre_canonicalize_arabic(text, msgfun=msg):
  if "{{" in text:
    # Embedded templates. Don't touch the stuff inside the embedded part.
    retval = run_on_non_template_code(text, lambda run: pre_pre_canonicalize_arabic(run, msgfun=msgfun), msgfun)
    if retval is not None:
      return retval

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
  # reduce multiple ZWNJ's to one
  text = rsub(text, ZWNJ + "+", ZWNJ)
  # remove leading/trailing spaces; don't strip newlines at the edges, which might be intentional, e.g. in a multiline
  # {{der3}} call.
  text = text.strip(" ")
  # canonicalize interior spaces (leave newlines alone)
  text = rsub(text, " +", " ")
  # replace Arabic, etc. characters with corresponding Farsi characters
  text = text.replace(u"ي", u"ی") # FARSI YEH
  text = text.replace(u"ك", u"ک") # ARABIC LETTER KEHEH (06A9)
  # Replace alif maqsuura with FARSI YEH
  text = text.replace(u"ى", u"ی")
  # Replace Eastern Arabic numerals with Persian numerals.
  text = rsub(text, ".", {
    u"١": u"۱",
    u"٢": u"۲",
    u"٣": u"۳",
    u"٤": u"۴",
    u"٥": u"۵",
    u"٦": u"۶",
    u"٦": u"۷",
    u"٧": u"۸",
    u"٨": u"۹",
    u"٠": u"۰",
  })
  # Replace one-char ۀ with two-character هٔ.
  text = text.replace(u"ۀ", u"هٔ")
  # Replace HEH GOAL ہ with regular heh ه.
  text = text.replace(u"ہ", u"ه")
  # [Replace ARABIC LETTER AE ە with regular heh ه; it's a mistake based on visual similarity.]
  # --Found intentionally in Sistani text.
  #text = text.replace(u"ە", u"ه")
  # Another weird letter like ه: ARABIC LETTER HEH DOACHASHMEE
  text = text.replace(u"ھ", u"ه")

  # Underscore weirdly appears at the beginning of several suffixes, where it should be tatweel.
  text = rsub(text, "^_", u"ـ")
  # Don't do this for Persian unless we really want to vocalize this way.
  # convert llh for allâh into ll+shadda+dagger-alif+h
  #text = rsub(text, u"لله", u"للّٰه")
  # msg("text enter: %s" % text)
  # shadda+short-vowel (including tanwin vowels, i.e. -an -in -un) gets
  # replaced with short-vowel+shadda during NFC normalisation, which
  # MediaWiki does for all Unicode strings; however, it makes the
  # transliteration process inconvenient, so undo it.
  text = rsub(text,
    u"([\u064B\u064C\u064D\u064E\u064F\u0650\u0670])" + SH, SH + r"\1")
  # tāʾ marbūṭa should always be preceded by fatha, alif, alif madda or
  # dagger alif; infer fatha if not. This fatha will force a match to an "a"
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
    msgfun("Removing shadda after sukuun + consonant in %s" % text)
    text = newtext
  # fatha mistakenly placed after consonant + alif should go before.
  newtext = rsub(text, "([" + lconsonants + "])" + A + "?" + ALIF + A,
      r"\1" + AA)
  if text != newtext:
    msgfun("Fixing fatha after consonant + alif in %s" % text)
    text = newtext
  return text

# Pre-canonicalize the Arabic. If SAFE, only do "safe" operations appropriate
# to canonicalizing Arabic on its own, not before a tr_matching() operation.
def pre_canonicalize_arabic(text, safe=False, msgfun=msg):
  if "{{" in text:
    # Embedded templates. Don't touch the stuff inside the embedded part.
    retval = run_on_non_template_code(text, lambda run: pre_canonicalize_arabic(run, safe=safe, msgfun=msgfun), msgfun)
    if retval is not None:
      return retval

  if dont_pre_canonicalize_arabic(text):
    return text
  if not safe:
    # word-initial al + consonant + shadda: remove shadda
    text = rsub(text, u"(^|\\s|\[\[|\|)(\u0627\u064E?\u0644[" + lconsonants + u"])" + SH, r"\1\2")
    # same for hamzat al-waṣl + l + consonant + shadda, anywhere
    text = rsub(text, u"(\u0671\u064E?\u0644[" + lconsonants + u"])" + SH, r"\1")
    # word-initial al + l + dagger-alif + h (allâh): convert second l
    # to double_l_subst; will match shadda in Latin allâh during
    # tr_matching(), will be converted back during post-canonicalization
    text = rsub(text, u"(^|\\s|\[\[|\|)(\u0627\u064E?\u0644)\u0644(\u0670?ه)", r"\1\2" + double_l_subst + r"\3")
    # same for hamzat al-waṣl + l + l + dagger-alif + h occurring anywhere.
    text = rsub(text, u"(\u0671\u064E?\u0644)\u0644(\u0670?ه)", r"\1" + double_l_subst + "\2")
    # Don't do this as we don't currently handle it in the main body of the code and it causes issues for lots of
    # words, e.g. tr_matching(السالوادور, elsâlvâdor), tr_matching(الدنگ, aldang), tr_matching(التهاب, eltehâb).
    # There are placed where Arabic ال does occur, e.g. tr_matching(حفظ الصحه, hefz ol-seha) [which we should
    # handle correctly] and tr_matching(علیه السلام, 'aleyhe-s-salâm), tr_matching(علیها السلام, 'aleyhâ-s-salâm)
    # [which need further work].
    #
    ## word-initial al + sun letter: convert l to assimilating_l_subst; will
    ## convert back during post-canonicalization; during tr_matching(),
    ## assimilating_l_subst will match the appropriate character, or "l"
    #text = rsub(text, u"(^|\\s|\[\[|\|)(\u0627\u064E?)\u0644([" +
    #    sun_letters + "])", r"\1\2" + assimilating_l_subst + r"\3")
    ## same for hamzat al-waṣl + l + sun letter occurring anywhere.
    #text = rsub(text, u"(\u0671\u064E?)\u0644([" + sun_letters + "])",
    #  r"\1" + assimilating_l_subst + r"\2")
  return text

def post_canonicalize_arabic(text, safe=False, msgfun=msg):
  if "{{" in text:
    # Embedded templates. Don't touch the stuff inside the embedded part.
    retval = run_on_non_template_code(text, lambda run: post_canonicalize_arabic(run, safe=safe, msgfun=msgfun), msgfun)
    if retval is not None:
      return retval

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
     r"\1\2\3" + SH)
  # same for hamzat al-waṣl + l + consonant + sukuun + sun letters anywhere
  text = rsub(text, u"(\u0671\u064E?\u0644)" + SK + "([" + sun_letters + "])",
     r"\1\2" + SH)
  # Undo shadda+short-vowel reversal in pre_pre_canonicalize_arabic.
  # Not strictly necessary as MediaWiki will automatically do this
  # reversal but ensures that e.g. we don't keep trying to revocalize and
  # save a page with a shadda in it. Don't undo shadda+dagger-alif because
  # that sequence may not get reversed to begin with.
  text = rsub(text,
    SH + u"([\u064B\u064C\u064D\u064E\u064F\u0650])", r"\1" + SH)
  return text

def split_multiple_translits(latin, foreign):
  # Check for multiple translits opposite a single Arabic-script term.
  # If processing for changing, we need to paste the results back together.
  if "," in latin and not re.search(u"[,،]", foreign):
    return re.split(r",\s*", latin)
  elif ";" in latin and not re.search(u"[;؛]", foreign):
    return re.split(r";\s*", latin)
  elif "~" in latin and "~" not in foreign:
    return re.split(r"\s*~\s*", latin)
  elif "/" in latin and "/" not in foreign:
    return re.split(r"\s*/\s*", latin)
  elif " ''or'' " in latin and " " not in foreign:
    return re.split(r"\s+''or''\s+", latin)
  elif " or " in latin and " " not in foreign:
    return re.split(r"\s+or\s+", latin)
  else:
    return None

# Vocalize Persian Arabic-script text based on transliterated Latin, and canonicalize the transliteration based on
# the Arabic script.  This works by matching the Latin to the unvocalized Arabic script and inserting the appropriate
# diacritics in the right places, so that ambiguities of Latin transliteration can be correctly handled. Returns a
# tuple of (Arabic, Latin, PARTIAL_FAILURE_ERROR_MESSAGES, PARTIAL_SUCCESS) where if there are multiple translits,
# PARTIAL_FAILURE_ERROR_MESSAGES contains the error messages of any failures and PARTIAL_SUCCESS is True if there was
# at least one success. Otherwise, if failure (unable to match), throw an error if ERR; if success,
# PARTIAL_FAILURE_ERROR_MESSAGES and PARTIAL_SUCCESS will be None.
def tr_matching(obj, arabic, latin, err=False, msgfun=msg, no_vocalize=None):
  origarabic = arabic
  origlatin = latin

  def debprint(x):
    if debug_tr_matching:
      msg(x)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (obj.index, obj.pagetitle, txt))

  latins = split_multiple_translits(latin, arabic)
  if latins is not None:
    arabic_res = None
    match_canon_errors = []
    match_canon_partial_success = False
    for i, one_latin in enumerate(latins):
      # Can't vocalize when multiple translits as they are likely different vocalizations. Use the first canonicalized
      # Arabic script for the return value.
      try:
        this_arabic_res, this_latin_res, _, _ = tr_matching(obj, arabic, one_latin, err=err, msgfun=msgfun, no_vocalize=True)
        if arabic_res is None:
          arabic_res = this_arabic_res
        latins[i] = this_latin_res
        match_canon_partial_success = True
      except RuntimeError as e:
        match_canon_error = u"%s" % e
        match_canon_errors.append(match_canon_error)
        pagemsg("NOTE: %s" % match_canon_error)
        # If we can't match, fall back on cross-canonicalization.
        this_latin_res, this_arabic_res = canonicalize_latin_foreign(obj, one_latin, arabic, msgfun=msgfun)
        if arabic_res is None:
          arabic_res = this_arabic_res
        latins[i] = this_latin_res
    latin_res = ", ".join(latins)
    match_canon_partial_failure_error = "; ".join(match_canon_errors)
    return arabic_res, latin_res, match_canon_partial_failure_error, match_canon_partial_success

  classical = check_for_classical_or_dialectal(obj, pagemsg)
  if no_vocalize is None:
    no_vocalize = obj.addl_params["no_vocalize"]

  arabic = pre_pre_canonicalize_arabic(arabic, msgfun=msgfun)
  latin = pre_canonicalize_latin(latin, arabic, classical=classical, msgfun=msgfun)
  arabic = pre_canonicalize_arabic(arabic, msgfun=msgfun)
  # convert double consonant after non-cons to consonant + shadda,
  # but not multiple quotes, periods, braces or brackets
  latin = re.sub(ur"(^|[\W" + vowel_chars + r"])([^'.{}\[\]])\2", r"\1\2" + SH,
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

  def create_state():
    return State(ar, aind, alen, la, lind, llen, res, lres, classical, no_vocalize)

  st = create_state()

  def get_matches():
    ac = ar[aind[0]]
    debprint("get_matches: ac is %s" % ac)

    potential_matching_tables = []
    if st.is_bow():
      potential_matching_tables.append(tt_to_arabic_matching_bow)
    if st.is_boc():
      potential_matching_tables.append(tt_to_arabic_matching_boc)
    if st.is_eow():
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
        error("Encountered non-Arabic (?) character " + ac + " at index " + str(aind[0]))
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
      handle_empty_match_early = False
      # If an element of the match list is a list, it means
      # "don't canonicalize".
      if isinstance(m, list):
        preserve_latin = True
        match = m[0]
      # A one-element tuple is a signal for use in self-canonicalization,
      # not here.
      elif isinstance(m, tuple):
        match = m[0]
      elif isinstance(m, LatinMatch):
        if m.when and not m.when(st):
          continue
        this_canon = m.canon_to
        if callable(this_canon):
          this_canon = this_canon(st)
          if this_canon is None:
            continue
        match = m.match
        handle_empty_match_early = m.handle_empty_match_early
        if callable(handle_empty_match_early):
          handle_empty_match_early = handle_empty_match_early(st)
      else:
        match = m

      # Don't allow matching against an empty string unless allow_empty_latin=True. This avoids problems matching the
      # empty string too soon, e.g. {{t|fa|شعله‌ور|tr=šo'levar|sc=fa-Arab}}, where ع (`ayn) can match the empty
      # string and canonicalize to ', but before that should happen, we have to consume the unmatched o.
      if not allow_empty_latin and not match and not handle_empty_match_early:
        # Allow if we're dealing with ع and ئ between vowels. This allows us to infer ' between vowels when it's not
        # present, instead of adding the apostrophe after both vowels.
        if ac not in [u"ع", u"ئ"]:
          continue
        prevla = st.prevla()
        thisla = st.thisla()
        if not prevla or not thisla:
          continue
        #msg("prevla=%s, thisla=%s" % (prevla, thisla))
        if prevla not in vowel_chars or thisla not in vowel_chars:
          continue

      l = lind[0]
      matched = True
      debprint("match: %s" % match)
      for cp in match:
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
          for cp in match:
            lres.append(cp)
        elif ac == u"ة":
          if not st.is_eow():
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
      error("Unable to match trailing Arabic character %s at index %s" % (ar[aind[0]], aind[0]))
    else:
      error("Unable to match trailing Latin character %s at index %s" % (la[lind[0]], lind[0]))

  # Check for an unmatched Latin short vowel or similar; if so, insert
  # corresponding Arabic diacritic.
  def check_latin_not_matching_arabic():
    if not (lind[0] < llen):
      return False
    # Don't allow an unmatching Latin short vowel at the beginning of a word; there should always be a alif, alif madda
    # or similar on the Arabic side.
    if st.is_bow():
      return False
    l = la[lind[0]]
    debprint("Unmatched Latin: %s at %s" % (l, lind[0]))
    arabic = tt_latin_to_unmatched_arabic.get(l)
    if arabic is not None:
      if isinstance(arabic, tuple):
        arabic, l, when = arabic
        if callable(l):
          l = l(st)
        if not when(st):
          return False
      if not no_vocalize:
        res.append(arabic)
      lres.append(l)
      lind[0] += 1
      return True
    return False

  # Check for certain unmatched Latin chars; allow. We do this at the very very end to avoid interfering with all other
  # checks.
  def check_latin_char_not_matching():
    if not (lind[0] < llen):
      return False
    l = la[lind[0]]
    a = None if aind[0] >= alen else ar[aind[0]]
    # Hyphens mark compounds, which may not be marked in the Arabic script (particularly if the last char of the first
    # part of the compound is non-joining; otherwise a ZWNJ would normally occur).
    #
    # Apostrophes in the translit are common in usexes to boldface the portion of the translit corresponding to the
    # page lemma.
    ok = False
    if l in ["-"]:
      ok = True
    if l == "'":
      # Make sure there are at least two apostrophes in a row.
      if st.prevla() == "'" or st.nextla() == "'":
        ok = True
    if ok:
      debprint("check_latin_char_not_matching(): Saw Latin %s against (unmatched) %s, copying" % (l, a))
      lres.append(l)
      lind[0] += 1
      return True

    # Check for <br> or variants and copy.
    def do_check(check):
      if check("<") and check("b") and check("r"):
        check(" ")
        check("/")
        if check(">"):
          return True
      return False

    lind_end = [lind[0]]
    def lcheck(ch):
      matched = lind_end[0] < llen and la[lind_end[0]] == ch
      if matched:
        lind_end[0] += 1
      return matched

    aind_end = [aind[0]]
    def acheck(ch):
      matched = aind_end[0] < alen and ar[aind_end[0]] == ch
      if matched:
        aind_end[0] += 1
      return matched

    if do_check(lcheck) and do_check(acheck):
      lchars_to_copy = la[lind[0]:lind_end[0]]
      achars_to_copy = ar[aind[0]:aind_end[0]]
      debprint("check_latin_char_not_matching(): Saw Latin %s against %s, copying"
        % ("".join(lchars_to_copy), "".join(achars_to_copy)))
      lres.extend(lchars_to_copy)
      lind[0] = lind_end[0]
      res.extend(achars_to_copy)
      aind[0] = aind_end[0]
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
          if not no_vocalize:
            res.append(I) # kasra marking the ezafe
          res.append(" ")
          aind[0] += 1
        elif lind[0] + 3 < llen and la[lind[0] + 1] == "y" and la[lind[0] + 2] == "e" and la[lind[0] + 3] in [" ", "-"]:
          # ezafe construction with -ye, often unmatched.
          lres.append("-ye ")
          lind[0] += 3 # it will get incremented once more below
          if not no_vocalize:
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
  #  if not (st.is_bow() and aind[0] < alen and ar[aind[0]] == u"ا"):
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

  # Check for inferring tanwin
  def check_eow_tanwin():
    tanwin_mapping = {"a":AN, "i":IN, "u":UN}
    # Infer tanwin at EOW
    if (aind[0] > 0 and st.is_eow(aind[0] - 1) and lind[0] < llen - 1 and
        la[lind[0]] in "aiu" and la[lind[0] + 1] == "n"):
      res.append(tanwin_mapping[la[lind[0]]])
      lres.append(la[lind[0]])
      lres.append(la[lind[0] + 1])
      lind[0] += 2
      return True
    # Infer fathatan before EOW alif/alif maqsuura
    if (aind[0] < alen and st.is_eow() and
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
      elif not no_vocalize:
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
    elif (not st.is_bow() and aind[0] < alen and
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
    elif check_latin_char_not_matching():
      # This should be the last thing checked.
      debprint("Matched: Clause check_latin_char_not_matching()")
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
  arabic = post_canonicalize_arabic(arabic, msgfun=msgfun)
  latin = post_canonicalize_latin(latin, classical=classical, msgfun=msgfun)
  return arabic, latin, None, None

def remove_diacritics(word):
  return arabiclib.remove_diacritics(word)

################################ Test code ##########################

num_failed = 0
num_succeeded = 0

def test_with_obj(obj, latin, arabic, should_outcome, should_latin=None):
  global num_succeeded, num_failed
  try:
    result = tr_matching(obj, arabic, latin, err=True)
  except RuntimeError as e:
    msg(u"%s" % e)
    result = False
  outcome = None
  if result == False:
    msg("tr_matching(%s, %s) = %s" % (arabic, latin, result))
    outcome = "failed"
  else:
    canonarabic, canonlatin, match_canon_partial_failure_error, match_canon_partial_success = result
    trlatin = tr(canonarabic)
    if match_canon_partial_failure_error is None:
      multimsg = ""
    elif match_canon_partial_failure_error:
      if match_canon_partial_success:
        multimsg = ", multi-translit partial success (%s)" % match_canon_partial_failure_error
      else:
        multimsg = ", multi-translit failure (%s)" % match_canon_partial_failure_error
        outcome = "failed"
    else:
      multimsg = ", multi-translit success"
    msgn("tr_matching(%s, %s) = %s %s%s" % (arabic, latin, canonarabic, canonlatin, multimsg))
    canon_changed = "" if latin == canonlatin else ", CANON-CHANGED"
    this_outcome = None
    if trlatin == canonlatin:
      msg(", tr() MATCHED" + canon_changed)
      this_outcome = "matched"
    elif trlatin is NotImplemented:
      msg(canon_changed)
      this_outcome = "matched"
    elif trlatin is None:
      msg(", tr() SKIPPED" + canon_changed)
      this_outcome = "matched"
    else:
      msg(", tr() UNMATCHED (= %s)" % trlatin + canon_changed)
      this_outcome = "unmatched"
    if outcome is None:
      outcome = this_outcome
  canonlatin, _ = canonicalize_latin_foreign(obj, latin, None)
  msg("canonicalize_latin(%s) = %s" %
      (latin, canonlatin))
  if outcome == should_outcome:
    msg("TEST SUCCEEDED.")
    num_succeeded += 1
  else:
    msg("TEST FAILED.")
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
  # The Arabic of the following consists of wâw + fatha + ZWJ + dâl + ḵâʾ + lâm.
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
  # Test final otiose alif maqsuura after fathatan
  test("hudan", u"هُدًى", "matched")
  # Test opposite with fathatan after alif otiose alif maqsuura
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

  # Test inferring fathatan
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
  msg("RESULTS: %s SUCCEEDED, %s FAILED." % (num_succeeded, num_failed))

if __name__ == "__main__":
  run_tests()
