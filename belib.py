#!/usr/bin/env python
#coding: utf-8

import re, sys

AC = u"\u0301"
GR = u"\u0300" # grave =  ̀

# non-primary accents (i.e. excluding acute) that indicate pronunciation
# (not counting diaeresis, which indicates a completely different vowel,
# and caron, which is used in translit as ě to indicate the yat vowel)
non_primary_pron_accents = GR
# accents that indicate pronunciation (not counting diaresis, which indicates
# a completely different vowel)
pron_accents = AC + non_primary_pron_accents
# all accents
accents = pron_accents
# accents indicating stress (primary or otherwise)
stress_accents = AC + GR

# regex for any optional accent(s)
opt_accent = "[" + accents + "]*"

composed_grave_vowel = u"ѐЀѝЍ"
vowel = u"аеіоуёэыяюАЕІОУЁЭЫЯЮ" + composed_grave_vowel
vowel_c = "[" + vowel + "]"
non_vowel_c = "[^" + vowel + "]"
cons_except_hushing_or_ts = u"бдфгґйклмнпрствхзь'БДФГҐЙКЛМНПРСТВХЗЬ"
cons_except_hushing_or_ts_c = "[" + cons_except_hushing_or_ts + "]"
hushing = u"чшжщЧШЖЩ"
hushing_c = "[" + hushing + "]"
hushing_or_ts = hushing + u"цЦ"
hushing_or_ts_c = "[" + hushing_or_ts + "]"
cons = cons_except_hushing_or_ts + hushing_or_ts
cons_c = "[" + cons + "]"
# Cyrillic velar consonants
velar = u"кгґхКГҐХ"
velar_c = "[" + velar + "]"
# uppercase Cyrillic consonants
uppercase = u"АЕІОУЁЭЫЯЮБЦДФГҐЧЙКЛМНПРСТВШХЗЖЬЩ"
uppercase_c = "[" + uppercase + "]"

grave_deaccenter = {
    GR:"", # grave accent
    u"ѐ":u"е", # composed Cyrillic chars w/grave accent
    u"Ѐ":u"Е",
    u"ѝ":u"и",
    u"Ѝ":u"И",
}

deaccenter = grave_deaccenter.copy()
deaccenter[AC] = "" # acute accent

def remove_accents(word):
  # remove pronunciation accents
  return re.sub("([" + pron_accents + u"ѐЀѝЍ])",
    lambda m: deaccenter[m.group(1)], word)

def remove_non_primary_accents(word):
  # remove all pronunciation accents except acute
  return re.sub("([" + non_primary_pron_accents + u"ѐЀѝЍ])",
    lambda m: deaccenter[m.group(1)], word)

def is_unstressed(word):
  return not is_stressed(word)

def is_stressed(word):
  return AC in word or u"ё" in word

def is_multi_stressed(word):
  num_stresses = sum(1 if x in [AC, u"ё"] else 0 for x in word)
  return num_stresses > 1

def is_monosyllabic(word):
  return len(re.sub(non_vowel_c, "", word)) <= 1

def add_monosyllabic_stress(word):
  if is_monosyllabic(word) and not is_stressed(word):
    return re.sub("(" + vowel_c + ")", r"\1" + AC, word)
  else:
    return word

def remove_monosyllabic_stress(word):
  if is_monosyllabic(word) and not word.startswith("-"):
    return remove_accents(word)
  return word

# Does a phrase of connected text need accents? We need to split by word
# and check each one.
def needs_accents(text, split_dash=False):
  # A word needs accents if it is unstressed and contains more than one vowel;
  # but if split_dash, allow cases like динь-динь with multiple monosyllabic
  # words separated by a hyphen. We don't just split on hyphens at top level
  # otherwise a word like Али-Баба́ will "need accents".
  def word_needs_accents(word):
    if not is_unstressed(word):
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

# Does a phrase of connected text need accents? We need to split by word
# and check each one.
def add_accent_to_o(text, split_dash=False):
  def add_accent_to_o_in_word(word):
    if not needs_accents(word):
      return word
    return word.replace(u"о", u"о́")
  words = re.split(r"([-\s])" if split_dash else r"(\s)", text)
  words = [add_accent_to_o_in_word(w) for w in words]
  return "".join(words)

def is_end_stressed(word, possible_endings=[]):
  for ending in possible_endings:
    if not re.search(vowel_c, ending):
      continue
    ending = remove_accents(ending)
    if not word.endswith(ending) and remove_accents(word).endswith(ending):
      return True
  return not not re.search(AC + non_vowel_c + "*$", word)

def is_mixed_stressed(word, possible_endings=[]):
  return is_multi_stressed(word) and is_end_stressed(word, possible_endings)
