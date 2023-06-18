#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, sys

from blib import rsub_repeatedly

AC = "\u0301"
GR = "\u0300" # grave =  ̀
DOTBELOW = "\u0323" # dot below =  ̣

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
vowel = "аеіоуяэыёюАЕІОУЯЭЫЁЮ" + composed_grave_vowel
vowel_c = "[" + vowel + "]"
non_vowel_c = "[^" + vowel + "]"
# Cyrillic velar consonants
velar = "кгґхКГҐХ"
velar_c = "[" + velar + "]"
always_hard = "ршчжРШЧЖ"
always_hard_c = "[" + always_hard + "]"
always_hard_or_ts = always_hard + "цЦ"
always_hard_or_ts_c = "[" + always_hard_or_ts + "]"
cons_except_always_hard_or_ts = "бдфгґйклмнпствхзўьБДФГҐЙКЛМНПСТВХЗЎЬ'"
cons_except_always_hard_or_ts_c = "[" + cons_except_always_hard_or_ts + "]"
cons = always_hard + cons_except_always_hard_or_ts + "цЦ"
cons_c = "[" + cons + "]"
# uppercase Cyrillic letters
uppercase = "АЕІОУЁЭЫЯЮБЦДФГҐЧЙКЛМНПРСТВШХЗЖЬЩЎ"
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

destresser = deaccenter.copy()
destresser["ё"] = "е"
destresser["Ё"] = "Е"
destresser["о"] = "а"
destresser["О"] = "А"
destresser["э"] = "а"
destresser["Э"] = "А"

pre_tonic_destresser = destresser.copy()
pre_tonic_destresser["ё"] = "я"
pre_tonic_destresser["Ё"] = "Я"
pre_tonic_destresser["е"] = "я"
pre_tonic_destresser["Е"] = "Я"

ae_stresser = {
  "а": "э",
  "я": "е",
}

ao_stresser = {
  "а": "о",
  "я": "ё",
}

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
  return not is_stressed(word)

def is_stressed(word):
  return AC in word or "ё" in word

def is_multi_stressed(word):
  num_stresses = sum(1 if x in [AC, "ё"] else 0 for x in word)
  return num_stresses > 1

def has_grave_accents(word):
  return re.search("[̀ѐЀѝЍ]", word)

def is_accented(word):
  return AC in word

def is_multi_accented(word):
  num_accents = sum(1 if x == AC else 0 for x in word)
  return num_accents > 1

def is_nonsyllabic(word):
  return len(re.sub(non_vowel_c, "", word)) == 0

def is_monosyllabic(word):
  return len(re.sub(non_vowel_c, "", word)) <= 1

def add_monosyllabic_accent(word):
  if is_monosyllabic(word) and not is_accented(word):
    return re.sub("(" + vowel_c + ")", r"\1" + AC, word)
  else:
    return word

def add_monosyllabic_stress(word):
  if is_monosyllabic(word) and not is_stressed(word):
    return re.sub("(" + vowel_c + ")", r"\1" + AC, word)
  else:
    return word

def remove_monosyllabic_accents(word):
  if is_monosyllabic(word) and not word.startswith("-"):
    return remove_accents(word)
  return word

def iotate(stem):
  stem = re.sub("с[ктц]$", "шч", stem)
  stem = re.sub("[ктц]$", "ч", stem)
  stem = re.sub("[сх]$", "ш", stem)
  stem = re.sub("[гґз]$", "ж", stem)
  stem = re.sub("дз?$", "дж", stem)
  stem = re.sub("([бўмпф])$", r"\1л", stem)
  stem = re.sub("в$", "ўл", stem)
  return stem

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
    return word.replace("о", "о́")
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
  return not not re.search("[ё" + AC + "]" + non_vowel_c + "*$", word)

def is_end_accented(word, possible_endings=[]):
  for ending in possible_endings:
    if not re.search(vowel_c, ending):
      continue
    ending = remove_accents(ending)
    if not word.endswith(ending) and remove_accents(word).endswith(ending):
      return True
  return not not re.search(AC + non_vowel_c + "*$", word)

def is_mixed_accented(word, possible_endings=[]):
  return is_multi_accented(word) and is_end_accented(word, possible_endings)


