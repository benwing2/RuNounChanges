#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Author: Benwing; bits and pieces taken from code written by CodeCat/Rua for MewBot

import pywikibot, mwparserfromhell, re, string, sys, codecs, urllib2, datetime, json, argparse, time
from arabiclib import reorder_shadda
from collections import defaultdict
import xml.sax
import difflib
import traceback
import multiprocessing as mp

site = pywikibot.Site()

appendix_only_langnames = [
  "Afrihili",
  "Black Speech",
  "Bolak",
  "Communicationssprache",
  "Dothraki",
  "Eloi",
  "Glosa",
  "Goa'uld",
  "Interlingue",
  "Klingon",
  "Kotava",
  u"Láadan",
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

def msg(text):
  #pywikibot.output(text.encode('utf-8'), toStdout = True)
  print text.encode('utf-8')

def msgn(text):
  #pywikibot.output(text.encode('utf-8'), toStdout = True)
  print text.encode('utf-8'),

def errmsg(text):
  #pywikibot.output(text.encode('utf-8'))
  print >> sys.stderr, text.encode('utf-8')

def errmsgn(text):
  print >> sys.stderr, text.encode('utf-8'),

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

def parse_text(text):
  return mwparserfromhell.parser.Parser().parse(text, skip_style_tags=True)

def parse(page):
  return parse_text(page.text)

def getparam(template, param):
  if template.has(param):
    return unicode(template.get(param).value)
  else:
    return ""

def addparam(template, param, value, showkey=None, before=None):
  if re.match("^[0-9]+", param):
    template.add(param, value, preserve_spacing=False, showkey=showkey,
        before=before)
  else:
    template.add(param, value, showkey=showkey, before=before)

def rmparam(template, param):
  if template.has(param):
    template.remove(param)

def getrmparam(template, param):
  val = getparam(template, param)
  rmparam(template, param)
  return val

def bool_param_is_true(param):
  return param and param not in ["0", "no", "n", "false"]

def tname(template):
  return unicode(template.name).strip()

def pname(param):
  return unicode(param.name).strip()

def set_template_name(template, name, origname=None):
  if not origname:
    origname = unicode(template.name)
  if origname.endswith("\n"):
    template.name = name + "\n"
  else:
    template.name = name

def do_assert(cond, msg=None):
  if msg:
    assert cond, msg
  else:
    assert cond
  return True

# Return the name of the first parameter in template T.
def find_first_param(t):
  if len(t.params) > 0:
    return pname(t.params[0])
  else:
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
  if isinstance(first_numeric, basestring):
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

# Retrieve a chain of parameters from template T, where the first parameter
# is named FIRST, and the remainder are named PREF2, PREF3, etc. FIRST can be
# a list of parameters to try in turn. If FIRSTDEFAULT is given, use if FIRST
# is missing or empty. This also checks for PREF if not the same as FIRST or
# (if FIRST is a list) any element of FIRST, and PREF1, because the
# parameter-handling code checks for both. Finally, it allows gaps in the
# numbered parameters, because the parameter-handling code allows them.
def fetch_param_chain(t, first, pref=None, firstdefault=""):
  is_number = type(first) is not list and re.search("^[0-9]+$", first)
  if pref is None:
    assert type(first) is not list, "If pref= is omitted, first= must not be a list"
    pref = "" if is_number else first
  ret = []
  if type(first) is not list:
    first = [first]
  val = None
  for f in first:
    val = getparam(t, f)
    if val:
      ret.append(val)
      break
  else:
    # no break
    if firstdefault:
      ret.append(firstdefault)
  if pref and pref not in first:
    val = getparam(t, pref)
    if val:
      ret.append(val)
  first_num = 1 if not is_number or pref else int(first[0]) + 1
  for i in xrange(first_num, 30):
    param = pref + str(i)
    if param not in first:
      val = getparam(t, param)
      if val:
        ret.append(val)
  return ret

def append_param_to_chain(t, val, firstparam, parampref=None, before=None):
  is_number = re.search("^[0-9]+$", firstparam)
  if parampref is None:
    parampref = "" if is_number else firstparam
  paramno = int(firstparam) - 1 if is_number else 0
  if is_number:
    insert_before_param = find_first_param(t)
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

def set_param_chain(t, values, firstparam, parampref=None, before=None):
  is_number = re.search("^[0-9]+$", firstparam) and not parampref
  if parampref is None:
    parampref = "" if is_number else firstparam
  paramno = int(firstparam) - 1 if is_number else 0
  if is_number:
    insert_before_param = find_first_param(t)
  else:
    insert_before_param = None
  first = True
  for val in values:
    paramno += 1
    next_param = firstparam if first else "%s%s" % (parampref, paramno)
    # When adding a param, if the param already exists, we want to just replace the param.
    # Otherwise, we want to add directly after the last-added param.
    if t.has(next_param):
      t.add(next_param, val, before=before)
    else:
      t.add(next_param, val, before=before or insert_before_param)
    insert_before_param = find_following_param(t, next_param)
    first = False
  for i in xrange(paramno + 1, 30):
    next_param = firstparam if first else "%s%s" % (parampref, i)
    rmparam(t, next_param)

def sort_params(t):
  numbered_params = []
  named_params = []
  for param in t.params:
    if re.search(r"^[0-9]+$", unicode(param.name)):
      numbered_params.append((param.name, param.value))
    else:
      named_params.append((param.name, param.value))
  numbered_params.sort(key=lambda nameval: int(unicode(nameval[0])))
  del t.params[:]
  for name, value in numbered_params:
    t.add(name, value)
  for name, value in named_params:
    t.add(name, value)

def display(page):
  errmsg(u'# [[{0}]]'.format(page.title()))

def dump(page):
  old = page.get(get_redirect=True)
  msg(u'Contents of [[{0}]]:\n{1}\n----------'.format(page.title(), old))

def handle_process_page_retval(retval, existing_text, pagemsg, verbose, do_diff):
  has_changed = False

  if retval is None:
    new = None
    comment = None
  else:
    new, comment = retval

  if new:
    new = unicode(new)

    # Canonicalize shaddas when comparing pages so we don't do saves
    # that only involve different shadda orders.
    has_changed = reorder_shadda(existing_text) != reorder_shadda(new)
    if has_changed:
      if do_diff:
        pagemsg("Diff:")
        oldlines = existing_text.splitlines(True)
        newlines = new.splitlines(True)
        diff = difflib.unified_diff(oldlines, newlines)
        dangling_newline = False
        for line in diff:
          dangling_newline = not line.endswith('\n')
          sys.stdout.write(line.encode('utf-8'))
          if dangling_newline:
            sys.stdout.write("\n")
        if dangling_newline:
          sys.stdout.write("\\ No newline at end of file\n")
        #pywikibot.showDiff(existing_text, new, context=3)
      elif verbose:
        pagemsg("Replacing <%s> with <%s>" % (existing_text, new))
      assert comment, "Text has changed without a comment specified"

  if type(comment) is list:
    comment = "; ".join(group_notes(comment))

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
    self.title = unicode(page.title())
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
    except urllib2.HTTPError as e:
      if e.code != 503: # Service unavailable
        raise
    except:
      p.errandpagemsg("WARNING: Error")
      raise

    break

def do_edit(page, index, func=None, null=False, save=False, verbose=False, diff=False):
  title = unicode(page.title())
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
          page.text = new
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
    except urllib2.HTTPError as e:
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
def iter_pages(pageiter, startsort = None, endsort = None, key = None):
  i = 0
  t = None
  steps = 50

  for current in pageiter:
    i += 1

    if startsort != None and isinstance(startsort, int) and i < startsort:
      continue

    if key:
      keyval = key(current)
      pagetitle = keyval
    elif isinstance(current, basestring):
      keyval = current
      pagetitle = keyval
    else:
      keyval = current.title(withNamespace=False)
      pagetitle = unicode(current.title())
    if endsort != None:
      if isinstance(endsort, int):
        if i > endsort:
          break
      else:
        if keyval >= endsort:
          break

    if not t and isinstance(endsort, int):
      t = datetime.datetime.now()

    # Ignore user pages, talk pages and certain Wiktionary pages
    if not page_should_be_ignored(pagetitle):
      yield current, i

    if i % steps == 0:
      tdisp = ""

      if isinstance(endsort, int):
        told = t
        t = datetime.datetime.now()
        pagesleft = (endsort - i) / steps
        tfuture = t + (t - told) * pagesleft
        tdisp = ", est. " + tfuture.strftime("%X")

      errmsg(str(i) + "/" + str(endsort) + tdisp)


def references(page, startsort = None, endsort = None, namespaces = None,
    only_template_inclusion = False, filter_redirects = False, include_page = False):
  if isinstance(page, basestring):
    page = pywikibot.Page(site, page)
  pageiter = page.getReferences(only_template_inclusion = only_template_inclusion,
      namespaces = namespaces, filter_redirects = filter_redirects)
  if include_page:
    pages = [page] + list(pageiter)
  else:
    pages = pageiter
  for i, current in iter_items(pages, startsort, endsort):
    yield i, current

def get_contributions(user, startsort=None, endsort=None, max=None, namespaces=None):
  """Get contributions for a given user."""
  itemiter = site.usercontribs(user=user, namespaces=namespaces, total=max)
  for i, current in iter_items(itemiter, startsort, endsort, get_name=lambda item: item['title']):
    yield i, current

def yield_articles(page, seen, startsort=None, prune_cats_regex=None, recurse=False):
  if not recurse:
    # Only use when non-recursive. Has a recurse= flag but doesn't allow for prune_cats_regex, doesn't correctly
    # ignore subcats and pages that may be seen multiple times.
    for article in page.articles(startsort=startsort):
      if seen is None:
        yield article
      else:
        pagetitle = unicode(article.title())
        if pagetitle not in seen:
          seen.add(pagetitle)
          yield article
  else:
    for subcat in yield_subcats(page, seen, prune_cats_regex=prune_cats_regex, do_this_page=True, recurse=True):
      for article in subcat.articles(startsort=startsort):
        if seen is None:
          yield article
        else:
          pagetitle = unicode(article.title())
          if pagetitle not in seen:
            seen.add(pagetitle)
            yield article

def raw_cat_articles(page, seen, startsort=None, prune_cats_regex=None, recurse=False):
  if type(page) is str:
    page = page.decode("utf-8")
  if isinstance(page, basestring):
    page = pywikibot.Category(site, "Category:" + page)
  for article in yield_articles(page, seen, startsort=startsort, prune_cats_regex=prune_cats_regex, recurse=recurse):
    yield article

def cat_articles(page, startsort=None, endsort=None, seen=None, prune_cats_regex=None, recurse=False, track_seen=False):
  if seen is None and track_seen:
    seen = set()
  for i, current in iter_items(raw_cat_articles(page, seen, startsort=startsort if not isinstance(startsort, int) else None,
      prune_cats_regex=prune_cats_regex, recurse=recurse), startsort, endsort):
    yield i, current

def yield_subcats(page, seen, prune_cats_regex=None, do_this_page=False, recurse=False):
  if seen is not None:
    pagetitle = unicode(page.title())
    if pagetitle in seen:
      return
    seen.add(pagetitle)
  if prune_cats_regex:
    this_cat = re.sub("^Category:", "", unicode(page.title()))
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
        pagetitle = unicode(subcat.title())
        if pagetitle not in seen:
          seen.add(pagetitle)
          yield subcat

def cat_subcats(page, startsort=None, endsort=None, seen=None, prune_cats_regex=None, do_this_page=False, recurse=False):
  if seen is None:
    seen = set()
  if type(page) is str:
    page = page.decode("utf-8")
  if isinstance(page, basestring):
    page = pywikibot.Category(site, "Category:" + page)
  pageiter = yield_subcats(page, seen, prune_cats_regex=prune_cats_regex, do_this_page=do_this_page, recurse=recurse)
  # Recursive support is built into page.subcategories() but it isn't smart enough to skip pages
  # already seen, which can lead to infinite loops, e.g. ku:All topics -> ku:List of topics -> ku:All topics.
  # pageiter = page.subcategories(recurse=recurse) #no startsort; startsort = startsort if not isinstance(startsort, int) else None)
  for i, current in iter_items(pageiter, startsort, endsort):
    yield i, current

def prefix_pages(prefix, startsort=None, endsort=None, namespace=None):
  pageiter = site.allpages(prefix=prefix, namespace=namespace)
  for i, current in iter_items(pageiter, startsort, endsort):
    yield i, current

def query_special_pages(specialpage, startsort=None, endsort=None):
  for i, current in iter_items(site.querypage(specialpage), startsort, endsort):
    yield i, current

def query_usercontribs(username, startsort=None, endsort=None, starttime=None, endtime=None):
  for i, current in iter_items(site.usercontribs(user=username, start=starttime, end=endtime), startsort, endsort,
      get_name=lambda item: item['title']):
    yield i, current

def stream(st, startsort = None, endsort = None):
  i = 0

  for name in st:
    i += 1

    if startsort != None and i < startsort:
      continue
    if endsort != None and i > endsort:
      break

    if type(name) is str:
      name = str.decode(name, "utf-8")

    name = re.sub(ur"^[#*] *\[\[(.+)]]$", ur"\1", name, flags=re.UNICODE)

    yield i, pywikibot.Page(site, name)

def split_utf8_arg(arg, canonicalize=None):
  arg = arg.decode("utf-8")
  def process(pagename):
    if canonicalize:
      pagename = canonicalize(pagename)
    return pagename
  return [process(x) for x in re.split(r",(?=[^ ])", arg)]

def yield_items_from_file(filename, canonicalize=None, filename_is_utf8=True, include_original_lineno=False,
    preserve_blank_lines=False):
  if filename_is_utf8:
    filename = filename.decode("utf-8")
  lineno = 0
  for line in codecs.open(filename, "r", "utf-8"):
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

def iter_items_from_file(filename, startsort=None, endsort=None, canonicalize=None, filename_is_utf8=True,
    preserve_blank_lines=False, skip_ignorable_pages=False):
  file_items = yield_items_from_file(filename, canonicalize=canonicalize, filename_is_utf8=filename_is_utf8,
      include_original_lineno=True, preserve_blank_lines=preserve_blank_lines)
  for _, (index, line) in iter_items(file_items, startsort=startsort, endsort=endsort, get_name=lambda x:x[1], get_index=lambda x:x[0],
      skip_ignorable_pages=skip_ignorable_pages):
    yield index, line

def get_page_name(page):
  if isinstance(page, basestring):
    return page
  # FIXME: withNamespace=False was used previously by cat_articles, in a
  # line like this:
  #    elif current.title(withNamespace=False) >= endsort:
  # Should we add this flag or support an option to add it?
  #return unicode(page.title(withNamespace=False))
  return unicode(page.title())

class ProcessItems(object):
  def __init__(self, startsort=None, endsort=None, get_name=get_page_name,
      skip_ignorable_pages=False):
    self.startsort = startsort
    self.endsort = endsort
    self.get_name = get_name
    self.skip_ignorable_pages = skip_ignorable_pages
    self.i = 0
    self.t = None
    self.steps = 50
    self.skipsteps = 1000
    self.no_time_output = True

  def should_process(self, item):
    self.i += 1

    if self.startsort != None:
      should_skip = False
      if isinstance(self.startsort, int):
        if self.i < self.startsort:
          should_skip = True
      elif self.get_name(item) < self.startsort:
        should_skip = True
      if should_skip:
        if self.i % self.skipsteps == 0:
          pywikibot.output("skipping %s" % str(self.i))
        return False

    if self.endsort != None:
      if isinstance(self.endsort, int):
        if self.i > self.endsort:
          return None
      elif self.get_name(item) > self.endsort:
        return None

    if isinstance(self.endsort, int) and not self.t:
      self.t = datetime.datetime.now()

    if self.skip_ignorable_pages and page_should_be_ignored(get_name(item)):
      pywikibot.output("Page %s %s: page has a prefix or suffix indicating it should not be touched, skipping" % (
        self.i, get_name(item)))
      retval = False
    else:
      retval = self.i

    if self.i % self.steps == 0:
      tdisp = ""

      if isinstance(self.endsort, int):
        told = self.t
        self.t = datetime.datetime.now()
        pagesleft = (self.endsort - self.i) / self.steps
        tfuture = self.t + (self.t - told) * pagesleft
        tdisp = ", est. " + tfuture.strftime("%X")

      pywikibot.output(str(self.i) + "/" + str(self.endsort) + tdisp)

    return retval

def iter_items(items, startsort=None, endsort=None, get_name=get_page_name, get_index=None,
    skip_ignorable_pages=False):
  i = 0
  t = None
  steps = 50
  skipsteps = 1000
  actual_startsort = None
  tstart = datetime.datetime.now()

  for current in items:
    i += 1
    if get_index:
      index = get_index(current)
    else:
      index = i

    if startsort != None:
      should_skip = False
      if isinstance(startsort, int):
        if index < startsort:
          should_skip = True
      elif get_name(current) < startsort:
        should_skip = True
      if should_skip:
        if i % skipsteps == 0:
          pywikibot.output("skipping %s" % str(i))
        continue

    if actual_startsort is None:
      actual_startsort = i
    actual_endsort = None

    if endsort != None:
      if isinstance(endsort, int):
        if index > endsort:
          break
      elif get_name(current) > endsort:
        break

    if isinstance(endsort, int) and not t:
      t = datetime.datetime.now()

    if skip_ignorable_pages and page_should_be_ignored(get_name(current)):
      pywikibot.output("Page %s %s: page has a prefix or suffix indicating it should not be touched, skipping" % (
        index, get_name(current)))
    else:
      yield index, current

    if i % steps == 0:
      tdisp = ""

      if isinstance(endsort, int):
        t = datetime.datetime.now()
        startsort_as_int = startsort if isinstance(startsort, int) else 1
        actual_endsort = endsort - (startsort_as_int - actual_startsort)
        # Logically:
        #
        # time_so_far = t - tstart
        # pages_so_far = i - startsort + 1
        # time_per_page = time_so_far / pages_so_far
        # remaining_pages = endsort - i
        # remaining_time = time_per_page * remaining_pages
        #
        # We do the same but multiply before dividing, for increased precision and due to the inability
        # to multiply or divide timedeltas by floats. We also use the actual startsort (i.e. the actual
        # index of the first page relative to the pages seen in the input stream, in case get_index() is
        # supplied and e.g. the indices supplied by get_index() are offset significantly compared with
        # the ordering in the input stream), and adjust the supplied `endsort` value by the difference
        # between the supplied `startsort` and observed actual first page. This way, for example, if the
        # get_index() indices start at 80000 and `startsort` = 82000 and `endsort` = 85000, we will
        # correctly account for there being 3000 pages to do. NOTE: If the indices supplied by get_index()
        # have gaps in them or are completely out of order, our calculations will be incorrect.
        remaining_pages = actual_endsort - i
        pages_so_far = i - actual_startsort + 1
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

      pywikibot.output(str(i) + "/" + str(actual_endsort) + tdisp)

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
  if isinstance(notes, basestring):
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
    parser.add_argument("--prefix-pages", help="Do pages with these prefixes, comma-separated.")
    parser.add_argument("--prefix-namespace", help="Namespace of pages to do using --prefix-pages.")
    parser.add_argument("--ref-namespaces", help="List of namespace(s) to restrict --refs to.")
    parser.add_argument("--filter-pages", help="Regex to use to filter page names.")
    parser.add_argument("--filter-pages-not", help="Regex to use to filter page names; only includes pages not matching this regex.")
    parser.add_argument("--find-regex", help="Output as by find_regex.py.", action="store_true")
    parser.add_argument("--no-output", help="In conjunction with --find-regex, don't output processed text.", action="store_true")
    parser.add_argument("--skip-ignorable-pages", help="Skip 'ignorable' pages (talk pages, user pages, etc.).", action="store_true")
    # Not implemented yet.
    #parser.add_argument("--parallel", help="Do in parallel.", action="store_true")
    #parser.add_argument("--num-workers", help="Number of workers for use with --parallel.", type=int, default=5)
  if include_stdin:
    parser.add_argument("--stdin", help="Read dump from stdin.", action="store_true")
    parser.add_argument("--only-lang", help="Only process the section of a page for this language (a canonical language name).")
  return parser

def parse_args(args = sys.argv[1:]):
  startsort = None
  endsort = None

  if len(args) >= 1:
    startsort = args[0]
  if len(args) >= 2:
    endsort = args[1]
  return parse_start_end(startsort, endsort)

def parse_start_end(startsort, endsort):
  if startsort != None:
    try:
      startsort = int(startsort)
    except ValueError:
      startsort = str.decode(startsort, "utf-8")
  if endsort != None:
    try:
      endsort = int(endsort)
    except ValueError:
      endsort = str.decode(endsort, "utf-8")

  return (startsort, endsort)

def args_has_non_default_pages(args):
  return not not (args.pages or args.pagefile or args.pages_from_find_regex or args.pages_from_previous_output
      or args.cats or args.refs or args.specials or args.contribs or args.prefix_pages
      or args.pages_and_refs)

# Process a run of pages, with the set of pages specified in various possible ways, e.g. from --pagefile, --cats,
# --refs, or (if --stdin is given) from a Wiktionary dump or find_regex.py output read from stdin. PROCESS is called
# to process the page, and has different calling conventions depending on the EDIT and STDIN flags:
#
# If stdin=True, PROCESS should be defined like this:
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
def do_pagefile_cats_refs(args, start, end, process, default_pages=[],default_cats=[],
    default_refs=[], edit=False, stdin=False, only_lang=None,
    filter_pages=None, ref_namespaces=None, canonicalize_pagename=None, skip_ignorable_pages=False):
  args_ref_namespaces = args.ref_namespaces and args.ref_namespaces.decode("utf-8").split(",")
  args_filter_pages = args.filter_pages and args.filter_pages.decode("utf-8")
  args_filter_pages_not = args.filter_pages_not and args.filter_pages_not.decode("utf-8")

  seen = set() if args.track_seen else None

  def do_handle_stdin_retval(retval, text, prev_comment, pagemsg, is_find_regex):
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

  def page_should_be_filtered_out(pagetitle):
    if filter_pages or args_filter_pages or args_filter_pages_not:
      if filter_pages and not filter_pages(pagetitle):
        return True
      if args_filter_pages and not re.search(args_filter_pages, pagetitle):
        return True
      if args_filter_pages_not and re.search(args_filter_pages_not, pagetitle):
        return True
    if (skip_ignorable_pages or args.skip_ignorable_pages) and page_should_be_ignored(pagetitle):
      return True
    return False

  def find_lang_section_for_only_lang(text, lang, pagemsg):
    sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

    lang_j = -1
    for j in xrange(2, len(sections), 2):
      if sections[j-1] == "==" + lang + "==\n":
        if lang_j >= 0:
          pagemsg("WARNING: Found two %s sections, skipping" % lang)
          return None
        lang_j = j
    if lang_j < 0:
      pagemsg("Can't find %s section, skipping" % lang)
      return None
    j = lang_j

    # Extract off trailing separator
    mm = re.match(r"^(.*?)(\n*--+\n*)$", sections[j], re.S)
    if mm:
      secbody, sectail = mm.group(1), mm.group(2)
    else:
      secbody = sections[j]
      sectail = ""

    return sections, j, secbody, sectail

  def do_process_text_on_page(index, pagetitle, text, pagemsg):
    if page_should_be_filtered_out(pagetitle):
      return None, None
    if args.only_lang:
      retval = find_lang_section_for_only_lang(text, args.only_lang, pagemsg)
      if retval is None:
        return None
      sections, j, secbody, sectail = retval
      if edit:
        retval = process(index, pagetitle, secbody)
      if retval is None:
        return None
      newsecbody, comment = retval
      sections[j] = newsecbody + sectail
      return "".join(sections), comment
    else:
      if only_lang and "==%s==" % only_lang not in text:
        return None, None
      return process(index, pagetitle, text)

  # Process a page read from Wiktionary using Pywikibot (as opposed to a page read from stdin, either from find_regex
  # output or from a dump file). `no_check_seen` means to not check the `seen` set to see whether a page has already
  # been seen. This is set when iterating over categories because the code to do this adds to the `seen` set itself
  # (necessary because it can recursively process subcategories) so if we check the `seen` set we'll never process any
  # pages.
  def process_pywikibot_page(index, page, no_check_seen=False):
    pagetitle = unicode(page.title())
    if not no_check_seen and seen is not None:
      if pagetitle in seen:
        return
      seen.add(pagetitle)
    if page_should_be_filtered_out(pagetitle):
      return
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))
    def errandpagemsg(txt):
      errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
    def do_process_page(page, index, parsed=None):
      if stdin:
        pagetext = safe_page_text(page, errandpagemsg)
        return do_process_text_on_page(index, pagetitle, pagetext, pagemsg)
      else:
        if only_lang:
          pagetext = safe_page_text(page, errandpagemsg)
          if "==%s==" % only_lang not in pagetext:
            return None, None
        if edit:
          return process(page, index, parsed)
        else:
          return process(page, index)

    if args.find_regex:
      # We are reading from Wiktionary but asked to output in find_regex format.
      retval = do_process_page(page, index)
      pagetext = safe_page_text(page, errandpagemsg)
      do_handle_stdin_retval(retval, pagetext, None, pagemsg, is_find_regex=True)
    elif edit:
      do_edit(page, index, do_process_page, save=args.save, verbose=args.verbose,
          diff=args.diff)
    else:
      do_process_page(page, index)

  if stdin and args.stdin:
    pages_to_filter = None
    if args.pages:
      pages_to_filter = set(split_utf8_arg(args.pages, canonicalize=canonicalize_pagename))
    if args.pagefile:
      new_pages_to_filter = set(yield_items_from_file(args.pagefile, canonicalize=canonicalize_pagename))
      if pages_to_filter is None:
        pages_to_filter = new_pages_to_filter
      else:
        pages_to_filter |= new_pages_to_filter
    def do_process_stdin_text_on_page(index, pagetitle, text):
      if pages_to_filter is not None and pagetitle not in pages_to_filter:
        return None
      elif page_should_be_filtered_out(pagetitle):
        return None
      else:
        def pagemsg(txt):
          msg("Page %s %s: %s" % (index, pagetitle, txt))
        return do_process_text_on_page(index, pagetitle, text, pagemsg)
    if args.find_regex:
      utf8_stdin = (line.decode("utf-8") for line in sys.stdin)
      index_pagetitle_text_comment = yield_text_from_find_regex(utf8_stdin, args.verbose)
      for _, (index, pagetitle, text, prev_comment) in iter_items(index_pagetitle_text_comment, start, end,
          get_name=lambda x:x[1], get_index=lambda x:x[0]):
        retval = do_process_stdin_text_on_page(index, pagetitle, text)
        def pagemsg(txt):
          msg("Page %s %s: %s" % (index, pagetitle, txt))
        if prev_comment:
          prev_comment = parse_grouped_notes(prev_comment)
        do_handle_stdin_retval(retval, text, prev_comment, pagemsg, is_find_regex=True)
    else:
      def do_process_stdin_dump_text_on_page(index, pagetitle, text):
        retval = do_process_stdin_text_on_page(index, pagetitle, text)
        def pagemsg(txt):
          msg("Page %s %s: %s" % (index, pagetitle, txt))
        do_handle_stdin_retval(retval, text, None, pagemsg, is_find_regex=False)
      parse_dump(sys.stdin, do_process_stdin_dump_text_on_page, start, end)

  elif args_has_non_default_pages(args):
    args_prune_cats = args.prune_cats and args.prune_cats.decode("utf-8") or None
    if args.pages:
      pages = split_utf8_arg(args.pages, canonicalize=canonicalize_pagename)
      for index, pagetitle in iter_items(pages, start, end):
        process_pywikibot_page(index, pywikibot.Page(site, pagetitle))
    if args.pagefile:
      for index, pagetitle in iter_items_from_file(args.pagefile, start, end, canonicalize=canonicalize_pagename):
        process_pywikibot_page(index, pywikibot.Page(site, pagetitle))
    if args.pages_from_find_regex:
      index_pagetitle_text_comment = yield_text_from_find_regex(
        codecs.open(args.pages_from_find_regex.decode("utf-8"), "r", "utf-8"), args.verbose
      )
      for _, (index, pagetitle, _, _) in iter_items(index_pagetitle_text_comment, start, end,
          get_name=lambda x:x[1], get_index=lambda x:x[0]):
        process_pywikibot_page(index, pywikibot.Page(site, pagetitle))
    if args.pages_from_previous_output:
      index_pagetitle = yield_pages_from_previous_output(
        codecs.open(args.pages_from_previous_output.decode("utf-8"), "r", "utf-8"), args.verbose
      )
      for _, (index, pagetitle) in iter_items(index_pagetitle, start, end,
          get_name=lambda x:x[1], get_index=lambda x:x[0]):
        process_pywikibot_page(index, pywikibot.Page(site, pagetitle))
    if args.cats:
      for cat in split_utf8_arg(args.cats):
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
    if args.refs:
      for ref in split_utf8_arg(args.refs):
        # We don't use ref_namespaces here because the user might not want it.
        for index, page in references(ref, start, end, namespaces=args_ref_namespaces):
          process_pywikibot_page(index, page)
    if args.pages_and_refs:
      for page_and_ref in split_utf8_arg(args.pages_and_refs):
        # We don't use ref_namespaces here because the user might not want it.
        for index, page in references(page_and_ref, start, end, namespaces=args_ref_namespaces,
            include_page=True):
          process_pywikibot_page(index, page)
    if args.specials:
      for special in split_utf8_arg(args.specials):
        for index, page in query_special_pages(special, start, end):
          title = unicode(page.title())
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
      for contrib in split_utf8_arg(args.contribs):
        for index, page in query_usercontribs(contrib, start, end, starttime=args.contribs_start, endtime=args.contribs_end):
          process_pywikibot_page(index, pywikibot.Page(site, page['title']))
    if args.prefix_pages:
      for prefix in split_utf8_arg(args.prefix_pages):
        namespace = args.prefix_namespace and args.prefix_namespace.decode("utf-8") or None
        for index, page in prefix_pages(prefix, start, end, namespace):
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

