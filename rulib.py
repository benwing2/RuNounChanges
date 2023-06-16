#!/usr/bin/python
# -*- coding: utf-8 -*-

import re
import unicodedata
import blib
from collections import OrderedDict

AC = u"\u0301" # acute =  ́
GR = u"\u0300" # grave =  ̀
CFLEX = u"\u0302" # circumflex =  ̂
DOTABOVE = u"\u0307" # dot above =  ̇
DOTBELOW = u"\u0323" # dot below =  ̣
DI = u"\u0308" # diaeresis =  ̈
DUBGR = u"\u030F" # double grave =  ̏
CARON = u"\u030C" # caron =  ̌

PSEUDOVOWEL = u"\uFFF1" # pseudovowel placeholder
PSEUDOCONS = u"\uFFF2" # pseudoconsonant placeholder

# non-primary accents (i.e. excluding acute) that indicate pronunciation
# (not counting diaeresis, which indicates a completely different vowel,
# and caron, which is used in translit as ě to indicate the yat vowel)
non_primary_pron_accents = GR + CFLEX + DOTABOVE + DOTBELOW + DUBGR
# accents that indicate pronunciation (not counting diaresis, which indicates
# a completely different vowel)
pron_accents = AC + non_primary_pron_accents
# all accents
accents = pron_accents + DI + CARON
# accents indicating stress (primary or otherwise)
stress_accents = AC + GR + CFLEX + DI + DUBGR

# regex for any optional accent(s)
opt_accent = "[" + accents + "]*"

composed_grave_vowel = u"ѐЀѝЍ"
vowel_no_jo = u"аеиоуяэыюіѣѵүАЕИОУЯЭЫЮІѢѴҮ" + composed_grave_vowel #omit ёЁ
vowel = vowel_no_jo + u"ёЁ"
cons_except_sib_c = u"бдфгйклмнпрствхзьъБДФГЙКЛМНПРСТВХЗЬЪ"
sib = u"шщчжШЩЧЖ"
sib_c = sib + u"цЦ"
cons = cons_except_sib_c + sib_c
velar = u"кгхКГХ"
uppercase = u"АЕИОУЯЭЫЁЮІѢѴБДФГЙКЛМНПРСТВХЗЬЪШЩЧЖЦ"
tr_vowel = u"aeěɛiouyAEĚƐIOUY"
# any consonant in transliteration, omitting soft/hard sign
tr_cons_no_sign = u"bcčdfghjklmnpqrsštvwxzžBCČDFGHJKLMNPQRSŠTVWXZŽ" + PSEUDOCONS
# any consonant in transliteration, including soft/hard sign
tr_cons = tr_cons_no_sign + u"ʹʺ"
# regex for any consonant in transliteration, including soft/hard sign,
# optionally followed by any accent
tr_cons_acc_re = "[" + tr_cons + "]" + opt_accent

def uniprint(x):
  print x.encode('utf-8')
def uniout(x):
  print x.encode('utf-8'),

def decompose_acute_grave(text):
  # Decompose sequences of character + acute or grave, but compose all other
  # accented sequences, e.g. Latin č and ě, Cyrillic ё and й.
  # (1) Decompose entirely.
  decomposed = unicodedata.normalize("NFD", str(text))
  # (2) Split into text sections separated by acutes and graves.
  split = re.split("([%s%s])" % (AC, GR), decomposed)
  # (3) Recompose each section.
  recomposed = [unicodedata.normalize("NFC", part) for part in split]
  # (4) Paste sections together.
  return "".join(recomposed)

def decompose(text):
  return decompose_acute_grave(text)

def recompose(text):
  return unicodedata.normalize("NFC", text)

def assert_decomposed(text):
  assert not re.search(u"[áéíóúýàèìòùỳäëïöüÿÁÉÍÓÚÝÀÈÌÒÙỲÄËÏÖÜŸ]", text)

def xlit_text(text, pagemsg, verbose=False):
  def expand_text(tempcall):
    # The page name doesn't matter when we call {{xlit}}.
    return blib.expand_text(tempcall, "foo bar", pagemsg, verbose)
  return expand_text("{{xlit|ru|%s}}" % text)

