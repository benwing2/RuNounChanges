#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Author: Benwing; bits and pieces taken from code written by CodeCat/Rua for MewBot

import pywikibot, mwparserfromhell, re, string, sys, urllib, datetime, json, argparse, time
from collections import defaultdict
import xml.sax
import difflib
import traceback
import unicodedata
import multiprocessing as mp
from json.decoder import JSONDecodeError

site = pywikibot.Site()

appendix_only_langnames = [
  "Adûni",
  "Afrihili",
  "Belter Creole",
  "Black Speech",
  "Bolak",
  "Communicationssprache",
  "Dothraki",
  "Eloi",
  "Glosa",
  "Goa'uld",
  "High Valyrian",
  "Interlingue",
  "Interslavic",
  "Klingon",
  "Kotava",
  "Láadan",
  "Lapine",
  "Lingua Franca Nova",
  "Lojban",
  "Mandalorian",
  "Medefaidrin",
  "Mundolinco",
  "Na'vi",
  "Neo",
  "Novial",
  "Noxilo",
  "Quenya",
  "Romanova",
  "Sindarin",
  "Talossan",
  "Toki Pona",
  "Unas",
]

lemma_poses = [
  "Abbreviation",
  "Acronym",
  "Adjectival noun", # Japanese-specific
  "Adjective",
  "Adnominal",
  "Adposition",
  "Adverb",
  "Affix",
  "Ambiposition",
  "Article",
  "Cardinal number",
  "Circumfix",
  "Circumposition",
  "Classifier",
  "Combined form",
  "Combining form",
  "Confix",
  "Conjunction",
  "Contraction",
  "Converb",
  "Counter",
  "Determiner",
  "Diacritical mark",
  "Gerund",
  "Han character",
  "Han tu",
  "Hanja",
  "Hanzi",
  "Ideophone",
  "Idiom",
  "Infinitive",
  "Infix",
  "Initialism",
  "Interfix",
  "Interjection",
  "Jyutping",
  "Kanji",
  "Kanji reading",
  "Letter",
  "Ligature",
  "Misspelling",
  "Morpheme",
  "Noun",
  "Number",
  "Numeral",
  "Numeral symbol",
  "Particle",
  "Participle",
  "Pinyin",
  "Phrase",
  "Postposition",
  "Postpositional phrase",
  "Predicative",
  "Prefix",
  "Preposition",
  "Prepositional phrase",
  "Preverb",
  "Pronominal adverb",
  "Pronoun",
  "Proper noun",
  "Proverb",
  "Punctuation mark",
  "Relative",
  "Romaji",
  "Romanization",
  "Root",
  "Singulative",
  "Stem",
  "Suffix",
  "Syllable",
  "Symbol",
  "Verb",
]

re_escaped_lemma_poses = [re.escape(k) for k in lemma_poses]
pos_regex = "==(%s)==" % "|".join(re_escaped_lemma_poses)

# Don't include t-simple here because it also has a langname= param that may need changing. (In any case, t-simple
# has been deleted.)
translation_templates = ["t", "t+", "tt", "tt+", "t-", "t+check", "tt+check", "t-check", "t-needed"]
label_templates = ["lb", "lbl", "label", "tlb", "term-label"]
qualifier_templates = ["q", "qual", "qualifier", "i", "qf", "q-lite"]

def remove_links(text):
  # eliminate [[FOO| in [[FOO|BAR]], and then remaining [[ and ]]
  text = re.sub(r"\[\[[^\[\]|]*\|", "", text)
  text = re.sub(r"\[\[|\]\]", "", text)
  return text

def remove_right_side_links(text):
  # eliminate |BAR]] in [[FOO|BAR]], and then remaining [[ and ]]
  text = re.sub(r"\|[^\[\]|]*\]\]", "", text)
  text = re.sub(r"\[\[|\]\]", "", text)
  return text

def remove_redundant_links(text):
  # remove redundant link surrounding entire text
  return re.sub(r"^\[\[([^\[\]|]*)\]\]$", r"\1", text)

def escape_newline(text):
  text = re.sub(r"\\([\\n])", lambda m: r"\\\\" if m.group(1) == "\\" else r"\\n", text)
  return text.replace("\n", r"\n")

def undo_escape_newline(text):
  return re.sub(r"\\([\\n])", lambda m: "\\" if m.group(1) == "\\" else "\n", text)

def msg(text):
  print(text)

def msgn(text):
  print(text, end='')

def errmsg(text):
  print(text, file=sys.stderr)

def errmsgn(text):
  print(text, end='', file=sys.stderr)

def errandmsg(text):
  msg(text)
  errmsg(text)

def errmsgn(text):
  msgn(text)
  errmsgn(text)

def rsub_repeatedly(fr, to, text, count=0, flags=0):
  while True:
    newtext = re.sub(fr, to, text, count, flags)
    if newtext == text:
      return text
    text = newtext

def ucfirst(txt):
  if not txt:
    return txt
  return txt[0].upper() + txt[1:]

def parse_text(text):
  return mwparserfromhell.parser.Parser().parse(text, skip_style_tags=True)

def parse(page):
  return parse_text(page.text)

def getparam(template, param):
  if template.has(param):
    return str(template.get(param).value)
  else:
    return ""

def addparam(template, param, value, showkey=None, before=None):
  template.add(param, value, preserve_spacing=False, showkey=showkey, before=before)

def rmparam(template, param):
  if template.has(param):
    template.remove(param)

def getrmparam(template, param):
  val = getparam(template, param)
  rmparam(template, param)
  return val

def bool_param_is_true(param):
  return param and param not in ["0", "no", "n", "false"]

def parse_template_name(name):
  m = re.search("\A(\s*)(.*?)(\s*(?:<!--.*?-->)?\s*)\Z", name, re.S)
  return m.groups()

def tname(template):
  before, name, after = parse_template_name(str(template.name))
  return name

def pname(param):
  before, name, after = parse_template_name(str(param.name))
  return name

def set_template_name(template, name, origname=None):
  if not origname:
    origname = str(template.name)
  before, namepart, after = parse_template_name(origname)
  template.name = before + name + after

def do_assert(cond, msg=None):
  if msg:
    assert cond, msg
  else:
    assert cond
  return True

# Return the name of the first parameter in template T.
def find_first_named_param(t):
  for param in t.params:
    pn = pname(param)
    if not re.search("^[0-9]+$", pn):
      return pn
  return None

# Return the name of the parameter following PARAM in template T.
def find_following_param(t, param):
  for i, par in enumerate(t.params):
    if pname(par) == param:
      if i < len(t.params) - 1:
        return pname(t.params[i + 1])
      else:
        return None
  return None

# Find maximum term index in templates that can take multiple terms. This is intended for templates such as {{affix}}
# and {{head}} that can take multiple terms possibly with gaps in them. This checks a subset of parameters and returns
# the maximum term index found among them. Numeric parameters are only checked if `first_numeric` is not None, in which
# case it should be either an integer or stringified integer (in which case only numeric parameters >= `first_numeric`
# are checked and the term index of the param is the param number minus an offset calculated as one less than
# `first_numeric`, so that e.g. if `first_numeric` is "3", numeric parameter "6" corresponds to term index 4); or a
# function of one argument to convert the param number to a term index (or None to skip the param). Named parameters
# are only checked if `named_params` is not None, in which case it should be:
# * True, meaning all named params are checked, and the term index of a named param is found by decomposing the param
#   name into NAME### i.e. a non-numeric part followed by numbers, and returning ###;
# * a list of prefixes, corresponding to the NAME part of a NAME### param, in which case only params whose non-numeric
#   prefix is NAME are checked and the term index is ###;
# * a function of one argument to convert the param name to a term index (or None to skip the param).
# If no matching params are found, 0 is returned.
def find_max_term_index(t, first_numeric=None, named_params=None):
  if isinstance(first_numeric, str):
    first_numeric = int(first_numeric)

  def find_index(pn):
    if re.search("^[0-9]+$", pn):
      pn = int(pn)
      if callable(first_numeric):
        return first_numeric(pn)
      elif first_numeric is None or pn < first_numeric:
        return None
      else:
        # See comment above why we are adding 1 (equivalently, subtracting one from `first_numeric`).
        return pn - first_numeric + 1
    if callable(named_params):
      return named_params(pn)
    if named_params is None:
      return None
    m = re.search("^(.*?)([0-9]*)$", pn)
    name, index = m.groups()
    if named_params is not True and name not in named_params:
      return None
    return int(index) if index else 1

  retval = 0
  for param in t.params:
    index = find_index(pname(param))
    if index is not None:
      retval = max(retval, index)
  return retval

class ParameterError(Exception):
  pass

# Retrieve a chain of parameters from template `t`, where the first parameter is named `first`, and the remainder are
# named `pref`2, `pref`3, etc. If `pref` is omitted (the default), the remainder are named `first`2, `first`3, etc. if
# `pref` is non-numeric, and sequentially higher numbers if `pref` is numeric. If `pref` is given, `first` can be a list
# of parameters, any of which can be specified. (If `pref` is not given and `first` is a list, an assertion error is
# thrown.) The code also checks for a parameter named `pref`1 (or `first`1 if `pref` is omitted), and uses it as the
# first value if `first` is missing or empty (or, if `first` is a list, all specified parameters are missing or empty).
# Note that if `first` and `pref` are specified, it is an error (see below) if a parameter named `pref` exists (even if
# empty), unless the value of `pref` is contained in the `first` list. If `first` is a list, all members are treated as
# aliases, and it is an error (see below) if more than one parameter in a `first` list has a value (see below). It is
# likewise an error if `pref`1 and any member of `first` both exist, since they are aliases.
#
# Treatment of gaps depends on the value of `holes`. If "close" (the default), holes are closed in the returned list by
# moving all parameters after the gap down by one. If "allow", holes are left with a value of None in the returned list.
# If "disallow", it is an error (see below) if any holes are found.
#
# Handling of parameter errors (see above) depends on the value of `errors`. If "throw" (the default), ParameterError
# is thrown. If "return", a string specifying the error message is returned.
def fetch_param_chain(t, first, pref=None, firstdefault="", holes="close", errors="throw"):
  is_number = pref is None and type(first) is not list and re.search("^[0-9]+$", first)
  assert first != "", "first= may not be an empty string"
  if type(first) is list:
    assert "" not in first, "first= may not contain an empty string"
  assert pref != "", "pref= may not be an empty string"
  assert holes in ["close", "allow", "disallow"], "holes=%s must be one of 'close', 'allow' or 'disallow'" % holes
  if pref is None:
    assert type(first) is not list, "If pref= is omitted, first= must not be a list"
    pref = "" if is_number else first
  ret = []
  if type(first) is not list:
    first = [first]
  saw_first = None
  def handle_error(err):
    if errors == "throw":
      raise ParameterError(err)
    return "Parameter error: %s" % err
  for f in first:
    val = getparam(t, f)
    if val:
      if saw_first is not None:
        return handle_error("Saw both %s= and %s=, which are aliases: %s" % (saw_first, f, str(t)))
      saw_first = f
      ret.append(val)
  if pref:
    if pref not in first and t.has(pref):
      return "Parameter error: Saw unrecognized param %s=: %s" % (pref, str(t))
    param = pref + "1"
    val = getparam(t, param)
    if val:
      if saw_first is not None:
        return handle_error("Saw both %s= and %s=, which are aliases: %s" % (saw_first, param, str(t)))
      saw_first = param
      ret.append(val)
  if saw_first is None:
    ret.append(None)
  assert pref or is_number
  first_num = 2 if pref else int(first[0]) + 1
  maxind = find_max_term_index(t, first_numeric=1) if is_number else find_max_term_index(t, named_params=[pref])
  for i in range(first_num, maxind + 1):
    param = pref + str(i)
    val = getparam(t, param) or None
    if val is None:
      if holes == "allow":
        ret.append(val)
      elif holes == "disallow":
        return handle_error("Saw hole in %s%s= and holes='disallow': %s" % (pref, i, str(t)))
    else:
      ret.append(val)
  if ret[0] is None:
    if len(ret) > 1:
      if holes == "close":
        del ret[0]
      elif holes == "disallow":
        return handle_error("Saw hole at beginning and holes='disallow': %s" % str(t))
    else:
      return [firstdefault] if firstdefault else []
  return ret

def append_param_to_chain(t, val, firstparam, parampref=None, before=None):
  is_number = re.search("^[0-9]+$", firstparam)
  if parampref is None:
    parampref = "" if is_number else firstparam
  paramno = int(firstparam) - 1 if is_number else 0
  if is_number:
    insert_before_param = find_first_named_param(t)
  else:
    insert_before_param = None
  changed = False
  while True:
    paramno += 1
    next_param = firstparam if paramno == 1 and not is_number else "%s%s" % (
        parampref, paramno)
    # When adding a param, we want to add directly after the last-existing param.
    if getparam(t, next_param):
      insert_before_param = find_following_param(t, next_param)
    else:
      t.add(next_param, val, before=before or insert_before_param)
      return next_param

def remove_param_chain(t, firstparam, parampref=None):
  is_number = re.search("^[0-9]+$", firstparam)
  if parampref is None:
    parampref = "" if is_number else firstparam
  paramno = int(firstparam) - 1 if is_number else 0
  changed = False
  while True:
    paramno += 1
    next_param = firstparam if paramno == 1 and not is_number else "%s%s" % (
        parampref, paramno)
    if getparam(t, next_param):
      rmparam(t, next_param)
      changed = True
    else:
      return changed

def set_param_chain(t, values, firstparam, parampref=None, before=None, preserve_spacing=True):
  is_number = re.search("^[0-9]+$", firstparam) and not parampref
  if parampref is None:
    parampref = "" if is_number else firstparam
  paramno = int(firstparam) - 1 if is_number else 0
  if is_number:
    insert_before_param = find_first_named_param(t)
  else:
    insert_before_param = None
  first = True
  for val in values:
    paramno += 1
    next_param = firstparam if first else "%s%s" % (parampref, paramno)
    # When adding a param, if the param already exists, we want to just replace the param.
    # Otherwise, we want to add directly after the last-added param.
    if t.has(next_param):
      t.add(next_param, val, before=before, preserve_spacing=preserve_spacing)
    else:
      t.add(next_param, val, before=before or insert_before_param, preserve_spacing=preserve_spacing)
    insert_before_param = find_following_param(t, next_param)
    first = False
  for i in range(paramno + 1, 30):
    next_param = firstparam if first else "%s%s" % (parampref, i)
    first = False
    rmparam(t, next_param)

def sort_params(t):
  numbered_params = []
  named_params = []
  for param in t.params:
    if re.search(r"^[0-9]+$", str(param.name)):
      numbered_params.append((param.name, param.value))
    else:
      named_params.append((param.name, param.value))
  numbered_params.sort(key=lambda nameval: int(str(nameval[0])))
  del t.params[:]
  for name, value in numbered_params:
    t.add(name, value)
  for name, value in named_params:
    t.add(name, value)

def changelog_to_string(comment):
  if type(comment) is list:
    comment = "; ".join(group_notes(comment))
  return comment

def show_diff(existing_text, newtext):
  oldlines = existing_text.splitlines(True)
  newlines = newtext.splitlines(True)
  diff = difflib.unified_diff(oldlines, newlines)
  dangling_newline = False
  for line in diff:
    dangling_newline = not line.endswith('\n')
    sys.stdout.write(line)
    if dangling_newline:
      sys.stdout.write("\n")
  if dangling_newline:
    sys.stdout.write("\\ No newline at end of file\n")
  #pywikibot.showDiff(existing_text, new, context=3)