families = None
families_byCode = None
families_byCanonicalName = None

scripts = None
scripts_byCode = None
scripts_byCanonicalName = None

etym_languages = None
etym_languages_byCode = None
etym_languages_byCanonicalName = None

wm_languages = None
wm_languages_byCode = None
wm_languages_byCanonicalName = None


def getData():
  getLanguageData()
  getFamilyData()
  getScriptData()
  getEtymLanguageData()

def getLanguageData():
  global languages, languages_byCode, languages_byCanonicalName

  jsondata = site.expand_text(u"{{#invoke:User:MewBot|getLanguageData}}")
  languages = json.loads(jsondata)
  languages_byCode = {}
  languages_byCanonicalName = {}

  for lang in languages:
    languages_byCode[lang["code"]] = lang
    languages_byCanonicalName[lang["canonicalName"]] = lang


def getFamilyData():
  global families, families_byCode, families_byCanonicalName

  families = json.loads(site.expand_text(u"{{#invoke:User:MewBot|getFamilyData}}"))
  families_byCode = {}
  families_byCanonicalName = {}

  for fam in families:
    families_byCode[fam["code"]] = fam
    families_byCanonicalName[fam["canonicalName"]] = fam


def getScriptData():
  global scripts, scripts_byCode, scripts_byCanonicalName

  scripts = json.loads(site.expand_text(u"{{#invoke:User:MewBot|getScriptData}}"))
  scripts_byCode = {}
  scripts_byCanonicalName = {}

  for sc in scripts:
    scripts_byCode[sc["code"]] = sc
    scripts_byCanonicalName[sc["canonicalName"]] = sc


