#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, time
import traceback
import unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site
from collections import OrderedDict

import rulib

ordinals = {
  1: "пе́рвый",
  2: "второ́й",
  3: "тре́тий",
  4: "четвёртый",
  5: "пя́тый",
  6: "шесто́й",
  7: "седьмо́й",
  8: "восьмо́й",
  9: "девя́тый",
}

cardinal_ten_decls = {
  # order is nom, gen, dat, acc, ins, pre
  20: ["два́дцать", "двадцати́", "двадцати́", "два́дцать", "двадцатью́", "двадцати́"],
  30: ["три́дцать", "тридцати́", "тридцати́", "три́дцать", "тридцатью́", "тридцати́"],
  40: ["со́рок", "сорока́", "сорока́", "со́рок", "сорока́", "сорока́"],
  50: ["пятьдеся́т", "пяти́десяти", "пяти́десяти", "пятьдеся́т", "пятью́десятью", "пяти́десяти"],
  60: ["шестьдеся́т", "шести́десяти", "шести́десяти", "шестьдеся́т", "шестью́десятью", "шести́десяти"],
  70: ["се́мьдесят", "семи́десяти", "семи́десяти", "се́мьдесят", "семью́десятью", "семи́десяти"],
  80: ["во́семьдесят", "восьми́десяти", "восьми́десяти", "во́семьдесят", ["восемью́десятью", "восьмью́десятью"], "восьми́десяти"],
  90: ["девяно́сто", "девяно́ста", "девяно́ста", "девяно́сто", "девяно́ста", "девяно́ста"],
}

cardinal_one_decls = {
  # order is nom_m, nom_f, gen, dat, ins, pre
  2: ["два́", "две́", "дву́х", "дву́м", "двумя́", "дву́х"],
  3: ["три́", "три́", "трёх", "трём", "тремя́", "трёх"],
  4: ["четы́ре", "четы́ре", "четырёх", "четырём", "четырьмя́", "четырёх"],
  5: ["пя́ть", "пя́ть", "пяти́", "пяти́", "пятью́", "пяти́"],
  6: ["ше́сть", "ше́сть", "шести́", "шести́", "шестью́", "шести́"],
  7: ["се́мь", "се́мь", "семи́", "семи́", "семью́", "семи́"],
  8: ["во́семь", "во́семь", "восьми́", "восьми́", ["восемью́", "восьмью́"], "восьми́"],
  9: ["де́вять", "де́вять", "девяти́", "девяти́", "девятью́", "девяти́"],
}

cardinal_tens = {num: decl[0] for num, decl in cardinal_ten_decls.items()}
cardinal_tens[100] = "сто́"