def normalize_text_for_save(text):
  # MediaWiki strips newlines from the end of the page and converts to NFC; we convert to NFC for comparison but we
  # can't strip newlines because we might be dealing with a partial page when using --find-regex.
  return unicodedata.normalize("NFC", text)

def handle_process_page_retval(retval, existing_text, pagemsg, verbose, do_diff):
  has_changed = False

  if retval is None:
    new = None
    comment = None
  else:
    new, comment = retval

  if new:
    new = str(new)

    existing_text = normalize_text_for_save(existing_text)
    new = normalize_text_for_save(new)
    has_changed = existing_text != new
    if has_changed:
      if do_diff:
        pagemsg("Diff:")
        show_diff(existing_text, new)
      elif verbose:
        pagemsg("Replacing <%s> with <%s>" % (existing_text, new))
      assert comment, "Text has changed without a comment specified"

  comment = changelog_to_string(comment)
  return new, comment, has_changed

def expand_text(tempcall, pagetitle, pagemsg, verbose, suppress_errors=False):
  if verbose:
    pagemsg("Expanding text: %s" % tempcall)
  result = try_repeatedly(lambda: site.expand_text(tempcall, title=pagetitle), pagemsg, "expand text: %s" % tempcall, bad_value_ret='<strong class="error">Invalid title</strong>')
  if verbose:
    pagemsg("Raw result is %s" % result)
  if result.startswith('<strong class="error">'):
    result = re.sub("<.*?>", "", result)
    if not verbose:
      pagemsg("Expanding text: %s" % tempcall)
    if not suppress_errors:
      pagemsg("WARNING: Got error: %s" % result)
    return False
  return result

# For use inside of expand_text in EditParams below.
def blib_expand_text(tempcall, pagetitle, pagemsg, verbose):
  return expand_text(tempcall, pagetitle, pagemsg, verbose)

class EditParams(object):
  def __init__(self, index, page, save=False, verbose=False, diff=False):
    self.index = index
    self.page = page
    self.title = str(page.title())
    self.save = save
    self.verbose = verbose
    self.diff = diff

  def pagemsg(self, txt):
    msg("Page %s %s: %s" % (self.index, self.title, txt))

  def errandpagemsg(self, txt):
    errandmsg("Page %s %s: %s" % (self, index, self, title, txt))

  def expand_text(self, tempcall):
    return blib_expand_text(tempcall, self.title, self.pagemsg, self.verbose)

def new_do_edit(index, page, func=None, null=False, save=False, verbose=False, diff=False):
  p = EditParams(index, page, save=save, verbose=verbose, diff=diff)
  while True:
    try:
      if func:
        if verbose:
          p.pagemsg("Begin processing")
        retval = func(page, index, parse(page))
        new, comment, has_changed = handle_process_page_retval(retval, page.text, p.pagemsg, verbose, diff)
        if has_changed:
          page.text = new
          if save:
            p.pagemsg("Saving with comment = %s" % comment)
            safe_page_save(page, comment, p.errandpagemsg)
          else:
            p.pagemsg("Would save with comment = %s" % comment)
        elif null:
          p.pagemsg("Purged page cache")
          safe_page_purge(page, p.errandpagemsg)
        elif comment:
          p.pagemsg("Skipped: %s" % comment)
        else:
          p.pagemsg("Skipped, no changes")
      else:
        p.pagemsg("Purged page cache")
        safe_page_purge(page, p.errandpagemsg)
    except urllib.error.HTTPError as e:
      if e.code != 503: # Service unavailable
        raise
    except:
      p.errandpagemsg("WARNING: Error")
      raise

    break

def do_edit(page, index, func=None, null=False, save=False, verbose=False, diff=False):
  title = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, title, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, title, txt))
  while True:
    try:
      if func:
        if verbose:
          pagemsg("Begin processing")
        retval = func(page, index, parse(page))

        new, comment, has_changed = handle_process_page_retval(retval, page.text, pagemsg, verbose, diff)
        if has_changed:
          def assign_changed_page():
            page.text = new
          try_repeatedly(assign_changed_page, errandpagemsg, "assign changed page to 'page.text'")
          if save:
            pagemsg("Saving with comment = %s" % comment)
            safe_page_save(page, comment, errandpagemsg)
          else:
            pagemsg("Would save with comment = %s" % comment)
        elif null:
          pagemsg("Purged page cache")
          safe_page_purge(page, errandpagemsg)
        elif comment:
          pagemsg("Skipped: %s" % comment)
        else:
          pagemsg("Skipped, no changes")
      else:
        pagemsg("Purged page cache")
        safe_page_purge(page, errandpagemsg)
    except urllib.error.HTTPError as e:
      if e.code != 503: # Service unavailable
        raise
    except:
      errandpagemsg("WARNING: Error")
      raise

    break

# we special-case anything with " talk:" in the title
talk_prefixes = ["Talk:", "Thread:",
  "Wiktionary:Beer parlour", "Wiktionary:Translation requests",
  "Wiktionary:Grease pit", "Wiktionary:Etymology scriptorium",
  "Wiktionary:Information desk", "Wiktionary:Tea room",
  "Wiktionary:Requests", "Wiktionary:Requested",
  "Wiktionary:Wikimedia Tech News", "Wiktionary:Feedback",
  "Wiktionary:Word of the day", "Wiktionary:Foreign Word of the Day",
  "Wiktionary:Sandbox", "Wiktionary:Votes", "Wiktionary:Wanted entries"
]

non_talk_ignore_regexps = ["^Module:", "^MediaWiki:", r"\.js$", r"\.css$"]

def is_talk_page(pagetitle):
  for tp in talk_prefixes:
    if pagetitle.startswith(tp):
      return True
  if " talk:" in pagetitle:
    return True
  return False

def page_should_be_ignored(pagetitle, allow_user_pages=False):
  # Ignore discussion pages and certain other pages, e.g. user pages
  if is_talk_page(pagetitle):
    return True
  for ignore_re in non_talk_ignore_regexps:
    if re.search(ignore_re, pagetitle):
      return True
  if not allow_user_pages and pagetitle.startswith("User:"):
    return True
  return False

# FIXME: Deprecated. Eliminate.
def iter_pages(pageiter, startprefix = None, endprefix = None, key = None):
  i = 0
  t = None
  steps = 50

  for current in pageiter:
    i += 1

    if startprefix != None and isinstance(startprefix, int) and i < startprefix:
      continue

    if key:
      keyval = key(current)
      pagetitle = keyval
    elif isinstance(current, str):
      keyval = current
      pagetitle = keyval
    else:
      keyval = current.title(withNamespace=False)
      pagetitle = str(current.title())
    if endprefix != None:
      if isinstance(endprefix, int):
        if i > endprefix:
          break
      else:
        if keyval >= endprefix:
          break

    if not t and isinstance(endprefix, int):
      t = datetime.datetime.now()

    # Ignore user pages, talk pages and certain Wiktionary pages
    if not page_should_be_ignored(pagetitle):
      yield current, i

    if i % steps == 0:
      tdisp = ""

      if isinstance(endprefix, int):
        told = t
        t = datetime.datetime.now()
        pagesleft = (endprefix - i) / steps
        tfuture = t + (t - told) * pagesleft
        tdisp = ", est. " + tfuture.strftime("%X")

      errmsg(str(i) + "/" + str(endprefix) + tdisp)


def references(page, startprefix = None, endprefix = None, namespaces = None,
    only_template_inclusion = False, filter_redirects = False, include_page = False):
  if isinstance(page, str):
    page = pywikibot.Page(site, page)
  pageiter = page.getReferences(only_template_inclusion = only_template_inclusion,
      namespaces = namespaces, filter_redirects = filter_redirects)
  if include_page:
    pages = [page] + list(pageiter)
  else:
    pages = pageiter
  for i, current in iter_items(pages, startprefix, endprefix):
    yield i, current

def get_contributions(user, startprefix=None, endprefix=None, max=None, namespaces=None):
  """Get contributions for a given user."""
  itemiter = site.usercontribs(user=user, namespaces=namespaces, total=max)
  for i, current in iter_items(itemiter, startprefix, endprefix, get_name=lambda item: item['title']):
    yield i, current

def yield_articles(page, seen, startprefix=None, prune_cats_regex=None, recurse=False):
  if not recurse:
    # Only use when non-recursive. Has a recurse= flag but doesn't allow for prune_cats_regex, doesn't correctly
    # ignore subcats and pages that may be seen multiple times.
    for article in page.articles(startprefix=startprefix):
      if seen is None:
        yield article
      else:
        pagetitle = str(article.title())
        if pagetitle not in seen:
          seen.add(pagetitle)
          yield article
  else:
    for subcat in yield_subcats(page, seen, prune_cats_regex=prune_cats_regex, do_this_page=True, recurse=True):
      for article in subcat.articles(startprefix=startprefix):
        if seen is None:
          yield article
        else:
          pagetitle = str(article.title())
          if pagetitle not in seen:
            seen.add(pagetitle)
            yield article

def raw_cat_articles(page, seen, startprefix=None, prune_cats_regex=None, recurse=False):
  if isinstance(page, str):
    if not page.startswith("Category:"):
      page = "Category:" + page
    page = pywikibot.Category(site, page)
  for article in yield_articles(page, seen, startprefix=startprefix, prune_cats_regex=prune_cats_regex, recurse=recurse):
    yield article

def cat_articles(page, startprefix=None, endprefix=None, seen=None, prune_cats_regex=None, recurse=False, track_seen=False):
  if seen is None and track_seen:
    seen = set()
  for i, current in iter_items(raw_cat_articles(page, seen, startprefix=startprefix if not isinstance(startprefix, int) else None,
      prune_cats_regex=prune_cats_regex, recurse=recurse), startprefix, endprefix):
    yield i, current

def yield_subcats(page, seen, prune_cats_regex=None, do_this_page=False, recurse=False):
  if seen is not None:
    pagetitle = str(page.title())
    if pagetitle in seen:
      return
    seen.add(pagetitle)
  if prune_cats_regex:
    this_cat = re.sub("^Category:", "", str(page.title()))
    if re.search(prune_cats_regex, this_cat):
      msg("Pruned category '%s'" % this_cat)
      return
  if do_this_page:
    yield page
  subcats = page.subcategories()
  if recurse:
    for subcat in subcats:
      for cat in yield_subcats(subcat, seen, prune_cats_regex=prune_cats_regex, do_this_page=True, recurse=True):
        yield cat
  else:
    for subcat in subcats:
      if seen is None:
        yield subcat
      else:
        pagetitle = str(subcat.title())
        if pagetitle not in seen:
          seen.add(pagetitle)
          yield subcat

def cat_subcats(page, startprefix=None, endprefix=None, seen=None, prune_cats_regex=None, do_this_page=False, recurse=False):
  if seen is None:
    seen = set()
  if isinstance(page, str):
    if not page.startswith("Category:"):
      page = "Category:" + page
    page = pywikibot.Category(site, page)
  pageiter = yield_subcats(page, seen, prune_cats_regex=prune_cats_regex, do_this_page=do_this_page, recurse=recurse)
  # Recursive support is built into page.subcategories() but it isn't smart enough to skip pages
  # already seen, which can lead to infinite loops, e.g. ku:All topics -> ku:List of topics -> ku:All topics.
  # pageiter = page.subcategories(recurse=recurse) #no startprefix; startprefix = startprefix if not isinstance(startprefix, int) else None)
  for i, current in iter_items(pageiter, startprefix, endprefix):
    yield i, current

def prefix_pages(prefix, startprefix=None, endprefix=None, namespace=None, filter_redirects=None):
  pageiter = site.allpages(
    prefix=None if prefix == '-' else prefix, namespace=namespace,
    start=startprefix if isinstance(startprefix, str) else None,
    filterredir=filter_redirects
  )
  for i, current in iter_items(pageiter, startprefix, endprefix):
    yield i, current

def query_special_pages(specialpage, startprefix=None, endprefix=None):
  for i, current in iter_items(site.querypage(specialpage, total=None), startprefix, endprefix):
    yield i, current

def query_usercontribs(username, startprefix=None, endprefix=None, starttime=None, endtime=None):
  for i, current in iter_items(site.usercontribs(user=username, start=starttime, end=endtime), startprefix, endprefix,
      get_name=lambda item: item['title']):
    yield i, current

def stream(st, startprefix=None, endprefix=None):
  i = 0

  for name in st:
    i += 1

    if startprefix != None and i < startprefix:
      continue
    if endprefix != None and i > endprefix:
      break

    name = re.sub(r"^[#*] *\[\[(.+)]]$", r"\1", name)

    yield i, pywikibot.Page(site, name)

def split_arg(arg, canonicalize=None):
  def process(pagename):
    if canonicalize:
      pagename = canonicalize(pagename)
    return pagename
  return [process(x) for x in re.split(r",(?=[^ ])", arg)]

def yield_items_from_file(filename, canonicalize=None, include_original_lineno=False, preserve_blank_lines=False):
  lineno = 0
  for line in open(filename, "r", encoding="utf-8"):
    lineno += 1
    line = line.strip()
    if line.startswith("#"):
      continue
    if not line and not preserve_blank_lines:
      continue
    if canonicalize:
      line = canonicalize(line)
    if include_original_lineno:
      yield lineno, line
    else:
      yield line

def iter_items_from_file(filename, startprefix=None, endprefix=None, canonicalize=None,
    preserve_blank_lines=False, skip_ignorable_pages=False):
  file_items = yield_items_from_file(filename, canonicalize=canonicalize,
      include_original_lineno=True, preserve_blank_lines=preserve_blank_lines)
  for _, (index, line) in iter_items(file_items, startprefix=startprefix, endprefix=endprefix, get_name=lambda x:x[1], get_index=lambda x:x[0],
      skip_ignorable_pages=skip_ignorable_pages):
    yield index, line

def get_page_name(page):
  if isinstance(page, str):
    return page
  # FIXME: withNamespace=False was used previously by cat_articles, in a
  # line like this:
  #    elif current.title(withNamespace=False) >= endprefix:
  # Should we add this flag or support an option to add it?
  #return str(page.title(withNamespace=False))
  return str(page.title())

class ProcessItems(object):
  def __init__(self, startprefix=None, endprefix=None, get_name=get_page_name,
      skip_ignorable_pages=False):
    self.startprefix = startprefix
    self.endprefix = endprefix
    self.get_name = get_name
    self.skip_ignorable_pages = skip_ignorable_pages
    self.i = 0
    self.t = None
    self.steps = 50
    self.skipsteps = 1000
    self.no_time_output = True

  def should_process(self, item):
    self.i += 1

    if self.startprefix != None:
      should_skip = False
      if isinstance(self.startprefix, int):
        if self.i < self.startprefix:
          should_skip = True
      elif self.get_name(item) < self.startprefix:
        should_skip = True
      if should_skip:
        if self.i % self.skipsteps == 0:
          pywikibot.output("skipping %s" % str(self.i))
        return False

    if self.endprefix != None:
      if isinstance(self.endprefix, int):
        if self.i > self.endprefix:
          return None
      elif self.get_name(item) > self.endprefix:
        return None

    if isinstance(self.endprefix, int) and not self.t:
      self.t = datetime.datetime.now()

    if self.skip_ignorable_pages and page_should_be_ignored(get_name(item)):
      pywikibot.output("Page %s %s: page has a prefix or suffix indicating it should not be touched, skipping" % (
        self.i, get_name(item)))
      retval = False
    else:
      retval = self.i

    if self.i % self.steps == 0:
      tdisp = ""

      if isinstance(self.endprefix, int):
        told = self.t
        self.t = datetime.datetime.now()
        pagesleft = (self.endprefix - self.i) / self.steps
        tfuture = self.t + (self.t - told) * pagesleft
        tdisp = ", est. " + tfuture.strftime("%X")

      pywikibot.output(str(self.i) + "/" + str(self.endprefix) + tdisp)

    return retval

