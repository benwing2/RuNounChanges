#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, copy

import blib
from blib import getparam, rmparam, tname, msg, errmsg, site

import rulib

def is_vowel_stem(stem):
  return re.search("[" + rulib.vowel + rulib.AC + rulib.DI + "]$", stem)

def split_ru_conj_args(t, is_temp):
  first_param = 2 if is_temp else 1
  verb_type = getparam(t, str(first_param))
  max_arg = 1
  arg_sets = []
  arg_set = []
  for i in range(first_param + 1, 30):
    if getparam(t, str(i)):
      max_arg = i
  # Gather the numbered arguments
  for i in range(first_param + 1, max_arg + 2):
    end_arg_set = False
    if i == max_arg + 1 or getparam(t, str(i)) == "or":
      end_arg_set = True
    if end_arg_set:
      # So we can access higher members without array-out-of-bounds errors
      arg_set.extend([""] * 30)
      arg_sets.append(arg_set)
      arg_set = []
    else:
      arg_set.append(getparam(t, str(i)))
  return verb_type, arg_sets

def paste_arg_sets(arg_sets, t, verb_type, rm_pres_stem, as_string,
    change_only=False, is_temp=False):
  first_param = 2 if is_temp else 1
  args = []
  if as_string:
    args.append(verb_type)
  else:
    args.append((str(first_param), verb_type))
  next_numbered_param = first_param + 1
  for arg_set_no, arg_set in enumerate(arg_sets):
    max_arg = -1
    for i in range(len(arg_set)):
      if arg_set[i]:
        max_arg = i
    for i in range(max_arg + 1):
      if arg_set_no > 0 and i == 0:
        if as_string:
          args.append("or")
        else:
          args.append((str(next_numbered_param), "or"))
        next_numbered_param += 1
      if as_string:
        args.append(arg_set[i])
      else:
        args.append((str(next_numbered_param), arg_set[i]))
      next_numbered_param += 1
  for param in t.params:
    pname = str(param.name)
    pvalue = str(param.value)
    if re.search("^[0-9]+$", pname):
      doadd = False
    elif change_only:
      doadd = pname == "pres_stem"
    else:
      doadd = not rm_pres_stem or pname != "pres_stem"
    if doadd:
      if as_string:
        args.append("%s=%s" % (str(param.name), str(param.value)))
      else:
        args.append((str(param.name), str(param.value)))
  return args

