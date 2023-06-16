#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re, sys

TEMP_CH = u"\uFFF0" # used to substitute ch temporarily in the default-reducible code
TEMP_OU = u"\uFFF1" # used to substitute ou temporarily in is_monosyllabic()

lc_vowel = u"aeiouyáéíóúýěů" + TEMP_OU
uc_vowel = lc_vowel.upper()
vowel = lc_vowel + uc_vowel
vowel_c = "[" + vowel + "]"
non_vowel_c = "[^" + vowel + "]"
# Consonants that can never form a syllabic nucleus.
lc_non_syllabic_cons = u"bcdfghjkmnpqstvwxzčňšžďť" + TEMP_CH
uc_non_syllabic_cons = lc_non_syllabic_cons.upper()
non_syllabic_cons = lc_non_syllabic_cons + uc_non_syllabic_cons
non_syllabic_cons_c = "[" + non_syllabic_cons + "]"
lc_syllabic_cons = u"lrř"
uc_syllabic_cons = lc_syllabic_cons.upper()
lc_cons = u"bcdfghjklmnpqrstvwxzčňřšžďť" + TEMP_CH
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
lc_paired_palatal = u"ňďť"
uc_paired_palatal = u"ŇĎŤ"
paired_palatal = lc_paired_palatal + uc_paired_palatal
lc_paired_plain = "ndt"
uc_paired_plain = "NDT"
paired_plain = lc_paired_plain + uc_paired_plain
paired_palatal_to_plain = {
  u"ň":"n",
  u"Ň":"N",
  u"ť":"t",
  u"Ť":"T",
  u"ď":"d",
  u"Ď":"D",
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
  #stem = re.sub(u"с[кт]$", u"щ", stem)
  #stem = re.sub(u"з[дгґ]$", u"ждж", stem)
  #stem = re.sub(u"к?т$", u"ч", stem)
  #stem = re.sub(u"зк$", u"жч", stem)
  #stem = re.sub(u"[кц]$", u"ч", stem)
  #stem = re.sub(u"[сх]$", u"ш", stem)
  #stem = re.sub(u"[гз]$", u"ж", stem)
  #stem = re.sub(u"д$", u"дж", stem)
  #stem = re.sub(u"([бвмпф])$", ur"\1л", stem)
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
    if vowel == u"í":
      if alt == u"quant-ě":
        if re.search("[" + paired_plain + labial + "]$", pre):
          return pre + u"ě" + post
        else:
          return pre + "e" + post
      else:
        return pre + "i" + post
    elif vowel == u"ů":
      return pre + "o" + post
    elif vowel == u"é":
      return pre + "e" + post
    else:
      return pre + "a" + post
  if alt == "quant" or alt == u"quant-ě":
    # [[sníh]] "snow", gen sg. [[sněhu]]
    # [[míra]] "snow", gen sg. [[měr]]
    # [[hůl]] "cane", gen sg. [[hole]]
    # [[práce]] "work", ins sg. [[prací]]
    modstem = re.sub(u"(.)([íůáé])(" + cons_c + "*)$", apply_alt, stem)
    if modstem == stem:
      return None
  else:
    return stem
  return modstem


def reduce(word):
  m = re.search(u"^(.*)(" + cons_c + u")([eě])(" + cons_c + "+)$", word)
  if not m:
    return None
  pre, letter, vowel, post = m.groups()
  if vowel == u"ě" and re.search("[" + paired_plain + "]", letter):
    letter = paired_plain_to_palatal[letter]
  return pre + letter + post


def dereduce(stem):
  m = re.search("^(.*)(" + cons_c + ")(" + cons_c + ")$", stem)
  if not m:
    return None
  pre, letter, post = m.groups()
  if re.search("[" + paired_palatal + "]", letter):
    letter = paired_palatal_to_plain[letter]
    epvowel = u"ě"
  else:
    epvowel = "e"
  return pre + letter + epvowel + post


def convert_paired_plain_to_palatal(stem, ending):
  if ending and not re.search(u"^[ěií]", ending):
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
  if ending and not rfind(ending, u"^[eěií]"):
    return stem, ending
  m = re.search("^(.*)([" + paired_palatal + "])$", stem)
  if m:
    stembegin, lastchar = m.groups()
    if ending == "e":
      ending = re.sub("^e", u"ě", ending)
    return stembegin + paired_palatal_to_plain[lastchar], ending
  else:
    return stem, ending
