#!/usr/bin/env python
#coding: utf-8

import re, sys

AC = u"\u0301"
vowel = u"аеиоуіїяєюАЕИОУІЇЯЄЮ"
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
uppercase = u"АЕИОУІЇЯЄЮБЦДФГҐЧЙКЛМНПРСТВШХЗЖЬЩ"
uppercase_c = "[" + uppercase + "]"

def remove_accents(word):
  return word.replace(AC, "")

def is_unstressed(word):
  return AC not in word

def is_stressed(word):
  return AC in word

def is_multi_stressed(word):
  num_stresses = sum(1 if x == AC else 0 for x in word)
  return num_stresses > 1

def is_monosyllabic(word):
  return len(re.sub(non_vowel_c, "", word)) <= 1

def add_monosyllabic_stress(word):
  if is_monosyllabic(word) and not is_stressed(word):
    return re.sub("(" + vowel_c + ")", r"\1" + AC, word)
  else:
    return word

def needs_accent(word):
  return not is_monosyllabic(word) and is_unstressed(word)

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

def reduce(word):
  m = re.search(u"^(.*)([оОеЕєЄіІ])́?(" + cons_c + "+)$", word)
  if not m:
    return None
  pre, letter, post = m.groups()
  if letter in [u"о", u"О"]:
    # FIXME, what about when the accent is on the removed letter?
    if post in [u"й", u"Й"]:
      # FIXME, is this correct?
      return None
    letter = ""
  else:
    is_upper = re.search(uppercase_c, post)
    if letter in [u"є", u"Є"]:
      # англі́єц -> англі́йц-
      letter = is_upper and u"Й" or u"й"
    elif post in [u"й", u"Й"]:
      # солове́й -> солов'-
      letter = "'"
      post = ""
    elif ((re.search(velar_c + "$", post) and re.search(cons_except_hushing_or_ts_c + "$", pre)) or
      (re.search(u"[^йЙ" + velar + "]$", post) and re.search(u"[лЛ]$", pre))):
      # FIXME, is this correct? This logic comes from ru-common.lua. The second clause that
      # adds ь after л is needed but I'm not sure about the first one.
      letter = is_upper and u"Ь" or u"ь"
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
  if re.search(velar_c, letter) or re.search(velar_c, post) or re.search(u"[вВ]", post):
    epvowel = is_upper and u"О" or u"о"
  elif re.search(u"['ьЬ]", post):
    # сім'я́ -> gen pl сіме́й
    # ескадри́лья -> gen pl ескадри́лей
    epvowel = re.search(uppercase_c, letter) and u"Е" or u"е"
    post = ""
  elif re.search(u"[йЙ]", letter):
    # яйце́ -> gen pl я́єць
    epvowel = is_upper and u"Є" or u"є"
    letter = ""
  else:
    if re.search(u"[ьЬ]", letter):
      # кільце́ -> gen pl кі́лець
      letter = ""
    epvowel = is_upper and u"Е" or u"е"
  if epenthetic_stress:
    epvowel = epvowel + AC
  return pre + letter + epvowel + post