def iter_items(items, startprefix=None, endprefix=None, get_name=get_page_name, get_index=None,
    skip_ignorable_pages=False):
  i = 0
  t = None
  steps = 50
  skipsteps = 1000
  actual_startprefix = None
  tstart = datetime.datetime.now()

  for current in items:
    i += 1
    if get_index:
      index = get_index(current)
    else:
      index = i

    if startprefix != None:
      should_skip = False
      if isinstance(startprefix, int):
        if index < startprefix:
          should_skip = True
      elif get_name(current) < startprefix:
        should_skip = True
      if should_skip:
        if i % skipsteps == 0:
          pywikibot.output("skipping %s" % str(i))
        continue

    if actual_startprefix is None:
      actual_startprefix = i
    actual_endprefix = None

    if endprefix != None:
      if isinstance(endprefix, int):
        if index > endprefix:
          break
      elif get_name(current) > endprefix:
        break

    if isinstance(endprefix, int) and not t:
      t = datetime.datetime.now()

    if skip_ignorable_pages and page_should_be_ignored(get_name(current)):
      pywikibot.output("Page %s %s: page has a prefix or suffix indicating it should not be touched, skipping" % (
        index, get_name(current)))
    else:
      yield index, current

    if i % steps == 0:
      tdisp = ""

      if isinstance(endprefix, int):
        t = datetime.datetime.now()
        startprefix_as_int = startprefix if isinstance(startprefix, int) else 1
        actual_endprefix = endprefix - (startprefix_as_int - actual_startprefix)
        # Logically:
        #
        # time_so_far = t - tstart
        # pages_so_far = i - startprefix + 1
        # time_per_page = time_so_far / pages_so_far
        # remaining_pages = endprefix - i
        # remaining_time = time_per_page * remaining_pages
        #
        # We do the same but multiply before dividing, for increased precision and due to the inability
        # to multiply or divide timedeltas by floats. We also use the actual startprefix (i.e. the actual
        # index of the first page relative to the pages seen in the input stream, in case get_index() is
        # supplied and e.g. the indices supplied by get_index() are offset significantly compared with
        # the ordering in the input stream), and adjust the supplied `endprefix` value by the difference
        # between the supplied `startprefix` and observed actual first page. This way, for example, if the
        # get_index() indices start at 80000 and `startprefix` = 82000 and `endprefix` = 85000, we will
        # correctly account for there being 3000 pages to do. NOTE: If the indices supplied by get_index()
        # have gaps in them or are completely out of order, our calculations will be incorrect.
        remaining_pages = actual_endprefix - i
        pages_so_far = i - actual_startprefix + 1
        remaining_time = (t - tstart) * remaining_pages / pages_so_far
        seconds_left = remaining_time.seconds
        hours_left_in_day = seconds_left // 3600
        hours_left = remaining_time.days * 24 + hours_left_in_day
        seconds_left_in_hour = seconds_left - 3600 * hours_left_in_day
        minutes_left_in_hour = seconds_left_in_hour // 60
        seconds_left_in_minute = seconds_left_in_hour - 60 * minutes_left_in_hour
        seconds_left_str = (
          "1 second" if seconds_left_in_minute == 1 else
          "%s seconds" % seconds_left_in_minute
        )
        minutes_left_str = (
          "" if minutes_left_in_hour == 0 else
          "1 minute" if minutes_left_in_hour == 1 else
          "%s minutes" % minutes_left_in_hour
        )
        hours_left_str = (
          "" if hours_left == 0 else
          "1 hour" if hours_left == 1 else
          "%s hours" % hours_left
        )
        time_left_str = ", ".join(
          x for x in [hours_left_str, minutes_left_str, seconds_left_str] if x
        )
        tdisp = ", est. %s left" % time_left_str

      pywikibot.output(str(i) + "/" + str(actual_endprefix) + tdisp)

# Parse the output of group_notes() back into individual notes. If a note is repeated, include that many copies
# in the result.
def parse_grouped_notes(comment):
  # FIXME: We should probably check for balanced parens/brackets/braces and not split semicolons inside them
  comment_parts = comment.split("; ")
  notes = []
  for comment_part in comment_parts:
    m = re.search(r"^(.*) \(([0-9]+)\)$", comment_part)
    if m:
      note, repfactor = m.groups()
      notes.extend([note] * int(repfactor))
    else:
      notes.append(comment_part)
  return notes

def group_notes(notes):
  if isinstance(notes, str):
    return [notes]
  notes_count = {}
  uniq_notes = []
  # Preserve ordering of notes but combine duplicate notes with previous notes,
  # maintaining a count.
  for note in notes:
    if note in notes_count:
      notes_count[note] += 1
    else:
      notes_count[note] = 1
      uniq_notes.append(note)
  def fmt_note(note):
    count = notes_count[note]
    if count == 1:
      return "%s" % note
    else:
      return "%s (%s)" % (note, count)
  notes = [fmt_note(note) for note in uniq_notes]
  return notes

starttime = time.time()

def create_argparser(desc, include_pagefile=False, include_stdin=False,
    no_beginning_line=False, suppress_start_end=False):
  if not no_beginning_line:
    msg("Beginning at %s" % time.ctime(starttime))
  parser = argparse.ArgumentParser(description=desc)
  if not suppress_start_end:
    parser.add_argument('start', help="Starting page index", nargs="?")
    parser.add_argument('end', help="Ending page index", nargs="?")
  parser.add_argument('-s', '--save', action="store_true", help="Save results")
  parser.add_argument('-v', '--verbose', action="store_true", help="More verbose output")
  parser.add_argument('-d', '--diff', action="store_true", help="Show diff of changes")
  if include_pagefile:
    parser.add_argument("--pagefile", help="File listing pages to process.")
    parser.add_argument("--pages", help="List of pages to process, comma-separated.")
    parser.add_argument("--pages-from-find-regex", help="Read pages to process (and their indices) from previous find_regex.py output.")
    parser.add_argument("--pages-from-previous-output", help="Read pages to process (and their indices) from previous output of the form 'Page ### PAGENAME: '.")
    parser.add_argument("--category-file", help="File listing categories to process.")
    parser.add_argument("--cats", help="List of categories to process, comma-separated.")
    parser.add_argument("--do-subcats", action="store_true",
      help="When processing categories, do subcategories instead of pages belong to the category.")
    parser.add_argument("--do-cat-and-subcats", action="store_true",
      help="When processing categories, do the category and subcategories instead of pages belong to the category.")
    parser.add_argument("--recursive", action="store_true",
      help="In conjunction with --cats, recursively process pages in subcategories.")
    parser.add_argument("--track-seen", action="store_true",
      help="Track previously seen articles and don't visit them again.")
    parser.add_argument("--prune-cats", help="Regex to use to prune categories when processing subcategories recursively; any categories matching the regex will be skipped along with any of their subcategories (unless reachable in some other manner).")
    parser.add_argument("--refs", help="List of references to process, comma-separated.")
    parser.add_argument("--pages-and-refs", help="List of pages to process, comma-separated, along with references to those pages.")
    parser.add_argument("--specials", help="Special pages to do, comma-separated.")
    parser.add_argument("--do-specials-cat-pages", action="store_true",
      help="When processing specials pages that are categories, do pages of those categories.")
    parser.add_argument("--do-specials-refs", action="store_true",
      help="When processing specials pages, do references to those pages.")
    parser.add_argument("--contribs", help="Names of users whose contributions to iterate over, comma-separated.")
    parser.add_argument("--contribs-start", help="Timestamp to start doing contributions at.")
    parser.add_argument("--contribs-end", help="Timestamp to end doing contributions at.")
    parser.add_argument("--prefix-pages", help="Do pages with these prefixes, comma-separated.",
                        default="-")
    parser.add_argument("--prefix-namespace", help="Namespace of pages to do using --prefix-pages.")
    parser.add_argument("--prefix-redirects-only", help="Restrict --prefix-pages to redirects only.", action="store_true")
    parser.add_argument("--namespaces", help="List of namespace(s) to restrict pages to.")
    parser.add_argument("--ref-namespaces", help="List of namespace(s) to restrict --refs to.")
    parser.add_argument("--filter-pages", help="Regex to use to filter page names.")
    parser.add_argument("--filter-pages-not", help="Regex to use to filter page names; only includes pages not matching this regex.")
    parser.add_argument("--skip-pages", help="List of pages to skip, comma-separated.")
    parser.add_argument("--skip-page-file", help="File containing pages to skip.")
    parser.add_argument("--find-regex-output", help="Output as by find_regex.py.", action="store_true")
    parser.add_argument("--no-output", help="In conjunction with --find-regex, don't output processed text.", action="store_true")
    parser.add_argument("--skip-ignorable-pages", help="Skip 'ignorable' pages (talk pages, user pages, etc.).", action="store_true")
    # Not implemented yet.
    #parser.add_argument("--parallel", help="Do in parallel.", action="store_true")
    #parser.add_argument("--num-workers", help="Number of workers for use with --parallel.", type=int, default=5)
  if include_stdin:
    parser.add_argument("--find-regex", help="Read find_regex.py output from stdin.", action="store_true")
    parser.add_argument("--stdin", help="Read XML dump from stdin.", action="store_true")
    parser.add_argument("--only-lang", help="Only process the section of a page for this language (a canonical language name).")
  return parser

def parse_args(args = sys.argv[1:]):
  startprefix = None
  endprefix = None

  if len(args) >= 1:
    startprefix = args[0]
  if len(args) >= 2:
    endprefix = args[1]
  return parse_start_end(startprefix, endprefix)

def parse_start_end(startprefix, endprefix):
  if startprefix != None:
    try:
      startprefix = int(startprefix)
    except ValueError:
      pass
  if endprefix != None:
    try:
      endprefix = int(endprefix)
    except ValueError:
      pass

  return (startprefix, endprefix)

def args_has_non_default_pages(args):
  return not not (args.pages or args.pagefile or args.pages_from_find_regex or args.pages_from_previous_output
      or args.cats or args.category_file or args.refs or args.specials or args.contribs or args.prefix_namespace
      or args.pages_and_refs)

def do_handle_stdin_retval(args, retval, text, prev_comment, pagemsg, is_find_regex, edit):
  new, this_comment, has_changed = handle_process_page_retval(retval, text, pagemsg, args.verbose, args.diff)
  new = new or text
  if has_changed:
    assert edit, "Changed text without edit=True given"
  if edit:
    if has_changed:
      # Join previous and this comment. Either may be None, a list of individual notes, an empty string (equivalent to
      # None), or a non-empty string specifying a single comment.
      if not prev_comment and not this_comment:
        comment = None
      elif not prev_comment:
        comment = this_comment
      elif not this_comment:
        comment = prev_comment
      else:
        if type(prev_comment) is not list:
          prev_comment = [prev_comment]
        if type(this_comment) is not list:
          this_comment = [this_comment]
        comment = prev_comment + this_comment
      if type(comment) is list:
        comment = "; ".join(group_notes(comment))
      pagemsg("Would save with comment = %s" % comment)
    elif prev_comment:
      if type(prev_comment) is list:
        prev_comment = "; ".join(group_notes(prev_comment))
      pagemsg("Skipped, no changes; previous comment = %s" % prev_comment)
    elif is_find_regex:
      pagemsg("Skipped, no changes")
    if is_find_regex and not args.no_output:
      final_newline = ""
      if not new.endswith("\n"):
        final_newline = "\n"
      pagemsg("-------- begin text --------\n%s%s-------- end text --------" % (new, final_newline))