# Does a phrase of connected text need accents? We need to split by word
# and check each one.
def needs_accents(text, split_dash=False):
  # A word needs accents if it is unstressed and contains more than one vowel;
  # but if split_dash, allow cases like динь-динь with multiple monosyllabic
  # words separated by a hyphen. We don't just split on hyphens at top level
  # otherwise a word like Али-Баба́ will "need accents".
  def word_needs_accents(word):
    if not is_unaccented(word):
      return False
    for sw in re.split(r"-", word) if split_dash else [word]:
      if not is_monosyllabic(sw):
        return True
    return False
  words = re.split(r"\s", text)
  for word in words:
    if word_needs_accents(word):
      return True
  return False

def is_stressed(word):
  # A word that has ё in it is inherently stressed.
  # diaeresis occurs in сѣ̈дла plural of сѣдло́
  return re.search(u"[́̈ёЁ]", word)

def is_tr_stressed(word):
  if not word:
    return False
  return re.search(u"[́̈]", unicodedata.normalize("NFD", word))

def is_unstressed(word):
  return not is_stressed(word)

def is_tr_unstressed(word):
  return not is_tr_stressed(word)

def is_unaccented(word):
  return not re.search("[" + stress_accents + u"ёЁѐЀѝЍ]", word)

def is_tr_unaccented(word):
  return not re.search("[" + stress_accents + "]", unicodedata.normalize("NFD", word))

def is_ending_stressed(word):
  return (re.search(u"[ёЁ][^" + vowel + "]*$", word) or
    re.search("[" + vowel + u"][́̈][^" + vowel + "]*$", word))

# True if any word in text has two or more stresses; don't count words like
# платёжеспосо́бность or трёхле́тний, where the first ё isn't accented
def is_multi_stressed(text):
  text = re.sub(u"[ёЁ]", u"е" + DI, text)
  words = re.split(r"[\s-]", text)
  for word in words:
    # Look for true accent (not diaeresis) + any another accent, in the
    # same word
    if re.search("[" + vowel + u"][́].*[" + vowel + u"][́̈]", word):
      return True
  return False

def number_of_accents(text):
  return len(re.sub("[^" + accents + u"ёЁѐЀѝЍ]", "", text))

def is_beginning_stressed(word):
  return (re.search("^[^" + vowel + u"]*[ёЁ]", word) or
    re.search("^[^" + vowel + "]*[" + vowel + u"]́", word))

def is_nonsyllabic(word):
  return not re.search("[" + vowel + "]", word)

# Includes non-syllabic stems such as льд-
def is_monosyllabic(word):
  vowel_or_hard_sign = vowel + u"ъЪ" # in case we're called for Bulgarian
  word = re.sub(u"ъ$", "", word)
  return not re.search("[" + vowel_or_hard_sign + "].*[" + vowel_or_hard_sign + "]", word)

# Includes non-syllabic stems such as lʹd-
def is_tr_monosyllabic(word):
  if not word:
    return False
  return not re.search("[" + tr_vowel + "].*[" + tr_vowel + "]",
      unicodedata.normalize("NFD", word))

def ends_with_vowel(word):
  return re.search("[" + vowel + "][" + AC + GR + DI + "]?$", word)

grave_deaccenter = {
    GR:"", # grave accent
    u"ѐ":u"е", # composed Cyrillic chars w/grave accent
    u"Ѐ":u"Е",
    u"ѝ":u"и",
    u"Ѝ":u"И",
}

deaccenter = grave_deaccenter.copy()
deaccenter[AC] = "" # acute accent
deaccenter[DI] = "" # diaeresis

def remove_grave_accents(word):
  # remove grave accents
  return re.sub("([" + GR + u"ѐЀѝЍ])", lambda m: grave_deaccenter[m.group(1)], word)

def remove_accents(word):
  # remove pronunciation accents (not diaeresis)
  return re.sub("([" + pron_accents + u"ѐЀѝЍ])",
    lambda m: deaccenter[m.group(1)], word)

def remove_tr_accents(word):
  # remove pronunciation accents from translit (not diaeresis)
  if not word:
    return word
  return unicodedata.normalize("NFC", re.sub(u"[" + pron_accents + "]", "",
    unicodedata.normalize("NFD", word)))

def remove_monosyllabic_accents(word):
  # note: This doesn't affect diaeresis (composed or uncomposed) because
  # it indicates a change in vowel quality, which still applies to
  # monosyllabic words.
  if is_monosyllabic(word) and not word.startswith("-"):
    return remove_accents(word)
  return word