cardinal_ones = {
  0: "",
  1: "оди́н",
  2: "два́",
  3: "три́",
  4: "четы́ре",
  5: "пя́ть",
  6: "ше́сть",
  7: "се́мь",
  8: "во́семь",
  9: "де́вять",
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

# Make sure there are two trailing newlines
def ensure_two_trailing_nl(text):
  return re.sub(r"\n*$", r"\n\n", text)

def combine(tens, ones):
  if type(tens) is not list:
    tens = [tens]
  if type(ones) is not list:
    ones = [ones]
  vals = []
  # The first clause below ensures that we get only two entries for the
  # instrumental of 88 (во́семьдесят во́семь) instead of four. The second
  # clause typically applies when one of the two words has a single
  # possibility and the other has two.
  if len(tens) == len(ones):
    for ten, one in zip(tens, ones):
      if one:
        vals.append("%s %s" % (ten, one))
      else:
        vals.append(ten)
  else:
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
    return """{{ru-adj-table
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
      combine(tnom, "оди́н"), combine(tnom, "одно́"), combine(tnom, "одна́"),
      combine(tnom, "одни́"),
      combine(tgen, "одного́"), combine(tgen, "одно́й"),
      combine(tgen, "одни́х"),
      combine(tdat, "одному́"), combine(tdat, "одно́й"),
      combine(tdat, "одни́м"),
      combine(tacc, "одного́"), combine(tacc, "одну́"),
      combine(tacc, "одни́х"),
      combine(tins, "одни́м"), combine(tins, ["одно́й", "одно́ю"]),
      combine(tins, "одни́ми"),
      combine(tpre, "одно́м"), combine(tpre, "одно́й"),
      combine(tpre, "одни́х")
      )
  elif ones == 2:
    return """{{ru-decl-adj|-|manual|nom_mp=%s|nom_fp=%s|gen_p=%s|dat_p=%s|ins_p=%s|pre_p=%s|special=cdva}}""" % (
      combine(tnom, "два́"), combine(tnom, "две́"), combine(tgen, "дву́х"),
      combine(tdat, "дву́м"), combine(tins, "двумя́"), combine(tpre, "дву́х"))
  elif ones == 3:
    return """{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, "три́"), combine(tgen, "трёх"), combine(tdat, "трём"),
      combine(tacc, "три́"), combine(tins, "тремя́"), combine(tpre, "трёх"))
  elif ones == 4:
    return """{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, "четы́ре"), combine(tgen, "четырёх"), combine(tdat, "четырём"),
      combine(tacc, "четы́ре"), combine(tins, "четырьмя́"), combine(tpre, "четырёх"))
  elif ones == 5:
    return """{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, "пя́ть"), combine(tgen, "пяти́"), combine(tdat, "пяти́"),
      combine(tacc, "пя́ть"), combine(tins, "пятью́"), combine(tpre, "пяти́"))
  elif ones == 6:
    return """{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, "ше́сть"), combine(tgen, "шести́"), combine(tdat, "шести́"),
      combine(tacc, "ше́сть"), combine(tins, "шестью́"), combine(tpre, "шести́"))
  elif ones == 7:
    return """{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, "се́мь"), combine(tgen, "семи́"), combine(tdat, "семи́"),
      combine(tacc, "се́мь"), combine(tins, "семью́"), combine(tpre, "семи́"))
  elif ones == 8:
    return """{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, "во́семь"), combine(tgen, "восьми́"), combine(tdat, "восьми́"),
      combine(tacc, "во́семь"), combine(tins, ["восемью́", "восьмью́"]), combine(tpre, "восьми́"))
  elif ones == 9:
    return """{{ru-decl-noun-unc
|%s
|%s
|%s
|%s
|%s
|%s
}}""" % (combine(tnom, "де́вять"), combine(tgen, "девяти́"), combine(tdat, "девяти́"),
      combine(tacc, "де́вять"), combine(tins, "девятью́"), combine(tpre, "девяти́"))

def generate_pron(num):
  tens = (num / 10) * 10
  ones = num % 10
  ones_pron = cardinal_ones[ones]
  if ones == 4:
    ones_pron = "четы́ре|pos=num"
  if tens in [20, 30, 40, 90]:
    return "* {{ru-IPA|%s %s}}" % (cardinal_tens[tens], ones_pron)
  if tens == 50:
    return """* {{ru-IPA|пятьдеся́т %s|gem=opt}}
* {{i|colloquial or fast speech}} {{ru-IPA|phon=пееся́т %s}}""" % (
      ones_pron, ones_pron)
  if tens == 60:
    return """* {{ru-IPA|шестьдеся́т %s}}
* {{i|colloquial or fast speech}} {{ru-IPA|phon=шееся́т %s}}""" % (
      ones_pron, ones_pron)
  if tens == 70:
    return """* {{ru-IPA|се́мьдесят %s}}