def getEtymLanguageData():
  global etym_languages, etym_languages_byCode, etym_languages_byCanonicalName

  etym_languages = json.loads(site.expand_text(u"{{#invoke:User:MewBot|getEtymLanguageData}}"))
  etym_languages_byCode = {}
  etym_languages_byCanonicalName = {}

  for etyl in etym_languages:
    etym_languages_byCode[etyl["code"]] = etyl
    etym_languages_byCanonicalName[etyl["canonicalName"]] = etyl

def try_repeatedly(fun, errandpagemsg, operation="save", bad_value_ret=None, max_tries=2, sleep_time=5):
  num_tries = 0
  def log_exception(txt, e, skipping=False):
    txt = "WARNING: %s when trying to %s%s: %s" % (
      txt, operation, ", skipping" if skipping else "", unicode(e)
    )
    errandpagemsg(txt)
    traceback.print_exc(file=sys.stdout)
  while True:
    try:
      return fun()
    except KeyboardInterrupt as e:
      raise
    except pywikibot.exceptions.InvalidTitle as e:
      log_exception("Invalid title", e, skipping=True)
      return bad_value_ret
    except (pywikibot.LockedPage, pywikibot.NoUsername) as e:
      log_exception("Page is protected", e, skipping=True)
      return bad_value_ret
    # Instead, retry, which will save the page.
    #except pywikibot.exceptions.PageSaveRelatedError as e:
    #  log_exception("Unable to save (abuse filter?)", e, skipping=True)
    except Exception as e:
      if "invalidtitle" in unicode(e):
        log_exception("Invalid title", e, skipping=True)
        return bad_value_ret
      if "abusefilter-disallowed" in unicode(e):
        log_exception("Abuse filter: Disallowed", e, skipping=True)
        return bad_value_ret
      if "abusefilter-warning" in unicode(e):
        log_exception("Abuse filter warning: Disallowed", e, skipping=True)
        return bad_value_ret
      if "customjsprotected" in unicode(e):
        log_exception("Protected JavaScript page: Disallowed", e, skipping=True)
        return bad_value_ret
      if "protectednamespace-interface" in unicode(e):
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
    page.save(comment=comment)
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
# parse_balanced_segment_run("foo(x(1)), bar(2)", "(", ")") = {"foo", "(x(1))", ", bar", "(2)", ""}.
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
      for j in xrange(1, len(parts)):
        grouped_runs.append(run)
        run = [parts[j]]
  if run:
    grouped_runs.append(run)
  return grouped_runs