# Process a run of pages, with the set of pages specified in various possible ways, e.g. from --pagefile, --cats,
# --refs, or (if --stdin is given) from a Wiktionary dump or find_regex.py output read from stdin. PROCESS is called
# to process the page, and has different calling conventions depending on the EDIT, STDIN and INCLUDE_COMMENT flags:
#
# If stdin=True and include_comment=True, PROCESS should be defined like this:
#
# def process_text_on_page(index, pagetitle, text, comment):
#   ...
#
# If stdin=True and include_comment=False, PROCESS should be defined like this:
#
# def process_text_on_page(index, pagetitle, text):
#   ...
#
# If stdin=False and edit=True, PROCESS should be defined like this:
#
# def process_page(page, index, parsed):
#   ...
#
# If stdin=False and edit=False, PROCESS should be defined like this:
#
# def process_page(page, index):
#   ...
#
# FIXME: The PARSED argument is unnecessary and shouldn't be passed in.
#
# The return value of PROCESS is immaterial if edit=False; otherwise it should be NEWTEXT, NOTES where NEWTEXT is the
# new text of the page, and NOTES is either a string (the comment to use when saving the page) or a list of strings
# (which are grouped together using blib.group_notes() to form the comment to use when saving the page). To make no
# change, return None or just use `return`.
#
# The pages iterated over will be:
#
# 1. Those from find_regex.py output on stdin if stdin=True and --stdin and --find-regex are given.
# 2. Else, those from a Wiktionary dump on stdin if stdin=True and --stdin is given.
# 3. Else, the pages in --pages, --pagefile, --cats, --refs, --specials, --contribs and/or --prefix-pages if any of
#    those arguments are given.
# 4. Else, pages in the category/categories in default_cats[] and/or pages referring to the page(s) specified in
#    default_refs[], if either argument is given.
# 5. Else, an error is thrown.
#
# If only_lang is given, it should be a canonical name of a language (e.g. "Latin"), and pages not containing this
# language will be skipped. (This is especially useful in conjunction with dumps on stdin, where it can greatly speed
# up processing by avoiding the need to parse every page.) Not to be confused with the --only-lang user-specifiable
# parameter, which causes processing over only the section of a given language.
#
# If filter_pages is given, it should be a function of one argument (a page title) that returns True to accept a page.
#
# If canonicalize_pagename is given, it should be a function of one argument, which is called on pagenames specified
# on the command line using --pages or read from a file using --pagefile.
def do_pagefile_cats_refs(args, start, end, process, default_pages=[], default_cats=[],
    default_refs=[], edit=False, stdin=False, only_lang=None, include_comment=False,
    filter_pages=None, ref_namespaces=None, canonicalize_pagename=None, skip_ignorable_pages=False):
  args_namespaces = args.namespaces and args.namespaces.split(",") or []
  args_namespaces = [0 if x == "-" else int(x) if re.search("^[0-9]+$", x) else x for x in args_namespaces]
  args_ref_namespaces = args.ref_namespaces and args.ref_namespaces.split(",")
  args_filter_pages = args.filter_pages
  args_filter_pages_not = args.filter_pages_not
  # FIXME: Is it correct to use canonicalize_pagename here?
  pages_to_skip = set(split_arg(args.skip_pages, canonicalize=canonicalize_pagename)) if args.skip_pages else set()
  if args.skip_page_file:
    pages_to_skip |= set(yield_items_from_file(args.skip_page_file, canonicalize=canonicalize_pagename))

  seen = set() if args.track_seen else None

  def page_should_be_filtered_out(pagetitle, errandpagemsg):
    if pagetitle in pages_to_skip:
      return True
    if filter_pages or args_filter_pages or args_filter_pages_not:
      if filter_pages and not filter_pages(pagetitle):
        return True
      if args_filter_pages and not re.search(args_filter_pages, pagetitle):
        return True
      if args_filter_pages_not and re.search(args_filter_pages_not, pagetitle):
        return True
    if (skip_ignorable_pages or args.skip_ignorable_pages) and page_should_be_ignored(pagetitle):
      return True
    if args_namespaces:
      namespace = try_repeatedly(lambda: pywikibot.Page(site, pagetitle).namespace(), errandpagemsg, "find namespace of page")
      if namespace is None:
        return True
      for allowed_namespace in args_namespaces:
        if type(allowed_namespace) is int:
          if namespace.id == allowed_namespace:
            return False
        else:
          coloned_allowed_namespace = [allowed_namespace + ":", ":" + allowed_namespace + ":"]
          if (namespace.canonical_prefix() in coloned_allowed_namespace or
              namespace.custom_prefix() in coloned_allowed_namespace):
            return False
      return True
    return False

  def find_lang_section_for_only_lang(text, lang, pagemsg):
    sections, sections_by_lang, _ = split_text_into_sections(text, pagemsg)

    if lang not in sections_by_lang:
      # Too noisy.
      # pagemsg("WARNING: Can't find %s section, skipping" % lang)
      return None
    else:
      j = sections_by_lang[lang]

    secbody, sectail = split_trailing_separator(sections[j])

    return sections, j, secbody, sectail

  def do_process_text_on_page(index, pagetitle, text, prev_comment, pagemsg):
    def errandpagemsg(txt):
      errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
    def call_process(text_to_call):
      if include_comment:
        return process(index, pagetitle, text_to_call, prev_comment)
      else:
        return process(index, pagetitle, text_to_call)
    if page_should_be_filtered_out(pagetitle, errandpagemsg):
      return None
    if args.only_lang:
      retval = find_lang_section_for_only_lang(text, args.only_lang, pagemsg)
      if retval is None:
        return None
      sections, j, secbody, sectail = retval
      retval = call_process(secbody)
      if retval is None:
        return None
      newsecbody, comment = retval
      sections[j] = newsecbody + sectail
      return "".join(sections), comment
    else:
      if only_lang and "==%s==" % only_lang not in text:
        return None
      return call_process(text)

  # Process a page read from Wiktionary using Pywikibot (as opposed to a page read from stdin, either from find_regex
  # output or from a dump file). `no_check_seen` means to not check the `seen` set to see whether a page has already
  # been seen. This is set when iterating over categories because the code to do this adds to the `seen` set itself
  # (necessary because it can recursively process subcategories) so if we check the `seen` set we'll never process any
  # pages.
  def process_pywikibot_page(index, page, no_check_seen=False):
    pagetitle = str(page.title())
    if not no_check_seen and seen is not None:
      if pagetitle in seen:
        return
      seen.add(pagetitle)
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))
    def errandpagemsg(txt):
      errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
    if page_should_be_filtered_out(pagetitle, errandpagemsg):
      return
    def do_process_page(page, index, parsed=None):
      if stdin:
        pagetext = safe_page_text(page, errandpagemsg)
        return do_process_text_on_page(index, pagetitle, pagetext, None, pagemsg)
      else:
        if only_lang:
          pagetext = safe_page_text(page, errandpagemsg)
          if "==%s==" % only_lang not in pagetext:
            return None, None
        if edit:
          return process(page, index, parsed)
        else:
          return process(page, index)

    if args.find_regex_output:
      # We are reading from Wiktionary but asked to output in find_regex format.
      retval = do_process_page(page, index)
      pagetext = safe_page_text(page, errandpagemsg)
      do_handle_stdin_retval(args, retval, pagetext, None, pagemsg, is_find_regex=True, edit=edit)
    elif edit:
      do_edit(page, index, do_process_page, save=args.save, verbose=args.verbose,
          diff=args.diff)
    else:
      do_process_page(page, index)

  if stdin and (args.stdin or args.find_regex):
    pages_to_filter = None
    if args.pages:
      pages_to_filter = set(split_arg(args.pages, canonicalize=canonicalize_pagename))
    if args.pagefile:
      new_pages_to_filter = set(yield_items_from_file(args.pagefile, canonicalize=canonicalize_pagename))
      if pages_to_filter is None:
        pages_to_filter = new_pages_to_filter
      else:
        pages_to_filter |= new_pages_to_filter
    def do_process_stdin_text_on_page(index, pagetitle, text, prev_comment):
      if pages_to_filter is not None and pagetitle not in pages_to_filter:
        return None
      def errandpagemsg(txt):
        errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
      if page_should_be_filtered_out(pagetitle, errandpagemsg):
        return None
      else:
        def pagemsg(txt):
          msg("Page %s %s: %s" % (index, pagetitle, txt))
        return do_process_text_on_page(index, pagetitle, text, prev_comment, pagemsg)
    if args.find_regex:
      index_pagetitle_text_comment = yield_text_from_find_regex(sys.stdin, args.verbose)
      for _, (index, pagetitle, text, prev_comment) in iter_items(index_pagetitle_text_comment, start, end,
          get_name=lambda x:x[1], get_index=lambda x:x[0]):
        retval = do_process_stdin_text_on_page(index, pagetitle, text, prev_comment)
        def pagemsg(txt):
          msg("Page %s %s: %s" % (index, pagetitle, txt))
        if prev_comment:
          prev_comment = parse_grouped_notes(prev_comment)
        do_handle_stdin_retval(args, retval, text, prev_comment, pagemsg, is_find_regex=True, edit=edit)
    else:
      def do_process_stdin_dump_text_on_page(index, pagetitle, text):
        retval = do_process_stdin_text_on_page(index, pagetitle, text, None)
        def pagemsg(txt):
          msg("Page %s %s: %s" % (index, pagetitle, txt))
        do_handle_stdin_retval(args, retval, text, None, pagemsg, is_find_regex=False, edit=edit)
      parse_dump(sys.stdin, do_process_stdin_dump_text_on_page, start, end)

  elif args_has_non_default_pages(args):
    args_prune_cats = args.prune_cats
    if args.pages:
      pages = split_arg(args.pages, canonicalize=canonicalize_pagename)
      for index, pagetitle in iter_items(pages, start, end):
        process_pywikibot_page(index, pywikibot.Page(site, pagetitle))
    if args.pagefile:
      for index, pagetitle in iter_items_from_file(args.pagefile, start, end, canonicalize=canonicalize_pagename):
        process_pywikibot_page(index, pywikibot.Page(site, pagetitle))
    if args.pages_from_find_regex:
      index_pagetitle_text_comment = yield_text_from_find_regex(
        open(args.pages_from_find_regex, "r", encoding="utf-8"), args.verbose
      )
      for _, (index, pagetitle, _, _) in iter_items(index_pagetitle_text_comment, start, end,
          get_name=lambda x:x[1], get_index=lambda x:x[0]):
        process_pywikibot_page(index, pywikibot.Page(site, pagetitle))
    if args.pages_from_previous_output:
      index_pagetitle = yield_pages_from_previous_output(
        open(args.pages_from_previous_output, "r", encoding="utf-8"), args.verbose
      )
      for _, (index, pagetitle) in iter_items(index_pagetitle, start, end,
          get_name=lambda x:x[1], get_index=lambda x:x[0]):
        process_pywikibot_page(index, pywikibot.Page(site, pagetitle))
    if args.cats or args.category_file:
      def do_cat(cat):
        if args.do_cat_and_subcats:
          for index, subcat in cat_subcats(cat, start, end, seen=seen, prune_cats_regex=args_prune_cats,
              do_this_page=True, recurse=args.recursive):
            process_pywikibot_page(index, subcat, no_check_seen=True)
        elif args.do_subcats:
          for index, subcat in cat_subcats(cat, start, end, seen=seen, prune_cats_regex=args_prune_cats,
              do_this_page=False, recurse=args.recursive):
            process_pywikibot_page(index, subcat, no_check_seen=True)
        else:
          for index, page in cat_articles(cat, start, end, seen=seen, prune_cats_regex=args_prune_cats,
              recurse=args.recursive, track_seen=args.track_seen):
            process_pywikibot_page(index, page, no_check_seen=True)
      if args.cats:
        for cat in split_arg(args.cats):
          do_cat(cat)
      if args.category_file:
        for _, cat in iter_items_from_file(args.category_file):
          do_cat(cat)
    if args.refs:
      for ref in split_arg(args.refs):
        # We don't use ref_namespaces here because the user might not want it.
        for index, page in references(ref, start, end, namespaces=args_ref_namespaces):
          process_pywikibot_page(index, page)
    if args.pages_and_refs:
      for page_and_ref in split_arg(args.pages_and_refs):
        # We don't use ref_namespaces here because the user might not want it.
        for index, page in references(page_and_ref, start, end, namespaces=args_ref_namespaces,
            include_page=True):
          process_pywikibot_page(index, page)
    if args.specials:
      for special in split_arg(args.specials):
        for index, page in query_special_pages(special, start, end):
          title = str(page.title())
          if args.do_specials_cat_pages and title.startswith("Category:"):
            for index2, subcat in cat_articles(re.sub("^Category:", "", title), seen=seen, prune_cats_regex=args_prune_cats,
                recurse=args.recursive):
              process_pywikibot_page(index2, subcat, no_check_seen=True)
          if args.do_specials_refs:
            # We don't use ref_namespaces here because the user might not want it.
            for index2, page2 in references(title, namespaces=args_ref_namespaces):
              process_pywikibot_page(index2, page2)
          if not args.do_specials_cat_pages and not args.do_specials_refs:
            process_pywikibot_page(index, page)
    if args.contribs:
      for contrib in split_arg(args.contribs):
        for index, page in query_usercontribs(contrib, start, end, starttime=args.contribs_start, endtime=args.contribs_end):
          process_pywikibot_page(index, pywikibot.Page(site, page['title']))
    if args.prefix_namespace:
      for prefix in split_arg(args.prefix_pages):
        namespace = args.prefix_namespace
        for index, page in prefix_pages(
            prefix, start, end, namespace, filter_redirects=True if args.prefix_redirects_only else None):
          process_pywikibot_page(index, page)

  elif args_namespaces:
    for namespace in args_namespaces:
      for index, page in prefix_pages(
          None, start, end, namespace, filter_redirects=True if args.prefix_redirects_only else None):
        process_pywikibot_page(index, page)

  else:
    if not default_pages and not default_cats and not default_refs:
      raise ValueError("One of --pages, --pagefile, --cats, --refs, --specials, --contribs or --prefix-pages should be specified")
    for index, pagetitle in iter_items(default_pages, start, end):
      process_pywikibot_page(index, pywikibot.Page(site, pagetitle))
    for cat in default_cats:
      for index, page in cat_articles(cat, start, end, seen=seen, track_seen=args.track_seen):
        process_pywikibot_page(index, page, no_check_seen=True)
    for ref in default_refs:
      for index, page in references(ref, start, end, namespaces=ref_namespaces):
        process_pywikibot_page(index, page)

  elapsed_time()