* {{ru-IPA|phon=се́мдесят %s}}""" % (
      ones_pron, ones_pron)
  if tens == 80:
    return """* {{ru-IPA|во́семьдесят %s}}
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
    return """* '''{tnom} оди́н''' governs the singular of the noun in the appropriate case, exactly as if it were an adjective.
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
:* {{{{uxi|ru|[[говорить|Говорю́]] [[о]] '''{tpre} одни́х''' [[большой|больши́х]] [[ножницы|но́жницах]].|I am speaking about '''{eng}''' large scissors.}}}}""".format(
      tnom=tnom, tgen=tgen, tdat=tdat, tacc=tacc, tins=tins, tpre=tpre,
      eng=en_num(num))
  onom_m, onom_f, ogen, odat, oins, opre = cardinal_one_decls[ones]
  if type(oins) is list:
    oins = "/".join(oins)

  if ones in [2, 3, 4]:
    return """* '''{tnom} {onom_m}''' in the nominative and accusative case governs the genitive singular of the noun, although modifying adjectives are in the genitive plural (or alternatively and preferably, for feminine nouns, in the nominative plural). Unlike with bare {{{{m|ru|{onom_m}}}}}, there is no animate/inanimate distinction.
:* {{{{uxi|ru|[[здесь|Здесь]] '''{tnom} {onom_m}''' [[русский|ру́сских]] [[мальчик|ма́льчика]].|Here are '''{eng}''' Russian boys.}}}}
:* {{{{uxi|ru|[[здесь|Здесь]] '''{tnom} {onom_f}''' [[большой|больши́е]]/[[большой|больши́х]] [[книга|кни́ги]].|Here are '''{eng}''' large books.}}}}
:* {{{{uxi|ru|[[я|Я]] [[видеть|ви́жу]] '''{tacc} {onom_m}''' [[русский|ру́сских]] [[мальчик|ма́льчика]].|I see '''{eng}''' Russian boys.}}}}
:* {{{{uxi|ru|[[я|Я]] [[видеть|ви́жу]] '''{tacc} {onom_f}''' [[большой|больши́е]]/[[большой|больши́х]] [[книга|кни́ги]].|I see '''{eng}''' large books.}}}}
* '''{tnom} {onom_m}''' in other cases governs the appropriate plural case of the noun, with adjectives agreeing appropriately.
:* {{{{uxi|ru|[[учи́тель]] '''{tgen} {ogen}''' [[русский|ру́сских]] [[мальчик|ма́льчиков]]|the teacher of the '''{eng}''' Russian boys}}}}
:* {{{{uxi|ru|[[с]] '''{tins} {oins}''' [[русский|ру́сскими]] [[мальчик|ма́льчиками]]|with '''{eng}''' Russian boys}}}}
:* {{{{uxi|ru|[[говорить|Говорю́]] [[о]] '''{tpre} {opre}''' [[русский|ру́сских]] [[мальчик|ма́льчиках]].|I am speaking about '''{eng}''' Russian boys.}}}}""".format(
      tnom=tnom, tgen=tgen, tdat=tdat, tacc=tacc, tins=tins, tpre=tpre,
      onom_m=onom_m, onom_f=onom_f, ogen=ogen, odat=odat, oins=oins, opre=opre,
      eng=en_num(num))
  if ones in [5, 6, 7, 8, 9]:
    return """* '''{tnom} {onom_m}''' in the nominative and accusative case governs the genitive plural of the noun. There is no animate/inanimate distinction.
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
  return """==Russian==
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