def process_page(page, index, parsed):
  global args
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  text = str(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = str(t)
    if tname(t) in ["ru-conj", "ru-conj-old", "User:Benwing2/ru-conj",
        "User:Benwing2/ru-conj-old"] or tname(t) == "temp" and getparam(t, "1") == "ru-conj":
      verb_type, arg_sets = split_ru_conj_args(t, tname(t) == "temp")
      refl = "refl" in verb_type
      orig_arg_sets = copy.deepcopy(arg_sets)
      rm_pres_stem = False

      ##### First, modify arg_sets according to normalized params

      for arg_set in arg_sets:
        # This complex spec matches matches 3°a, 3oa, 4a1a, 6c1a,
        # 1a6a, 6a1as13, 6a1as14, etc.
        m = re.search("^([0-9]+[°o0-9abc]*[abc]s?1?[34]?)", arg_set[0])
        if not m:
          m = re.search("^(irreg-?[абцдеѣфгчийклмнопярстувшхызёюжэщьъ%-]*)", arg_set[0])
          if not m:
            errpagemsg("Unrecognized conjugation type: %s" % arg_set[0])
            continue
        conj_type = m.group(1).replace("o", "°")
        inf, tr = rulib.split_russian_tr(arg_set[1])
        if refl:
          new_style = re.search("([тч]ься|ти́?сь)$", inf)
        else:
          new_style = re.search("([тч]ь|ти́?)$" if conj_type.startswith("7") or conj_type.startswith("irreg") else "[тч]ь$", inf)
        if new_style:
          if arg_set[0].startswith("irreg-"):
            arg_set[0] = re.sub("^irreg-.*?(/.*|$)", r"irreg\1", arg_set[0])
          arg_set[1] = rulib.paste_russian_tr(rulib.remove_monosyllabic_accents(inf),
            rulib.remove_tr_monosyllabic_accents(tr))
        else:
          if not re.search("^[124]", conj_type):
            assert not tr
          if conj_type in ["1a", "2a", "2b"]:
            inf += "ть"
            if tr:
              tr += "tʹ"
          elif conj_type in ["3a", "3°a"]:
            inf += "нуть"
          elif conj_type in ["3b", "3c"]:
            inf += "у́ть"
          elif conj_type == "4a":
            inf += "ить"
            if tr:
              tr += "itʹ"
          elif conj_type in ["4b", "4c"]:
            inf, tr = rulib.make_unstressed(inf, rulib.decompose(tr))
            inf += "ить"
            if tr:
              tr += "ítʹ"
          elif conj_type == "4a1a":
            inf = re.sub("[ая]$", "", inf) + "ить"
            if tr:
              tr = re.sub("j?a$", "", tr) + "itʹ"
          elif conj_type == "5a":
            inf = arg_set[2] + "ть" if arg_set[2] else arg_set[1] + "еть"
            normal_pres_stem = re.sub("[еая]ть$", "", inf)
            if normal_pres_stem == arg_set[1]:
              arg_set[2] = ""
            else:
              arg_set[2] = arg_set[1]
          elif conj_type == "5b":
            inf = arg_set[2] + "ть"
            normal_pres_stem = re.sub("[еая]́ть$", "", inf)
            if normal_pres_stem == arg_set[1]:
              arg_set[2] = ""
            else:
              arg_set[2] = arg_set[1]
          elif conj_type == "5c":
            inf = arg_set[2] + "ть"
            normal_pres_stem = rulib.make_ending_stressed_ru(
              re.sub("[еая]́ть$", "", inf))
            if normal_pres_stem == arg_set[1]:
              arg_set[2] = ""
            else:
              arg_set[2] = arg_set[1]
          elif re.search("^6°?a", conj_type) or conj_type == "1a6a":
            assert not arg_set[3]
            if arg_set[2]:
              inf = arg_set[2] + "ть"
              arg_set[2] = ""
              normal_pres_stem = rulib.make_ending_stressed_ru(
                re.sub("а́ть$", "", inf))
              assert arg_set[1] == normal_pres_stem
            elif is_vowel_stem(inf):
              inf += "ять"
            else:
              inf += "ать"
            if getparam(t, "pres_stem"):
              arg_set[2] = getparam(t, "pres_stem")
              rm_pres_stem = True
          elif re.search("^6°?b", conj_type):
            if is_vowel_stem(inf):
              inf += "я́ть"
            else:
              inf += "а́ть"
            # arg_set[2] (present stem) remains
          elif re.search("^6°?c", conj_type):
            inf = rulib.make_unstressed_once_ru(inf) + "а́ть"
          elif conj_type in ["7a", "7b"]:
            pass # nothing needed to do
          elif conj_type in ["8a", "8b"]:
            inf = arg_set[2]
            arg_set[2] = arg_set[1]
          elif conj_type == "9a":
            inf += "еть"
            # arg_set[2] (present stem) remains
          elif conj_type == "9b":
            inf = rulib.make_unstressed_once_ru(inf) + "е́ть"
            # arg_set[2] (present stem) remains
            # arg_set[3] (optional past participle stem) remains
          elif conj_type == "10a":
            inf += "оть"
          elif conj_type == "10c":
            inf += "ть"
            if rulib.make_unstressed_once_ru(arg_set[2]) == re.sub("о́$", "", arg_set[1]):
              arg_set[2] = ""
          elif conj_type == "11a":
            inf += "ить"
          elif conj_type == "11b":
            inf += "и́ть"
            if arg_set[2] == arg_set[1]:
              arg_set[2] = ""
          elif conj_type == "12a":
            inf += "ть"
            if arg_set[2] == arg_set[1]:
              arg_set[2] = ""
          elif conj_type == "12b":
            inf += "ть"
            if rulib.make_ending_stressed_ru(arg_set[2]) == arg_set[1]:
              arg_set[2] = ""
          elif conj_type == "13b":
            inf += "ть"
            assert re.sub("ва́ть$", "", inf) == arg_set[2]
            arg_set[2] = ""
          elif conj_type in ["14a", "14b", "14c"]:
            inf += "ть"
            # arg_set[2] (present stem) remains
          elif conj_type in ["15a", "16a", "16b"]:
            inf += "ть"
          elif conj_type == "irreg-минуть":
            inf = "мину́ть"
          elif conj_type == "irreg-живописать-миновать":
            inf += "ть"
            arg_set[2] = ""
          elif conj_type == "irreg-слыхать-видать":
            inf += "ть"
          elif conj_type == "irreg-стелить-стлать":
            inf = arg_set[2] + inf + "ть"
            arg_set[2] = ""
            arg_set[3] = ""
          elif conj_type == "irreg-ссать-сцать":
            assert arg_set[2] == re.sub("а́$", "", inf)
            inf = arg_set[3] + inf + "ть"
            arg_set[2] = ""
            arg_set[3] = ""
          elif conj_type in ["irreg-сыпать", "irreg-ехать", "irreg-ѣхать"]:
            infstem = re.sub("^irreg-", "", conj_type)
            if arg_set[1] != "вы́":
              infstem = rulib.make_beginning_stressed_ru(infstem)
            inf = arg_set[1] + infstem
          elif conj_type == "irreg-обязывать":
            if arg_set[1] == "вы́":
              inf = "вы́обязывать"
            else:
              inf = arg_set[1] + "обя́зывать"
          elif conj_type == "irreg-зиждиться":
            if arg_set[1] == "вы́":
              inf = "вы́зиждить"
            else:
              inf = arg_set[1] + "зи́ждить"
          elif conj_type == "irreg-идти":
            if not arg_set[1]:
              inf = "идти́"
            elif arg_set[1] == "вы́":
              inf = "вы́йти"
            else:
              inf = arg_set[1] + "йти́"
          elif re.search("^irreg-", conj_type):
            infstem = re.sub("^irreg-", "", conj_type)
            if arg_set[1] != "вы́":
              infstem = rulib.make_ending_stressed_ru(infstem)
            inf = arg_set[1] + infstem
          else:
            error("Unknown conjugation type " + conj_type)
          if inf:
            if refl:
              if re.search("[тч]ь$", inf):
                inf += "ся"
                if tr:
                  tr += "sja"
              else:
                assert re.search("и́?$", inf)
                inf += "сь"
                if tr:
                  tr += "sʹ"
            arg_set[1] = rulib.paste_russian_tr(rulib.remove_monosyllabic_accents(inf),
             rulib.remove_tr_monosyllabic_accents(tr))

      ##### If something changed ...

      if orig_arg_sets != arg_sets or rm_pres_stem:

        ##### ... compare the forms generated by the original and new
        ##### arguments and make sure they're the same.

        if not pagetitle.startswith("User:Benwing2/"):
          # 1. Generate and expand the appropriate call to
          #    {{ru-generate-verb-forms}} for the original arguments.

          orig_args = paste_arg_sets(orig_arg_sets, t, verb_type,
            rm_pres_stem=False, as_string=True)
          orig_tempcall = "{{ru-generate-verb-forms|%s%s}}" % (
              "|".join(orig_args), "|old=1" if tname(t).endswith("ru-conj-old") else "")
          orig_result = expand_text(orig_tempcall)
          if not orig_result:
            errpagemsg("WARNING: Error expanding original template %s" % orig_tempcall)
            continue
          orig_forms = blib.split_generate_args(orig_result)

          # 2. Generate and expand the appropriate call to
          #    {{ru-generate-verb-forms}} for the new arguments.

          new_args = paste_arg_sets(arg_sets, t, verb_type,
            rm_pres_stem, as_string=True)
          new_tempcall = "{{ru-generate-verb-forms|%s%s}}" % (
              "|".join(new_args), "|old=1" if tname(t).endswith("ru-conj-old") else "")
          new_result = expand_text(new_tempcall)
          if not new_result:
            errpagemsg("WARNING: Error expanding new template %s" % new_tempcall)
            continue
          new_forms = blib.split_generate_args(new_result)

          # 3. Compare each form and accumulate a list of mismatches.

          all_keys = set(orig_forms.keys()) | set(new_forms.keys())
          def sort_numbers_first(key):
            if re.search("^[0-9]+$", key):
              return "%05d" % int(key)
            return key
          all_keys = sorted(list(all_keys), key=sort_numbers_first)
          mismatches = []
          for key in all_keys:
            origval = orig_forms.get(key, "<<missing>>")
            newval = new_forms.get(key, "<<missing>>")
            if origval != newval:
              mismatches.append("%s: old=%s new=%s" % (key, origval, newval))

          # 4. If mismatches, output them and don't change anything.

          if mismatches:
            errpagemsg("WARNING: Mismatch comparing old %s to new %s: %s" % (
              orig_tempcall, new_tempcall, " || ".join(mismatches)))
            continue

        # 5. If no mismatches, modify the template to contain the new args.

        new_params = paste_arg_sets(arg_sets, t, verb_type, rm_pres_stem,
          as_string=False, is_temp=tname(t) == "temp")
        del t.params[:]
        if tname(t) == "temp":
          t.add("1", "ru-conj")
        for name, value in new_params:
          t.add(name, value)

        # 6. Build up the save comment.

        orig_changed_params = paste_arg_sets(orig_arg_sets, t, verb_type,
          rm_pres_stem=False, as_string=True, change_only=True)
        new_changed_params = paste_arg_sets(arg_sets, t, verb_type,
          rm_pres_stem, as_string=True, change_only=True)
        notes.append("ru-conj: normalized %s to %s" % (
          "|".join(orig_changed_params), "|".join(new_changed_params)))

      newt = str(t)
      if origt != newt:
        pagemsg("Replaced %s with %s" % (origt, newt))

  return str(parsed), notes

parser = blib.create_argparser("Fix up verb conjugations to use the infinitive",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_refs=["Template:ru-conj-old"],
  default_cats=["Russian irregular verbs", "Russian verbs"])

for pagename, index in [
  ("User:Benwing2/test-ru-verb", 1),
  ("User:Benwing2/test-ru-verb-2", 2),
  ("Module:ru-verb/documentation", 1)
]:
  blib.do_edit(pywikibot.Page(site, pagename), index, process_page,
  save=args.save, verbose=args.verbose, diff=args.diff)
