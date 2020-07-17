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
cons_except_hushing_or_ts = u"бдфгґйклмнпрствхзўь'БДФГҐЙКЛМНПРСТВХЗЎЬ"
cons_except_hushing_or_ts_c = "[" + cons_except_hushing_or_ts + "]"
hushing = u"чшжщЧШЖЩ"
hushing_c = "[" + hushing + "]"
hushing_or_ts = hushing + u"цЦ"
hushing_or_ts_c = "[" + hushing_or_ts + "]"
cons = cons_except_hushing_or_ts + hushing_or_ts
always_hard = u"чшжрЧШЖР"
cons_c = "[" + cons + "]"
# Cyrillic velar consonants
velar = u"кгґхКГҐХ"
velar_c = "[" + velar + "]"
# uppercase Cyrillic letters
uppercase = u"АЕІОУЁЭЫЯЮБЦДФГҐЧЙКЛМНПРСТВШХЗЖЬЩЎ"
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
  return not not re.search(u"[ё" + AC + "]" + non_vowel_c + "*$", word)

def is_mixed_stressed(word, possible_endings=[]):
  return is_multi_stressed(word) and is_end_stressed(word, possible_endings)

def reduce(word):
  m = re.search(u"^(.*)([оОёЁаАэЭеЕ])́?(" + cons_c + "+)$", word)
  if not m:
    return None
  pre, letter, post = m.groups()
  if letter in [u"о", u"О", u"а", u"А", u"э", u"Э"]:
    # FIXME, what about when the accent is on the removed letter?
    if post in [u"й", u"Й"]:
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
      letter = is_upper and u"Й" or u"й"
    elif post in [u"й", u"Й"]:
      if letter in u"вВ":
        # салаве́й -> салаў-
        letter = ""
      elif letter in u"бБпПфФмМ":
        # верабе́й -> вераб'-
        letter = "'"
      elif is_upper:
        letter = pre
      else:
        # вуле́й -> вулл-
        letter = pre.lower()
      post = ""
    elif ((re.search(velar_c + "$", post) and re.search(cons_except_hushing_or_ts_c + "$", pre)) or
      (re.search(u"[^йЙ" + velar + "]$", post) and re.search(u"[лЛ]$", pre))):
      # For the first part: князёк -> князьк-
      # For the second part: алёс -> альс-, відэ́лец -> відэ́льц-
      # Both at once: матылёк -> матыльк-
      letter = is_upper and u"Ь" or u"ь"
    else:
      # пёс -> пс-
      # асёл -> асл-, бу́сел -> бу́сл-
      # бабёр -> бабр-, шва́гер -> шва́гр-
      # італья́нец -> італья́нц-
      letter = ""
    # адзёр -> адр-
    # ірла́ндзец -> ірла́ндц-
    pre = re.sub(u"([Дд])з$", r"\1", pre)
    # кацёл -> катл-, ве́цер -> ве́тр-
    pre = re.sub(u"ц$", u"т", pre)
    pre = re.sub(u"Ц$", u"Т", pre)
  # ало́вак -> ало́ўк-, авёс -> аўс-, чо́вен -> чо́ўн-, ядло́вец -> ядло́ўц-
  # NOTE: любо́ў -> любв- but we need to handle this elsewhere as it also applies
  # to non-reduced nouns, e.g. во́страў -> во́страв-
  pre = re.sub(u"в$", u"ў", pre)
  pre = re.sub(u"В$", u"Ў", pre)
  return pre + letter + post

def dereduce(stem, epenthetic_stress):
  if epenthetic_stress:
    stem = remove_accents(stem)
  m = re.search("^(.*)(" + cons_c + ")(" + cons_c + ")$", stem)
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
  elif letter in cons_except_hushing_or_ts and post in velar or letter in velar:
    if epenthetic_stress:
      epvowel = is_upper and u"О́" or u"о́"
    else:
      epvowel = is_upper and u"А" or u"а"
  elif post in u"цЦ":
    if letter in always_hard:
      if epenthetic_stress:
        # FIXME, is this right?
        epvowel = is_upper and u"Э" or u"э"
      else:
        epvowel = is_upper and u"А" or u"а"
    else:
      epvowel = is_upper and u"Е" or u"е"
  elif epenthetic_stress:
    if letter in always_hard:
      epvowel = is_upper and u"О́" or u"о́"
    else:
      epvowel = is_upper and u"Ё" or u"ё"
  elif letter in always_hard:
    epvowel = is_upper and u"А" or u"а"
  else:
    epvowel = is_upper and u"Е" or u"е"
  if epenthetic_stress:
    if not is_stressed(epvowel):
      epvowel += AC
  if letter == u"ў":
    letter = u"в"
  elif letter == u"Ў":
    letter = u"В"
  stem = pre + letter + epvowel + post
  return stem
