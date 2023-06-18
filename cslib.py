#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, sys

TEMP_CH = "\uFFF0" # used to substitute ch temporarily in the default-reducible code
TEMP_OU = "\uFFF1" # used to substitute ou temporarily in is_monosyllabic()

lc_vowel = "aeiouyáéíóúýěů" + TEMP_OU
uc_vowel = lc_vowel.upper()
vowel = lc_vowel + uc_vowel
vowel_c = "[" + vowel + "]"
non_vowel_c = "[^" + vowel + "]"
# Consonants that can never form a syllabic nucleus.
lc_non_syllabic_cons = "bcdfghjkmnpqstvwxzčňšžďť" + TEMP_CH
uc_non_syllabic_cons = lc_non_syllabic_cons.upper()
non_syllabic_cons = lc_non_syllabic_cons + uc_non_syllabic_cons
non_syllabic_cons_c = "[" + non_syllabic_cons + "]"
lc_syllabic_cons = "lrř"
uc_syllabic_cons = lc_syllabic_cons.upper()
lc_cons = "bcdfghjklmnpqrstvwxzčňřšžďť" + TEMP_CH
lc_cons = lc_non_syllabic_cons + lc_syllabic_cons
uc_cons = lc_cons.upper()
cons = lc_cons + uc_cons
cons_c = "[" + cons + "]"
# lowercase consonants
lowercase = lc_vowel + lc_cons
lowercase_c = "[" + lowercase + "]"
# uppercase consonants
uppercase = uc_vowel + uc_cons
uppercase_c = "[" + uppercase + "]"
lc_paired_palatal = "ňďť"
uc_paired_palatal = "ŇĎŤ"
paired_palatal = lc_paired_palatal + uc_paired_palatal
lc_paired_plain = "ndt"
uc_paired_plain = "NDT"
paired_plain = lc_paired_plain + uc_paired_plain
paired_palatal_to_plain = {
  "ň":"n",
  "Ň":"N",
  "ť":"t",
  "Ť":"T",
  "ď":"d",
  "Ď":"D",
}
paired_plain_to_palatal = {}
for k, v in paired_palatal_to_plain.items():
    paired_plain_to_palatal[v] = k
lc_velar = "kgh"
uc_velar = "KGH"
velar = lc_velar + uc_velar
velar_c = "[" + velar + "]"
lc_labial = "mpbfv"
uc_labial = "MPBFV"
labial = lc_labial + uc_labial
labial_c = "[" + labial + "]"


def iotate(stem):
  raise NotImplementedError
  #stem = re.sub("с[кт]$", "щ", stem)
  #stem = re.sub("з[дгґ]$", "ждж", stem)
  #stem = re.sub("к?т$", "ч", stem)
  #stem = re.sub("зк$", "жч", stem)
  #stem = re.sub("[кц]$", "ч", stem)
  #stem = re.sub("[сх]$", "ш", stem)
  #stem = re.sub("[гз]$", "ж", stem)
  #stem = re.sub("д$", "дж", stem)
  #stem = re.sub("([бвмпф])$", r"\1л", stem)
  #return stem


# Return true if `word` is monosyllabic. Beware of words like [[čtvrtek]], [[plný]] and [[třmen]], which aren't
# monosyllabic but have only one vowel, and contrariwise words like [[brouk]], which are monosyllabic but have
# two vowels.
def is_monosyllabic(word):
  word = word.replace("ou", TEMP_OU)
  # Convert all vowels to 'e'.
  word = re.sub(vowel_c, "e", word)
  # All consonants next to a vowel are non-syllabic; convert to 't'.
  word = re.sub(cons_c + "e", "te", word)
  word = re.sub("e" + cons_c, "et", word)
  # Convert all remaining non-syllabic consonants to 't'.
  word = re.sub(non_syllabic_cons_c, "t", word)
  # At this point, what remains is 't', 'e', or a syllabic consonant. Count the latter two types.
  word = word.replace("t", "")
  return len(word) <= 1


def apply_vowel_alternation(alt, stem):
  def apply_alt(m):
    pre, vowel, post = m.groups()
    if vowel == "í":
      if alt == "quant-ě":
        if re.search("[" + paired_plain + labial + "]$", pre):
          return pre + "ě" + post
        else:
          return pre + "e" + post
      else:
        return pre + "i" + post
    elif vowel == "ů":
      return pre + "o" + post
    elif vowel == "é":
      return pre + "e" + post
    else:
      return pre + "a" + post
  if alt == "quant" or alt == "quant-ě":
    # [[sníh]] "snow", gen sg. [[sněhu]]
    # [[míra]] "snow", gen sg. [[měr]]
    # [[hůl]] "cane", gen sg. [[hole]]
    # [[práce]] "work", ins sg. [[prací]]
    modstem = re.sub("(.)([íůáé])(" + cons_c + "*)$", apply_alt, stem)
    if modstem == stem:
      return None
  else:
    return stem
  return modstem


def reduce(word):
  m = re.search("^(.*)(" + cons_c + ")([eě])(" + cons_c + "+)$", word)
  if not m:
    return None
  pre, letter, vowel, post = m.groups()
  if vowel == "ě" and re.search("[" + paired_plain + "]", letter):
    letter = paired_plain_to_palatal[letter]
  return pre + letter + post


def dereduce(stem):
  m = re.search("^(.*)(" + cons_c + ")(" + cons_c + ")$", stem)
  if not m:
    return None
  pre, letter, post = m.groups()
  if re.search("[" + paired_palatal + "]", letter):
    letter = paired_palatal_to_plain[letter]
    epvowel = "ě"
  else:
    epvowel = "e"
  return pre + letter + epvowel + post


def convert_paired_plain_to_palatal(stem, ending):
  if ending and not re.search("^[ěií]", ending):
    return stem
  m = re.search("^(.*)([" + paired_plain + "])$", stem)
  if m:
    stembegin, lastchar = m.groups()
    return stembegin + paired_plain_to_palatal[lastchar]
  else:
    return stem


def convert_paired_palatal_to_plain(stem, ending):
  # For stems that alternate between n/t/d and ň/ť/ď, we always maintain the stem in the latter format and
  # convert to the corresponding plain as needed, with e -> ě (normally we always have 'ě' as the ending, but
  # the user may specify 'e').
  if ending and not rfind(ending, "^[eěií]"):
    return stem, ending
  m = re.search("^(.*)([" + paired_palatal + "])$", stem)
  if m:
    stembegin, lastchar = m.groups()
    if ending == "e":
      ending = re.sub("^e", "ě", ending)
    return stembegin + paired_palatal_to_plain[lastchar], ending
  else:
    return stem, ending