def elapsed_time():
  endtime = time.time()
  elapsed = endtime - starttime
  hours = int(elapsed // 3600)
  hoursecs = elapsed % 3600
  mins = int(hoursecs / 60)
  secs = hoursecs % 60
  if hours:
    msg("Elapsed time: %s hours %s mins %0.2f secs" % (hours, mins, secs))
  else:
    msg("Elapsed time: %s mins %0.2f secs" % (mins, secs))
  msg("Ending at %s" % time.ctime(endtime))

languages = None
languages_byCode = None
languages_byCanonicalName = None
languages_byAlias = None

families = None
families_byCode = None
families_byCanonicalName = None

scripts = None
scripts_byCode = None
scripts_byCanonicalName = None

etym_languages = None
etym_languages_byCode = None
etym_languages_byCanonicalName = None
etym_languages_byAlias = None

wm_languages = None
wm_languages_byCode = None
wm_languages_byCanonicalName = None


def getData():
  getLanguageData()
  getFamilyData()
  getScriptData()
  getEtymLanguageData()

def json_loads(data):
  try:
    return json.loads(data)
  except JSONDecodeError:
    print("JSON decode error processing the following: %s" % data)
    raise

def getLanguageData():
  global languages, languages_byCode, languages_byCanonicalName, languages_byAlias

  jsondata = site.expand_text("{{#invoke:User:MewBot|getLanguageData}}")
  languages = json_loads(jsondata)
  languages_byCode = {}
  languages_byCanonicalName = {}
  languages_byAlias = defaultdict(list)

  for lang in languages:
    languages_byCode[lang["code"]] = lang
    languages_byCanonicalName[lang["canonicalName"]] = lang
    if "aliases" in lang:
      for alias in lang["aliases"]:
        assert(type(alias) is str)
        languages_byAlias[alias].append(lang)

def getFamilyData():
  global families, families_byCode, families_byCanonicalName

  families = json_loads(site.expand_text("{{#invoke:User:MewBot|getFamilyData}}"))
  families_byCode = {}
  families_byCanonicalName = {}

  for fam in families:
    families_byCode[fam["code"]] = fam
    families_byCanonicalName[fam["canonicalName"]] = fam


def getScriptData():
  global scripts, scripts_byCode, scripts_byCanonicalName

  scripts = json_loads(site.expand_text("{{#invoke:User:MewBot|getScriptData}}"))
  scripts_byCode = {}
  scripts_byCanonicalName = {}

  for sc in scripts:
    scripts_byCode[sc["code"]] = sc
    scripts_byCanonicalName[sc["canonicalName"]] = sc


def getEtymLanguageData():
  global etym_languages, etym_languages_byCode, etym_languages_byCanonicalName, etym_languages_byAlias

  etym_languages = json_loads(site.expand_text("{{#invoke:User:MewBot|getEtymLanguageData}}"))
  etym_languages_byCode = {}
  etym_languages_byCanonicalName = {}
  etym_languages_byAlias = defaultdict(list)

  for etyl in etym_languages:
    etym_languages_byCode[etyl["code"]] = etyl
    etym_languages_byCanonicalName[etyl["canonicalName"]] = etyl
    if "aliases" in etyl:
      for alias in etyl["aliases"]:
        assert(type(alias) is str)
        etym_languages_byAlias[alias].append(etyl)


def try_repeatedly(fun, errandpagemsg, operation="save", bad_value_ret=None, max_tries=2, sleep_time=5):
  num_tries = 0
  def log_exception(txt, e, skipping=False):
    txt = "WARNING: %s when trying to %s%s: %s" % (
      txt, operation, ", skipping" if skipping else "", str(e)
    )
    errandpagemsg(txt)
    traceback.print_exc(file=sys.stdout)
  while True:
    try:
      return fun()
    except KeyboardInterrupt as e:
      raise
    except pywikibot.exceptions.InvalidTitleError as e:
      log_exception("Invalid title", e, skipping=True)
      return bad_value_ret
    except pywikibot.exceptions.TitleblacklistError as e:
      log_exception("Title is blacklisted", e, skipping=True)
      return bad_value_ret
    except (pywikibot.exceptions.LockedPageError, pywikibot.exceptions.NoUsernameError, pywikibot.exceptions.UnsupportedPageError) as e:
      log_exception("Page is protected", e, skipping=True)
      return bad_value_ret
    except pywikibot.exceptions.AbuseFilterDisallowedError as e:
      log_exception("Abuse filter: Disallowed", e, skipping=True)
      return bad_value_ret
    # Instead, retry, which will save the page.
    #except pywikibot.exceptions.PageSaveRelatedError as e:
    #  log_exception("Unable to save (abuse filter?)", e, skipping=True)
    except Exception as e:
      if "invalidtitle" in str(e):
        log_exception("Invalid title", e, skipping=True)
        return bad_value_ret
      if "title-blacklist-forbidden" in str(e):
        log_exception("Title is blacklisted", e, skipping=True)
        return bad_value_ret
      if "abusefilter-disallowed" in str(e):
        log_exception("Abuse filter: Disallowed", e, skipping=True)
        return bad_value_ret
      if "abusefilter-warning" in str(e):
        log_exception("Abuse filter warning: Disallowed", e, skipping=True)
        return bad_value_ret
      if "customjsprotected" in str(e):
        log_exception("Protected JavaScript page: Disallowed", e, skipping=True)
        return bad_value_ret
      if "protectednamespace-interface" in str(e):
        log_exception("Protected namespace interface: Disallowed", e, skipping=True)
        return bad_value_ret
      #except (pywikibot.exceptions.Error, StandardError) as e:
      log_exception("Error", e)
      num_tries += 1
      if num_tries >= max_tries:
        errandpagemsg("WARNING: Can't %s!!!!!!!" % operation)
        raise
      errandpagemsg("Sleeping for %s seconds" % sleep_time)
      time.sleep(sleep_time)
      #if sleep_time >= 40:
      #  sleep_time += 40
      #else:
      #  sleep_time *= 2

def safe_page_text(page, errandpagemsg, bad_value_ret=""):
  return try_repeatedly(lambda: page.text, errandpagemsg, "fetch page text", bad_value_ret=bad_value_ret)

def safe_page_exists(page, errandpagemsg):
  return try_repeatedly(lambda: page.exists(), errandpagemsg, "determine if page exists", bad_value_ret=False)

def safe_page_save(page, comment, errandpagemsg):
  def do_save():
    page.save(summary=comment)
    return True
  return try_repeatedly(do_save, errandpagemsg, "save page", bad_value_ret=False)

def safe_page_purge(page, errandpagemsg):
  def do_purge():
    page.purge(forcelinkupdate = True)
    return True
  return try_repeatedly(do_purge, errandpagemsg, "purge page", bad_value_ret=False)

class ParseException(Exception):
  pass

# Parse a string containing matched instances of parens, brackets or the like. Return a list of strings, alternating
# between textual runs not containing the open/close characters and runs beginning and ending with the open/close
# characters. For example,
#
# parse_balanced_segment_run("foo(x(1)), bar(2)", "(", ")") = ["foo", "(x(1))", ", bar", "(2)", ""]
def parse_balanced_segment_run(segment_run, op, cl):
  break_on_op_cl = re.split("([\\" + op + "\\" + cl + "])", segment_run)
  text_and_specs = []
  level = 0
  seg_group = []
  for i, seg in enumerate(break_on_op_cl):
    if i % 2 == 1:
      if seg == op:
        seg_group.append(seg)
        level += 1
      else:
        assert seg == cl
        seg_group.append(seg)
        level -= 1
        if level < 0:
          raise ParseException("Unmatched " + cl + " sign: '" + segment_run + "'")
        elif level == 0:
          text_and_specs.append("".join(seg_group))
          seg_group = []
    elif level > 0:
      seg_group.append(seg)
    else:
      text_and_specs.append(seg)
  if level > 0:
    raise ParseException("Unmatched " + op + " sign: '" + segment_run + "'")
  return text_and_specs


# Like parse_balanced_segment_run() but accepts multiple sets of delimiters, and individual delimiters are specified
# via regexes. For example,
#
# parse_multi_delimiter_balanced_segment_run("foo[bar(baz[bat])], quux<glorp>", [(r"\[", r"\]"), (r"\(", r"\)"), ("<", ">")]) =
#   ["foo", "[bar(baz[bat])]", ", quux", "<glorp>", ""]
def parse_multi_delimiter_balanced_segment_run(segment_run, delimiter_pairs):
  open_to_close_map = {}
  open_close_items = []
  open_items = []
  for (open, close) in delimiter_pairs:
    open_to_close_map[open] = close
    open_close_items.append(open)
    open_close_items.append(close)
    open_items.append(open)
  open_close_pattern = "(" + "|".join(open_close_items) + ")"
  open_pattern = "(" + "|".join(open_items) + ")"
  break_on_open_close = re.split(open_close_pattern, segment_run)
  text_and_specs = []
  level = 0
  seg_group = []
  open_at_level_zero = None
  for i, seg in enumerate(break_on_open_close):
    if i % 2 == 1:
      seg_group.append(seg)
      if level == 0:
        if not re.search(open_pattern, seg):
          raise ParseException("Unmatched close sign " + seg + ": '" + segment_run + "'")
        assert open_at_level_zero is None
        for (open, close) in delimiter_pairs:
          if re.search(open, seg):
            open_at_level_zero = open
            break
        else: # no break
          assert False, "Internal error: Segment %s didn't match any open regex" % seg
        level += 1
      elif re.search(open_at_level_zero, seg):
        level += 1
      elif re.search(open_to_close_map[open_at_level_zero], seg):
        level -= 1
        assert level >= 0
        if level == 0:
          text_and_specs.append("".join(seg_group))
          seg_group = []
          open_at_level_zero = None
    elif level > 0:
      seg_group.append(seg)
    else:
      text_and_specs.append(seg)
  if level > 0:
    raise ParseException("Unmatched open sign " + open_at_level_zero + ": '" + segment_run + "'")
  return text_and_specs


#Split a list of alternating textual runs of the format returned by `parse_balanced_segment_run` on `splitchar`. This
#only splits the odd-numbered textual runs (the portions between the balanced open/close characters).  The return value
#is a list of lists, where each list contains an odd number of elements, where the even-numbered elements of the sublists
#are the original balanced textual run portions. For example, if we do
#
#parse_balanced_segment_run("foo<M.proper noun> bar<F>", "<", ">") =
#  ["foo", "<M.proper noun>", " bar", "<F>", ""]
#
#then
#
#split_alternating_runs(["foo", "<M.proper noun>", " bar", "<F>", ""], " ") =
#  [["foo", "<M.proper noun>", ""], ["bar", "<F>", ""]]
#
#Note that we did not touch the text "<M.proper noun>" even though it contains a space in it, because it is an
#even-numbered element of the input list. This is intentional and allows for embedded separators inside of
#brackets/parens/etc. Note also that the inner lists in the return value are of the same form as the input list (i.e.
#they consist of alternating textual runs where the even-numbered segments are balanced runs), and can in turn be passed
#to split_alternating_runs().
#
#If `preserve_splitchar` is passed in, the split character is included in the output, as follows:
#
#split_alternating_runs(["foo", "<M.proper noun>", " bar", "<F>", ""], " ", true) =
#  [["foo", "<M.proper noun>", ""], [" "], ["bar", "<F>", ""]]
#
#Consider what happens if the original string has multiple spaces between brackets, and multiple sets of brackets
#without spaces between them.
#
#parse_balanced_segment_run("foo[dated][low colloquial] baz-bat quux xyzzy[archaic]", "[", "]") =
#  ["foo", "[dated]", "", "[low colloquial]", " baz-bat quux xyzzy", "[archaic]", ""]
#
#then
#
#split_alternating_runs(["foo", "[dated]", "", "[low colloquial]", " baz-bat quux xyzzy", "[archaic]", ""], "[ %-]") =
#  [["foo", "[dated]", "", "[low colloquial]", ""], ["baz"], ["bat"], ["quux"], ["xyzzy", "[archaic]", ""]]
#
#If `preserve_splitchar` is passed in, the split character is included in the output,
#as follows:
#
#split_alternating_runs(["foo", "[dated]", "", "[low colloquial]", " baz bat quux xyzzy", "[archaic]", ""], "[ %-]", true) =
#  [["foo", "[dated]", "", "[low colloquial]", ""], [" "], ["baz"], ["-"], ["bat"], [" "], ["quux"], [" "], ["xyzzy", "[archaic]", ""]]
#
#As can be seen, the even-numbered elements in the outer list are one-element lists consisting of the separator text.
def split_alternating_runs(segment_runs, splitchar, preserve_splitchar=False):
  grouped_runs = []
  run = []
  for i, seg in enumerate(segment_runs):
    if i % 2 == 1:
      run.append(seg)
    else:
      parts = preserve_splitchar and re.split("(" + splitchar + ")", seg) or re.split(splitchar, seg)
      run.append(parts[0])
      for j in range(1, len(parts)):
        grouped_runs.append(run)
        run = [parts[j]]
  if run:
    grouped_runs.append(run)
  return grouped_runs


class ProcessLinks(object):
  def __init__(self, index, pagetitle, text, parsed, t, origt, tlang, param, langparam):
    # The index of the page containing the template being processed.
    self.index = index
    # The title of the page containing the template being processed.
    self.pagetitle = pagetitle
    # The raw text of the page containing the template being processed.
    self.text = text
    # The result of calling `parse_text()` on the text of the page containing the template being processed (an
    # mwparserfromhell structure).
    self.parsed = parsed
    # The template being processed (an mwparserfromhell structure).
    self.t = t
    # The Unicode string of the original form of the template (before any mods were made to it).
    self.origt = origt
    # The language of the value being considered.
    self.tlang = tlang
    # The parameters of the value being processed (its foreign-script value and corresponding Latin translit). This is
    # a tuple where the first element of the tuple is a string specifying the type of parameter combination being
    # processed, and the remaining elements specify the parameters being processed and depend on the value of the first
    # element. The exact format is documented below in the comment above the doparam() function inside of the
    # do_process_one_page_links() function inside of process_one_page_links().
    self.param = param
    # The parameter holding the language of the value being considered.
    self.langparam = langparam
    self.addl_params = {}


class ParamWithInlineModifier(object):
  def __init__(self, mainval, modifiers, preceding_whitespace="", following_whitespace=""):
    self.mainval = mainval
    self.modifiers = modifiers
    self.preceding_whitespace = preceding_whitespace
    self.following_whitespace = following_whitespace

  def reconstruct_param(self):
    parts = [self.mainval]
    for mod, val in self.modifiers:
      parts.append("<%s:%s>" % (mod, val))
    return self.preceding_whitespace + "".join(parts) + self.following_whitespace

  def get_modifier(self, mod, allow_multiple=False):
    retval = [] if allow_multiple else None
    for thismod, thisval in self.modifiers:
      if thismod == mod:
        if allow_multiple:
          retval.append(thisval)
        elif retval is None:
          retval = thisval
        else:
          raise ParseException("Modifier %s occurs twice, with values '%s' and '%s'" % (mod, retval, thisval))
    return retval

  def set_modifier(self, mod, val):
    if isinstance(val, list):
      existing_pos = []
      for thispos, (thismod, thisval) in enumerate(self.modifiers):
        if thismod == mod:
          existing_pos.append(thispos)
      if len(existing_pos) > len(val):
        # Maybe we should optionally allow this, with a flag, and delete the excess values.
        raise ParseException("For modifier %s, saw %s existing value(s) and trying to set only %s value(s)"
          % (mod, len(existing_pos), len(val)))
      else:
        for valpos, pos in enumerate(existing_pos):
          self.modifiers[pos] = (mod, val[valpos])
        for val_to_add in val[len(existing_pos):]:
          self.modifiers.append((mod, val_to_add))
    else:
      pos = None
      for thispos, (thismod, thisval) in enumerate(self.modifiers):
        if thismod == mod:
          if pos is None:
            pos = thispos
          else:
            raise ParseException("Modifier %s occurs twice when trying to set modifier, in positions '%s' and '%s'"
              % (mod, pos, thispos))
      if pos is None:
        self.modifiers.append((mod, val))
      else:
        self.modifiers[pos] = ((mod, val))

  def remove_modifier(self, mod):
    removed = False
    new_modifiers = []
    for thispos, (thismod, thisval) in enumerate(self.modifiers):
      if thismod != mod:
        new_modifiers.append((thismod, thisval))
      else:
        removed = True
    if not removed:
      raise ParseException("Modifier %s not found when trying to remove modifier" % mod)
    self.modifiers = new_modifiers


def parse_inline_modifier(value):
  m = re.search("^(\s*)(.*?)(\s*)$", value)
  preceding_whitespace, value, following_whitespace = m.groups()
  segments = parse_balanced_segment_run(value, "<", ">")
  mainval = segments[0]
  modifiers = []
  for k in range(1, len(segments), 2):
    if segments[k + 1] != "":
      raise ParseException("Extraneous text '" + segments[k + 1] + "' after modifier")
    m = re.search("^<(.*)>$", segments[k])
    if not m:
      raise ValueError("Internal error: Modifier '" + segments[k] + "' isn't surrounded by angle brackets")
    modtext = m.group(1)
    m = re.search("^([a-zA-Z0-9+_-]+):(.*)$", modtext)
    if not m:
      raise ParseException("Modifier " + segments[k] + " lacks a recognized prefix")
    prefix, val = m.groups()
    modifiers.append((prefix, val))
  return ParamWithInlineModifier(mainval, modifiers, preceding_whitespace, following_whitespace)


# Process link-like templates containing foreign text in specified language(s). PROCESS_PARAM is the function called,
# which is called with a single argument, an object of type ProcessLinks holding information on the page; its index
# (an integer); the page text; the template on the page; the language code of the template; the combination of
# parameters in the template containing the foreign text and Latin transliteration; and the parameter holding the
# language code of the template. If the function makes any in-place modifications to the template, it should return
# a changelog string or a list of changelog strings; otherwise it should return False.
#
# Returns two values: the changed text along with a list of changelog messages (created by collecting all the changelog
# strings returned by PROCESS_PARAM).
#
# INDEX is the index of the page to process; PAGETITLE is its title; and TEXT is its text.

# LANGS is a list of the language code(s) of the languages to do; only templates referencing the specified language(s)
# will be processed.
#
# TEMPLATES_SEEN and TEMPLATES_CHANGED on entry should be empty dictionaries. On exit, the keys will record the names
# respectively of templates "seen" (where PROCESS_PARAM was called at least once on the template) and templates
# "changed" (where at least one change was made to the template by PROCESS_PARAM). Note the PROCESS_PARAM may be
# called multiple times on certain templates (e.g. {{affix}}, {{alt}} and other templates containing multiple values).
#
# If SPLIT_TEMPLATES is given, then if the transliteration of a given parameter contains multiple entries, the template
# is split into multiple copies, each with one of the entries, and the templates are comma-separated. SPLIT_TEMPLATES
# is either True (which splits on commas) or a string specifying a regex used for splitting; optional whitespace is
# automatically added to both sides of the regex. (FIXME: This is currently disabled because it needs rethinking and
# expansion to make it more robust.)
#
# If INCLUDE_NOTFOREIGN is given, then PROCESS_PARAM will be called on templates referencing one of the languages in
# LANGS but not containing any foreign-script values. In that case, the first element of the tuple passed in `param`
# to PROCESS_PARAM will be "notforeign". See below.
def process_one_page_links(index, pagetitle, text, langs, process_param,
  templates_seen, templates_changed, split_templates=None, include_notforeign=False):

  def lang_prefix_template(tn):
    return ":" in tn or re.search("^[a-z][a-z][a-z]?-", tn)

  # Process the link-like templates on the page with the given title and text,
  # calling PROCESSFN for each pair of foreign/Latin. Return a list of
  # changelog actions.
  def do_process_one_page_links(pagetitle, index, parsed, processfn):
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))

    actions = []
    for t in parsed.filter_templates():
      tn = tname(t)
      origt = str(t)
      saw_template = [False]
      changed_template = [False]

      # Return the value of a parameter in template `t`.
      def getp(param):
        return getparam(t, param)

      # Return the value of a parameter (possibly with multiple names) in template `t`. `params` is either a string
      # naming a single param or a list of such strings, which are checked in turn for a present and non-empty param.
      # Returns a tuple of two values, the value of the first found param and its name. If no param found, returns
      # an empty string along with the first specified param name.
      def getpm(params):
        if isinstance(params, str):
          return getp(params), params
        assert isinstance(params, list)
        assert len(params) > 0
        for param in params:
          val = getp(param)
          if val:
            return val, param
        return "", params[0]

      # Parse a `langparam` value into the actual lang code and the name of the param.
      def get_lang_and_langparam(langparam):
        if isinstance(langparam, tuple):
          assert langparam[0] == "direct"
          tlang = langparam[1]
          langparam = None
        else:
          tlang = getp(langparam)
        return tlang, langparam

      # Create an indexed param suitable for passing to getpm(). If `ind` == 1, a list is returned, without and with the
      # index (so that e.g. both tr= and tr1= are recognized); otherwise an indexed string is returned.
      def index_param(param, ind):
        if ind == 1:
          return [param, param + "1"]
        else:
          return "param%s" % ind

      # Call `processfn` on a given foreign-script/Latin combination:
      # * `langparam` is the parameter holding the language of the foreign script param. If the language is not found in
      #   a param (e.g. with a lang-specific template), the value should be a two-element tuple ("direct", LANG) where
      #   LANG is the actual language code.
      # * `param` specifies the parameters involved and is a tuple, where the first element specifies the type of
      #   parameter combination and the remaining elements specify the parameters involved. Specifically:
      #   * ("separate", FOREIGN, LATIN) specifies the case where the foreign-script value is found in parameter
      #     FOREIGN and the corresponding Latin translit is in LATIN (possibly None).
      #   * ("separate-pagetitle", FOREIGN_DEST, LATIN) specifies the case where the foreign-script value comes
      #     directly from the page title. If it needs to be canonicalized (e.g. accents added), the canonicalized
      #     value should be written to FOREIGN_DEST. The corresponding Latin translit is in LATIN (possibly None).
      #   * ("inline", FOREIGN_PARAM, FOREIGN_MOD, LATIN_MOD[, PARSED_INLINE_MOD]) specifies the case where inline
      #     modifiers are involved. FOREIGN_PARAM is the parameter holding everything. FOREIGN_MOD is the inline
      #     modifier holding the foreign-script value, or None if the main value (the part outside the <...>) is the
      #     foreign-script value. LATIN_MOD specifies the inline modifier holding the Latin translit. PARSED_INLINE_MOD
      #     is the parsed version of the contents of FOREIGN_PARAM (a ParamWithInlineModifier object). If omitted, an
      #     additional value will be appended to the tuple before calling `processfn`, containing the results of calling
      #     parse_inline_modifier() on the value in FOREIGN_PARAM.
      #   * ("notforeign") specifies the case where a template references a given language but doesn't contain a
      #     foreign/Latin combination to process. These cases won't be included at all unless `include_notforeign`
      #     is given in `process_one_page_links`.
      #
      # Before calling `processfn`, checks are made to ensure that the language is one of those in `langs` and the
      # requested parameter actually has a value. The return value is True if any changes were made, otherwise False.
      def doparam(langparam, param):
        tlang, langparam = get_lang_and_langparam(langparam)
        if tlang not in langs:
          return False
        try:
          if param[0] == "separate":
            _, foreign, latin = param
            assert foreign is not None
            if not getp(foreign):
              return False
          elif param[0] == "inline":
            if len(param) == 4:
              _, foreign_param, foreign_mod, latin_mod = param
              assert foreign_param is not None
              paramval = getp(foreign_param)
              if not paramval:
                return False
              inline_mod = parse_inline_modifier(paramval)
              if foreign_mod is not None and inline_mod.get_modifier(foreign_mod) is None:
                return False
              param = ("inline", foreign_param, foreign_mod, latin_mod, inline_mod)

          saw_template[0] = True
          obj = ProcessLinks(index, pagetitle, text, parsed, t, origt, tlang, param, langparam)
          result = processfn(obj)
          if result:
            if isinstance(result, list):
              actions.extend(result)
            else:
              assert isinstance(result, str)
              actions.append(result)
            changed_template[0] = True
            return True
          return False
        except ParseException as e:
          pagemsg("Exception processing lang %s, param %s in template %s: %s"
            % (tlang, param, str(t), e))
          return False

      # Call doparam() and hence `processfn` on a given foreign-script/Latin-translit combination with an optional
      # display-text (alt) param and possibly inline modifiers.
      # * `langparam` is as in doparam();
      # * `param` is the name of the foreign-script param, or a list of such params, checked in turn for a non-empty
      #   value;
      # * `altparam` is the display-text param (or None if there is no corresponding display-text param), or a list of
      #   such params, as in `param`;
      # * `trparam` is the corresponding Latin-translit param (or None if there is no corresponding translit param), or
      #   a list of such params, as in `param`;
      # * If `other_lang_param` is specified and is a string or list, it is the name of the parameter (or parameters, as
      #   in `param`) holding the term-specific language of the term. If this parameter exists, `param` is ignored as
      #   presumably not being in the right language. (FIXME: We should consider checking the term's language against
      #   the languages given in `langs` to process_one_page_links(), and take appropriate action if it matches.) If
      #   `other_lang_param` is specified (either as a string or the value True), we also check for a language code
      #   prefixed to the value of `param` (e.g. 'LL.:minūtia' or 'grc:[[σκῶρ|σκατός]]'), and ignore `param` if so.
      # * If `check_inline_modifiers` is specified, check the value of `param` for a less-than sign and if so, try to
      #   parse as an inline modifier, checking for a display-text param in 'alt:' and translit in 'tr:'. In this case,
      #   if `other_lang_param` is specified, check for a 'lang:' inline modifier and ignore `param` if so.
      def doparam_checking_alt(langparam, param, altparam, trparam, other_lang_param=None,
          check_inline_modifiers=False):
        # Here we repeat the check at the beginning of `doparam`; but this short-circuits all the templates for
        # different languages.
        tlang, langparam = get_lang_and_langparam(langparam)
        if tlang not in langs:
          return False
        if altparam:
          altval, altparam = getpm(altparam)
        else:
          altval = ""
        paramval, param = getpm(param)
        if trparam:
          _, trparam = getpm(trparam)
        if isinstance(other_lang_param, (str, list)):
          other_lang_val, other_lang_param = getpm(other_lang_param)
          if other_lang_val:
            pagemsg("Skipping param %s=%s with alt param %s=%s because it is in a different lang %s=%s: %s"
              % (param, paramval, altparam, altval, other_lang_param, other_lang_val, str(t)))
            return False
        if other_lang_param:
          m = re.search("^([A-Za-z0-9._-]+):(.*)$", paramval)
          if m:
            other_lang_val, actual_paramval = m.groups()
            pagemsg("Skipping param %s=%s because of it begins with other-language prefix '%s:': %s"
              % (param, paramval, other_lang_val, str(t)))
            return False
        if check_inline_modifiers and "<" in paramval:
          try:
            inline_mod = parse_inline_modifier(paramval)
            if altval:
              pagemsg("WARNING: Found inline modifier in param %s=%s along with alt param %s=%s, can't process: %s"
                % (param, paramval, altparam, altval, str(t)))
              return False
            if other_lang_param and inline_mod.get_modifier("lang") is not None:
              pagemsg("Skipping param %s=%s because of inline 'lang' modifier: %s"
                % (param, paramval, str(t)))
              return False
            if inline_mod.get_modifier("alt") is not None:
              return doparam(langparam, ("inline", param, "alt", "tr", inline_mod))
            else:
              return doparam(langparam, ("inline", param, None, "tr", inline_mod))
          except ParseException as e:
            pagemsg("WARNING: Exception processing lang %s, param %s=%s in template %s: %s"
              % (tlang, param, paramval, str(t), e))
            # fall through to the code below
        if altval:
          return doparam(langparam, ("separate", altparam, trparam))
        elif paramval:
          return doparam(langparam, ("separate", param, trparam))
        else:
          return False

      did_template = False
      if "grc" in langs:
        # Special-casing for Ancient Greek
        did_template = True
        def dogrcparam(trparam):
          if getp("head"):
            doparam(("direct", "grc"), ("separate", "head", trparam))
          else:
            doparam(("direct", "grc"), ("separate-pagetitle", "head", trparam))
        if tn in ["grc-noun-con"]:
          dogrcparam("5")
        elif tn in ["grc-proper noun", "grc-noun"]:
          dogrcparam("4")
        elif tn in ["grc-adj-1&2", "grc-adj-1&3", "grc-part-1&3"]:
          dogrcparam("3")
        elif tn in ["grc-adj-2nd", "grc-adj-3rd", "grc-adj-2&3"]:
          dogrcparam("2")
        elif tn in ["grc-num"]:
          dogrcparam("1")
        elif tn in ["grc-verb"]:
          dogrcparam("tr")
        else:
          did_template = False
      if "ru" in langs:
        # Special-casing for Russian
        if tn in ["ru-participle of", "ru-abbrev of", "ru-etym abbrev of",
            "ru-acronym of", "ru-etym acronym of", "ru-initialism of",
            "ru-etym initialism of", "ru-clipping of", "ru-etym clipping of",
            "ru-pre-reform"]:
          if getp("2"):
            doparam(("direct", "ru"), ("separate", "2", "tr"))
          else:
            doparam(("direct", "ru"), ("separate", "1", "tr"))
          did_template = True
      if "fa" in langs:
        # Special-casing for Persian
        did_template = True
        def dofaparam(trparam):
          if getp("head"):
            doparam(("direct", "fa"), ("separate", "head", trparam))
          else:
            doparam(("direct", "fa"), ("separate-pagetitle", "head", trparam))
        if tn in ["fa-noun"]:
          dofaparam("tr")
          if getp("tr2"):
            doparam(("direct", "fa"), ("separate-pagetitle", None, "tr2"))
          if getp("tr3"):
            doparam(("direct", "fa"), ("separate-pagetitle", None, "tr3"))
          doparam(("direct", "fa"), ("separate", "pl", "pltr"))
          doparam(("direct", "fa"), ("separate", "pl2", "pl2tr"))
          doparam(("direct", "fa"), ("separate", "pl3", "pl3tr"))
        elif tn in ["fa-proper noun"]:
          dofaparam("tr")
          if getp("tr2"):
            doparam(("direct", "fa"), ("separate-pagetitle", None, "tr2"))
          if getp("tr3"):
            doparam(("direct", "fa"), ("separate-pagetitle", None, "tr3"))
          if getp("tr4"):
            doparam(("direct", "fa"), ("separate-pagetitle", None, "tr4"))
          doparam(("direct", "fa"), ("separate", "pl", None))
          doparam(("direct", "fa"), ("separate", "pl2", None))
        elif tn in ["fa-adj", "fa-verb/new"]:
          dofaparam("tr")
          i = 2
          while getp("head" + str(i)):
            doparam(("direct", "fa"), ("separate", "head" + str(i), "tr" + str(i)))
            i += 1
          if tn == "fa-verb/new":
            i = 1
            while True:
              suf = "" if i == 1 else str(i)
              prstem = "prstem%s" % suf
              prstemtr = "prstem%str" % suf
              if not getp(prstem):
                break
              doparam(("direct", "fa"), ("separate", prstem, prstemtr))
              i += 1
        elif tn in ["fa-verb", "fa-colloq-verb"]:
          dofaparam("tr")
          doparam(("direct", "fa"), ("separate", "prstem", "tr2"))
          doparam(("direct", "fa"), ("separate", "prstem2", "tr3"))
        elif tn.startswith("fa-conj") and "head" not in tn:
          doparam(("direct", "fa"), ("separate", "1", "2"))
          doparam(("direct", "fa"), ("separate", "3", "4"))
          # FIXME! Some fa-conj-* templates use 5= as an alternative translit for 2= in the past,
          # and 6= as an alternative translit for 4= in the aorist. We don't currently have a way
          # of saying "read the Persian from param X= and translit from param Y= but don't save
          # the canonicalized Persian". The following two depend on us running in non-vocalizing mode.
          doparam(("direct", "fa"), ("separate", "1", "5"))
          doparam(("direct", "fa"), ("separate", "3", "6"))
          doparam(("direct", "fa"), ("separate", "7", "8"))
          doparam(("direct", "fa"), ("separate", "pre", "pretr"))
          doparam(("direct", "fa"), ("separate", "pr-part", "pr-part-tr"))
        elif tn in ["fa-numeral", "fa-number", "fa-interjection", "fa-adv", "fa-conjunction", "fa-preposition",
            "fa-pronoun"]:
          dofaparam("tr")
        elif tn in ["fa-phrase"]:
          if getp("head"):
            doparam(("direct", "fa"), ("separate", "head", "tr"))
          elif getp("1"):
            doparam(("direct", "fa"), ("separate", "1", "tr"))
          else:
            doparam(("direct", "fa"), ("separate-pagetitle", "head", "tr"))
        elif tn in ["fa-pred-c", "fa-adj-pred-c"]:
            doparam(("direct", "fa"), ("separate-pagetitle", None, "1"))
        elif tn in ["fa-decl-e-unc"]:
            doparam(("direct", "fa"), ("separate", "1", "2"))
        elif tn in ["fa-decl-c", "fa-decl-c-unc"]:
            doparam(("direct", "fa"), ("separate-pagetitle", None, "1"))
            # 4= when it exists often has a stress mark, which this will remove.
            doparam(("direct", "fa"), ("separate-pagetitle", None, "4"))
        else:
          did_template = False
      if "ar" in langs:
        pass
        # Special-casing for Arabic
        # FIXME, implement this
      #if "bg" in langs:
        # Special-casing for Bulgarian
        # FIXME, implement this

      if did_template:
        pass
      # Skip {{cattoc|...}}, {{i|...}}, etc. where the param isn't a language code,
      # as well as {{w|FOO|lang=LANG}} or {{wikipedia|FOO|lang=LANG}} or {{pedia|FOO|lang=LANG}} etc.,
      # where LANG is a Wikipedia language code, not a Wiktionary language code.
      elif (tn in [
        "cattoc", "commonscat",
        "gloss", "gl",
        "non-gloss definition", "non-gloss", "non gloss", "n-g", "ng", "ngd",
        "qualifier", "qual", "q", "i", "qf", "q-lite",
        # skip Wikipedia templates
        "pedialite", "pedia",
        "sense", "italbrac-colon",
        "w", "wikipedia", "wp", "lw",
        "slim-wikipedia", "swp",
        "pedlink",
        ]
        # More Wiki-etc. templates
        or tn.startswith("projectlink")
        or tn.startswith("PL:")
        # Babel/User templates indicating language proficiency
        or re.search("([Bb]abel|User)", tn)):
        pass
      # Skip {{attention|LANG|FOO}} or {{etyl|LANG|FOO}} or {{audio|LANG|FOO}}
      # or {{lb|LANG|FOO}} or {{context|LANG|FOO}} or {{Babel-2|LANG|FOO}}
      # or various others, where FOO is not text in LANG, and {{w|FOO|lang=LANG}}
      # or {{wikipedia|FOO|lang=LANG}} or {{pedia|FOO|lang=LANG}} etc., where
      # FOO is text in LANG but diacritics aren't stripped so shouldn't be added.
      elif tn in [
        "attention", "attn",
        "audio", "audio-IPA",
        "categorize", "cat", "catlangname", "cln", "topics", "top", "topic", "catlangcode", "C", "c",
        "dercat",
        "etyl", "etymid",
        "given name",
        "hyphenation", "hyph",
        "IPA", "IPAchar", "ic",
        "label", "lb", "lbl", "context", "cx", "term-label", "tlb",
        "+preo", "+posto", "+obj", "phrasebook", "place",
        "PIE word",
        "refcat", "rfe", "rfinfl", "rfc", "rfc-pron-n",
        "rhymes", "rhyme",
        "senseid", "senseno", "surname",
        "unknown", "unk", "uncertain", "unc",
        "was fwotd"
      ]:
        if include_notforeign:
          doparam("1", ("notforeign",))
      # Look for {{head|LANG|...|head=<FOREIGNTEXT>}}
      elif tn == "head":
        # There may be holes in heads or inflections.
        maxhead = find_max_term_index(t, named_params=["head", "tr"])
        if getp("head"):
          doparam("1", ("separate", "head", "tr"))
        else:
          doparam("1", ("separate-pagetitle", "head", "tr"))
        for i in range(2, maxhead + 1):
          doparam("1", ("separate", "head%s" % i, "tr%s" % i))
        maxinfl = find_max_term_index(t,
          first_numeric=lambda pn: (pn - 1) // 2 if pn >= 3 else None,
          named_params=lambda pn:
            int(re.sub("^f([0-9]+)(alt|tr)$", r"\1", pn)) if re.search("^f([0-9]+)(alt|tr)$", pn) else None
        )
        for i in range(1, maxinfl + 1):
          if getp("f%salt" % i):
            doparam("1", ("separate", "f%salt" % i, "f%str" % i))
          else:
            doparam("1", ("separate", str(i * 2 + 2), "f%str" % i))
      # Look for {{t|LANG|<PAGENAME>|alt=<FOREIGNTEXT>}}
      elif tn in translation_templates:
        doparam_checking_alt("1", "2", "alt", "tr")
      # Look for {{suffix|LANG|<PAGENAME>|alt1=<FOREIGNTEXT>|<PAGENAME>|alt2=...}}
      # or  {{suffix|LANG|<FOREIGNTEXT>|<FOREIGNTEXT>|...}}
      elif tn in ["suffix", "suf", "prefix", "pre", "affix", "af",
          "confix", "con", "circumfix", "infix", "compound", "com",
          "prefixusex", "prefex", "suffixusex", "sufex", "affixusex", "afex",
          "surf", "surface analysis", "blend", "univerbation", "univ", # remove 'blend of'
          "doublet", "dbt"]:
        if tn in ["circumfix", "confix", "con"]:
          maxind = 3
        elif tn in ["infix"]:
          maxind = 2
        else:
          # Don't just do cases up through where there's a numbered param because there may be holes.
          maxind = find_max_term_index(t, first_numeric="2", named_params=True)
        offset = 1
        for i in range(1, maxind + 1):
          # require_index specified in [[Module:compound/templates]] and [[Module:etymology/templates/doublet]]
          doparam_checking_alt("1", str(i + offset), "alt" + str(i), "tr" + str(i), other_lang_param="lang" + str(i),
            check_inline_modifiers=True)
      elif tn in ["pseudo-loan", "pl"]:
        maxind = find_max_term_index(t, first_numeric="3", named_params=True)
        offset = 2
        for i in range(1, maxind + 1):
          # require_index specified in [[Module:compound/templates]]
          doparam_checking_alt("2", str(i + offset), "alt" + str(i), "tr" + str(i), other_lang_param="lang" + str(i),
            check_inline_modifiers=True)
        if include_notforeign:
          doparam("1", ("notforeign",))
      elif tn in ["synonyms", "syn", "antonyms", "ant", "antonym", "hypernyms", "hyper",
          "hyponyms", "hypo", "meronyms", "mer", "mero", "holonyms", "hol", "holo", "troponyms",
          "coordinate terms", "cot", "coord", "coo", "perfectives", "pf", "imperfectives", "impf",
          "homophones", "homophone", "hmp", "inline alt forms", "alti", "altform-inline"]:
        maxind = find_max_term_index(t, first_numeric="2", named_params=["alt", "tr"])
        termind = 0
        for i in range(1, maxind + 1):
          term = getp(str(i + 1))
          if term.startswith("Thesaurus:"):
            break
          if term != ";": # semicolons are ignored for indexed params
            termind += 1
            # require_index not specified in [[Module:nyms]]
            doparam_checking_alt("1", str(i + 1), index_param("alt", termind), index_param("tr", termind),
                check_inline_modifiers=True)
      elif tn == "form of":
        if getp("4"):
          doparam("1", ("separate", "4", "tr"))
        else:
          doparam("1", ("separate", "3", "tr"))
      # Templates where we don't check for alternative text because
      # the following parameter is used for the translation.
      elif tn in ["ux", "usex", "uxi", "quote", "coi"]:
        doparam("1", ("separate", "2", "tr"))
      elif tn == "Q":
        doparam("1", ("separate", "quote", "tr"))
      elif tn == "lang":
        doparam("1", ("separate", "2", None))
      #elif tn in ["w", "wikipedia", "wp"]:
      #  if getp("2"):
      #    # Can't replace param 1 (page linked to), but it's OK to frob the
      #    # display text
      #    doparam("lang", ("separate", "2", None))
      elif tn in ["w2"]: # FIXME: review this
        if getp("3"):
          # Can't replace param 2 (page linked to), but it's OK to frob the
          # display text
          doparam("1", ("separate", "3", "tr"))
      elif tn in ["cardinalbox", "ordinalbox"]:
        # FUCKME: This is a complicated template, might be doing it wrong
        doparam("1", ("separate", "5", None))
        doparam("1", ("separate", "6", None))
        for p in ["card", "ord", "adv", "mult", "dis", "coll", "frac",
            "optx", "opt2x"]:
          if getp(p + "alt"):
            doparam("1", ("separate", p + "alt", p + "tr"))
          else:
            doparam("1", ("separate", p, p + "tr"))
        if getp("alt"):
          doparam("1", ("separate", "alt", "tr"))
        else:
          doparam("1", ("separate", "wplink", None))
      elif tn in ["quote-book", "quote-hansard", "quote-journal",
          "quote-newsgroup", "quote-song", "quote-us-patent", "quote-video",
          "quote-web", "quote-wikipedia"]:
        if getp("passage") or getp("text"):
          doparam("1", ("separate", "passage" if getp("passage") else "text",
            "transliteration" if getp("transliteration") else "tr"))
      elif tn in ["alter", "alt"]:
        i = 1
        # Dialect specifiers follow a blank param.
        while True:
          if not getp(str(i + 1)):
            break
          # require_index not specified in [[Module:alternative forms]]
          doparam_checking_alt("1", str(i + 1), index_param("alt", i), index_param("tr", i),
              check_inline_modifiers=True)
          i += 1
      elif tn in ["desc", "descendant", "desctree", "descendants tree"]:
        # Don't just do cases up through where there's a numbered param because there may be holes.
        maxind = find_max_term_index(t, first_numeric="2", named_params=True)
        for i in range(1, maxind + 1):
          # require_index not specified in [[Module:etymology/templates/descendant]]
          doparam_checking_alt("1", str(i + 1), index_param("alt", i), index_param("tr", i),
              check_inline_modifiers=True)
      elif tn in ["&lit"]:
        # Don't just do cases up through where there's a numbered param because there may be holes.
        maxind = find_max_term_index(t, first_numeric="2", named_params=True)
        for i in range(1, maxind + 1):
          # require_index specified in [[Module:definition/templates]]; no translit param currently
          doparam_checking_alt("1", str(i + 1), "alt" + str(i), None)
      elif tn in [
          "col1", "col2", "col3", "col4", "col5",
          "col1-u", "col2-u", "col3-u", "col4-u", "col5-u",
          "der2", "der3", "der4",
          "rel2", "rel3", "rel4"]:
        i = 2
        while getp(str(i)):
          doparam_checking_alt("1", str(i), None, None, check_inline_modifiers=True)
          i += 1
      elif tn in ["col", "col-u"]:
        i = 3
        while getp(str(i)):
          doparam_checking_alt("1", str(i), None, None, check_inline_modifiers=True)
          i += 1
      elif tn == "elements":
        doparam("1", ("separate", "3", None))
        doparam("1", ("separate", "5", None))
        doparam("1", ("separate", "next2", None))
        doparam("1", ("separate", "prev2", None))
      elif tn in ["der", "derived", "uder", "der+", "inh", "inherited", "inh+", "bor", "borrowed", "bor+",
          "lbor", "learned borrowing", "slbor", "semi-learned borrowing",
          "obor", "orthographic borrowing", "ubor", "unadapted borrowing",
          "sl", "semantic loan" "psm", "phono-semantic matching",
          "calque", "cal", "clq", "partial calque", "pcal", "partial translation", "semi-calque"]:
        if getp("alt"):
          doparam("2", ("separate", "alt", "tr"))
        elif getp("4"):
          doparam("2", ("separate", "4", "tr"))
        else:
          doparam("2", ("separate", "3", "tr"))
        tlang = getp("1")
        if include_notforeign:
          doparam("1", ("notforeign",))
      elif tn == "root":
        i = 3
        while getp(str(i)):
          doparam("2", ("separate", str(i), None))
          i += 1
        if include_notforeign:
          doparam("1", ("notforeign",))
      elif tn == "etyl":
        if include_notforeign:
          doparam("1", ("notforeign",))
          doparam("2", ("notforeign",))
      # Look for any other template with lang as first argument, but skip templates
      # that have what looks like a language prefix in their name, e.g. 'eo-form of',
      # 'cs-conj-pros-it', 'vep-decl-stems', 'sw-adj form of'. Also skip templates with
      # a colon in their name, e.g. 'U:tr:first-person singular'.
      elif not lang_prefix_template(tn) and getp("1") in langs:
        # Look for:
        #   {{m|LANG|<PAGENAME>|<FOREIGNTEXT>}}
        #   {{m|LANG|<PAGENAME>|alt=<FOREIGNTEXT>}}
        #   {{m|LANG|<FOREIGNTEXT>}}
        if getp("alt"):
          doparam("1", ("separate", "alt", "tr"))
        elif getp("3"):
          doparam("1", ("separate", "3", "tr"))
        elif tn != "transliteration":
          doparam("1", ("separate", "2", "tr"))
      if saw_template[0]:
        templates_seen[tn] = templates_seen.get(tn, 0) + 1
      if changed_template[0]:
        templates_changed[tn] = templates_changed.get(tn, 0) + 1
    return actions

  actions = []
  newtext = [text]
  parsed = parse_text(text)

  # First split up any templates with commas in the Latin.
  if split_templates:
    assert False, "split_templates not currently supported"
  #  def pagemsg(txt):
  #    msg("Page %s %s: %s" % (index, pagetitle, txt))

  #  def process_param_for_splitting(obj):
  #    if isinstance(obj.param, list):
  #      fromparam, toparam = obj.param
  #    else:
  #      fromparam = obj.param
  #    if fromparam == "page title":
  #      foreign = obj.pagetitle
  #    else:
  #      foreign = getparam(obj.t, fromparam)
  #    latin = getparam(obj.t, obj.paramtr)
  #    if (re.search(split_templates, latin) and not
  #        re.search(split_templates, foreign)):
  #      trs = re.split("\\s*" + split_templates + "\\s*", latin)
  #      oldtemp = str(obj.t)
  #      newtemps = []
  #      for tr in trs:
  #        addparam(obj.t, obj.paramtr, tr)
  #        newtemps.append(str(obj.t))
  #      newtemp = ", ".join(newtemps)
  #      old_newtext = newtext[0]
  #      pagemsg("Splitting template %s into %s" % (oldtemp, newtemp))
  #      new_newtext = old_newtext.replace(oldtemp, newtemp)
  #      if old_newtext == new_newtext:
  #        pagemsg("WARNING: Unable to locate old template when splitting trs on commas: %s"
  #            % oldtemp)
  #      elif len(new_newtext) - len(old_newtext) != len(newtemp) - len(oldtemp):
  #        pagemsg("WARNING: Length mismatch when splitting template on tr commas, may have matched multiple templates: old=%s, new=%s" % (
  #          oldtemp, newtemp))
  #      newtext[0] = new_newtext
  #      return ["split %s=%s" % (obj.paramtr, latin)]
  #    return []
  #
  #  actions += do_process_one_page_links(pagetitle, index, parsed,
  #      process_param_for_splitting)
  #  parsed = parse_text(newtext[0])

  actions += do_process_one_page_links(pagetitle, index, parsed, process_param)
  return str(parsed), actions