def remove_tr_monosyllabic_accents(word):
  # note: This doesn't affect diaeresis (composed or uncomposed) because
  # it indicates a change in vowel quality, which still applies to
  # monosyllabic words.
  if not word:
    return word
  if is_tr_monosyllabic(word) and not word.startswith("-"):
    return remove_tr_accents(word)
  return word

def remove_non_primary_accents(word):
  # remove all pronunciation accents except acute
  return re.sub("([" + non_primary_pron_accents + u"ѐЀѝЍ])",
    lambda m: deaccenter[m.group(1)], word)

def remove_tr_non_primary_accents(word):
  # remove all pronunciation accents except acute from translit
  if not word:
    return word
  return unicodedata.normalize("NFC", re.sub(u"[" + non_primary_pron_accents + "]", "",
    unicodedata.normalize("NFD", word)))

# Subfunction of split_syllables(). On input we get sections of text
# consisting of CONSONANT - VOWEL - CONSONANT - VOWEL ... - CONSONANT,
# where CONSONANT consists of zero or more consonants and VOWEL consists
# of exactly one vowel plus any following accent(s); we combine these into
# syllables as required by split_syllables().
def combine_captures(captures):
  if len(captures) == 1:
    return captures
  combined = []
  for i in range(0, len(captures) - 1, 2):
    combined.append(captures[i] + captures[i+1])
  combined[-1] = combined[-1] + captures[-1]
  return combined

# Split Russian text and transliteration into syllables. Syllables end with
# vowel + accent(s), except for the last syllable, which includes any
# trailing consonants.
# NOTE: Translit must already be decomposed! See comment at top.
def split_syllables(ru, tr):
  # Split into alternating consonant/vowel sequences, as described in
  # combine_captures().
  rusyllables = combine_captures(re.split("([" + vowel + "]" + opt_accent + ")", ru))
  trsyllables = None
  if tr:
    assert_decomposed(tr)
    trsyllables = combine_captures(re.split("([" + tr_vowel + "]" + opt_accent + ")", tr))
    if len(rusyllables) != len(trsyllables):
      raise ValueError("Russian " + ru + " doesn't have same number of syllables as translit " + tr)
  # msg("/".join(rusyllables) + "(" + str(len(rusyllables)) + (trsyllables and (") || " + "/".join(trsyllables) + "(" + str(len(trsyllables)) + ")") or ""))
  return rusyllables, trsyllables

# Split Russian word and transliteration into hyphen-separated components.
# Rejoining with "-".join(...) will recover the original word.
# If the original word ends in a hyphen, that hyphen gets included with the
# preceding component (this is the only case when an individual component has
# a hyphen in it).
def split_hyphens(ru, tr):
  rucomponents = ru.split("-")
  if rucomponents[-1] == "" and len(rucomponents) > 1:
    rucomponents[-2] = rucomponents[-2] + "-"
    del rucomponents[-1]
  trcomponents = None
  if tr:
    trcomponents = tr.split("-")
    if trcomponents[-1] == "" and len(trcomponents) > 1:
      trcomponents[-2] = trcomponents[-2] + "-"
      del trcomponents[-1]
    if len(rucomponents) != len(trcomponents):
      raise ValueError("Russian " + ru + " doesn't have same number of hyphenated components as translit " + tr)
  return rucomponents, trcomponents

# Apply j correction, converting je to e after consonants, jo to o after
# a sibilant, ju to u after hard sibilant.
# NOTE: Translit must already be decomposed! See comment at top.
def j_correction(tr):
  tr = re.sub("([" + tr_cons_no_sign + "]" + opt_accent + u")[Jj]([EeĚě])", r"\1\2", tr)
  tr = re.sub(u"([žščŽŠČ])[Jj]([Oo])", r"\1\2", tr)
  tr = re.sub(u"([žšŽŠ])[Jj]([Uu])", r"\1\2", tr)
  return tr

destresser = deaccenter.copy()
destresser[u"ё"] = u"е"
destresser[u"Ё"] = u"Е"

def make_unstressed_ru(ru):
  # The following regexp has grave+acute+diaeresis after the bracket
  #
  return re.sub(u"([̀́̈ёЁѐЀѝЍ])", lambda m: destresser[m.group(1)], ru)

