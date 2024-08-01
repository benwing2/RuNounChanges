#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse, json, re

parser = argparse.ArgumentParser(description="Create boilerplate entries from Old Polish JSON dump.")
parser.add_argument('--direcfile', help="File containing JSON.", required=True)
args = parser.parse_args()

boilerplate = """
==Old Polish==

===Alternative forms===
* {{alt|zlw-opl|}}

===Etymology===
{{bor+|zlw-opl|}}. {{etydate|}}.
{{dercat|zlw-opl|ine-bsl-pro|ine-pro|inh=2}}
{{inh+|zlw-opl|sla-pro|*}}. {{surf|zlw-opl|}}. {{etydate|}}.
From {{af|zlw-opl|}}. {{etydate|}}.

===Pronunciation===
* {{zlw-opl-IPA}}

===%s===
{{zlw-opl|}}

# {{lb|zlw-opl|attested in|}} [[]]
#* {{RQ:zlw-opl:||-}}

====Descendants====
* {{desc|zlw-mas|}}
* {{desc|pl|}}
* {{desc|szl|}}

===References===
* {{R:pl:Boryś}}
* {{R:pl:Mańczak}}
* {{R:pl:Bańkowski}}
* {{R:pl:Sławski}}
* {{R:zlw-opl:SPJSP}}
* {{R:zlw-opl:Rozariusze|+|}}

{{C|zlw-opl|}}
"""

data = json.loads(open(args.direcfile).read())
for k, v in data.items():
  index = int(k) + 1
  pagename = v["pagename"]
  defs = v["defs"]
  for defn, quotes in defs.items():
    for quotenum, quote in enumerate(quotes):
      quote_type = quote["typ"]
      rodzaj = quote["rodzaj"]
      numer = quote["numer"]
      funkcja = quote.get("funkcja", "")
      gramatyka = quote.get("gramatyka", "")
      semantyka = quote.get("semantyka", "")
      def clean_up_html(text):
        return text.replace("&lt", "<").replace("&gt", ">")
      defn = clean_up_html(defn)
      uwagi = clean_up_html(quote.get("uwagi", ""))
      orig = clean_up_html(quote["transliteracji"])
      def split_quote_year(val):
        m = re.search(r"^(.*?) (?:\(([0-9][0-9][0-9][0-9])\) )?((?:ca )?(?:[0-9][0-9][0-9][0-9](?:[-–—][0-9]+)?|X[XIV]*(?: (?:ex|med|p\. *pr|p\. *in|p\. *post))?))?\.?$", val)
        if m:
          val, paren_year, year = m.groups()
          if paren_year:
            published_year = year or ""
            year = paren_year
          else:
            year = year or ""
            published_year = ""
        else:
          year = ""
          published_year = ""
        year = re.sub("^ca ", "c. ", year)
        published_year = re.sub("^ca ", "c. ", published_year)
        return val, year, published_year
      orig, origyear, origpublished_year = split_quote_year(orig)
      norm = clean_up_html(quote["transkrypcji"])
      norm, normyear, normpublished_year = split_quote_year(norm)
      source = quote["lokalizacja"]
      line = [index, pagename, defn, quotenum + 1, orig, origyear, origpublished_year, norm, normyear,
              normpublished_year, source, quote_type, rodzaj, numer, funkcja, gramatyka, semantyka, uwagi]
      print("\t".join("%s" % x for x in line))