#def process_one_page_links_wrapper(page, index, text):
#  return process_one_page_links(str(page.title()), index, text)
#
#if "," in cattype:
#  cattypes = cattype.split(",")
#else:
#  cattypes = [cattype]
#for cattype in cattypes:
#  if cattype in ["translation", "links"]:
#    if cattype == "translation":
#      templates = translation_templates
#    else:
#      templates = ["l", "m", "term", "link", "mention"]
#    for template in templates:
#      msg("Processing template %s" % template)
#      errmsg("Processing template %s" % template)
#      for index, page in references("Template:%s" % template, startFrom, upTo):
#        do_edit(page, index, process_one_page_links_wrapper, save=save,
#            verbose=verbose)
#  elif cattype == "pages":
#    for index, pagename in iter_items(pages_to_do, startFrom, upTo):
#      page = pywikibot.Page(site, pagename)
#      do_edit(page, index, process_one_page_links_wrapper, save=save,
#          verbose=verbose)
#  elif cattype == "pagetext":
#    for index, current in iter_items(pages_to_do, startFrom, upTo,
#        get_name=lambda x:x[0]):
#      pagetitle, pagetext = current
#      do_process_text(pagetitle, pagetext, index, process_one_page_links,
#          verbose=verbose)
#  else:
#    if cattype == "vocab":
#      cats = ["%s lemmas" % longlang, "%s non-lemma forms" % longlang]
#    elif cattype == "borrowed":
#      cats = [subcat for subcat, index in
#          cat_subcats("Terms derived from %s" % longlang)]
#    else:
#      cats = [cattype]
#      #raise ValueError("Category type '%s' should be 'vocab', 'borrowed', 'translation', 'links', 'pages' or 'pagetext'")
#    for index, page in cat_articles(cats, startFrom, upTo):
#      do_edit(page, index, process_one_page_links_wrapper, save=save,
#          verbose=verbose)

