#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

pronun_mapping = {
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
    "UW": "u",
    }

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

def process_pronun(index, word, pronun):
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
    if phoneme_with_accent in pronun_mapping:
      ipa = pronun_mapping[phoneme_with_accent]
    elif phoneme not in pronun_mapping:
      pagemsg("WARNING: Something wrong, unrecognized phoneme %s" % phoneme)
      return None
    else:
      ipa = pronun_mapping[phoneme]
    if accent == "1":
      ipa_sounds.append(u"ˈ")
    if accent == "2":
      ipa_sounds.append(u"ˌ")
    ipa_sounds.append(ipa)
  ipa_word = "".join(ipa_sounds)
  # ɚ before vowel -> əɹ
  ipa_word = rsub_repeatedly(u"ɚ(" + accent_c + "?" + vowel_c + ")", ur"əɹ\1",
      ipa_word)
  # ɚ after vowel -> əɹ
  ipa_word = rsub_repeatedly("(" + vowel_c + u")ɚ", ur"\1əɹ",
      ipa_word)
  # ɝ before vowel -> ɜɹ
  ipa_word = rsub_repeatedly(u"ɝ(" + accent_c + "?" + vowel_c + ")", ur"ɜɹ\1",
      ipa_word)
  # əl after consonant not before vowel -> l̩
  ipa_word = rsub_repeatedly("(" + consonant_c + u")əl($|" + consonant_c + ")",
      ur"\1l̩\2", ipa_word)
  # ən after alveolar and not before vowel -> n̩
  ipa_word = rsub_repeatedly(u"([tdszln])ən($|" + consonant_c + ")", ur"\1n̩\2",
      ipa_word)
  # Move stress before any initial consonant cluster
  ipa_word = re.sub("^(" + consonant_c + u"+)(" + accent_c + ")", r"\2\1",
    ipa_word)
  # In the middle of a word, move stress before possible onsets as listed above
  def move_before_onset(m):
    v, c, accent = m.groups()
    for i in xrange(len(c)):
      if c[i:] in possible_onsets:
        return v + c[0:i] + accent + c[i:]
    return v + c + accent
  ipa_word = re.sub("(" + vowel_c + ")(" + consonant_c + u"+)(" + accent_c + ")",
      move_before_onset, ipa_word)
  m = re.search("^" + accent_c + "*(" + consonant_c + "*)", ipa_word)
  seen_onsets.add(m.group(1))
  return ipa_word

def process_line(index, word, pronuns):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, word, txt))
  ipas = [process_pronun(index, word, pronun) for pronun in pronuns]
  pagemsg("Pronunciation: %s" % " | ".join(ipas))

parser = blib.create_argparser("Generate English IPA")
parser.add_argument('--cmu', help="File containing CMU pronouncing dictionary.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

pagedirecs = []
lines = [x.strip() for x in codecs.open(args.cmu, "r", "iso8859-1") if not
    x.startswith(";;;")]
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
  process_line(i, word, pronuns)

for i, onset in enumerate(list(sorted(seen_onsets))):
  msg("#%3s %s" % (i, onset))
