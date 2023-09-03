#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import fileinput, sys

for lineind, line in enumerate(fileinput.input()):
  def msg(txt, fil=sys.stdout):
    print("Line %s: %s" % (lineind + 1, txt))
  def warn(txt):
    msg(txt, fil=sys.stderr)
  chars = list(line)
  out = []
  def ins(txt):
    out.append(txt)
  in_double_quote_string = False
  in_single_quote_string = False
  in_comment = False
  i = 0
  def get(ind):
    if ind >= 0 and ind < len(chars):
      return chars[ind]
    else:
      return None
  must_break = False
  while i < len(chars):
    ch = chars[i]
    if ch == "-" and get(i + 1) == "-": # comment
      ins("".join(chars[i:]))
      break
    if ch == '"' or ch == "'": # start of string
      saw_double_quote = False
      strchars = [ch]
      def istr(txt):
        strchars.append(txt)
      j = i + 1
      while True:
        nch = get(j)
        if nch == "\\":
          nnch = get(j + 1)
          if nnch is None or nnch == "\n":
            warn("Backslash at end of line")
            istr(nch)
            if nnch:
              istr(nnch)
            ins("".join(strchars))
            must_break = True
            break
          istr(nch)
          istr(nnch)
          j += 2
        elif nch is None or nch == "\n":
          warn("Unterminated string")
          if nch:
            istr(nch)
          ins("".join(strchars))
          must_break = True
          break
        elif nch == ch: # end of string
          if ch == '"' or ch == "'" and saw_double_quote:
            # copy string unchanged
            istr(nch)
            ins("".join(strchars))
            i = j + 1
            break
          istr(nch)
          strchars[0] = '"'
          strchars[-1] = '"'
          # change backslashed single quotes to regular quotes
          k = 0
          while k < len(strchars):
            kch = strchars[k]
            if kch == "\\" and strchars[k + 1] == "'":
              ins("'")
              k += 2
            elif kch == "\\":
              ins(kch)
              ins(strchars[k + 1])
              k += 2
            else:
              ins(kch)
              k += 1
          i = j + 1
          break
        else:
          if ch == "'" and nch == '"':
            saw_double_quote = True
          istr(nch)
          j += 1
    else:
      ins(ch)
      i += 1
    if must_break:
      break
  sys.stdout.write("".join(out))