def output_process_links_template_counts(templates_seen, templates_changed):
  msg("Templates seen:")
  for template, count in sorted(templates_seen.items(), key=lambda x:-x[1]):
    msg("  %s = %s" % (template, count))
  msg("Templates processed:")
  for template, count in sorted(templates_changed.items(), key=lambda x:-x[1]):
    msg("  %s = %s" % (template, count))

def find_lang_section_from_page(pagename, lang, pagemsg, errandpagemsg):
  page = pywikibot.Page(site, pagename)
  if not safe_page_exists(page, errandpagemsg):
    pagemsg("Page %s doesn't exist" % pagename)
    return False

  pagetext = str(page.text)

  return find_lang_section(pagetext, lang, pagemsg)

def split_trailing_separator(sectext):
  mm = re.match(r"^(.*?\n)(\n*--+\n*)$", sectext, re.S)
  if mm:
    secbody, sectail = mm.group(1), mm.group(2)
  else:
    secbody = sectext
    sectail = ""
  return secbody, sectail

def split_trailing_categories(secbody, sectail):
  mm = re.match(r"^(.*?\n)(\n*(?:(?:\[\[(?:[Cc][Aa][Tt][Ee][Gg][Oo][Rr][Yy]|[Cc][Aa][Tt]):[^\[\]\n]+\]\]|\{\{(?:c|C|cat|cln|top|topic|topics|categorize|catlangname|catlangcode)\|[^{}\n]*\}\})\n*)*)$",
      secbody, re.S)
  if mm:
    secbody, secbodytail = mm.group(1), mm.group(2)
    sectail = secbodytail + sectail
  return secbody, sectail

