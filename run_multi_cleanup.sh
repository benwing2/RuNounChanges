#!/bin/sh

langcode=
langname=
do_see_also=
no_synonyms=
while [ -n "$1" ]; do
  case "$1" in
    --langcode ) langcode="$2"; shift 2 ;;
    --langname ) langname="$2"; shift 2 ;;
    --do-see-also ) do_see_also="--do-see-also"; shift ;;
    --no-synonyms ) no_synonyms=1; shift ;;
    -- ) shift; break ;;
  esac
done

if [ -z "$langcode" ]; then
  echo "--langcode required"
  exit 1
fi
if [ -z "$langname" ]; then
  echo "--langname required"
  exit 1
fi

FIX_LINKS="python3 fix_links.py --find-regex --langs $langcode --single-lang '$langname' $do_see_also"
DETEMPLATIZE_EN_LINKS="python3 detemplatize_en_links.py --find-regex --partial-page"
TEMPLATIZE_CATEGORIES="python3 templatize_categories.py --find-regex --langname '$langname' --langcode $langcode"
MOVE_SYNONYMS="python3 move_synonyms.py --find-regex --langcode $langcode --langname '$langname' --partial-page"
CONVERT_ALT_FORMS="python3 convert_alt_forms.py --find-regex --partial-page"
MOVE_WIKIPEDIA="python3 move_wikipedia.py --find-regex --partial-page"

if [ -n "$no_synonyms" ]; then
  CMD="$FIX_LINKS | $DETEMPLATIZE_EN_LINKS | $TEMPLATIZE_CATEGORIES | $CONVERT_ALT_FORMS | $MOVE_WIKIPEDIA"
else
  CMD="$FIX_LINKS | $DETEMPLATIZE_EN_LINKS | $TEMPLATIZE_CATEGORIES | $MOVE_SYNONYMS | $CONVERT_ALT_FORMS | $MOVE_WIKIPEDIA"
fi

eval $CMD
