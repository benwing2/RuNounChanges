#!/usr/bin/python
# -*- coding: utf-8 -*-

import re

AC = u"\u0301" # acute =  ́
GR = u"\u0300" # grave =  ̀
CFLEX = u"\u0302" # circumflex =  ̂
DOTABOVE = u"\u0307" # dot above =  ̇
DI = u"\u0308" # diaeresis =  ̈
DUBGR = u"\u030F" # double grave =  ̏

composed_grave_vowel = u"ѐЀѝЍ"
vowel_no_jo = u"аеиоуяэыюіѣѵАЕИОУЯЭЫЮІѢѴ" + composed_grave_vowel #omit ёЁ
vowel = vowel_no_jo + u"ёЁ"
cons_except_sib_c = u"бдфгйклмнпрствхзьъБДФГЙКЛМНПРСТВХЗЬЪ"
sib = u"шщчжШЩЧЖ"
sib_c = sib + u"цЦ"
cons = cons_except_sib_c + sib_c
velar = u"кгхКГХ"
uppercase = u"АЕИОУЯЭЫЁЮІѢѴБДФГЙКЛМНПРСТВХЗЬЪШЩЧЖЦ"

# Does a word of set of connected text need accents? We need to split by word
# and check each one.
def needs_accents(text):
  def word_needs_accents(word):
    # A word needs accents if it is unstressed and contains more than one vowel
    return is_unstressed(word) and not is_monosyllabic(word)
  words = re.split(r"\s", text)
  for word in words:
    if word_needs_accents(word):
      return True
  return False

def is_stressed(word):
  # A word that has ё in it is inherently stressed.
  # diaeresis occurs in сѣ̈дла plural of сѣдло́
  return re.search(u"[́̈ёЁ]", word)

def is_unstressed(word):
  return not is_stressed(word)

def is_ending_stressed(word):
  return (re.search(u"[ёЁ][^" + vowel + "]*$", word) or
    re.search("[" + vowel + u"][́̈][^" + vowel + "]*$", word))

# True if a word has two or more stresses
def is_multi_stressed(word):
  word = re.sub(u"[ёЁ]", u"е́", word)
  return re.search("[" + vowel + u"][́̈].*[" + vowel + u"][́̈]", word)

def is_beginning_stressed(word):
  return (re.search("^[^" + vowel + u"]*[ёЁ]", word) or
    re.search("^[^" + vowel + "]*[" + vowel + u"]́", word))

def is_nonsyllabic(word):
  return not re.search("[" + vowel + "]", word)

# Includes non-syllabic stems such as льд-
def is_monosyllabic(word):
  return not re.search("[" + vowel + "].*[" + vowel + "]", word)

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

def remove_accents(word):
  # remove acute, grave and diaeresis (but not affecting composed ёЁ)
    return re.sub(u"([̀́̈ѐЀѝЍ])", lambda m: deaccenter[m.group(1)], word)

def remove_monosyllabic_accents(word):
  # note: This doesn't affect ё or Ё, provided that the word is
  # precomposed (which it normally is, as this is done automatically by
  # MediaWiki upon saving)
  if is_monosyllabic(word):
    return remove_accents(word)
  else:
    return word

destresser = deaccenter.copy()
destresser[u"ё"] = u"е"
destresser[u"Ё"] = u"Е"

def make_unstressed(word):
  return re.sub(u"([̀́̈ёЁѐЀѝЍ])", lambda m: destresser[m.group(1)], word)

def remove_jo(word):
  return re.sub(u"([ёЁ])", lambda m: destresser[m.group(1)], word)

def make_unstressed_once(word):
  # leave graves alone
  return re.sub(u"([́̈ёЁ])([^́̈ёЁ]*)$", lambda m: destresser[m.group(1)] + m.group(2), word, 1)

def make_unstressed_once_at_beginning(word):
  # leave graves alone
  return re.sub(u"^([^́̈ёЁ]*)([́̈ёЁ])", lambda m: m.group(1) + destresser[m.group(2)], word, 1)

def correct_grave_acute_clash(word):
  word = re.sub(u"([̀ѐЀѝЍ])́", lambda m: grave_deaccenter[m.group(1)] + AC, word)
  return re.sub(AC + GR, AC, word)

def make_ending_stressed(word):
  # If already ending stressed, just return word so we don't mess up ё
  if is_ending_stressed(word):
    return word
  word = make_unstressed_once(word)
  word = re.sub("([" + vowel_no_jo + "])([^" + vowel + "]*)$", ur"\1́\2", word)
  return correct_grave_acute_clash(word)

def make_beginning_stressed(word):
  # If already beginning stressed, just return word so we don't mess up ё
  if is_beginning_stressed(word):
    return word
  word = make_unstressed_once_at_beginning(word)
  word = re.sub("^([^" + vowel + "]*)([" + vowel_no_jo + "])", ur"\1\2́", word)
  return correct_grave_acute_clash(word)

def try_to_stress(word):
  if is_unstressed(word) and is_monosyllabic(word):
    return make_ending_stressed(word)
  else:
    return word

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

def split_generate_args(tempresult):
  args = {}
  for arg in re.split(r"\|", tempresult):
    name, value = re.split("=", arg)
    args[name] = re.sub("<!>", "|", value)
  return args

