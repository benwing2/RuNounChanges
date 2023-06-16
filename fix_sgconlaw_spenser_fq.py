#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Move text outside of {{RQ:Spenser FQ}} inside, with some renaming of templates and args. Specifically, we replace:
#
#* {{RQ:Spenser FQ|3|2|stanza=8}}
#*: of which great worth and '''worship''' may be won
#
# with:
#
#* {{RQ:Spenser Faerie Queene|book=III|canto=II|stanza=8|passage=of which great worth and '''worship''' may be won}}

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errmsg, site

arabic_to_roman_form = {
  "1":"I", "2":"II", "3":"III", "4":"IV", "5":"V",
  "6":"VI", "7":"VII", "8":"VIII", "9":"IX", "10":"X",
  "11":"XI", "12":"XII", "13":"XIII", "14":"XIV", "15":"XV",
  "16":"XVI", "17":"XVII", "18":"XVIII", "19":"XIX", "20":"XX",
  "21":"XXI", "22":"XXII", "23":"XXIII", "24":"XXIV", "25":"XXV",
  "26":"XXVI", "27":"XXVII", "28":"XXVIII", "29":"XXIX", "30":"XXX",
  "31":"XXXI", "32":"XXXII", "33":"XXXIII", "34":"XXXIV", "35":"XXXV",
  "36":"XXXVI", "37":"XXXVII", "38":"XXXVIII", "39":"XXXIX", "40":"XL",
  "41":"XLI", "42":"XLII", "43":"XLIII", "44":"XLIV", "45":"XLV",
  "46":"XLVI", "47":"XLVII", "48":"XLVIII", "49":"XLIX", "50":"L",
  "51":"LI", "52":"LII", "53":"LIII", "54":"LIV", "55":"LV",
  "56":"LVI", "57":"LVII", "58":"LVIII", "59":"LIX", "60":"LX",
  "61":"LXI", "62":"LXII", "63":"LXIII", "64":"LXIV", "65":"LXV",
  "66":"LXVI", "67":"LXVII", "68":"LXVIII", "69":"LXIX", "70":"LXX",
  "71":"LXXI", "72":"LXXII", "73":"LXXIII", "74":"LXXIV", "75":"LXXV",
  "76":"LXXVI", "77":"LXXVII", "78":"LXXVIII", "79":"LXXIX", "80":"LXXX",
  "81":"LXXXI", "82":"LXXXII", "83":"LXXXIII", "84":"LXXXIV", "85":"LXXXV",
  "86":"LXXXVI", "87":"LXXXVII", "88":"LXXXVIII", "89":"LXXXIX", "90":"XC",
  "91":"XCI", "92":"XCII", "93":"XCIII", "94":"XCIV", "95":"XCV",
  "96":"XCVI", "97":"XCVII", "98":"XCVIII", "99":"XCIX", "100":"C",
  "101":"CI", "102":"CII", "103":"CIII", "104":"CIV", "105":"CV",
  "106":"CVI", "107":"CVII", "108":"CVIII", "109":"CIX", "110":"CX",
  "111":"CXI", "112":"CXII", "113":"CXIII", "114":"CXIV", "115":"CXV",
  "116":"CXVI", "117":"CXVII", "118":"CXVIII", "119":"CXIX", "120":"CXX",
  "121":"CXXI", "122":"CXXII", "123":"CXXIII", "124":"CXXIV", "125":"CXXV",
  "126":"CXXVI", "127":"CXXVII", "128":"CXXVIII", "129":"CXXIX", "130":"CXXX",
  "131":"CXXXI", "132":"CXXXII", "133":"CXXXIII", "134":"CXXXIV", "135":"CXXXV",
  "136":"CXXXVI", "137":"CXXXVII", "138":"CXXXVIII", "139":"CXXXIX", "140":"CXL",
  "141":"CXLI", "142":"CXLII", "143":"CXLIII", "144":"CXLIV", "145":"CXLV",
  "146":"CXLVI", "147":"CXLVII", "148":"CXLVIII", "149":"CXLIX", "150":"CL",
  "151":"CLI", "152":"CLII", "153":"CLIII", "154":"CLIV", "155":"CLV",
  "156":"CLVI", "157":"CLVII", "158":"CLVIII", "159":"CLIX", "160":"CLX",
  "161":"CLXI", "162":"CLXII", "163":"CLXIII", "164":"CLXIV", "165":"CLXV",
  "166":"CLXVI", "167":"CLXVII", "168":"CLXVIII", "169":"CLXIX", "170":"CLXX",
  "171":"CLXXI", "172":"CLXXII", "173":"CLXXIII", "174":"CLXXIV", "175":"CLXXV",
  "176":"CLXXVI", "177":"CLXXVII", "178":"CLXXVIII", "179":"CLXXIX", "180":"CLXXX",
  "181":"CLXXXI", "182":"CLXXXII", "183":"CLXXXIII", "184":"CLXXXIV", "185":"CLXXXV",
  "186":"CLXXXVI", "187":"CLXXXVII", "188":"CLXXXVIII", "189":"CLXXXIX", "190":"CXC",
  "191":"CXCI", "192":"CXCII", "193":"CXCIII", "194":"CXCIV", "195":"CXCV",
  "196":"CXCVI", "197":"CXCVII", "198":"CXCVIII", "199":"CXCIX", "200":"CC",
}

roman_numerals = {y for x, y in arabic_to_roman_form.items()}

def process_text_on_page(index, pagename, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagename, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagename, txt))

  pagemsg("Processing")

  notes = []

  curtext = text + "\n"

  def arabic_to_roman(num):
    if num in roman_numerals:
      return num
    if num not in arabic_to_roman_form:
      pagemsg("WARNING: Couldn't convert Arabic numeral %s to Roman" % num)
      return None
    return arabic_to_roman_form[num]

  def replace_spenser_fq(m):
    template, text = m.groups()
    parsed = blib.parse_text(template)
    t = list(parsed.filter_templates())[0]
    par2 = getparam(t, "2")
    if par2:
      canto = arabic_to_roman(par2)
      if not canto:
        return m.group(0)
      t.add("canto", canto, before="2")
      rmparam(t, "2")
    par1 = getparam(t, "1")
    if par1:
      book = arabic_to_roman(par1)
      if not book:
        return m.group(0)
      t.add("book", book, before="1")
      rmparam(t, "1")
    text = re.sub(r"\s*<br */?>\s*", " / ", text)
    text = re.sub(r"^\{\{quote\|en\|(.*)\}\}$", r"\1", text)
    t.add("passage", text)
    blib.set_template_name(t, "RQ:Spenser Faerie Queene")
    notes.append("reformat {{RQ:Spenser FQ}} into {{RQ:Spenser Faerie Queene}}")
    return str(t) + "\n"

  curtext = re.sub(r"(\{\{RQ:Spenser FQ\|.*?\}\})\n#+\*: (.*?)\n",
      replace_spenser_fq, curtext)

  return curtext.rstrip("\n"), notes

parser = blib.create_argparser("Reformat {{RQ:Spenser FQ}}", include_pagefile=True,
    include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
    default_refs=["Template:RQ:Spenser FQ"], edit=True, stdin=True)