# Remove all stress marks (acute, grave, diaeresis).
# NOTE: Translit must already be decomposed! See comment at top.
def make_unstressed(ru, tr=None):
  if not tr:
    return make_unstressed_ru(ru), None
  # In the presence of TR, we need to do things the hard way: Splitting
  # into syllables and only converting Latin o to e opposite a ё.
  rusyl, trsyl = split_syllables(ru, tr)
  for i in range(len(rusyl)):
    if re.search(u"[ёЁ]", rusyl[i]):
      trsyl[i] = trsyl[i].replace("o", "e").replace("O", "E")
    rusyl[i] = make_unstressed_ru(rusyl[i])
    # the following should still work as it will affect accents only
    trsyl[i] = make_unstressed_ru(trsyl[i])
  # Also need to apply j correction as otherwise we'll have je after cons, etc.
  return "".join(rusyl), j_correction("".join(trsyl))

def remove_jo_ru(word):
  return re.sub(u"([̈ёЁ])", destresser, word)

# Remove diaeresis stress marks only.
# NOTE: Translit must already be decomposed! See comment at top.
def remove_jo(ru, tr=None):
  if not tr:
    return remove_jo_ru(ru), None
  # In the presence of TR, we need to do things the hard way: Splitting
  # into syllables and only converting Latin o to e opposite a ё.
  rusyl, trsyl = split_syllables(ru, tr)
  for i in range(len(rusyl)):
    if re.search(u"[ёЁ]", rusyl[i]):
      trsyl[i] = trsyl[i].replace("o", "e").replace("O", "E")
    rusyl[i] = remove_jo_ru(rusyl[i])
    # the following should still work as it will affect accents only
    trsyl[i] = make_unstressed_once_ru(trsyl[i])
  # Also need to apply j correction as otherwise we'll have je after cons, etc.
  return "".join(rusyl), j_correction("".join(trsyl))

def make_unstressed_once_ru(word):
  # leave graves alone
  return re.sub(u"([́̈ёЁ])([^́̈ёЁ]*)$", lambda m: destresser[m.group(1)] + m.group(2), word, 1)

def map_last_hyphenated_component(fn, ru, tr):
  if "-" in ru:
    # If there is a hyphen, do it the hard way by splitting into
    # individual components and doing the last one. Otherwise we just do
    # the whole string.
    rucomponents, trcomponents = split_hyphens(ru, tr)
    lastru, lasttr = fn(rucomponents[-1], trcomponents and trcomponents[-1] or None)
    rucomponents[-1] = lastru
    ru = "-".join(rucomponents)
    if trcomponents:
      trcomponents[-1] = lasttr
      tr = "-".join(trcomponents)
    return ru, tr
  return fn(ru, tr)

# Make last stressed syllable (acute or diaeresis) unstressed; leave
# unstressed; leave graves alone; if NOCONCAT, return individual syllables.
# NOTE: Translit must already be decomposed! See comment at top.
def make_unstressed_once_after_hyphen_split(ru, tr=None, noconcat=False):
  if not tr:
    return make_unstressed_once_ru(ru), None
  # In the presence of TR, we need to do things the hard way, as with
  # make_unstressed().
  rusyl, trsyl = split_syllables(ru, tr)
  for i in range(len(rusyl) - 1, -1, -1):
    stressed = is_stressed(rusyl[i])
    if stressed:
      if re.search(u"[ёЁ]", rusyl[i]):
        trsyl[i] = trsyl[i].replace("o", "e").replace("O", "E")
      rusyl[i] = make_unstressed_once_ru(rusyl[i])
      # the following should still work as it will affect accents only
      trsyl[i] = make_unstressed_once_ru(trsyl[i])
      break
  if noconcat:
    return rusyl, trsyl
  # Also need to apply j correction as otherwise we'll have je after cons
  return "".join(rusyl), j_correction("".join(trsyl))

# Make last stressed syllable (acute or diaeresis) to the right of any hyphen
# unstressed (unless the hyphen is word-final); leave graves alone. We don't
# destress a syllable to the left of a hyphen unless the hyphen is word-final
# (i.e. a prefix). Otherwise e.g. the accents in the first part of words like
# ко́е-како́й and а́льфа-лу́ч won't remain.
# NOTE: Translit must already be decomposed! See comment at top.
def make_unstressed_once(ru, tr=None):
  return map_last_hyphenated_component(make_unstressed_once_after_hyphen_split, ru, tr)

def make_unstressed_once_at_beginning_ru(word):
  # leave graves alone
  return re.sub(u"^([^́̈ёЁ]*)([́̈ёЁ])", lambda m: m.group(1) + destresser[m.group(2)], word, 1)

