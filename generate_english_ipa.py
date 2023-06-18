#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

cmu_pronun_mapping = {
  # consonants
  "B": "b",
  "CH": "tʃ",
  "D": "d",
  "DH": "ð",
  "F": "f",
  "G": "ɡ",
  "HH": "h",
  "JH": "dʒ",
  "K": "k",
  "L": "l",
  "M": "m",
  "N": "n",
  "NG": "ŋ",
  "P": "p",
  "R": "ɹ",
  "S": "s",
  "SH": "ʃ",
  "T": "t",
  "TH": "θ",
  "V": "v",
  "W": "w",
  "Y": "j",
  "Z": "z",
  "ZH": "ʒ",
  # vowels
  "AA": "ɑ",
  "AE": "æ",
  "AH0": "ə",
  "AH1": "ʌ",
  "AH2": "ʌ",
  "AO": "ɔ",
  "AW": "aʊ",
  "AY": "aɪ",
  "EH": "ɛ",
  "ER0": "ɚ",
  "ER1": "ɝ",
  "ER2": "ɝ",
  "EY": "eɪ",
  "IH": "ɪ",
  "IY": "i",
  "OW": "oʊ",
  "OY": "ɔɪ",
  "UH": "ʊ",
  "UW": "u"
}

moby_pronun_mapping = {
  # consonants
  "b": "b",
  "/tS/": "tʃ",
  "d": "d",
  "/D/": "ð",
  "f": "f",
  "g": "ɡ",
  "h": "h",
  "/dZ/": "dʒ",
  "k": "k",
  "l": "l",
  "m": "m",
  "n": "n",
  "/N/": "ŋ",
  "p": "p",
  "r": "ɹ",
  "s": "s",
  "/S/": "ʃ",
  "t": "t",
  "/T/": "θ",
  "v": "v",
  "w": "w",
  "/hw/": "hw",
  "/j/": "j",
  "z": "z",
  "/Z/": "ʒ",
  # vowels
  "/A/": "ɑ",
  "/&/": "æ",
  "/@/": "ə",
  "/(@)/": "e", # always before r, e.g. Mary, Aaron
  "/O/": "ɔ",
  "/AU/": "aʊ",
  "/aI/": "aɪ",
  "/E/": "ɛ",
  "/[@]/r": "ɝ",
  "/[@]/R": "ɝ",
  "/[@]/": "ɜ",
  "/eI/": "eɪ",
  "/I/": "ɪ",
  "/i/": "i",
  "/oU/": "oʊ",
  "//Oi//": "ɔɪ",
  "/U/": "ʊ",
  "/u/": "u",
  "/-/n": "n̩",
  "/-/l": "l̩",
  "/-/r": "ᵊɹ",
  "'": "ˈ",
  ",": "ˌ",
  "_": " ",
  # foreign phonemes
  "/x/": "X",
  "/y/": "Œ",
  "A": "A",
  "R": "R",
  "N": "N",
  "Zh": "ʒ",
}

max_moby_length = max([len(x) for x in moby_pronun_mapping.iterkeys()])

# Onsets used for syllabification. This is not the full set of possible
# onsets but omits uncommon ones that occur primarily in foreign words or
# in small numbers of learned words (e.g. 'sphere', 'phthalene').
possible_onsets = set([
  "b", "bj", "bl", "bɹ",
  "d", "dj", "dɹ", "dw",
  "dʒ",
  "f", "fj", "fl", "fɹ",
  "h", "hj", "hw",
  "j",
  "k", "kj", "kl", "kɹ", "kw",
  "l",
  "m", "mj",
  "n",
  "p", "pj", "pl", "pɹ",
  "ɹ",
  "s", "sj", "sk", "skj", "skl", "skɹ", "skw", "sl", "sm", "sn",
  "sp", "spj", "spl", "spɹ", "st", "stj", "stɹ", "sw",
  "t", "tj", "tɹ", "tw", "tʃ",
  "v", "vj", "vɹ", # arguable whether we should include vɹ
  "w",
  "z",
  "ð", "ðj",
  "ɡ", "ɡj", "ɡl", "ɡɹ", "ɡw",
  "ʃ", "ʃɹ",
  "ʒ",
  "θ", "θj", "θɹ", "θw"
])

seen_onsets = set()
vocalized_diacritic = "\u0329"
vowel = "aeiouɑæɛɪɔʊʌəɜɚɝ" + vocalized_diacritic
vowel_c = "[" + vowel + "]"
consonant = "bdfɡhjklmnpɹstvwzʃʒθðŋ"
consonant_c = "[" + consonant + "]"
accent = "ˈˌ"
accent_c = "[" + accent + "]"
vowel_or_accent_c = "[" + vowel + accent + "]"

def rsub_repeatedly(fr, to, text):
  while True:
    new_text = re.sub(fr, to, text)
    if new_text == text:
      return new_text
    text = new_text

