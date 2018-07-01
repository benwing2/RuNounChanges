#!/usr/bin/env python
#coding: utf-8

#   create_ru_numerals.py is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

import pywikibot, re, sys, codecs, argparse, time
import traceback
import unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, errmsg, site
from collections import OrderedDict

import rulib

ordinals = {
  1: u"пе́рвый",
  2: u"второ́й",
  3: u"тре́тий",
  4: u"четвёртый",
  5: u"пя́тый",
  6: u"шесто́й",
  7: u"седьмо́й",
  8: u"восьмо́й",
  9: u"девя́тый",
}

cardinal_ten_decls = {
  # order is nom, gen, dat, acc, ins, pre
  20: [u"два́дцать", u"двадцати́", u"двадцати́", u"два́дцать", u"двадцатью́", u"двадцати́"],
  30: [u"три́дцать", u"тридцати́", u"тридцати́", u"три́дцать", u"тридцатью́", u"тридцати́"],
  40: [u"со́рок", u"сорока́", u"сорока́", u"со́рок", u"сорока́", u"сорока́"],
  50: [u"пятьдеся́т", u"пяти́десяти", u"пяти́десяти", u"пятьдеся́т", u"пятью́десятью", u"пяти́десяти"],
  60: [u"шестьдеся́т", u"шести́десяти", u"шести́десяти", u"шестьдеся́т", u"шестью́десятью", u"шести́десяти"],
  70: [u"се́мьдесят", u"семи́десяти", u"семи́десяти", u"се́мьдесят", u"семью́десятью", u"семи́десяти"],
  80: [u"во́семьдесят", u"восьми́десяти", u"восьми́десяти", u"во́семьдесят", [u"восемью́десятью", u"восьмью́десятью"], u"восьми́десяти"],
  90: [u"девяно́сто", u"девяно́ста", u"девяно́ста", u"девяно́сто", u"девяно́ста", u"девяно́ста"],
}

cardinal_one_decls = {
  # order is nom_m, nom_f, gen, dat, ins, pre
  2: [u"два́", u"две́", u"дву́х", u"дву́м", u"двумя́", u"дву́х"],
  3: [u"три́", u"три́", u"трёх", u"трём", u"тремя́", u"трёх"],
  4: [u"четы́ре", u"четы́ре", u"четырёх", u"четырём", u"четырьмя́", u"четырёх"],
  5: [u"пя́ть", u"пя́ть", u"пяти́", u"пяти́", u"пятью́", u"пяти́"],
  6: [u"ше́сть", u"ше́сть", u"шести́", u"шести́", u"шестью́", u"шести́"],
  7: [u"се́мь", u"се́мь", u"семи́", u"семи́", u"семью́", u"семи́"],
  8: [u"во́семь", u"во́семь", u"восьми́", u"восьми́", [u"восемью́", u"восьмью́"], u"восьми́"],
  9: [u"де́вять", u"де́вять", u"девяти́", u"девяти́", u"девятью́", u"девяти́"],
}

cardinal_tens = {num: decl[0] for num, decl in cardinal_ten_decls.items()}
cardinal_tens[100] = u"сто́"

cardinal_ones = {
  0: "",
  1: u"оди́н",
  2: u"два́",
  3: u"три́",
  4: u"четы́ре",
  5: u"пя́ть",
  6: u"ше́сть",
  7: u"се́мь",
  8: u"во́семь",
  9: u"де́вять",
}

english_cardinals = {
  1: "one",
  2: "two",
  3: "three",
  4: "four",
  5: "five",
  6: "six",
  7: "seven",
  8: "eight",
  9: "nine",
  20: "twenty",
  30: "thirty",
  40: "forty",
  50: "fifty",
  60: "sixty",
  70: "seventy",
  80: "eighty",
  90: "ninety"
}

def combine(tens, ones):
  if type(tens) is not list:
    tens = [tens]
  if type(ones) is not list:
    ones = [ones]
  vals = []
  for ten in tens:
    for one in ones:
      if one:
        vals.append("%s %s" % (ten, one))
      else:
        vals.append(ten)
  return ",".join(vals)

def ru_num(num):
  tens = (num / 10) * 10
  ones = num % 10
  return combine(cardinal_tens[tens], cardinal_ones[ones])

def en_num(num):
  tens = (num / 10) * 10
  ones = num % 10
  return "%s-%s" % (english_cardinals[tens], english_cardinals[ones])
  