# Make first stressed syllable (acute or diaeresis) unstressed; leave
# graves alone; if NOCONCAT, return individual syllables.
# NOTE: Translit must already be decomposed! See comment at top.
def make_unstressed_once_at_beginning(ru, tr=None, noconcat=False):
  if not tr:
    return make_unstressed_once_at_beginning_ru(ru), None
  # In the presence of TR, we need to do things the hard way, as with
  # make_unstressed().
  rusyl, trsyl = split_syllables(ru, tr)
  for i in range(len(rusyl)):
    stressed = is_stressed(rusyl[i])
    if stressed:
      if re.search(u"[ёЁ]", rusyl[i]):
        trsyl[i] = trsyl[i].replace("o", "e").replace("O", "E")
      rusyl[i] = make_unstressed_once_at_beginning_ru(rusyl[i])
      # the following should still work as it will affect accents only
      trsyl[i] = make_unstressed_once_at_beginning_ru(trsyl[i])
      break
  if noconcat:
    return rusyl, trsyl
  # Also need to apply j correction as otherwise we'll have je after cons
  return "".join(rusyl), j_correction("".join(trsyl))

# Subfunction of make_ending_stressed(), make_beginning_stressed(), which
# add an acute accent to a syllable that may already have a grave accent;
# in such a case, remove the grave.
# NOTE: Translit must already be decomposed! See comment at top.
def correct_grave_acute_clash(word, tr=None):
  word = re.sub(u"([̀ѐЀѝЍ])́", lambda m: grave_deaccenter[m.group(1)] + AC, word)
  word = word.replace(AC + GR, AC)
  if not tr:
    return word, None
  assert_decomposed(tr)
  tr = tr.replace(GR + AC, AC)
  tr = tr.replace(AC + GR, AC)
  return word, tr

def make_ending_stressed_ru(word):
  # If already ending stressed, just return word so we don't mess up ё
  if is_ending_stressed(word):
    return word
  # Destress the last stressed syllable
  word = make_unstressed_once_ru(word)
  # Add an acute to the last syllable
  word = re.sub("([" + vowel_no_jo + "])([^" + vowel + "]*)$", ur"\1́\2", word)
  # If that caused an acute and grave next to each other, remove the grave
  return correct_grave_acute_clash(word)[0]

# Remove the last primary stress from the word and put it on the final
# syllable. Leave grave accents alone except in the last syllable.
# If final syllable already has primary stress, do nothing.
# NOTE: Translit must already be decomposed! See comment at top.
def make_ending_stressed_after_hyphen_split(ru, tr):
  if not tr:
    return make_ending_stressed_ru(ru), None
  # If already ending stressed, just return ru/tr so we don't mess up ё
  if is_ending_stressed(ru):
    return ru, tr
  # Destress the last stressed syllable; pass in "noconcat" so we get
  # the individual syllables back
  rusyl, trsyl = make_unstressed_once_after_hyphen_split(ru, tr, "noconcat")
  # Add an acute to the last syllable of both Russian and translit
  rusyl[-1] = re.sub("([" + vowel_no_jo + "])", r"\1" + AC, rusyl[-1])
  trsyl[-1] = re.sub("([" + tr_vowel + "])", r"\1" + AC, trsyl[-1])
  # If that caused an acute and grave next to each other, remove the grave
  rusyl[-1], trsyl[-1] = correct_grave_acute_clash(rusyl[-1], trsyl[-1])
  # j correction didn't get applied in make_unstressed_once because
  # we short-circuited it and made it return lists of syllables
  return "".join(rusyl), j_correction("".join(trsyl))

# Remove the last primary stress from the portion of the word to the right of
# any hyphen (unless the hyphen is word-final) and put it on the final
# syllable. Leave grave accents alone except in the last syllable. If final
# syllable already has primary stress, do nothing. (See make_unstressed_once()
# for why we don't affect stresses to the left of a hyphen.)
# NOTE: Translit must already be decomposed! See comment at top.
def make_ending_stressed(ru, tr=None):
  return map_last_hyphenated_component(make_ending_stressed_after_hyphen_split, ru, tr)

def make_beginning_stressed_ru(word):
  # If already beginning stressed, just return word so we don't mess up ё
  if is_beginning_stressed(word):
    return word
  # Destress the first stressed syllable
  word = make_unstressed_once_at_beginning_ru(word)
  # Add an acute to the first syllable
  word = re.sub("^([^" + vowel + "]*)([" + vowel_no_jo + "])", ur"\1\2́", word)
  # If that caused an acute and grave next to each other, remove the grave
  return correct_grave_acute_clash(word)[0]