# Apply a vowel_alternant specification ("ao", "ae" or nil) to the vowel directly
# preceding the stress.
def apply_vowel_alternation(word, vowel_alternant):
  if vowel_alternant == "ao":
    new_word = re.sub("([ая])(" + non_vowel_c + "*" + vowel_c + AC + ")",
      lambda m: ao_stresser[m.group(1)] + m.group(2), word
    )
    if new_word == word:
      return None
    return new_word
  elif vowel_alternant == "ae":
    new_word = re.sub("([ая])(" + non_vowel_c + "*" + vowel_c + AC + ")",
      lambda m: ae_stresser[m.group(1)] + m.group(2), word
    )
    if new_word == word:
      return None
    return new_word
  elif vowel_alternant:
    assert False, "Unrecognized vowel alternant '" + vowel_alternant + "'"
  else:
    return word


# Mark vowels that should only occur in stressed syllables (э, о, ё) but
# actually occur in unstressed syllables with a dot-below. Also mark е
# that occurs directly before the stress in this fashion, and add an acute
# accent to stressed ё. We determine whether an ё is stressed as follows:
# (1) If an acute accent already occurs, an ё isn't marked with an acute
#     accent (e.g. ра́дыё).
# (2) Otherwise, mark only the last ё with an acute, as multiple ё sounds
#     can occur (at least, in Russian this is the case, as in трёхколёсный).
def mark_stressed_vowels_in_unstressed_syllables(word, pagemsg):
  if is_nonsyllabic(word):
    return word
  if is_multi_stressed(word):
    pagemsg("WARNING: Word " + word + " has multiple accent marks")
  if has_grave_accents(word):
    pagemsg("WARNING: Word " + word + " has grave accents")
  word = add_monosyllabic_accent(word)
  if AC not in word:
    if re.search("[ёЁ]", word):
      word = re.sub("([ёЁ])(.*?)$", r"\1" + AC + r"\2", word)
    else:
      pagemsg("WARNING: Multisyllabic word " + word + "missing an accent")

  word = re.sub("([эоёЭОЁ])([^́]|$)", r"\1" + DOTBELOW + r"\2", word)
  word = re.sub("([еЕ])(" + non_vowel_c + "*" + vowel_c + AC + ")",
    r"\1" + DOTBELOW + r"\2", word)
  return word


# Undo extra diacritics added by `mark_stressed_vowels_in_unstressed_syllables`.
def undo_mark_stressed_vowels_in_unstressed_syllables(word):
  word = word.replace(DOTBELOW, "")
  word = re.sub("([ёЁ])́", r"\1", word)
  return word


# Destress vowels in unstressed syllables. Vowels followed by DOTBELOW are unchanged;
# otherwise, о -> а; э -> а; ё -> я directly before the stress, otherwise е;
# е -> я directly before the stress. After that, remove extra diacritics added by
# mark_stressed_vowels_in_unstressed_syllables().
def destress_vowels_after_stress_movement(word):
  word = rsub_repeatedly("([эоёЭОЁ])([^" + AC + DOTBELOW + "]|$)",
    lambda m: destresser[m.group(1)] + m.group(2), word
  )
  word = re.sub("([еЕ])(" + non_vowel_c + "*" + vowel_c + AC + ")",
    lambda m: (
      pre_tonic_destresser[m.group(1)]
      if not m.group(2).startswith(DOTBELOW) else m.group(1)
    ) + m.group(2),
    word)
  return undo_mark_stressed_vowels_in_unstressed_syllables(word)


# If word is lacking an accent, add it onto the initial syllable.
# This assumes the word has been processed by mark_stressed_vowels_in_unstressed_syllables(),
# so that even the ё vowel gets stress.
def maybe_accent_initial_syllable(word):
  if AC not in word:
    # accent first syllable
    word = re.sub("^(.*?" + vowel_c + ")", r"\1" + AC, word)
  return word


# If word is lacking an accent, add it onto the final syllable.
# This assumes the word has been processed by mark_stressed_vowels_in_unstressed_syllables(),
# so that even the ё vowel gets stress.
def maybe_accent_final_syllable(word):
  if AC not in word:
    # accent last syllable
    word = re.sub("(.*" + vowel_c + ")", r"\1" + AC, word)
  return word