[[Category:Russian cardinal numbers]]
""" % (
    prevnum, num, nextnum, ru_num(prevnum), ru_num(nextnum),
    "%s %s" % (cardinal_tens[tens], ordinals[ones]), ru_num(num),
    generate_pron(num),
    cardinal_tens[tens], cardinal_ones[ones],
    en_num(num), num,
    generate_usage(num),
    generate_decl(num)
)

def process_page(index, num, save, verbose, params):
  comment = None
  notes = []

  lemma = ru_num(num)
  pagetitle = rulib.remove_accents(lemma)
  newtext = generate_page(num)

  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  # Prepare to create page
  pagemsg("Creating entry")
  page = pywikibot.Page(site, pagetitle)

  # If invalid title, don't do anything.
  existing_text = blib.safe_page_text(page, errandpagemsg, bad_value_ret=None)
  if existing_text is None:
    return

  if not blib.safe_page_exists(page, errandpagemsg):
    # Page doesn't exist. Create it.
    pagemsg("Creating page")
    comment = "Create page for Russian numeral %s (%s)" % (
        lemma, num)
    page.text = newtext
    if verbose:
      pagemsg("New text is [[%s]]" % page.text)
  else: # Page does exist
    pagetext = existing_text

    # Split into sections
    splitsections = re.split("(^==[^=\n]+==\n)", pagetext, 0, re.M)
    # Extract off pagehead and recombine section headers with following text
    pagehead = splitsections[0]
    sections = []
    for i in range(1, len(splitsections)):
      if (i % 2) == 1:
        sections.append("")
      sections[-1] += splitsections[i]

    # Go through each section in turn, looking for existing Russian section
    for i in range(len(sections)):
      m = re.match("^==([^=\n]+)==$", sections[i], re.M)
      if not m:
        pagemsg("Can't find language name in text: [[%s]]" % (sections[i]))
      elif m.group(1) == "Russian":
        # Extract off trailing separator
        mm = re.match(r"^(.*?\n)(\n*--+\n*)$", sections[i], re.S)
        if mm:
          # Note that this changes the number of sections, which is seemingly
          # a problem because the for-loop above calculates the end point
          # at the beginning of the loop, but is not actually a problem
          # because we always break after processing the Russian section.
          sections[i:i+1] = [mm.group(1), mm.group(2)]

        if params.overwrite_page:
          if "==Etymology 1==" in sections[i] and not params.overwrite_etymologies:
            errandpagemsg("WARNING: Found ==Etymology 1== in page text, not overwriting, skipping form")
            return
          else:
            pagemsg("WARNING: Overwriting entire Russian section")
            comment = "Create Russian section for numeral %s (%s)" % (
              lemma, num)
            sections[i] = newtext
            notes.append("overwrite section")
            break
        else:
          errandpagemsg("WARNING: Not overwriting existing Russian section")
          return
      elif m.group(1) > "Russian":
        pagemsg("Exists; inserting before %s section" % (m.group(1)))
        comment = "Create Russian section and entry for numeral %s (%s); insert before %s section" % (
            lemma, num, m.group(1))
        sections[i:i] = [newtext, "\n----\n\n"]
        break

    else: # else of for loop over sections, i.e. no break out of loop
      pagemsg("Exists; adding section to end")
      comment = "Create Russian section and entry for numeral %s (%s); append at end" % (
          lemma, num)

      if sections:
        sections[-1] = ensure_two_trailing_nl(sections[-1])
        sections += ["----\n\n", newsection]
      else:
        if not params.overwrite_page:
          notes.append("formerly empty")
        if pagehead.lower().startswith("#redirect"):
          pagemsg("WARNING: Page is redirect, overwriting")
          notes.append("overwrite redirect")
          pagehead = re.sub(r"#redirect *\[\[(.*?)\]\] *(<!--.*?--> *)*\n*",
              r"{{also|\1}}\n", pagehead, 0, re.I)
        elif not params.overwrite_page:
          pagemsg("WARNING: No language sections in current page")
        sections += [newsection]

    # End of loop over sections in existing page; rejoin sections
    newtext = pagehead + ''.join(sections)

    if page.text != newtext:
      assert comment or notes

    # Eliminate sequences of 3 or more newlines, which may come from
    # ensure_two_trailing_nl(). Add comment if none, in case of existing page
    # with extra newlines.
    newnewtext = re.sub(r"\n\n\n+", r"\n\n", newtext)
    if newnewtext != newtext and not comment and not notes:
      notes = ["eliminate sequences of 3 or more newlines"]
    newtext = newnewtext

    if page.text == newtext:
      pagemsg("No change in text")
    elif verbose:
      pagemsg("Replacing <%s> with <%s>" % (page.text, newtext))
    else:
      pagemsg("Text has changed")
    page.text = newtext

  # Executed whether creating new page or modifying existing page.
  # Check for changed text and save if so.
  notestext = '; '.join(notes)
  if notestext:
    if comment:
      comment += " (%s)" % notestext
    else:
      comment = notestext
  if page.text != existing_text:
    if save:
      pagemsg("Saving with comment = %s" % comment)
      blib.safe_page_save(page, comment, errandpagemsg)
    else:
      pagemsg("Would save with comment = %s" % comment)

pa = blib.create_argparser("Save Russian numbers to Wiktionary")
pa.add_argument("--offline", help="Operate offline, outputting text of new pages", action="store_true")
pa.add_argument("--overwrite-page", action="store_true",
    help="""If specified, overwrite the entire existing page of inflections.
Won't do this if it finds "Etymology N", unless --overwrite-etymologies is
given. WARNING: Be careful!""")
pa.add_argument("--overwrite-etymologies", action="store_true",
    help="""If specified and --overwrite-page, overwrite the entire existing
page of inflections even if "Etymology N". WARNING: Be careful!""")
pa.add_argument("--numerals",
    help="""Comma-separated and/or hyphen-separated list of numerals to process.""")

params = pa.parse_args()
startFrom, upTo = blib.parse_start_end(params.start, params.end)

def iter_numerals():
  for ten in sorted(cardinal_tens.keys())[:-1]: # Skip 100
    for one in sorted(cardinal_ones.keys())[1:]: # Skip 0
        yield ten + one

def iter_specified_numerals(spec):
  for singlespec in re.split(",", spec):
    if "-" in singlespec:
      fro, to = re.split("-", singlespec)
      for num in range(int(fro), int(to) + 1):
        yield num
    else:
      yield int(singlespec)

if params.numerals:
  pages = iter_specified_numerals(params.numerals)
else:
  pages = iter_numerals()
for current, index in blib.iter_pages(pages, startFrom, upTo,
    key=lambda x:str(x)):
  if params.offline:
    print("========== Text for #%s: ==========" % current)
    print("")
    print(generate_page(current))
    print("")
  else:
    process_page(index, current, params.save, params.verbose, params)