# Remove the first primary stress from the word and put it on the initial
# syllable. Leave grave accents alone except in the first syllable.
# If initial syllable already has primary stress, do nothing.
# NOTE: Translit must already be decomposed! See comment at top.
def make_beginning_stressed(ru, tr=None):
  if not tr:
    return make_beginning_stressed_ru(ru), None
  # If already beginning stressed, just return ru/tr so we don't mess up ё
  if is_beginning_stressed(ru):
    return ru, tr
  # Destress the first stressed syllable; pass in "noconcat" so we get
  # the individual syllables back
  rusyl, trsyl = make_unstressed_once_at_beginning(ru, tr, "noconcat")
  # Add an acute to the first syllable of both Russian and translit
  rusyl[0] = re.sub("([" + vowel_no_jo + "])", r"\1" + AC, rusyl[0])
  trsyl[0] = re.sub("([" + tr_vowel + "])", r"\1" + AC, trsyl[0])
  # If that caused an acute and grave next to each other, remove the grave
  rusyl[0], trsyl[0] = correct_grave_acute_clash(rusyl[0], trsyl[0])
  # j correction didn't get applied in make_unstressed_once_at_beginning
  # because we short-circuited it and made it return lists of syllables
  return "".join(rusyl), j_correction("".join(trsyl))

def try_to_stress(word):
  if is_unaccented(word) and is_monosyllabic(word):
    return make_ending_stressed(word)
  else:
    return word

def tr_try_to_stress(word):
  if is_tr_unaccented(word) and is_tr_monosyllabic(word):
    # FIXME, won't work, make_ending_stressed() needs to take both ru and tr, see Lua
    #return make_tr_ending_stressed(word)
    return unicodedata.normalize("NFC",
        re.sub("([" + tr_vowel + "])([^" +  + "]*)$", ur"\1́\2", word))
  else:
    return word

def reduce_stem(stem):
    m = re.search(u"^(.*)([оОеЕёЁ])́?([" + cons + "]+)$", stem)
    if not m:
      return None
    pre, letter, post = m.groups()
    if letter in u"оО":
      if post in u"йЙ":
        return None # FIXME, is this correct?
      letter = ""
    else:
      is_upper = post in uppercase
      if re.search("[" + vowel + u"]́?$", pre):
        letter = is_upper and u"Й" or u"й"
      elif post in u"йЙ":
        letter = is_upper and u"Ь" or u"ь"
        post = ""
      elif ((post in velar and pre in cons_except_sib_c) or
          (post not in u"йЙ" + velar and re.search(u"[лЛ]$", pre))):
        letter = is_upper and u"Ь" or u"ь"
      else:
        letter = ""
    stem = pre + letter + post
    return stem

def dereduce_stem(stem, epenthetic_stress):
  if epenthetic_stress:
    stem = make_unstressed_once(stem)
  m = re.search("^(.*)([" + cons + "])([" + cons + "])$", stem)
  if not m:
    return None
  pre, letter, post = m.groups()
  is_upper = post in uppercase
  if letter in u"ьйЬЙ":
    letter = ""
    if post in u"цЦ" or not epenthetic_stress:
      epvowel = is_upper and u"Е" or u"е"
    else:
      epvowel = is_upper and u"Ё" or u"ё"
  elif letter in cons_except_sib_c and post in velar or letter in velar:
    epvowel = is_upper and u"О" or u"о"
  elif post in u"цЦ":
    epvowel = is_upper and u"Е" or u"е"
  elif epenthetic_stress:
    if letter in sib:
      epvowel = is_upper and u"О́" or u"о́"
    else:
      epvowel = is_upper and u"Ё" or u"ё"
  else:
    epvowel = is_upper and u"Е" or u"е"
  stem = pre + letter + epvowel + post
  if epenthetic_stress:
    stem = make_ending_stressed(stem)
  return stem

def add_soft_sign(stem):
  if re.search("[" + vowel + "]$", stem):
    return stem + u"й"
  else:
    return stem + u"ь"

def add_hard_neuter(stem):
  if re.search("[" + sib_c + "]$", stem):
    return stem + u"е"
  else:
    return stem + u"о"

def split_russian_tr(arg):
  if "//" in arg:
    return re.split("//", arg)
  else:
    return arg, None

