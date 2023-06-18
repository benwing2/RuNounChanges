#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, sys

AC = "\u0301"
GR = "\u0300" # grave =  ̀

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

composed_grave_vowel = "ѐЀѝЍ"
vowel = "аеиоуіїяєюАЕИОУІЇЯЄЮ" + composed_grave_vowel
vowel_c = "[" + vowel + "]"
non_vowel_c = "[^" + vowel + "]"
cons_except_hushing_or_ts = "бдфгґйклмнпрствхзь'БДФГҐЙКЛМНПРСТВХЗЬ"
cons_except_hushing_or_ts_c = "[" + cons_except_hushing_or_ts + "]"
hushing = "чшжщЧШЖЩ"
hushing_c = "[" + hushing + "]"
hushing_or_ts = hushing + "цЦ"
hushing_or_ts_c = "[" + hushing_or_ts + "]"
cons = cons_except_hushing_or_ts + hushing_or_ts
cons_c = "[" + cons + "]"
# Cyrillic velar consonants
velar = "кгґхКГҐХ"
velar_c = "[" + velar + "]"
# uppercase Cyrillic consonants
uppercase = "АЕИОУІЇЯЄЮБЦДФГҐЧЙКЛМНПРСТВШХЗЖЬЩ"
uppercase_c = "[" + uppercase + "]"

grave_deaccenter = {
    GR:"", # grave accent
    "ѐ":"е", # composed Cyrillic chars w/grave accent
    "Ѐ":"Е",
    "ѝ":"и",
    "Ѝ":"И",
}

deaccenter = grave_deaccenter.copy()
deaccenter[AC] = "" # acute accent

def remove_grave_accents(word):
  # remove grave accents
  return re.sub("([" + GR + "ѐЀѝЍ])", lambda m: grave_deaccenter[m.group(1)], word)

def remove_accents(word):
  # remove pronunciation accents
  return re.sub("([" + pron_accents + "ѐЀѝЍ])",
    lambda m: deaccenter[m.group(1)], word)

def remove_non_primary_accents(word):
  # remove all pronunciation accents except acute
  return re.sub("([" + non_primary_pron_accents + "ѐЀѝЍ])",
    lambda m: deaccenter[m.group(1)], word)

def is_unstressed(word):
  return AC not in word

def is_stressed(word):
  return AC in word

def is_accented(word):
  return AC in word

def is_multi_stressed(word):
  num_stresses = sum(1 if x == AC else 0 for x in word)
  return num_stresses > 1

def is_nonsyllabic(word):
  return len(re.sub(non_vowel_c, "", word)) == 0

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

def iotate(stem):
  stem = re.sub("с[кт]$", "щ", stem)
  stem = re.sub("з[дгґ]$", "ждж", stem)
  stem = re.sub("к?т$", "ч", stem)
  stem = re.sub("зк$", "жч", stem)
  stem = re.sub("[кц]$", "ч", stem)
  stem = re.sub("[сх]$", "ш", stem)
  stem = re.sub("[гз]$", "ж", stem)
  stem = re.sub("д$", "дж", stem)
  stem = re.sub("([бвмпф])$", r"\1л", stem)
  return stem

def reduce(word):
  m = re.search("^(.*)([оОеЕєЄіІ])́?(" + cons_c + "+)$", word)
  if not m:
    return None
  pre, letter, post = m.groups()
  if letter in ["о", "О"]:
    # FIXME, what about when the accent is on the removed letter?
    if post in ["й", "Й"]:
      # FIXME, is this correct?
      return None
    letter = ""
  else:
    is_upper = re.search(uppercase_c, post)
    if letter in ["є", "Є"]:
      # англі́єц -> англі́йц-
      letter = is_upper and "Й" or "й"
    elif post in ["й", "Й"]:
      # солове́й -> солов'-
      letter = "'"
      post = ""
    elif ((re.search(velar_c + "$", post) and re.search(cons_except_hushing_or_ts_c + "$", pre)) or
      (re.search("[^йЙ" + velar + "]$", post) and re.search("[лЛ]$", pre))):
      # FIXME, is this correct? This logic comes from ru-common.lua. The second clause that
      # adds ь after л is needed but I'm not sure about the first one.
      letter = is_upper and "Ь" or "ь"
    else:
      letter = ""
  return pre + letter + post


def dereduce(stem, epenthetic_stress):
  if epenthetic_stress:
    stem = remove_accents(stem)
  # We don't require there to be two consonants at the end because of ону́ка (gen pl ону́ок).
  m = re.search("^(.*)(.)(" + cons_c + ")$", stem)
  if not m:
    return None
  pre, letter, post = m.groups()
  is_upper = re.search(uppercase_c, post)
  if re.search(velar_c, letter) or re.search(velar_c, post) or re.search("[вВ]", post):
    epvowel = is_upper and "О" or "о"
  elif re.search("['ьЬ]", post):
    # сім'я́ -> gen pl сіме́й
    # ескадри́лья -> gen pl ескадри́лей
    epvowel = re.search(uppercase_c, letter) and "Е" or "е"
    post = ""
  elif re.search("[йЙ]", letter):
    # яйце́ -> gen pl я́єць
    epvowel = is_upper and "Є" or "є"
    letter = ""
  else:
    if re.search("[ьЬ]", letter):
      # кільце́ -> gen pl кі́лець
      letter = ""
    epvowel = is_upper and "Е" or "е"
  if epenthetic_stress:
    epvowel = epvowel + AC
  return pre + letter + epvowel + post
