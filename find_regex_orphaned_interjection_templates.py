#!/usr/bin/env python3
# -*- coding: utf-8 -*-

templates_to_do = [
  ("am-interjection", "Amharic"),
  ("arc-interj", "Aramaic"),
  ("arc-intj", "Aramaic"),
  ("as-interj", "Assamese"),
  ("axm-interj", "Middle Armenian"),
  ("cel-interj", "Proto-Celtic"),
  ("ckb-interjection", "Central Kurdish"),
  ("da-interj", "Danish"),
  ("egy-interj", "Egyptian"),
  ("el-interj", "Greek"),
  ("et-interjection", "Estonian"),
  ("eu-interj", "Basque"),
  ("evn-interjection", "Evenki"),
  ("fi-int", "Finnish"),
  ("is-interjection", "Icelandic"),
  ("jam-interj", "Jamaican Creole"),
  ("kn-interj", "Kannada"),
  ("la-interj", "Latin"),
  ("lt-interj", "Lithuanian"),
  ("mi-interj", "Maori"),
  ("ml-interj", "Malayalam"),
  ("mr-interj", "Marathi"),
  ("mwr-interjection", "Marwari"),
  ("nrf-intj", "Norman"),
  ("ny-interj", "Chichewa"),
  ("pt-interj", "Portuguese"),
  ("ro-interj", "Romanian"),
  ("sco-interj", "Scots"),
  ("sco-intj", "Scots"),
  ("sq-interj", "Albanian"),
  ("srs-interjection", "Tsuut'ina"),
  ("sv-interjection", "Swedish"),
  ("syc-interj", "Classical Syriac"),
  ("syc-intj", "Classical Syriac"),
  ("tok-int", "Toki Pona"),
  ("tr-interj", "Turkish"),
  ("tr-interjection", "Turkish"),
  ("tyz-interj", "Tày"),
  ("xcl-interj", "Old Armenian"),
  ("xcl-interjection", "Old Armenian"),
]

for temp, lang in templates_to_do:
  #cmd = f"python3 find_regex.py --refs 'Template:{temp}' --lang '{lang}' --text > find_regex.{temp}.out.1.orig"
  #print(f'echo "python3 find_regex.py --refs \'Template:{temp}\' --lang \'{lang}\' --text > find_regex.{temp}.out.1.orig"')
  #print(cmd)
  #cmd = f"cp 'find_regex.{temp}.out.1.orig' 'find_regex.{temp}.out.1'"
  #print(f'echo "{cmd}"')
  #print(cmd)
  cmd = f"python3 push_find_regex_changes.py --direcfile find_regex.{temp}.out.1 --origfile find_regex.{temp}.out.1.orig --comment 'obsolete/orphan {{{{{temp}}}}} per [[WT:RFDO#interjection templates]] (manually assisted)' --diff --save --lang '{lang}' > push_find_regex_changes.find_regex.{temp}.out.1.out.1.save"
  print(f'echo "{cmd}"')
  print(cmd)