def paste_russian_tr(ru, tr):
  if tr:
    return "%s//%s" % (ru, tr)
  else:
    return ru

# Given an ru-noun+ or ru-proper noun+ template, fetch the arguments
# associated with it. May return None if an error occurred in template
# expansion.
def fetch_noun_args(t, expand_text, forms_only=False):
  generate_template = ("ru-generate-noun-forms" if forms_only else
      "ru-generate-noun-args")
  if str(t.name) == "ru-noun+":
    generate_template = re.sub(r"^\{\{ru-noun\+",
        "{{%s" % generate_template, str(t))
  else:
    generate_template = re.sub(r"^\{\{ru-proper noun\+",
        "{{%s|ndef=sg" % generate_template, str(t))
  generate_result = expand_text(generate_template)
  if not generate_result:
    return None
  return blib.split_generate_args(generate_result)

# Given an ru-noun+ or ru-proper noun+ template, fetch the lemma, which
# is of the form of one or more terms separted by commas, where each
# term is either a Cyrillic word or words, or a combination CYRILLIC/LATIN
# with manual transliteration. May return None if an error occurred
# in template expansion.
def fetch_noun_lemma(t, expand_text):
  # FIXME, probably not necessary to specify forms_only=True
  args = fetch_noun_args(t, expand_text, forms_only=True)
  if args is None:
    return None
  return args["nom_sg"] if "nom_sg" in args else args["nom_pl"]

# Given a list of form values, each of which is a tuple (RUSSIAN, TRANSLIT)
# where the TRANSLIT may be None or the empty string (in both cases treated
# as missing), group by RUSSIAN to handle cases where multiple translits are
# possible, generate any missing translits and join by commas. Return the list
# of form values, in the same order except with multiple translits combined.
def group_translits(formvals, pagemsg, verbose=False):
  # Group formvals by Russian, to group multiple translits
  formvals_by_russian = OrderedDict()
  for formvalru, formvaltr in formvals:
    if formvalru in formvals_by_russian:
      formvals_by_russian[formvalru].append(formvaltr)
    else:
      formvals_by_russian[formvalru] = [formvaltr]
  formvals = []
  # If there is more than one translit, then generate the
  # translit for any missing translit and join by commas
  for russian, translits in formvals_by_russian.iteritems():
    if len(translits) == 1:
      formvals.append((russian, translits[0]))
    else:
      manual_translits = []
      for translit in translits:
        if translit:
          manual_translits.append(translit)
        else:
          translit = xlit_text(russian, pagemsg, verbose)
          if not translit:
            pagemsg("WARNING: Error generating translit for %s" % russian)
          else:
            manual_translits.append(translit)
      joined_manual_translits = ", ".join(manual_translits)
      pagemsg("NOTE: For Russian %s, found multiple manual translits %s" %
          (russian, joined_manual_translits))
      formvals.append((russian, joined_manual_translits))
  return formvals

def check_for_alt_yo_terms(text, pagemsg):
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tname = str(t.name)
    if tname in [u"ru-adj-alt-ё", u"ru-noun-alt-ё", u"ru-proper noun-alt-ё",
        u"ru-verb-alt-ё", u"ru-pos-alt-ё"]:
      pagemsg(u"Skipping alt-ё term")
      return True
  return False

def find_defns(text):
  return blib.find_defns(text, 'ru')

################################ Test code ##########################

num_failed = 0
num_succeeded = 0

def test(actual, expected_ru, expected_tr):
  global num_succeeded, num_failed
  if type(actual) is tuple:
    actual_ru, actual_tr = actual
  else:
    actual_ru = actual
    actual_tr = None
  if actual_ru == expected_ru and actual_tr == expected_tr:
    uniprint("(%s, %s) == (%s, %s): TEST SUCCEEDED." %
        (actual_ru, actual_tr, expected_ru, expected_tr))
    num_succeeded += 1
  else:
    uniprint("(%s, %s) != (%s, %s): TEST FAILED." %
        (actual_ru, actual_tr, expected_ru, expected_tr))
    num_failed += 1

