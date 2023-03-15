#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, unicodedata
import traceback

import blib, pywikibot
from blib import msg, errmsg, getparam, addparam, tname

show_template=True
show_backtrace=False

# Set below when we've output the failure rate message.
total_num_succeeded = 0
total_num_failed = 0
printed_succeeded_failed = False

def show_failure(pagemsg, num_succeeded=None, num_failed=None):
  if num_succeeded is None:
    num_succeeded = total_num_succeeded
  if num_failed is None:
    num_failed = total_num_failed
  total = num_failed + num_succeeded
  if total == 0:
    pagemsg("Failure = 0/0 = NA")
  else:
    pagemsg("Failure = %s/%s = %.1f%%" % (num_failed, total, 100.0 * num_failed / total))

def nfd_form(txt):
  return unicodedata.normalize("NFD", unicode(txt))

def template_changelog_name(template, lang):
  tn = tname(template)
  def getp(param):
    return getparam(template, param)
  if tn == "head":
    return "head|%s|%s" % (getp("1"), getp("2"))
  elif getp("1") == lang:
    return "%s|%s" % (tn, lang)
  else:
    return tn

# Canonicalize FOREIGN and LATIN. Return (CANONFOREIGN, CANONLATIN, ACTIONS).
# CANONFOREIGN is accented and/or canonicalized foreign text to
# substitute for the existing foreign text, or False to do nothing.
# CANONLATIN is match-canonicalized or self-canonicalized Latin text to
# substitute for the existing Latin text, or True to remove the Latin
# text parameter entirely, or False to do nothing. ACTIONS is a list of
# actions indicating what was done, to insert into the changelog messages.
# TEMPLATE is the template being processed; FROMPARAM is the name of the
# parameter in this template containing the foreign text; TOPARAM is the
# name of the parameter into which canonicalized foreign text is saved;
# PARAMTR is the name of the parameter in this template containing the Latin
# text. All four are used only in status messages and ACTIONS.
def do_canon_param(obj, translit_module):
  actions = []
  tn = tname(obj.t)
  fromparam = None
  toparam = None
  paramtr = None

  def pagemsg(txt):
    msg("Page %s %s: %s.%s: %s" % (obj.index, obj.pagetitle, tn, fromparam, txt))
  def getp(param):
    return getparam(obj.t, param)

  foreign = None
  latin = None
  if obj.param[0] == "separate":
    _, fromparam, paramtr = obj.param
    toparam = fromparam
    foreign = getp(fromparam)
    latin = getp(paramtr)
  elif obj.param[0] == "separate-pagetitle":
    _, toparam, paramtr = obj.param
    fromparam = "page title"
    foreign = obj.pagetitle
    latin = getp(paramtr)
  elif obj.param[0] == "inline":
    _, foreign_param, foreign_mod, latin_mod, inline_mod = obj.param
    if foreign_mod is None:
      fromparam = "%s(main)" % foreign_param
    else:
      fromparam = "%s<%s>" % (foreign_param, foreign_mod)
    toparam = fromparam
    paramtr = "%s<%s>" % (foreign_param, latin_mod)
    foreign = inline_mod.mainval if foreign_mod is None else inline_mod.get_modifier(foreign_mod)
    latin = inline_mod.get_modifier(latin_mod)

  global printed_succeeded_failed
  if int(obj.index) % 100 == 0:
    if not printed_succeeded_failed:
      printed_succeeded_failed = True
      show_failure(pagemsg)
  else:
    printed_succeeded_failed = False

  if show_template:
    pagemsg("Processing %s" % (unicode(obj.t)))

  if not foreign or latin in ["-", "?"]:
    pagemsg("Skipped: foreign=%s, latin=%s" % (foreign, latin))
    return False, False, []

  # Compute canonforeign and canonlatin
  match_canon = False
  canonlatin = ""
  if latin:
    try:
      canonforeign, canonlatin = translit_module.tr_matching(obj, foreign, latin, err=True, msgfun=pagemsg)
      match_canon = True
      global total_num_succeeded
      total_num_succeeded += 1
    except RuntimeError as e:
      if show_backtrace:
        errmsg("WARNING: Unable to match-canon %s (%s): %s: %s" % (foreign, latin, e, unicode(obj.t)))
        traceback.print_exc()
      pagemsg("NOTE: Unable to match-canon %s (%s): %s: %s" % (foreign, latin, e, unicode(obj.t)))
      global total_num_failed
      total_num_failed += 1
      canonlatin, canonforeign = (
          translit_module.canonicalize_latin_foreign(latin, foreign,
            msgfun=pagemsg))
  else:
    _, canonforeign = (
        translit_module.canonicalize_latin_foreign(None, foreign,
          msgfun=pagemsg))

  newlatin = canonlatin == latin and "same" or canonlatin
  newforeign = canonforeign == foreign and "same" or canonforeign

  latintrtext = (latin or canonlatin) and " (%s -> %s)" % (latin, newlatin) or ""

  try:
    translit = translit_module.tr(canonforeign, msgfun=pagemsg)
    if translit is NotImplemented:
      translit = None
    elif not translit:
      pagemsg("NOTE: Unable to auto-translit %s (canoned from %s): %s" %
          (canonforeign, foreign, unicode(obj.t)))
  except Exception as e:
    pagemsg("NOTE: Unable to transliterate %s (canoned from %s): %s: %s" %
        (canonforeign, foreign, e, unicode(obj.t)))
    translit = None

  if canonforeign == foreign:
    pagemsg("No change in foreign %s%s" % (foreign, latintrtext))
    canonforeign = False
  else:
    if match_canon:
      operation="Match-canoning"
      actionop="match-canon"
    # No cross-canonicalizing takes place with Russian or Ancient Greek.
    # (FIXME not true with Russian, but the cross-canonicalizing is minimal.)
    elif latin:
      operation="Cross-canoning"
      actionop="cross-canon"
    else:
      operation="Self-canoning"
      actionop="self-canon"
    pagemsg("%s foreign %s -> %s%s" % (operation, foreign, canonforeign,
      latintrtext))
    if fromparam == toparam:
      actions.append("%s %s=%s -> %s in {{%s}}" % (actionop, fromparam, foreign,
        canonforeign, template_changelog_name(obj.t, obj.tlang)))
    else:
      actions.append("%s %s=%s -> %s=%s in {{%s}}" % (actionop, fromparam, foreign,
        toparam, canonforeign, template_changelog_name(obj.t, obj.tlang)))
    if (translit_module.remove_diacritics(canonforeign) !=
        translit_module.remove_diacritics(foreign)):
      msgs = ""
      if "  " in foreign or foreign.startswith(" ") or foreign.endswith(" "):
        msgs += " (stray space in old foreign)"
      if re.search("[A-Za-z]", nfd_form(foreign)):
        msgs += " (Latin in old foreign)"
      if u"\u00A0" in foreign:
        msgs += " (NBSP in old foreign)"
      if re.search(u"[\u200E\u200F]", foreign):
        msgs += " (L2R/R2L in old foreign)"
      pagemsg("NOTE: Without diacritics, old foreign %s different from canon %s%s: %s"
          % (foreign, canonforeign, msgs, unicode(obj.t)))

  if not latin:
    pass
  elif translit and translit == canonlatin:
    pagemsg("Removing redundant translit for %s -> %s%s" % (
        foreign, newforeign, latintrtext))
    actions.append("remove redundant %s=%s in {{%s}}" % (paramtr, latin, template_changelog_name(obj.t, obj.tlang)))
    canonlatin = True
  else:
    if translit:
      pagemsg("NOTE: Canoned Latin %s not same as auto-translit %s, can't remove: %s" %
          (canonlatin, translit, unicode(obj.t)))
    if canonlatin == latin:
      pagemsg("No change in Latin %s: foreign %s -> %s (auto-translit %s)" %
          (latin, foreign, newforeign, translit))
      canonlatin = False
    else:
      if match_canon:
        operation="Match-canoning"
        actionop="match-canon"
      # No cross-canonicalizing takes place with Russian or Ancient Greek.
      # (FIXME not true with Russian, but the cross-canonicalizing is minimal.)
      #else:
      #  operation="Cross-canoning"
      #  actionop="cross-canon"
      else:
        operation="Self-canoning"
        actionop="self-canon"
      pagemsg("%s Latin %s -> %s: foreign %s -> %s (auto-translit %s)" % (
          operation, latin, canonlatin, foreign, newforeign, translit))
      actions.append("%s %s=%s -> %s in {{%s}}" % (actionop, paramtr, latin, canonlatin, template_changelog_name(obj.t, obj.tlang)))

  return (canonforeign, canonlatin, actions)

