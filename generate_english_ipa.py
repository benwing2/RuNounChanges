#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site

cmu_pronun_mapping = {
  # consonants
  "B": "b",
  "CH": u"tʃ",
  "D": "d",
  "DH": u"ð",
  "F": "f",
  "G": u"ɡ",
  "HH": "h",
  "JH": u"dʒ",
  "K": "k",
  "L": "l",
  "M": "m",
  "N": "n",
  "NG": u"ŋ",
  "P": "p",
  "R": u"ɹ",
  "S": "s",
  "SH": u"ʃ",
  "T": "t",
  "TH": u"θ",
  "V": "v",
  "W": "w",
  "Y": "j",
  "Z": "z",
  "ZH": u"ʒ",
  # vowels
  "AA": u"ɑ",
  "AE": u"æ",
  "AH0": u"ə",
  "AH1": u"ʌ",
  "AH2": u"ʌ",
  "AO": u"ɔ",
  "AW": u"aʊ",
  "AY": u"aɪ",
  "EH": u"ɛ",
  "ER0": u"ɚ",
  "ER1": u"ɝ",
  "ER2": u"ɝ",
  "EY": u"eɪ",
  "IH": u"ɪ",
  "IY": "i",
  "OW": u"oʊ",
  "OY": u"ɔɪ",
  "UH": u"ʊ",
  "UW": "u"
}

moby_pronun_mapping = {
  # consonants
  "b": "b",
  "/tS/": u"tʃ",
  "d": "d",
  "/D/": u"ð",
  "f": "f",
  "g": u"ɡ",
  "h": "h",
  "/dZ/": u"dʒ",
  "k": "k",
  "l": "l",
  "m": "m",
  "n": "n",
  "/N/": u"ŋ",
  "p": "p",
  "r": u"ɹ",
  "s": "s",
  "/S/": u"ʃ",
  "t": "t",
  "/T/": u"θ",
  "v": "v",
  "w": "w",
  "/hw/": "hw",
  "/j/": "j",
  "z": "z",
  "/Z/": u"ʒ",
  # vowels
  "/A/": u"ɑ",
  "/&/": u"æ",
  "/@/": u"ə",
  "/(@)/": u"e", # always before r, e.g. Mary, Aaron
  "/O/": u"ɔ",
  "/AU/": u"aʊ",
  "/aI/": u"aɪ",
  "/E/": u"ɛ",
  "/[@]/r": u"ɝ",
  "/[@]/R": u"ɝ",
  "/[@]/": u"ɜ",
  "/eI/": u"eɪ",
  "/I/": u"ɪ",
  "/i/": "i",
  "/oU/": u"oʊ",
  "//Oi//": u"ɔɪ",
  "/U/": u"ʊ",
  "/u/": "u",
  "/-/n": u"n̩",
  "/-/l": u"l̩",
  "/-/r": u"ᵊɹ",
  "'": u"ˈ",
  ",": u"ˌ",
  "_": u" ",
  # foreign phonemes
  "/x/": "X",
  "/y/": u"Œ",
  "A": "A",
  "R": "R",
  "N": "N",
  "Zh": u"ʒ",
}

max_moby_length = max([len(x) for x in moby_pronun_mapping.iterkeys()])

# Onsets used for syllabification. This is not the full set of possible
# onsets but omits uncommon ones that occur primarily in foreign words or
# in small numbers of learned words (e.g. 'sphere', 'phthalene').
possible_onsets = set([
  "b", "bj", "bl", u"bɹ",
  "d", "dj", u"dɹ", "dw",
  u"dʒ",
  "f", "fj", "fl", u"fɹ",
  "h", "hj", "hw",
  "j",
  "k", "kj", "kl", u"kɹ", "kw",
  "l",
  "m", "mj",
  "n",
  "p", "pj", "pl", u"pɹ",
  u"ɹ",
  "s", "sj", "sk", "skj", "skl", u"skɹ", "skw", "sl", "sm", "sn",
  "sp", "spj", "spl", u"spɹ", "st", "stj", u"stɹ", "sw",
  "t", "tj", u"tɹ", "tw", u"tʃ",
  "v", "vj", u"vɹ", # arguable whether we should include vɹ
  "w",
  "z",
  u"ð", u"ðj",
  u"ɡ", u"ɡj", u"ɡl", u"ɡɹ", u"ɡw",
  u"ʃ", u"ʃɹ",
  u"ʒ",
  u"θ", u"θj", u"θɹ", u"θw"
])

seen_onsets = set()
vocalized_diacritic = u"\u0329"
vowel = u"aeiouɑæɛɪɔʊʌəɜɚɝ" + vocalized_diacritic
vowel_c = "[" + vowel + "]"
consonant = u"bdfɡhjklmnpɹstvwzʃʒθðŋ"
consonant_c = "[" + consonant + "]"
accent = u"ˈˌ"
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
      ipa_sounds.append(u"ˈ")
    if accent == "2":
      ipa_sounds.append(u"ˌ")
    ipa_sounds.append(ipa)
  ipa_word = "".join(ipa_sounds)
  # ɚ before vowel -> əɹ
  ipa_word = rsub_repeatedly(u"ɚ(" + accent_c + "?" + vowel_c + ")", r"əɹ\1",
      ipa_word)
  # ɚ after vowel -> əɹ
  ipa_word = rsub_repeatedly("(" + vowel_c + u")ɚ", r"\1əɹ",
      ipa_word)
  # ɝ before vowel -> ɜɹ
  ipa_word = rsub_repeatedly(u"ɝ(" + accent_c + "?" + vowel_c + ")", r"ɜɹ\1",
      ipa_word)
  # əl after consonant not before vowel -> l̩
  ipa_word = rsub_repeatedly("(" + consonant_c + u")əl($|" + consonant_c + ")",
      r"\1l̩\2", ipa_word)
  # ən after alveolar and not before vowel -> n̩
  ipa_word = rsub_repeatedly(u"([tdszln])ən($|" + consonant_c + ")", r"\1n̩\2",
      ipa_word)
  # Move stress before any initial consonant cluster
  ipa_word = re.sub("^(" + consonant_c + u"+)(" + accent_c + ")", r"\2\1",
    ipa_word)
  # In the middle of a word, move stress before possible onsets as listed above
  def move_before_onset(m):
    v, c, accent = m.groups()
    for i in range(len(c)):
      if c[i:] in possible_onsets:
        return v + c[0:i] + accent + c[i:]
    return v + c + accent
  ipa_word = re.sub("(" + vowel_c + ")(" + consonant_c + u"+)(" + accent_c + ")",
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