def run_tests():
  global num_succeeded, num_failed
  num_succeeded = 0
  num_failed = 0

  test(make_unstressed(u"де́лать"), u"делать", None)
  test(make_unstressed(u"де́лать", decompose(u"délat")), u"делать", "delat")
  test(make_unstressed(u"де́ла́ть"), u"делать", None)
  test(make_unstressed(u"де́ла́ть", decompose(u"délát")), u"делать", "delat")
  test(make_unstressed(u"дёлать"), u"делать", None)
  test(make_unstressed(u"дёлать", decompose(u"djólat")), u"делать", "delat")
  test(make_unstressed(u"дйо́лать"), u"дйолать", None)
  test(make_unstressed(u"дйо́лать", decompose(u"djólat")), u"дйолать", "djolat")
  test(make_unstressed_once(u"де́лать"), u"делать", None)
  test(make_unstressed_once(u"де́лать", decompose(u"délat")), u"делать", "delat")
  test(make_unstressed_once(u"дела́ть"), u"делать", None)
  test(make_unstressed_once(u"дела́ть", decompose(u"delát")), u"делать", "delat")
  test(make_unstressed_once(u"де́ла́ть"), u"де́лать", None)
  test(make_unstressed_once(u"де́ла́ть", decompose(u"délát")), u"де́лать", decompose(u"délat"))
  test(make_unstressed_once(u"дёлать"), u"делать", None)
  test(make_unstressed_once(u"дёлать", decompose(u"djólat")), u"делать", "delat")
  test(make_unstressed_once(u"дйо́лать"), u"дйолать", None)
  test(make_unstressed_once(u"дйо́лать", decompose(u"djólat")), u"дйолать", "djolat")
  test(make_unstressed_once(u"ко́е-как"), u"ко́е-как", None)
  test(make_unstressed_once(u"ко́е-как", decompose(u"kóe-kak")), u"ко́е-как", decompose(u"kóe-kak"))
  test(make_unstressed_once_at_beginning(u"де́лать"), u"делать", None)
  test(make_unstressed_once_at_beginning(u"де́лать", decompose(u"délat")), u"делать", "delat")
  test(make_unstressed_once_at_beginning(u"дела́ть"), u"делать", None)
  test(make_unstressed_once_at_beginning(u"дела́ть", decompose(u"delát")), u"делать", "delat")
  test(make_unstressed_once_at_beginning(u"де́ла́ть"), u"дела́ть", None)
  test(make_unstressed_once_at_beginning(u"де́ла́ть", decompose(u"délát")), u"дела́ть", decompose(u"delát"))
  test(make_unstressed_once_at_beginning(u"дёлать"), u"делать", None)
  test(make_unstressed_once_at_beginning(u"дёлать", decompose(u"djólat")), u"делать", "delat")
  test(make_unstressed_once_at_beginning(u"дйо́лать"), u"дйолать", None)
  test(make_unstressed_once_at_beginning(u"дйо́лать", decompose(u"djólat")), u"дйолать", "djolat")
  test(make_ending_stressed(u"де́лать"), u"дела́ть", None)
  test(make_ending_stressed(u"де́лать", decompose(u"délat")), u"дела́ть", decompose(u"delát"))
  test(make_ending_stressed(u"де́ла́ть"), u"де́ла́ть", None)
  test(make_ending_stressed(u"де́ла́ть", decompose(u"délát")), u"де́ла́ть", decompose(u"délát"))
  test(make_ending_stressed(u"да̀ла́лать"), u"да̀лала́ть", None)
  test(make_ending_stressed(u"да̀ла́лать", decompose(u"dàlálat")), u"да̀лала́ть", decompose(u"dàlalát"))
  test(make_ending_stressed(u"ко́е-как"), u"ко́е-ка́к", None)
  test(make_ending_stressed(u"ко́е-как", decompose(u"kóe-kak")), u"ко́е-ка́к", decompose(u"kóe-kák"))
  test(make_beginning_stressed(u"дела́ть"), u"де́лать", None)
  test(make_beginning_stressed(u"дела́ть", decompose(u"delát")), u"де́лать", decompose(u"délat"))
  test(make_beginning_stressed(u"де́ла́ть"), u"де́ла́ть", None)
  test(make_beginning_stressed(u"де́ла́ть", decompose(u"délát")), u"де́ла́ть", decompose(u"délát"))
  test(make_beginning_stressed(u"да̀ла́ть"), u"да́лать", None)
  test(make_beginning_stressed(u"да̀ла́ть", decompose(u"dàlát")), u"да́лать", decompose(u"dálat"))

  # Final results
  uniprint("RESULTS: %s SUCCEEDED, %s FAILED." % (num_succeeded, num_failed))

if __name__ == "__main__":
    run_tests()