# If param is 'head', add it after any numeric params; otherwise, add at the end.
def add_param_handling_head(template, param, value):
  if param != "head":
    addparam(template, param, value)
    return
  before = None
  for paramobj in template.params:
    pname = unicode(paramobj.name).strip()
    if re.match("^[0-9]+", pname):
      continue
    before = pname
    break
  addparam(template, param, value, before=before)

# Attempt to canonicalize foreign parameter PARAM (which may be a list
# [FROMPARAM, TOPARAM], where FROMPARAM may be "page title") and Latin
# parameter PARAMTR. Return False if PARAM has no value, else list of
# changelog actions.
def canon_param(obj, translit_module):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (obj.index, obj.pagetitle, txt))
  canonforeign, canonlatin, actions = do_canon_param(obj, translit_module)
  oldtempl = "%s" % unicode(obj.t)
  if obj.param[0] in ["separate", "separate-pagetitle"]:
    _, toparam, paramtr = obj.param
    if canonforeign:
      if toparam is None:
        pagemsg("WARNING: No param to set new foreign value `%s` to in %s" %
          (canonforeign, unicode(obj.t)))
      else:
        add_param_handling_head(obj.t, toparam, canonforeign)
    if canonlatin == True:
      obj.t.remove(paramtr)
    elif canonlatin:
      addparam(obj.t, paramtr, canonlatin)
  elif obj.param[0] == "inline":
    _, foreign_param, foreign_mod, latin_mod, inline_mod = obj.param
    if canonforeign:
      if foreign_mod is None:
        inline_mod.mainval = canonforeign
      else:
        inline_mod.set_modifier(foreign_mod, canonforeign)
    if canonlatin == True:
      inline_mod.remove_modifier(latin_mod)
    elif canonlatin:
      inline_mod.set_modifier(latin_mod, canonlatin)
    addparam(obj.t, foreign_param, inline_mod.reconstruct_param())
    if foreign_mod is None:
      fromparam = "%s(main)" % foreign_param
    else:
      fromparam = "%s<%s>" % (foreign_param, foreign_mod)

  if canonforeign or canonlatin:
    pagemsg("Replaced %s with %s" % (oldtempl, unicode(obj.t)))
  return actions