def generate_decl(num):
  tens = (num / 10) * 10
  tnom, tgen, tdat, tacc, tins, tpre = cardinal_ten_decls[tens]
  ones = num % 10
  if ones == 1:
    return u"""{{ru-adj-table
|nom_m=%s
|nom_n=%s
|nom_f=%s
|nom_p=%s
|gen_m=%s
|gen_f=%s
|gen_p=%s
|dat_m=%s
|dat_f=%s
|dat_p=%s
|acc_m_an=%s
|acc_f=%s
|acc_p_an=%s
|ins_m=%s
|ins_f=%s
|ins_p=%s
|pre_m=%s
|pre_f=%s
|pre_p=%s
}}""" % (
      combine(tnom, u"оди́н"), combine(tnom, u"одно́"), combine(tnom, u"одна́"),
      combine(tnom, u"одни́"),
      combine(tgen, u"одного́"), combine(tgen, u"одно́й"),
      combine(tgen, u"одни́х"),
      combine(tdat, u"одному́"), combine(tdat, u"одно́й"),
      combine(tdat, u"одни́м"),
      combine(tacc, u"одного́"), combine(tacc, u"одну́"),
      combine(tacc, u"одни́х"),
      combine(tins, u"одни́м"), combine(tins, [u"одно́й", u"одно́ю"]),
      combine(tins, u"одни́ми"),
      combine(tpre, u"одно́м"), combine(tpre, u"одно́й"),
      combine(tpre, u"одни́х")
      )
  elif ones == 2:
    return u"""{{ru-decl-adj|-|manual|nom_mp=%s|nom_fp=%s|gen_p=%s|dat_p=%s|ins_p=%s|pre_p=%s|special=cdva}}""" % (
      combine(tnom, u"два́"), combine(tnom, u"две́"), combine(tgen, u"дву́х"),
      combine(tdat, u"дву́м"), combine(tins, u"двумя́"), combine(tpre, u"дву́х"))
  elif ones == 3:
    return u"""{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, u"три́"), combine(tgen, u"трёх"), combine(tdat, u"трём"),
      combine(tacc, u"три́"), combine(tins, u"тремя́"), combine(tpre, u"трёх"))
  elif ones == 4:
    return u"""{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, u"четы́ре"), combine(tgen, u"четырёх"), combine(tdat, u"четырём"),
      combine(tacc, u"четы́ре"), combine(tins, u"четырьмя́"), combine(tpre, u"четырёх"))
  elif ones == 5:
    return u"""{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, u"пя́ть"), combine(tgen, u"пяти́"), combine(tdat, u"пяти́"),
      combine(tacc, u"пя́ть"), combine(tins, u"пятью́"), combine(tpre, u"пяти́"))
  elif ones == 6:
    return u"""{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, u"ше́сть"), combine(tgen, u"шести́"), combine(tdat, u"шести́"),
      combine(tacc, u"ше́сть"), combine(tins, u"шестью́"), combine(tpre, u"шести́"))
  elif ones == 7:
    return u"""{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, u"се́мь"), combine(tgen, u"семи́"), combine(tdat, u"семи́"),
      combine(tacc, u"се́мь"), combine(tins, u"семью́"), combine(tpre, u"семи́"))
  elif ones == 8:
    return u"""{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, u"во́семь"), combine(tgen, u"восьми́"), combine(tdat, u"восьми́"),
      combine(tacc, u"во́семь"), combine(tins, [u"восемью́", u"восьмью́"]), combine(tpre, u"восьми́"))
  elif ones == 9:
    return u"""{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, u"де́вять"), combine(tgen, u"девяти́"), combine(tdat, u"девяти́"),
      combine(tacc, u"де́вять"), combine(tins, u"девятью́"), combine(tpre, u"девяти́"))

def generate_pron(num):
  tens = (num / 10) * 10
  ones = num % 10
  ones_pron = cardinal_ones[ones]
  if ones == 4:
    ones_pron = u"четы́ре|pos=num"
  if tens in [20, 30, 40, 90]:
    return "* {{ru-IPA|%s %s}}" % (cardinal_tens[tens], ones_pron)
  if tens == 50:
    return u"""* {{ru-IPA|пятьдеся́т %s|gem=opt}}
* {{i|colloquial or fast speech}} {{ru-IPA|phon=пееся́т %s}}""" % (
      ones_pron, ones_pron)
  if tens == 60:
    return u"""* {{ru-IPA|шестьдеся́т %s}}
* {{i|colloquial or fast speech}} {{ru-IPA|phon=шееся́т %s}}""" % (
      ones_pron, ones_pron)
  if tens == 70:
    return u"""* {{ru-IPA|се́мьдесят %s}}
* {{ru-IPA|phon=се́мдесят %s}}""" % (
      ones_pron, ones_pron)
  if tens == 80:
    return u"""* {{ru-IPA|во́семьдесят %s}}
* {{ru-IPA|phon=во́семдесят %s}}""" % (
      ones_pron, ones_pron)
  raise ValueError("Unrecognized tens: %s" % tens)

def generate_usage(num):
  tens = (num / 10) * 10
  tnom, tgen, tdat, tacc, tins, tpre = cardinal_ten_decls[tens]
  if type(tins) is list:
    tins = "/".join(tins)
  ones = num % 10

  if ones == 1:
    return u"""* '''{tnom} оди́н''' governs the singular of the noun in the appropriate case, exactly as if it were an adjective.