def split_trailing_separator_and_categories(sectext):
  # Extract off trailing separator
  secbody, sectail = split_trailing_separator(sectext)

  # Split off categories at end
  secbody, sectail = split_trailing_categories(secbody, sectail)

  return secbody, sectail

def force_two_newlines_in_secbody(secbody, sectail):
  m = re.search(r"\A(.*?)(\n*)\Z", secbody, re.S)
  secbody, secbody_finalnl = m.groups()
  secbody += "\n\n"
  sectail = secbody_finalnl + sectail
  return secbody, sectail

def split_text_into_sections(pagetext, pagemsg):
  # Split into sections
  sections = re.split(r"(^==[^=\n]+==[ \t]*\n)", pagetext, 0, re.M)
  sections_by_lang = {}
  section_langs = []
  for j in range(2, len(sections), 2):
    m = re.search(r"\A==[ \t]*(.*?)[ \t]*==[ \t]*\n\Z", sections[j - 1])
    if not m:
      if pagemsg:
        pagemsg("WARNING: Internal error: Can't match section header: %s" % (sections[j - 1].rstrip("\n")))
    else:
      seclang = m.group(1)
      section_langs.append((j, seclang))
      if seclang in sections_by_lang:
        if pagemsg:
          pagemsg("WARNING: Found two %s sections, skipping second one" % seclang)
      else:
        sections_by_lang[seclang] = j
  return sections, sections_by_lang, section_langs

# Split `secbody` (the body of a language section, as returned by find_modifiable_lang_section()) into subsections.
# Return a tuple of four values:
#   `subsections`, `subsections_by_header`, `subsection_headers`, `subsection_levels`
# `subsections` is a list of the text of the sections, where odd-numbered elements contain headers and even-numbered
# elements contain text between headers. `subsections_by_header` is a dictionary from header name to a list of the
# indices of the sections with that header (indices are to the section text, not the header text). `subsection_headers`
# is a dictionary from section index (only for even-numbered sections starting with 2) to the header of that section.
# `subsection_levels` is similar to `subsection_headers` but the values indicate the the header level of that section
# (as determined by the number of equal signs of the section header). The original language section body can be
# reconstructed by concatenating the values of `subsections` with a blank string between them.
def split_text_into_subsections(secbody, pagemsg):
  subsections = re.split(r"(^==+[^=\n]+==+[ \t]*\n)", secbody, 0, re.M)
  subsection_headers = {}
  subsections_by_header = defaultdict(list)
  subsection_levels = {}
  for j in range(2, len(subsections), 2):
    m = re.search(r"\A(==+)[ \t]*(.*?)[ \t]*(==+)[ \t]*\n\Z", subsections[j - 1])
    if not m:
      if pagemsg:
        pagemsg("WARNING: Internal error: Can't match subsection header: %s" % (subsections[j - 1].rstrip("\n")))
    else:
      left_equals, header, right_equals = m.groups()
      left_equals = len(left_equals)
      right_equals = len(right_equals)
      if left_equals != right_equals:
        if pagemsg:
          pagemsg("WARNING: Found %s equalsigns on the left but %s equal signs on the right, assuming smaller one: %s"
            % (left_equals, right_equals, subsections[j - 1].rstrip("\n")))
        num_equals = min(left_equals, right_equals)
      else:
        num_equals = left_equals
      subsection_levels[j] = num_equals
      subsection_headers[j] = header
      subsections_by_header[header].append(j)
  return subsections, subsections_by_header, subsection_headers, subsection_levels

# Find the section for the language `lang` in `text` (the text of the page), returning values so that the
# language-specific text can be modified and then the page as a whole put back together in preparation for saving.
# Return None if the language can't be found; otherwise, return a tuple of five values:
#   `sections`, `j`, `secbody`, `sectail`, `has_non_lang`
# `sections` contains the per-language sections, where `j` points to the section containing the language in
# question. The text of this section has been split into `secbody` and `sectail`, where `sectail` contains
# any trailing categories and separator, and `secbody` contains the remainder of the section text. `has_non_lang`
# is True if any sections for other languages are encountered.
#
# The code to call this function should look like this:
#
#    retval = blib.find_modifiable_lang_section(text, langname, pagemsg)
#    if retval is None:
#      return
#    sections, j, secbody, sectail, has_non_lang = retval
#
# After modifying `secbody` as appropriate, reconstruct the page text as follows:
#
#    sections[j] = secbody + sectail
#    text = "".join(sections)
#
# If `lang` is None, the passed-in `text` is assumed to already contain only the text of the appropriate language
# (as, for example, if find_regex.py is run with the '--lang LANGNAME' option set). The function won't look for
# a language-specific section but will still separate off trailing categories and separators.
#
# If `force_final_nls` is given, `secbody` will be modified so that it always ends in two newlines, and the
# actual newlines (if any) at the end of `secbody` will be included at the beginning of `sectail`. This
# simplifies doing things like rearranging subsections or adding subsections to the end. In this case, to
# reconstruct the page text, use the following:
#
#    sections[j] = secbody.rstrip("\n") + sectail
#    text = "".join(sections)
def find_modifiable_lang_section(text, lang, pagemsg, force_final_nls=False):
  sections, sections_by_lang, _ = split_text_into_sections(text, pagemsg)

  has_non_lang = False

  if lang is None:
    sections = [text]
    j = 0
  elif lang not in sections_by_lang:
    if pagemsg:
      pagemsg("WARNING: Can't find %s section, skipping" % lang)
    return None
  else:
    j = sections_by_lang[lang]
    has_non_lang = len(sections_by_lang) > 1

  secbody, sectail = split_trailing_separator_and_categories(sections[j])

  if force_final_nls:
    secbody, sectail = force_two_newlines_in_secbody(secbody, sectail)

  return sections, j, secbody, sectail, has_non_lang

def find_lang_section(pagetext, lang, pagemsg):
  splitsections, sections_by_lang, _ = split_text_into_sections(pagetext, pagemsg)

  if lang not in sections_by_lang:
    if pagemsg:
      pagemsg("WARNING: Can't find %s section, skipping" % lang)
    return None
  return splitsections[sections_by_lang[lang]]

def replace_in_text(text, curr, repl, pagemsg, count=-1, no_found_repl_check=False,
    abort_if_warning=False, is_re=False):
  if is_re:
    m = re.search(curr, text, re.M)
    if not m:
      pagemsg("WARNING: Unable to locate regexp: %s" % curr)
      return text, False
    curr = m.group(0)
  else:
    found_curr = curr in text
    if not found_curr:
      pagemsg("WARNING: Unable to locate current text: %s" % curr)
      return text, False
  if not no_found_repl_check and repl:
    found_repl = repl in text
    if found_repl:
      pagemsg("WARNING: Already found replacement text: %s" % repl)
      return text, False
  newtext = text.replace(curr, repl, count)
  newtext_text_diff = len(newtext) - len(text)
  repl_curr_diff = len(repl) - len(curr)
  if repl_curr_diff == 0:
    if newtext_text_diff != 0:
      pagemsg("WARNING: Something wrong, no change in text length during replacement but expected change: Expected length change=%s, actual=%s, curr=%s, repl=%s"
          % (repl_curr_diff, newtext_text_diff, curr, repl))
      if abort_if_warning:
        return text, False
  else:
    ratio = float(newtext_text_diff) / repl_curr_diff
    if ratio == int(ratio):
      if int(ratio) > 1:
        pagemsg("WARNING: Replaced %s occurrences of curr=%s with repl=%s"
            % (int(ratio), curr, repl))
        if abort_if_warning:
          return text, False
    else:
      pagemsg("WARNING: Something wrong, length mismatch during replacement: Expected length change=%s, actual=%s, ratio=%.2f, curr=%s, repl=%s"
          % (repl_curr_diff, newtext_text_diff, ratio, curr, repl))
      if abort_if_warning:
        return text, False
  text = newtext
  return text, True

def split_generate_args(tempresult):
  args = {}
  for arg in re.split(r"\|", tempresult):
    values = arg.split("=")
    if len(values) != 2:
      errandmsg("WARNING: Bad value '%s' during split_generate_args" % values)
    else:
      name, value = values
      value = value.replace("<!>", "|").replace("<->", "=")
      # With manually specified declensions, we get back "-" for unspecified
      # forms, which need to be omitted; otherwise they're automatically omitted.
      if value != "-":
        args[name] = value
  return args

def compare_new_and_old_template_forms(origt, newt, generate_old_forms, generate_new_forms, pagemsg, errandpagemsg,
    already_split=False, show_all=False):
  bad = False
  old_result = generate_old_forms()
  if old_result is None:
    errandpagemsg("WARNING: Error generating old forms, can't compare")
    return False
  old_forms = old_result if already_split else split_generate_args(old_result)
  new_result = generate_new_forms()
  if new_result is None:
    errandpagemsg("WARNING: Error generating new forms, can't compare")
    return False
  new_forms = new_result if already_split else split_generate_args(new_result)
  for form in set(old_forms.keys() + new_forms.keys()):
    if form not in new_forms:
      pagemsg("WARNING: for original %s and new %s, form %s=%s in old forms but missing in new forms" % (
        origt, newt, form, old_forms[form]))
      bad = True
      if not show_all:
        return False
      continue
    if form not in old_forms:
      pagemsg("WARNING: for original %s and new %s, form %s=%s in new forms but missing in old forms" % (
        origt, newt, form, new_forms[form]))
      bad = True
      if not show_all:
        return False
      continue
    nforms = new_forms[form]
    if type(nforms) is list:
      nforms = set(nforms)
    oforms = old_forms[form]
    if type(oforms) is list:
      oforms = set(oforms)
    if nforms != oforms:
      pagemsg("WARNING: for original %s and new %s, form %s=%s in old forms but =%s in new forms" % (
        origt, newt, form, old_forms[form], new_forms[form]))
      bad = True
      if not show_all:
        return False
      continue
  if not bad:
    pagemsg("%s and %s have same forms" % (origt, newt))
  return not bad

def find_defns(text, langcode):
  lines = text.split("\n")
  defns = []
  for line in lines:
    if not line.startswith('#'):
      continue
    if line.startswith('#:') or line.startswith('#*'):
      line = re.sub('^#[*:]+ *', '', line)
      line = re.sub(r'\{\{uxi?\|%s\|((?:[^{}]|\{\{.*?\}\})+)\}\}' % langcode, r'ux:\1', line)
    else:
      line = re.sub('^# *', '', line)
    def convert_to_parens(m):
      labels = m.group(1).split('|')
      return ''.join('(%s)' % label for label in labels)
    line = re.sub(r'\{\{lb\|%s\|(.*?)\}\} *' % langcode, convert_to_parens, line)
    line = line.replace(';', r'\;')
    defns.append(line)
  return defns

class WikiDumpHandler(xml.sax.ContentHandler):
  def __init__(self, pagecallback):
    self.pagecallback = pagecallback
    self.title = None
    self.text = None
    self.cur = None

  def startElement(self, name, attrs):
    if name == "title":
      self.cur = "title"
      self.title = ""
    elif name == "text":
      self.cur = "text"
      self.text = []

  def endElement(self, name):
    if name == "text":
      self.pagecallback(self.title, "".join(self.text))
    self.cur = None

  def characters(self, content):
    if self.cur == "title":
      self.title += content
    elif self.cur == "text":
      self.text.append(content)

class DumpExitException(Exception):
  pass

def parse_dump(fp, pagecallback, startprefix=None, endprefix=None,
    skip_ignorable_pages=False):
  item_handler = ProcessItems(startprefix=startprefix, endprefix=endprefix,
      skip_ignorable_pages=skip_ignorable_pages)

  def mycallback(title, text):
    retval = item_handler.should_process(title)
    if retval is None:
      raise DumpExitException
    if retval != False:
      pagecallback(retval, title, text)

  handler = WikiDumpHandler(mycallback)
  try:
    xml.sax.parse(fp, handler)
  except DumpExitException as e:
    return

def yield_text_from_find_regex(lines, verbose):
  in_multiline = False
  comment = None
  while True:
    try:
      line = next(lines)
    except StopIteration:
      break
    if in_multiline and re.search("^-+ end text -+$", line):
      in_multiline = False
      yield pagenum, pagename, "".join(templines), comment
      comment = None
    elif in_multiline:
      if line.rstrip('\n').endswith(':'):
        if verbose:
          errmsg("WARNING: Possible missing ----- end text -----: %s" % line.rstrip('\n'))
      templines.append(line)
    else:
      line = line.rstrip('\n')
      #if line.endswith(':'):
      #  pagename = "Template:%s" % line[:-1]
      #  in_multiline = True
      #  templines = []
      #else:
      m = re.search("^Page ([0-9]+) (.*): (?:Would save with comment|Skipped, no changes; previous comment) = (.*)$", line)
      if m:
        comment_pagenum, comment_pagename, comment = m.groups()
        comment_pagenum = int(comment_pagenum)
      else:
        m = re.search("^Page ([0-9]+) (.*): -+ begin text -+$", line)
        if m:
          pagenum, pagename = m.groups()
          pagenum = int(pagenum)
          if comment is not None and (pagenum != comment_pagenum or pagename != comment_pagename):
            errmsg("WARNING: Processing text for index %s, page '%s' but saw comment '%s' for different index %s, page '%s'; ignoring"
              % (pagenum, pagename, comment, comment_pagenum, comment_pagename))
            comment = None
          in_multiline = True
          templines = []
        elif verbose:
          msg("Skipping: %s" % line)

def yield_text_from_diff(lines, verbose):
  in_multiline = False
  while True:
    try:
      line = next(lines)
    except StopIteration:
      break
    if in_multiline and re.search("^Page [0-9]+", line):
      in_multiline = False
      yield pagenum, pagename, "".join(templines)
    elif in_multiline:
      templines.append(line)
    else:
      line = line.rstrip('\n')
      m = re.search("^Page ([0-9]+) (.*): Diff:$", line)
      if m:
        pagenum = m.group(1)
        pagename = m.group(2)
        in_multiline = True
        templines = []
      elif verbose:
        msg("Skipping: %s" % line)

def yield_pages_from_previous_output(lines, verbose):
  prev_pagenum = None
  prev_pagename = None
  while True:
    try:
      line = next(lines)
    except StopIteration:
      break
    line = line.rstrip('\n')
    m = re.search("^Page ([0-9]+) (.*?): ", line)
    if m:
      pagenum = int(m.group(1))
      pagename = m.group(2)
      if pagenum != prev_pagenum or pagename != prev_pagename:
        yield pagenum, pagename
      prev_pagenum = pagenum
      prev_pagename = pagename

def do_process(q, iolock, process):
  while True:
    item = q.get()
    if item is None:
      break
    process(item, iolock)

def process_in_parallel(generator, process, num_workers=5):
  q = mp.Queue(maxsize=num_workers)
  iolock = mp.Lock()
  pool = mp.Pool(num_workers, initializer=do_process, initargs=(q, iolock, process))
  for index, item in enumerate(generator):
    q.put(item)  # blocks until q below its max size
    with iolock:
      msg("Queued item #%s" % (index + 1))
  for _ in range(num_workers):  # tell workers we're done
    q.put(None)
  pool.close()
  pool.join()