class ProcessLinks(object):
  def __init__(self, index, pagetitle, parsed, t, tlang, param, langparam):
    # The index of the page containing the template being processed.
    self.index = index
    # The title of the page containing the template being processed.
    self.pagetitle = pagetitle
    # The result of calling `parse_text()` on the text of the page containing the template being processed (an
    # mwparserfromhell structure).
    self.parsed = parsed
    # The template being processed (an mwparserfromhell structure).
    self.t = t
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


class ParamWithInlineModifier(object):
  def __init__(self, mainval, modifiers):
    self.mainval = mainval
    self.modifiers = modifiers

  def reconstruct_param(self):
    parts = [self.mainval]
    for mod, val in self.modifiers:
      parts.append("<%s:%s>" % (mod, val))
    return "".join(parts)

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


def parse_inline_modifier(value):
  segments = parse_balanced_segment_run(value, "<", ">")
  mainval = segments[0]
  modifiers = []
  for k in xrange(1, len(segments), 2):
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
  return ParamWithInlineModifier(mainval, modifiers)


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
    def pagemsg(text):
      msg("Page %s %s: %s" % (index, pagetitle, text))

    actions = []
    for t in parsed.filter_templates():
      tn = tname(t)
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
        if isinstance(params, basestring):
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
          obj = ProcessLinks(index, pagetitle, parsed, t, tlang, param, langparam)
          result = processfn(obj)
          if result:
            if isinstance(result, list):
              actions.extend(result)
            else:
              assert isinstance(result, basestring)
              actions.append(result)
            changed_template[0] = True
            return True
          return False
        except ParseException as e:
          pagemsg("Exception processing lang %s, param %s in template %s: %s"
            % (tlang, param, unicode(t), e))
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
        if isinstance(other_lang_param, (basestring, list)):
          other_lang_val, other_lang_param = getpm(other_lang_param)
          if other_lang_val:
            pagemsg("Skipping param %s=%s with alt param %s=%s because it is in a different lang %s=%s: %s"
              % (param, paramval, altparam, altval, other_lang_param, other_lang_val, unicode(t)))
            return False
        if other_lang_param:
          m = re.search("^([A-Za-z0-9._-]+):(.*)$", paramval)
          if m:
            other_lang_val, actual_paramval = m.groups()
            pagemsg("Skipping param %s=%s because of it begins with other-language prefix '%s:': %s"
              % (param, paramval, other_lang_val, unicode(t)))
            return False
        if check_inline_modifiers and "<" in paramval:
          try:
            inline_mod = parse_inline_modifier(paramval)
            if altval:
              pagemsg("WARNING: Found inline modifier in param %s=%s along with alt param %s=%s, can't process: %s"
                % (param, paramval, altparam, altval, unicode(t)))
              return False
            if other_lang_param and inline_mod.get_modifier("lang") is not None:
              pagemsg("Skipping param %s=%s because of inline 'lang' modifier: %s"
                % (param, paramval, unicode(t)))
              return False
            if inline_mod.get_modifier("alt") is not None:
              return doparam(langparam, ("inline", param, "alt", "tr", inline_mod))
            else:
              return doparam(langparam, ("inline", param, None, "tr", inline_mod))
          except ParseException as e:
            pagemsg("WARNING: Exception processing lang %s, param %s=%s in template %s: %s"
              % (tlang, param, paramval, unicode(t), e))
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
      #if "fa" in langs:
        # Special-casing for Persian
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
        "etyl",
        "given name",
        "hyphenation", "hyph",
        "IPA", "IPAchar", "ic",
        "label", "lb", "lbl", "context", "cx", "term-label", "tlb",
        "+preo", "+posto", "+obj", "phrasebook", "place",
        "refcat", "rfe", "rfinfl", "rfc", "rfc-pron-n",
        "rhymes", "rhyme",
        "senseid", "surname",
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
      elif tn in ["t", "t+", "tt", "tt+", "t-", "t+check", "t-check"]:
        doparam_checking_alt("1", "2", "alt", "tr")
      # Look for {{suffix|LANG|<PAGENAME>|alt1=<FOREIGNTEXT>|<PAGENAME>|alt2=...}}
      # or  {{suffix|LANG|<FOREIGNTEXT>|<FOREIGNTEXT>|...}}
      elif tn in ["suffix", "suf", "prefix", "pre", "affix", "af",
          "confix", "con", "circumfix", "infix", "compound", "com",
          "prefixusex", "prefex", "suffixusex", "sufex", "affixusex", "afex",
          "surf", "surface analysis", "blend", "univerbation", "univ"]: # remove 'blend of'
        if tn in ["circumfix", "confix", "con"]:
          maxind = 3
        elif tn in ["infix"]:
          maxind = 2
        else:
          # Don't just do cases up through where there's a numbered param because there may be holes.
          maxind = find_max_term_index(t, first_numeric="2", named_params=True)
        offset = 1
        for i in xrange(1, maxind + 1):
          # require_index specified in [[Module:compound/templates]]
          doparam_checking_alt("1", str(i + offset), "alt" + str(i), "tr" + str(i), other_lang_param="lang" + str(i),
            check_inline_modifiers=True)
      elif tn in ["pseudo-loan", "pl"]:
        maxind = find_max_term_index(t, first_numeric="3", named_params=True)
        offset = 2
        for i in xrange(1, maxind + 1):
          # require_index specified in [[Module:compound/templates]]
          doparam_checking_alt("2", str(i + offset), "alt" + str(i), "tr" + str(i), other_lang_param="lang" + str(i),
            check_inline_modifiers=True)
        if include_notforeign:
          doparam("1", ("notforeign",))
      elif tn in ["synonyms", "syn", "antonyms", "ant", "hypernyms", "hyper",
          "hyponyms", "hypo", "meronyms", "holonyms", "troponyms",
          "coordinate terms", "perfectives", "pf", "imperfectives", "impf",
          "homophone", "homophones", "hmp"]:
        maxind = find_max_term_index(t, first_numeric="2", named_params=["alt", "tr"])
        termind = 0
        for i in xrange(1, maxind + 1):
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
      elif tn in ["ux", "usex", "uxi", "quote"]:
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
        for i in xrange(1, maxind + 1):
          # require_index not specified in [[Module:alternative forms]]
          doparam_checking_alt("1", str(i + 1), index_param("alt", i), index_param("tr", i),
              check_inline_modifiers=True)
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
      elif tn in ["der", "derived", "inh", "inherited", "bor", "borrowed",
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
  #      oldtemp = unicode(obj.t)
  #      newtemps = []
  #      for tr in trs:
  #        addparam(obj.t, obj.paramtr, tr)
  #        newtemps.append(unicode(obj.t))
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
  return unicode(parsed), actions

#def process_one_page_links_wrapper(page, index, text):
#  return process_one_page_links(unicode(page.title()), index, text)
#
#if "," in cattype:
#  cattypes = cattype.split(",")
#else:
#  cattypes = [cattype]
#for cattype in cattypes:
#  if cattype in ["translation", "links"]:
#    if cattype == "translation":
#      templates = ["t", "t+", "t-", "t+check", "t-check"]
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

def find_lang_section(pagename, lang, pagemsg, errandpagemsg):
  page = pywikibot.Page(site, pagename)
  if not safe_page_exists(page, errandpagemsg):
    pagemsg("Page %s doesn't exist" % pagename)
    return False

  pagetext = unicode(page.text)

  return find_lang_section_from_text(pagetext, lang, pagemsg)

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
  sections = re.split("(^==[^=\n]+==\n)", text, 0, re.M)

  has_non_lang = False

  if lang is None:
    sections = [text]
    j = 0
  else:
    lang_j = -1
    for j in xrange(2, len(sections), 2):
      if sections[j-1] != "==" + lang + "==\n":
        has_non_lang = True
      else:
        if lang_j >= 0:
          pagemsg("WARNING: Found two %s sections, skipping" % lang)
          return None
        lang_j = j
    if lang_j < 0:
      pagemsg("Can't find %s section, skipping" % lang)
      return None
    j = lang_j

  secbody, sectail = split_trailing_separator_and_categories(sections[j])

  if force_final_nls:
    secbody, sectail = force_two_newlines_in_secbody(secbody, sectail)

  return sections, j, secbody, sectail, has_non_lang

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

def split_text_into_sections(pagetext, lang):
  # Split into sections
  splitsections = re.split("(^==[^=\n]+==\n)", pagetext, 0, re.M)
  # Extract off pagehead and recombine section headers with following text
  pagehead = splitsections[0]
  sections = []
  for i in xrange(1, len(splitsections)):
    if (i % 2) == 1:
      sections.append("")
    sections[-1] += splitsections[i]
  return pagehead, sections

def find_lang_section_from_text(pagetext, lang, pagemsg):
  pagehead, sections = split_text_into_sections(pagetext, lang)

  # Go through each section in turn, looking for existing language section
  for i in xrange(len(sections)):
    m = re.match("^==([^=\n]+)==$", sections[i], re.M)
    if not m:
      pagemsg("Can't find language name in text: [[%s]]" % (sections[i]))
    elif m.group(1) == lang:
      return sections[i]

  return None

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

def parse_dump(fp, pagecallback, startsort=None, endsort=None,
    skip_ignorable_pages=False):
  item_handler = ProcessItems(startsort=startsort, endsort=endsort,
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