:* {{{{uxi|ru|[[здесь|Здесь]] '''{tnom} оди́н''' [[ру́сский]] [[ма́льчик]].|Here are '''{eng}''' Russian boys.}}}}
:* {{{{uxi|ru|[[здесь|Здесь]] '''{tnom} одна́''' [[большой|больша́я]] [[кни́га]].|Here are '''{eng}''' large books.}}}}
:* {{{{uxi|ru|[[здесь|Здесь]] '''{tnom} одно́''' [[маленький|ма́ленькое]] [[окно́]].|Here are '''{eng}''' small windows.}}}}
:* {{{{uxi|ru|[[я|Я]] [[видеть|ви́жу]] '''{tacc} одного́''' [[русский|ру́сского]] [[мальчик|ма́льчика]].|I see '''{eng}''' Russian boys.}}}}
:* {{{{uxi|ru|[[я|Я]] [[видеть|ви́жу]] '''{tacc} одну́''' [[большой|большу́ю]] [[книга|кни́гу]].|I see '''{eng}''' large books.}}}}
:* {{{{uxi|ru|[[я|Я]] [[видеть|ви́жу]] '''{tacc} одно́''' [[маленький|ма́ленькое]] [[окно́]].|I see '''{eng}''' small windows.}}}}
:* {{{{uxi|ru|[[учи́тель]] '''{tgen} одно́й''' [[русский|ру́сской]] [[де́вушка|де́вушки]]|the teacher of the '''{eng}''' Russian girls}}}}
:* {{{{uxi|ru|[[с]] '''{tins} одни́м''' [[русский|ру́сским]] [[мальчик|ма́льчиком]]|with '''{eng}''' Russian boys}}}}
:* {{{{uxi|ru|[[говорить|Говорю́]] [[о]] '''{tpre} одно́м''' [[русский|ру́сском]] [[мальчик|ма́льчике]].|I am speaking about '''{eng}''' Russian boys.}}}}
* With pluralia tantum nouns, the plural forms of '''{tnom} оди́н''' are used.
:* {{{{uxi|ru|[[здесь|Здесь]] '''{tnom} одни́''' [[большой|больши́е]] [[но́жницы]].|Here are '''{eng}''' large scissors.}}}}
:* {{{{uxi|ru|[[я|Я]] [[видеть|ви́жу]] '''{tacc} одни́''' [[большой|больши́е]] [[но́жницы]].|I see '''{eng}''' large scissors.}}}}
:* {{{{uxi|ru|[[владе́лец]] '''{tgen} одни́х''' [[большой|больши́х]] [[ножницы|но́жниц]]|the owner of the '''{eng}''' large scissors}}}}
:* {{{{uxi|ru|[[с]] '''{tins} одни́ми''' [[большой|больши́ми]] [[ножницы|но́жницами]]|with '''{eng}''' large scissors}}}}
:* {{{{uxi|ru|[[говорить|Говорю́]] [[о]] '''{tpre} одни́х''' [[русский|больши́х]] [[ножницы|но́жницах]].|I am speaking about '''{eng}''' large scissors.}}}}""".format(
      tnom=tnom, tgen=tgen, tdat=tdat, tacc=tacc, tins=tins, tpre=tpre,
      eng=en_num(num))
  onom_m, onom_f, ogen, odat, oins, opre = cardinal_one_decls[ones]
  if type(oins) is list:
    oins = "/".join(oins)

  if ones in [2, 3, 4]:
    return u"""* '''{tnom} {onom_m}''' in the nominative and accusative case governs the genitive singular of the noun, although modifying adjectives are in the genitive plural. (Unlike with bare {{{{m|ru|{onom_m}}}}}, there is no animate/inanimate distinction.)