def process_cmu_pronun(index, word, pronun):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, word, txt))
  phonemes = re.split(" ", pronun)
  ipa_sounds = []
  for phoneme_with_accent in phonemes:
    m = re.search("^([A-Z]+)([0-9]?)$", phoneme_with_accent)
    if not m:
      pagemsg("WARNING: Something wrong, bad phoneme_with_accent %s" % phoneme_with_accent)
      return None
    phoneme, accent = m.groups()
    if phoneme_with_accent in cmu_pronun_mapping:
      ipa = cmu_pronun_mapping[phoneme_with_accent]
    elif phoneme not in cmu_pronun_mapping:
      pagemsg("WARNING: Something wrong, unrecognized phoneme %s" % phoneme)
      return None
    else:
      ipa = cmu_pronun_mapping[phoneme]
    if accent == "1":
      ipa_sounds.append("ˈ")
    if accent == "2":
      ipa_sounds.append("ˌ")
    ipa_sounds.append(ipa)
  ipa_word = "".join(ipa_sounds)
  # ɚ before vowel -> əɹ
  ipa_word = rsub_repeatedly("ɚ(" + accent_c + "?" + vowel_c + ")", r"əɹ\1",
      ipa_word)
  # ɚ after vowel -> əɹ
  ipa_word = rsub_repeatedly("(" + vowel_c + ")ɚ", r"\1əɹ",
      ipa_word)
  # ɝ before vowel -> ɜɹ
  ipa_word = rsub_repeatedly("ɝ(" + accent_c + "?" + vowel_c + ")", r"ɜɹ\1",
      ipa_word)
  # əl after consonant not before vowel -> l̩
  ipa_word = rsub_repeatedly("(" + consonant_c + ")əl($|" + consonant_c + ")",
      r"\1l̩\2", ipa_word)
  # ən after alveolar and not before vowel -> n̩
  ipa_word = rsub_repeatedly("([tdszln])ən($|" + consonant_c + ")", r"\1n̩\2",
      ipa_word)
  # Move stress before any initial consonant cluster
  ipa_word = re.sub("^(" + consonant_c + "+)(" + accent_c + ")", r"\2\1",
    ipa_word)
  # In the middle of a word, move stress before possible onsets as listed above
  def move_before_onset(m):
    v, c, accent = m.groups()
    for i in range(len(c)):
      if c[i:] in possible_onsets:
        return v + c[0:i] + accent + c[i:]
    return v + c + accent
  ipa_word = re.sub("(" + vowel_c + ")(" + consonant_c + "+)(" + accent_c + ")",
      move_before_onset, ipa_word)
  m = re.search("^" + accent_c + "*(" + consonant_c + "*)", ipa_word)
  seen_onsets.add(m.group(1))
  return ipa_word

def process_moby_pronun(index, word, pronun):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, word, txt))
  phonemes = []
  i = 0
  wl = len(pronun)
  while i < wl:
    for l in range(min(max_moby_length, wl - i), 0, -1):
      nextphon = pronun[i:i+l]
      if nextphon in moby_pronun_mapping:
        phonemes.append(moby_pronun_mapping[nextphon])
        i += l
        break
    else:
      pagemsg("WARNING: Unrecognized phoneme %s" % pronun[i])
      i += 1
  ipa_word = "".join(phonemes)
  return ipa_word

def process_cmu_line(index, word, pronuns):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, word, txt))
  ipas = [process_cmu_pronun(index, word, pronun) for pronun in pronuns]
  pagemsg("Pronunciation: %s" % " | ".join(ipas))

def process_moby_line(index, word, pronun):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, word, txt))
  ipa = process_moby_pronun(index, word, pronun)
  pagemsg("Pronunciation: %s" % ipa)

parser = blib.create_argparser("Generate English IPA")
parser.add_argument('--cmu', help="File containing CMU pronouncing dictionary.")
parser.add_argument('--moby', help="File containing Moby Pronunciator.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.cmu:
  pagedirecs = []
  lines = [x.strip() for x in open(args.cmu, "r", encoding="iso8859-1") if not x.startswith(";;;")]
  joined_lines = []
  prev_word = None
  seen_pronuns = []
  for line in lines:
    word, pronun = re.split("  ", line)
    m = re.search(r"^(.*)\([0-9]+\)$", word)
    if m and m.group(1) == prev_word:
      seen_pronuns.append(pronun)
    else:
      if prev_word:
        joined_lines.append([prev_word, seen_pronuns])
      prev_word = word
      seen_pronuns = [pronun]
  if prev_word:
    joined_lines.append([prev_word, seen_pronuns])

  for i, line in blib.iter_items(joined_lines, start, end):
    word, pronuns = line
    process_cmu_line(i, word, pronuns)

  for i, onset in enumerate(list(sorted(seen_onsets))):
    msg("#%3s %s" % (i, onset))

if args.moby:
  lines = [x.strip() for x in open(args.moby, "r", encoding="mac_roman")]
  for i, line in blib.iter_items(lines, start, end):
    word, pronun = re.split(" ", line)
    process_moby_line(i, word, pronun)