def combine_adjacent(values):
  combined = []
  for val in values:
    if combined:
      last_val, num = combined[-1]
      if val == last_val:
        combined[-1] = (val, num + 1)
        continue
    combined.append((val, 1))
  return ["%s(x%s)" % (val, num) if num > 1 else val for val, num in combined]

def sort_group_changelogs(actions):
  grouped_actions = {}
  begins = ["split ", "match-canon ", "cross-canon ", "self-canon ",
      "remove redundant ", "remove ", ""]
  for begin in begins:
    grouped_actions[begin] = []
  actiontype = None
  action = ""
  for action in actions:
    for begin in begins:
      if action.startswith(begin):
        actiontag = action.replace(begin, "", 1)
        grouped_actions[begin].append(actiontag)
        break

  grouped_action_strs = (
    [begin + ', '.join(combine_adjacent(grouped_actions[begin]))
        for begin in begins
        if len(grouped_actions[begin]) > 0])
  all_grouped_actions = '; '.join([x for x in grouped_action_strs if x])
  return all_grouped_actions

# Canonicalize foreign and Latin in link-like templates on pages from STARTFROM
# to (but not including) UPTO, either page names or 0-based integers. Save
# changes if SAVE is true. Show exact changes if VERBOSE is true. CATTYPE
# should be 'vocab', 'borrowed', 'translation', 'links', 'pagetext', 'pages',
# an arbitrary category or a list of such items, indicating which pages to
# examine. If CATTYPE is 'pagetext', PAGES_TO_DO should be a list of
# (PAGETITLE, PAGETEXT). If CATTYPE is 'pages', PAGES_TO_DO should be a list
# of page titles, specifying the pages to do. LANG is a language code and
# LONGLANG the canonical language name, as in blib.process_links(). SCRIPT
# is a script code or list of script codes to remove from templates.
# TRANSLIT_MODULE is the module handling transliteration,
# match-canonicalization and removal of diacritics.
def canon_one_page_links(pagetitle, index, text, lang, script, translit_module, templates_seen, templates_changed,
    addl_params):
  if not isinstance(script, list):
    script = [script]
  def process_param(obj):
    def pagemsg(txt):
      msg("Page %s %s: %s" % (obj.index, obj.pagetitle, txt))
    obj.addl_params = addl_params
    result = canon_param(obj, translit_module)
    scvalue = getparam(obj.t, "sc")
    if scvalue in script:
      tn = tname(obj.t)
      if show_template and result == False:
        pagemsg("%s.%s: Processing %s" % (tn, "sc", unicode(obj.t)))
      pagemsg("%s.%s: Removing sc=%s" % (tn, "sc", scvalue))
      oldtempl = "%s" % unicode(obj.t)
      obj.t.remove("sc")
      pagemsg("Replaced %s with %s" % (oldtempl, unicode(obj.t)))
      newresult = ["remove sc=%s in {{%s}}" % (scvalue, template_changelog_name(obj.t, obj.tlang))]
      if result != False:
        result = result + newresult
      else:
        result = newresult
    return result

  text, actions = blib.process_one_page_links(index, pagetitle, text, [lang], process_param,
      templates_seen, templates_changed)
  return text, sort_group_changelogs(actions)