:* {{{{uxi|ru|[[здесь|Здесь]] '''{tnom} {onom_m}''' [[русский|ру́сских]] [[мальчик|ма́льчика]].|Here are '''{eng}''' Russian boys.}}}}
:* {{{{uxi|ru|[[здесь|Здесь]] '''{tnom} {onom_f}''' [[большой|больши́х]] [[книга|кни́ги]].|Here are '''{eng}''' large books.}}}}
:* {{{{uxi|ru|[[я|Я]] [[видеть|ви́жу]] '''{tacc} {onom_m}''' [[русский|ру́сских]] [[мальчик|ма́льчика]].|I see '''{eng}''' Russian boys.}}}}
:* {{{{uxi|ru|[[я|Я]] [[видеть|ви́жу]] '''{tacc} {onom_f}''' [[большой|больши́х]] [[книга|кни́ги]].|I see '''{eng}''' large books.}}}}
* '''{tnom} {onom_m}''' in other cases governs the appropriate plural case of the noun, with adjectives agreeing appropriately.
:* {{{{uxi|ru|[[учи́тель]] '''{tgen} {ogen}''' [[русский|ру́сских]] [[мальчик|ма́льчиков]]|the teacher of the '''{eng}''' Russian boys}}}}
:* {{{{uxi|ru|[[с]] '''{tins} {oins}''' [[русский|ру́сскими]] [[мальчик|ма́льчиками]]|with '''{eng}''' Russian boys}}}}
:* {{{{uxi|ru|[[говорить|Говорю́]] [[о]] '''{tpre} {opre}''' [[русский|ру́сских]] [[мальчик|ма́льчиках]].|I am speaking about '''{eng}''' Russian boys.}}}}""".format(
      tnom=tnom, tgen=tgen, tdat=tdat, tacc=tacc, tins=tins, tpre=tpre,
      onom_m=onom_m, onom_f=onom_f, ogen=ogen, odat=odat, oins=oins, opre=opre,
      eng=en_num(num))
  if ones in [5, 6, 7, 8, 9]:
    return u"""* '''{tnom} {onom_m}''' in the nominative and accusative case governs the genitive plural of the noun. There is no animate/inanimate distinction.
:* {{{{uxi|ru|[[здесь|Здесь]] '''{tnom} {onom_m}''' [[русский|ру́сских]] [[мальчик|ма́льчиков]].|Here are '''{eng}''' Russian boys.}}}}
:* {{{{uxi|ru|[[здесь|Здесь]] '''{tnom} {onom_f}''' [[большой|больши́х]] [[книга|кни́г]].|Here are '''{eng}''' large books.}}}}
:* {{{{uxi|ru|[[я|Я]] [[видеть|ви́жу]] '''{tacc} {onom_m}''' [[русский|ру́сских]] [[мальчик|ма́льчиков]].|I see '''{eng}''' Russian boys.}}}}
:* {{{{uxi|ru|[[я|Я]] [[видеть|ви́жу]] '''{tacc} {onom_f}''' [[большой|больши́х]] [[книга|кни́г]].|I see '''{eng}''' large books.}}}}
* '''{tnom} {onom_m}''' in other cases governs the appropriate plural case of the noun.
:* {{{{uxi|ru|[[учи́тель]] '''{tgen} {ogen}''' [[русский|ру́сских]] [[мальчик|ма́льчиков]]|the teacher of the '''{eng}''' Russian boys}}}}
:* {{{{uxi|ru|[[с]] '''{tins} {oins}''' [[русский|ру́сскими]] [[мальчик|ма́льчиками]]|with '''{eng}''' Russian boys}}}}
:* {{{{uxi|ru|[[говорить|Говорю́]] [[о]] '''{tpre} {opre}''' [[русский|ру́сских]] [[мальчик|ма́льчиках]].|I am speaking about '''{eng}''' Russian boys.}}}}""".format(
      tnom=tnom, tgen=tgen, tdat=tdat, tacc=tacc, tins=tins, tpre=tpre,
      onom_m=onom_m, onom_f=onom_f, ogen=ogen, odat=odat, oins=oins, opre=opre,
      eng=en_num(num))
  raise ValueError("Unknown ones: %s" % ones)

def generate_page(num):
  prevnum = num - 1
  nextnum = num + 1
  tens = (num / 10) * 10
  ones = num % 10
  return u"""==Russian==
{{cardinalbox|ru|%s|%s|%s|%s|%s|ord=%s|alt=%s}}

===Pronunciation===
%s

===Numeral===
{{head|ru|numeral|head=[[%s]] [[%s]]}}

# [[%s]] (%s)

====Usage notes====
%s

====Declension====
%s

====Coordinate terms====
{{ru-cardinals}}

[[Category:Russian cardinal numbers]]""" % (
    prevnum, num, nextnum, ru_num(prevnum), ru_num(nextnum),
    "%s %s" % (cardinal_tens[tens], ordinals[ones]), ru_num(num),
    generate_pron(num),
    cardinal_tens[tens], cardinal_ones[ones],
    en_num(num), num,
    generate_usage(num),
    generate_decl(num)
)

pa = blib.init_argparser("Save numbers to Wiktionary")

params = pa.parse_args()
startFrom, upTo = blib.parse_start_end(params.start, params.end)

def iter_numerals():
  for ten in sorted(cardinal_tens.keys())[:-1]: # Skip 100
    for one in sorted(cardinal_ones.keys())[1:]: # Skip 0
        yield ten + one

pages = iter_numerals()
for current, index in blib.iter_pages(pages, startFrom, upTo,
    key=lambda x:str(x)):
  print "========== Text for #%s: ==========" % current
  print ""
  print generate_page(current).encode('utf-8')
  print ""
