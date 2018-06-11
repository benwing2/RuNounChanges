#!/usr/bin/env python
#coding: utf-8

#    extract_lemmas.py is free software: you can redistribute it and/or modify
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

import re, sys, codecs, argparse

from blib import msg, errmsg
import rulib

parser = argparse.ArgumentParser(description="Generate adjective stubs.")
parser.add_argument('--direcfile', help="File containing directives.")
args = parser.parse_args()

lemmas = set()

for line in codecs.open(args.direcfile, "r", "utf-8"):
  line = line.strip()
  if "Would save with comment" in line:
    m = re.search("Would save with comment.* (?:of|dictionary form) (.*?)(,| after| \(add| \(modify|$)", line)
    if not m:
      errmsg("WARNING: Unable to parse line: %s" % line)
    else:
      lemmas.add(rulib.remove_accents(m.group(1)))
for lemma in sorted(lemmas):
  print lemma.encode('utf-8')