def reduce(word):
  m = re.search("^(.+)([оОёЁаАэЭеЕ])́?(" + cons_c + "+)$", word)
  if not m:
    return None
  pre, letter, post = m.groups()
  if letter in "оОаАэЭ":
    # FIXME, what about when the accent is on the removed letter?
    if post in "йЙ":
      # FIXME, is this correct?
      return None
    # аўто́рак -> аўто́рк-, вы́нятак -> вы́нятк-, ло́жак -> ло́жк-
    # алжы́рац -> алжы́рц-
    # міні́стар -> міні́стр-
    letter = ""
  else:
    is_upper = re.search(uppercase_c, post)
    if re.search(vowel_c + AC + "?$", pre):
      # аўстралі́ец -> аўстралі́йц-
      # аўстры́ец -> аўстры́йц-
      # еўрапе́ец -> еўрапе́йц
      letter = is_upper and "Й" or "й"
    elif post in ["й", "Й"]:
      if re.search("[вВ]$", pre):
        # салаве́й -> салаў-
        letter = ""
      elif re.search("[бБпПфФмМ]$", pre):
        # верабе́й -> вераб'-
        letter = "'"
      elif is_upper:
        letter = pre[-1]
      else:
        # вуле́й -> вулл-
        letter = pre[-1].lower()
      post = ""
    elif ((re.search(velar_c + "$", post) and re.search(cons_except_always_hard_or_ts_c + "$", pre)) or
      (re.search("[^йЙ" + velar + "]$", post) and re.search("[лЛ]$", pre))):
      # For the first part: князёк -> князьк-
      # For the second part: алёс -> альс-, відэ́лец -> відэ́льц-
      # Both at once: матылёк -> матыльк-
      letter = is_upper and "Ь" or "ь"
    else:
      # пёс -> пс-
      # асёл -> асл-, бу́сел -> бу́сл-
      # бабёр -> бабр-, шва́гер -> шва́гр-
      # італья́нец -> італья́нц-
      letter = ""
    # адзёр -> адр-
    # ірла́ндзец -> ірла́ндц-
    pre = re.sub("([Дд])[Зз]$", r"\1", pre)
    # кацёл -> катл-, ве́цер -> ве́тр-
    pre = re.sub("ц$", "т", pre)
    pre = re.sub("Ц$", "Т", pre)
  # ало́вак -> ало́ўк-, авёс -> аўс-, чо́вен -> чо́ўн-, ядло́вец -> ядло́ўц-
  # NOTE: любо́ў -> любв- but we need to handle this elsewhere as it also applies
  # to non-reduced nouns, e.g. во́страў -> во́страв-
  pre = re.sub("в$", "ў", pre)
  pre = re.sub("В$", "Ў", pre)
  return pre + letter + post

def dereduce(stem, epenthetic_stress):
  if epenthetic_stress:
    stem = remove_accents(stem)
  m = re.search("^(.*)(" + cons_c + ")(" + cons_c + ")$", stem)
  if not m:
    return None
  pre, letter, post = m.groups()
  is_upper = post in uppercase
  if post == "'":
    # сям'я́ "family" -> сяме́й
    post = "й"
    epvowel = "е"
  elif letter in "ьйЬЙ":
    letter = ""
    if post in "цЦ" or not epenthetic_stress:
      epvowel = "е"
    else:
      epvowel = "ё"
  elif letter in cons_except_always_hard_or_ts and post in velar or letter in velar:
    if epenthetic_stress:
      epvowel = "о"
    else:
      epvowel = "а"
  elif post in "цЦ":
    if letter in always_hard:
      if epenthetic_stress:
        # FIXME, is this right?
        epvowel = "э"
      else:
        epvowel = "а"
    else:
      epvowel = "е"
  elif epenthetic_stress:
    if letter in always_hard:
      epvowel = "о"
    else:
      epvowel = "ё"
  elif letter in always_hard:
    epvowel = "а"
  else:
    epvowel = "е"
  if letter == "ў":
    letter = "в"
  elif letter == "Ў":
    letter = "В"
  if epvowel in "её":
    if letter == "т":
      letter = "ц"
    elif letter == "Т":
      letter = "Ц"
    elif letter == "д":
      letter = "дз"
    elif letter == "Д":
      letter = is_upper and "ДЗ" or "Дз"
  if is_upper:
    epvowel = epvowel.upper()
  if epenthetic_stress:
    epvowel += AC
  stem = pre + letter + epvowel + post
  return stem
