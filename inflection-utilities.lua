local export = {}

local m_links = require("Module:links")
local m_str_utils = require("Module:string utilities")
local m_table = require("Module:table")
local put = require("Module:parse utilities")
local headword_data_module = "Module:headword/data"
local script_utilities_module = "Module:script utilities"
local table_tools_module = "Module:table tools"

local split = m_str_utils.split
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local ucfirst = m_str_utils.ucfirst
local dump = mw.dumpObject

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function track(page)
	require("Module:debug/track")("inflection utilities/" .. page)
	return true
end

local footnote_abbrevs = {
	["a"] = "archaic",
	["c"] = "colloquial",
	["d"] = "dialectal",
	["fp"] = "folk-poetic",
	["l"] = "literary",
	["lc"] = "low colloquial",
	["p"] = "poetic",
	["pej"] = "pejorative",
	["r"] = "rare",
}


------------------------------------------------------------------------------------------------------------
--                                             PARSING CODE                                               --
------------------------------------------------------------------------------------------------------------

-- FIXME: Callers of this code should call [[Module:parse-utilities]] directly.

--[==[
FIXME: Older entry point. Call `parse_balanced_segment_run()` in [[Module:parse utilities]] directly.
]==]
function export.parse_balanced_segment_run(segment_run, open, close)
	track("parse-balanced-segment-run")
	return put.parse_balanced_segment_run(segment_run, open, close)
end

--[==[
FIXME: Older entry point. Call `parse_multi_delimiter_balanced_segment_run()` in [[Module:parse utilities]] directly.
]==]
function export.parse_multi_delimiter_balanced_segment_run(segment_run, delimiter_pairs, no_error_on_unmatched)
	track("parse-multi-delimiter-balanced-segment-run")
	return put.parse_multi_delimiter_balanced_segment_run(segment_run, delimiter_pairs, no_error_on_unmatched)
end

--[==[
FIXME: Older entry point. Call `split_alternating_runs()` in [[Module:parse utilities]] directly.
]==]
function export.split_alternating_runs(segment_runs, splitchar, preserve_splitchar)
	track("parse-multi-delimiter-balanced-segment-run")
	return put.split_alternating_runs(segment_runs, splitchar, preserve_splitchar)
end

--[==[
FIXME: Older entry point. Call `split_alternating_runs_and_frob_raw_text()` in [[Module:parse utilities]] directly.
Like `split_alternating_runs()` but strips spaces from both ends of the odd-numbered elements (only in odd-numbered runs
if `preserve_splitchar` is given). Effectively we leave alone the footnotes and splitchars themselves, but otherwise
strip extraneous spaces. Spaces in the middle of an element are also left alone.
]==]
function export.split_alternating_runs_and_strip_spaces(segment_runs, splitchar, preserve_splitchar)
	track("split-alternating-runs-and-strip-spaces")
	return put.split_alternating_runs_and_frob_raw_text(segment_runs, splitchar, put.strip_spaces, preserve_splitchar)
end


------------------------------------------------------------------------------------------------------------
--                                             INFLECTION CODE                                            --
------------------------------------------------------------------------------------------------------------

--[==[ intro:
The following code is used in building up the inflection of terms in inflected languages, where a term can potentially
consist of several inflected words, each surrounded by fixed text, and a given slot (e.g. accusative singular) of a
given word can potentially consist of multiple possible inflected forms. In addition, each form may be associated with
a manual transliteration and/or a list of footnotes (or qualifiers, in the case of headword lines). The following
terminology is helpful to understand:

* A '''term''' is a word or multiword expression that can be inflected. A multiword term may in turn consist of several
  single-word inflected terms with surrounding fixed text. A term belongs to a particular '''part of speech''' (e.g.
  noun, verb, adjective, etc.).
* An '''inflection dimension''' is a particular dimension over which a term may be inflected, such as case, number,
  gender, person, tense, mood, voice, aspect, etc.
* The '''lemma''' is the particular form of a term under which the term is entered into a dictionary. For example, for
  verbs, it is most commonly the infinitive, but this differs for some languages: e.g. Latin, Greek and Bulgarian use
  the first-person singular present indicative (active voice in the case of Latin and Greek); Sanskrit and Macedonian
  use the third-person singular present indicative (active voice in the case of Sanskrit); Hebrew and Arabic use the
  third-person singular masculine past (aka "perfect"); etc. For nouns, the lemma form is most commonly the nominative
  singular, but e.g. for Old French it is the objective singular and for Sanskrit it is the root.
* A '''slot''' is a particular combination of inflection dimensions. An example might be "accusative plural" for a noun,
  or "first-person singular present indicative" for a verb. Slots are named in a language-specific fashion. For
  example, the slot "accusative plural" might have a name `accpl`, while "first-person singular present indicative"
  might be variously named `pres1s`, `pres_ind_1_sg`, etc. Each slot is filled with zero or more '''forms'''.
* A '''form''' is a particular inflection of a slot for a particular term. Note that a given slot may (and often does)
  have more than one associated form; these different forms are termed '''variants'''. An example is
  {{m+|de|Bug||bow (of a ship)}}, which has two genitive singular forms ''Buges'' and ''Bugs''; two plural forms in all
  cases, e.g. nominative plural ''Buge'' and ''Büge''; and two dative singular forms ''Bug'' and rare/archaic ''Buge''.
  The form variants for a given slot are ordered, and generally should have the more common and/or preferred variants
  first, along with rare, archaic or obsolete variants last (if they are included at all).
* Forms are described using '''form objects''', which are Lua objects taking the form
  `{form="``form_value``", translit="``manual_translit``", footnotes={"``footnote``", "``footnote``", ...}}`.
  (Additional '''metadata''' may be present in a form object, although the support for preserving such metadata when
  transformations are applied to form objects isn't yet complete.) ``form_value`` is a '''form value''' specifying the
  value of the form itself in the term's script. ``manual_translit`` specifies optional manual transliteration for the
  form, in case (a) the form value is in a different script; and (b) either the form's automatic transliteration is
  incorrect and needs to be overridden, or the language of the term has no automatic transliteration (e.g. in the case
  of Persian and Hebrew). ``footnote`` is a footnote to be attached to the form in question, and should be e.g.
  {"[archaic]"} or {"[only in the meaning 'to succeed (an officeholder)']"}, i.e. the string must be surrounded by
  brackets and should begin with a lowercase letter and not end in a period/full stop. When such footnotes are converted
  to actual footnotes in a table of inflected forms, the brackets will be removed, the first letter will be capitalized
  and a period/full stop will be added to the end. (However, when such footnotes are used as qualifiers in headword
  lines, only the brackets will be removed, with no capitalization or final period.) Note that only ``form_value`` is
  mandatory.
* A list of zero or more form objects is termed a '''form object list''', or usually just a '''form list'''. Such lists
  are ordered and go into form tables (see below).
* A '''form table''' is a Lua table (i.e. a dictionary) describing all the possible inflections of a given term. The
  keys in such a table are slots (strings) and the values are form lists. '''NOTE:''' All inflection code assumes and
  maintains the invariant that no two slots, and no two forms in a single slot, share the same form object (by
  reference, i.e. the Lua object describing a form object should never be shared in two places). This allows for safely
  side-effecting form objects in certain sorts of operations. This same invariant necessarily applies to the Lua list
  objects containing the form objects, but does '''NOT''' apply to metadata inside of form objects. In particular, a
  list of footnotes may well be shared among different form objects. This means it is '''NOT''' safe to side-effect
  such lists, and in fact no code in this module that manipulates footnote lists will ever side-effect such lists; they
  are treated as immutable.
* Some functions, to save memory, accept and work with abbreviated forms of form objects and/or form lists.
  Specifically, an '''abbreviated form object''' is either a form object or a string, the latter corresponding to a form
  object whose form value is the string and all other properties are nil. Similarly, an '''abbreviated form list''' is
  either a single abbreviated form object or a list of such objects, i.e. any of a string, form object or list of
  strings and/or form objects. Functions that do not accept such abbreviated structures may be said to insist on being
  passed form objects in '''general form''', or form lists in '''general list form'''.
* Each slot is associated with an '''accelerator tag set''', which is a list of inflection tags that are used when
  generating an accelerator entry for the forms in the slot (see [[WT:ACCEL]]). For example, the first singular present
  indicative of a verb might have slot name `pres_1sg` and corresponding accelerator tag set `1|s|pres|ind`. As shown,
  the accelerator tag set is a string consisting of inflection tags (as used in {{tl|inflection of}}) separated by `|`.
  Despite the terminology ''tag set'', the tags in a tag set are ordered, although the same tag should never occur
  twice.
* Some inflected terms are '''multiword''', i.e. they consist of multiple '''words''', where each word is generally
  separated by spaces or sometimes hyphens. In such a term, some of the words inflect, while others remain fixed. Words
  that inflect are termed '''inflecting words''' (or more correctly '''inflecting parts''', since in some circumstances,
  parts of a word can inflect). The '''fixed text''' is all the parts of a multiword term that do not inflect.
* The descriptor that describes how a given term inflects is called an '''inflection spec''', and consists of the lemma
  form of the term itself, annotated with an '''angle bracket spec''' after each inflecting word. As the name implies,
  an angle bracket spec is surrounded by angle brackets (`<...>`). A simple example is {{m+|de|Feder||feather}}, whose
  inflection spec looks like `Feder<f>`, where `f` specifies the feminine gender. In this case, although there are
  several properties that could be specified between angle brackets, all except the gender are optional and have been
  left out, indicating that defaults should be used. Another example is {{m+|de|Baske|Basque person}}, whose inflection
  spec looks like `Baske<m.weak>`, where `m` specifies the masculine gender and `weak` specifies the weak inflection.
  Note that individual components of an angle bracket spec like `m` and `weak` are termed '''indicators''' and are
  separated by periods/full stops. A slightly more complex example is {{m+|de|Zeitgeist||zeitgeist}}, whose inflection
  spec looks like `Zeitgeist<m,es:s,er>` and which specifies three things in a single '''compound indicator''': `m` (the
  masculine gender); `es:s` (the genitive singular, which can end in either ''-es'' or ''-s''); and `er` (the
  nomininative plural, which ends in ''-er'').
* If there are several inflecting words in a term, each one will be followed by its own angle bracket spec. An example
  is {{m+|de|schwarzes Loch||black hole}}, whose inflection spec looks like `schwarzes<+> Loch<n,es:s,^er>`. Here,
  the adjective ''schwarzes'' (the nominative neuter singular of {{m|de|schwarz||black}}) is followed by the angle
  bracket spec `<+>` specifying that it inflects as an adjective, and the noun ''Loch'' has the angle bracket spec
  `<n,es:s,^er>`, indicating (similarly to the above example) that it is neuter, has a genitive singular in either
  ''-es'' or ''-s'', and has a nominative plural in ''-er'' with umlaut, hence ''Löcher'' (the `^` specifies that the
  form requires umlaut).
* Sometimes a given term has multiple ways of inflecting that differ in ways that can't be specified using a single
  angle bracket spec. This is supported using '''alternants''', which are specified using double parentheses. (This is
  so that terms that themselves contain parentheses can be specified without interference.) An example is
  {{m+|uk|русин||Rusyn}}, which can be stressed either as ''ру́син'' (stress on the first syllable and following accent
  paradigm ''a'', hence genitive singular ''ру́сина'') or ''руси́н'' (stress on the second syllable and following accent
  paradigm ''b'', hence genitive singular ''русина́''; note how the stress moves onto the ending, in accordance with the
  accent paradigm). This is specified using `((ру́син<pr>,руси́н<b.pr>))`, i.e. each separate the alternants with a comma
  and surround them with double parentheses. (Here, `pr` means that the terms belong to the personal animacy class, and
  `b` specifies the accent paradigm; paradigm ''a'' is the default and hence is omitted.)
* Note that occasionally, parts of a single space-delimited word can inflect separately. An example is
  {{m+|la|rōsmarīnus||rosemary}}, which is a compound of {{m+|la|rōs||dew}} and {{m|la|marīnus||marine, of the sea}}.
  In this compound, both parts of the compound can inflect separately; hence genitive singular ''rōrismarīnī'',
  accusative singular ''rōremmarīnum'', etc. Alternatively, only the second part inflects; hence genitive singular
  ''rōsmarīnī'', accusative singular ''rōsmarīnum'', etc. This is specified as
  `((rōs/rōr<3.M>marīnus<2>,rōsmarīnus<2>))`. Here, the term {{m|la|rōs}} by itself would have inflection spec
  `rōs/rōr<3.M>` (indicating that it is third declension masculine with a non-nominative-singular stem ''rōr-'') and
  the term {{m|la|marīnus}} would have inflection spec `<2>` (indicating that it is second declension; the masculine
  gender is inferred from the ''-us'' ending). When combined in a single inflection spec, the doubly-inflecting
  alternant is written `rōs/rōr<3.M>marīnus<2>`, with each inflecting part followed by its corresponding angle bracket
  spec, and the singly-inflecting alternant is written `rōsmarīnus<2>`. As this example shows, the two alternants
  need not correspond in how many inflecting parts there are. It should also be noted that fixed text can surround
  an alternant and it is even possible to supply multiple alternants in a single inflection spec (e.g. if the term
  has two words in it and each word requires an alternant to inflect).
* The result of parsing a single angle bracket spec is stored into a '''word spec'''. The structure of a word spec is
  fairly arbitrary and is determined by the user-written `parse_indicator_spec` function, but always contains a form
  table under the `forms` key that is populated during inflection (see below). A parameter or local variable that holds
  a word spec is conventionally named `base` for historical reasons. Word specs are grouped together into a structure
  termed a '''multiword spec''', which describes one or more word specs along with the fixed text in between and around
  the inflected words. Multiword specs are in turn grouped into structures termed '''alternant specs''', indicating
  the distinct alternants and the words in each alternant. Finally, multiword specs and alternant specs are grouped into
  an '''alternant multiword spec''', which is the top-level object describing an inflection spec. Each of these
  different specs has a form table in it stored in the `forms` key that is populated during the inflection process and
  contains the form objects that specify the inflections of this part of the full multiword term. (It should be noted
  that the term '''spec''' is overloaded to mean two different things: the user-specified descriptor that specifies the
  lemma form of the term and associated inflection, and the associated internal Lua object that encapsulates all
  information derived from the descriptor, along with later-generated information on how to inflect the term(s) being
  described.)
* Among these various "spec" structures, the two most important are the top-level alternant multiword spec and the
  bottom-level word spec or "base". You will rarely find it necessary to manipulate the intermediate structures or
  concern yourself with the details of their formation.
* The term ''form'' is unfortunatately overloaded in various modules to mean several things. In particular, for
  historical reasons, the form value inside of a form object is stored using the key `form`; the form table inside of an
  alternant multiword spec, a word spec (or "base") and the intermediate structures is stored using the key `forms`; and
  the accelerator tag set is internally referred to in [[WT:ACCEL]] as a "form". To avoid confusion, the following
  conventions are followed in code in this module, and should be followed for code in invoking modules as well:
*# Functions that accept form objects often name the relevant parameter `form` (if a single form object is required) or
  `forms` (if a list of form objects, aka form list, is required).
*# Functions that accept abbreviated form objects should (but don't always) indicate this by naming the parameter
  `abform` (for a single abbreviated form object) or `abforms` (for an abbreviated form list).
*# Functions that accept a form value (the native-script string portion of a form object, stored for historical reasons
   in the `.form` property) should '''not''' call such a parameter `form`, but instead use something that makes clear
   that a form value is required, such as `formval` or sometimes just `val`.
*# Similarly, functions that accept a form table should '''not''' call such a parameter `forms` (although for historical
   reasons the form table in an alternant multiword spec is stored in the field `forms`). Instead, use `formtable` or
   `formtab`, or similar name that makes clear that the value is a form table (i.e. a map from slot to form list).

====Footnote handling====

Each form can have one or more attached footnotes. The form of a footnote as specified by the user and stored in form
values is e.g. {"[archaic]"} or {"[only in the meaning 'to succeed (an officeholder)']"}, i.e. the string must be
surrounded by brackets and should begin with a lowercase letter and not end in a period/full stop. When such footnotes
are converted to actual footnotes in a table of inflected forms, the brackets will be removed, the first letter will be
capitalized and a period/full stop will be added to the end. (However, when such footnotes are used as qualifiers in
headword lines, only the brackets will be removed, with no capitalization or final period.)

When merging two forms into one, such as when concatenating the form objects of two inflected words in a multiword term
or deduplicating form objects sharing the same form value during `show_forms()`, the footnotes are generally combined as
well. This means that if one form object has footnotes and the other doesn't, the resulting form object inherits the
footnotes of the object that has them, and if both form objects have footnotes, the resulting form object gets all
footnotes from both source form objects, with duplicates removed. However, when inserting a form into a form table slot
that already has a form whose form value and translit are identical to the new form, the behavior is different. In
under normal circumstances the footnotes of the new form are ''not'' incorporated into those of the existing form (if
any), but are simply dropped. To understand why this makes sense, consider a term that has two possible forms of its
lemma (e.g. two forms differing in stress or in vowel length), where the second form is archaic, rare, colloquial or the
like, and has an attached footnote indicating this. An example of this is {{m+|ru|кожух||sheepskin coat; bullet shell}},
where the form ''кожу́х'' with accent pattern ''b'' is more common overall but the form ''ко́жух'' with accent pattern
''c(1)'' is more common among professionals. On first glance, this could be indicated using
`((кожу́х&lt;b>,ко́жух<c(1).[professional usage only]>))`. But some forms of these two declensions are the same (in
particular, the genitive, dative, instrumental and prepositional plural). If for these slots, the footnotes of the
duplicate forms were combined (i.e. the footnotes of the second declension pattern were added to the already-existing
form taken from the first declension pattern), these forms would wrongly be labeled as ''professional usage only''.
For this reason, it makes more sense to drop the footnotes of the second form when deduplicating.

The same sort of behavior makes sense when a single lemma can have two different declensions, the second of which
requires a footnote and where some forms in the two declensions are shared. An example of this is
{{m+|uk|окови́та||strong, high-quality liquor}}, which can be inflected adjectivally or (rarely) nominally. This would be
indicated as `((окови́та<sg.+>,окови́та<sg.[rare]>))` where the `+` indicates adjectival declension and the `sg` indicates
that this term only exists in the singular. Here, the two declensions differ in the genitive, dative/locative and
vocative (respectively, adjectival ''окови́тої'', ''окови́тій'', ''окови́та'' vs. nominal ''окови́ти'', ''окови́ті'',
''окови́то'') but are the same in the accusative (''окови́ту'') and instrumental (''окови́тою''). Again, dropping the
footnotes of the second form when deduplicating is correct and including them would be wrong.

This behavior can be changed by attaching a '''footnote modifier''' to the footnote associated the second form. A
footnote modifier is a symbol attached to the beginning of a footnote, directly following the opening bracket. The
following modifiers are currently recognized:
* `!` or `+`: If placed on a footnote of the second form, combine that footnote with those of the first form (if any)
              rather than dropping it.
* `*`: If placed on a footnote of the first form, drop that footnote when merging a second form with any footnotes.
An example where the `*` modifier makes sense is a modification of the above example with {{m+|ru|кожух}}. If we
notated it as `((кожу́х<b.[more common among laymen]>,ко́жух<c(1).[more common among professionals]>))`, the shared forms
would wrongly have the footnote ''more common among laymen'' when in fact they are the only possible forms. If instead
we used `((кожу́х<b.[*more common among laymen]>,ко́жух<c(1).[more common among professionals]>))`, the shared forms
would correctly have no footnote.

Finally, be aware of '''old-style footnote symbols'''. For compatibility reasons, some inflection implementations
support a system whereby footnote symbols (consisting of numbers; certain ASCII symbols such as `*`, `~`, `@`, `#`,
`+`, etc.; and a large number of Unicode symbols) are directly attached to form values and the footnotes themselves
specified manually using the `footnotes` property passed to `show_forms()`. This is allowed only when
`allow_footnote_symbols` is set and is highly deprecated. All uses of such symbols should be converted to standard
footnotes and the support for such symbols removed.
]==]


local function extract_footnote_modifiers(footnote)
	local footnote_mods, footnote_without_mods = rmatch(footnote, "^%[([!*+]?)(.*)%]$")
	if not footnote_mods then
		error("Saw footnote '" .. footnote .. "' not surrounded by brackets")
	end
	return footnote_mods, footnote_without_mods
end


--[==[
Insert a form object (see above) into a list of such objects. If the form is already present (i.e. both the form
value and translit, if any, match), the footnotes of the existing and new form might be combined (specifically,
footnotes in the new form beginning with `!` will be combined).
]==]
function export.insert_form_into_list(list, form)
	-- Don't do anything if the form object or the form inside it is nil. This simplifies
	-- form insertion in the presence of inflection generating functions that may return nil,
	-- such as generate_noun_vocative() and generate_noun_count_form().
	if not form or not form.form then
		return
	end
	for _, listform in ipairs(list) do
		if listform.form == form.form and listform.translit == form.translit then
			-- Form already present; maybe combine footnotes.
			if form.footnotes then
				-- Check to see if there are existing footnotes with *; if so, remove them.
				if listform.footnotes then
					local any_footnotes_with_asterisk = false
					for _, footnote in ipairs(listform.footnotes) do
						local footnote_mods, _ = extract_footnote_modifiers(footnote)
						if rfind(footnote_mods, "%*") then
							any_footnotes_with_asterisk = true
							break
						end
					end
					if any_footnotes_with_asterisk then
						local filtered_footnotes = {}
						for _, footnote in ipairs(listform.footnotes) do
							local footnote_mods, _ = extract_footnote_modifiers(footnote)
							if not rfind(footnote_mods, "%*") then
								table.insert(filtered_footnotes, footnote)
							end
						end
						if #filtered_footnotes > 0 then
							listform.footnotes = filtered_footnotes
						else
							listform.footnotes = nil
						end
					end
				end

				-- The behavior here has changed; track cases where the old behavior might
				-- be needed by adding ! to the footnote.
				track("combining-footnotes")
				local any_footnotes_with_bang = false
				for _, footnote in ipairs(form.footnotes) do
					local footnote_mods, _ = extract_footnote_modifiers(footnote)
					if rfind(footnote_mods, "[!+]") then
						any_footnotes_with_bang = true
						break
					end
				end
				if any_footnotes_with_bang then
					if not listform.footnotes then
						listform.footnotes = {}
					else
						listform.footnotes = m_table.shallowcopy(listform.footnotes)
					end
					for _, footnote in ipairs(form.footnotes) do
						local already_seen = false
						local footnote_mods, footnote_without_mods = extract_footnote_modifiers(footnote)
						if rfind(footnote_nods, "[!+]") then
							for _, existing_footnote in ipairs(listform.footnotes) do
								local existing_footnote_mods, existing_footnote_without_mods =
									extract_footnote_modifiers(existing_footnote)
								if existing_footnote_without_mods == footnote_without_mods then
									already_seen = true
									break
								end
							end
							if not already_seen then
								table.insert(listform.footnotes, footnote)
							end
						end
					end
				end
			end
			return
		end
	end
	-- Form not found.
	table.insert(list, form)
end

--[==[
Insert a form object (see above) into the given slot in the given form table. ``form`` can be {nil}, in which case
nothing happens.
]==]
function export.insert_form(formtable, slot, form)
	-- Don't do anything if the form object or the form inside it is nil. This simplifies
	-- form insertion in the presence of inflection generating functions that may return nil,
	-- such as generate_noun_vocative() and generate_noun_count_form().
	if not form or not form.form then
		return
	end
	if not formtable[slot] then
		formtable[slot] = {}
	end
	export.insert_form_into_list(formtable[slot], form)
end


--[==[
Insert a list of form objects (see above) into the given slot in the given form table. ``forms`` can be {nil},
in which case nothing happens.
]==]
function export.insert_forms(formtable, slot, forms)
	if not forms then
		return
	end
	for _, form in ipairs(forms) do
		export.insert_form(formtable, slot, form)
	end
end


--[==[
Identity mapping function.
]==]
function export.identity(formval, translit)
	return formval, translit
end


local function form_value_transliterable(formval)
	return formval ~= "?" and formval ~= "—"
end

local function call_map_function_str(str, fun)
	if str == "?" then
		return "?"
	end
	local newformval, newtranslit = fun(str)
	if newtranslit then
		return {form=newformval, translit=newtranslit}
	else
		return newformval
	end
end

-- FIXME: This doesn't correctly handle metadata.
local function call_map_function_obj(form, fun)
	if form.form == "?" then
		return {form = "?", footnotes = form.footnotes}
	end
	local newformval, newtranslit = fun(form.form, form.translit)
	return {form = newformval, translit = newtranslit, footnotes = form.footnotes}
end


--[==[
Map a function over the form values in ``forms`` (a list of form objects in "general list form; see above). If an
input form value is {"?"}, it is preserved on output and the function is not called. Otherwise, the function is
called with two arguments, the original form and manual translit; if manual translit isn't relevant, it's fine to
declare the function with only one argument. The return value is either a single value (the new form) or two values
(the new form and new manual translit). The footnotes (if any) from the input form objects are preserved on output. Uses
`insert_form_into_list()` to insert the resulting form objects into the returned list in case two different forms map
to the same thing.

FIXME: Expand this to correctly handle metadata, or create a variant that correctly handles metadata.
]==]
function export.map_forms(forms, fun)
	if not forms then
		return nil
	end
	local retval = {}
	for _, form in ipairs(forms) do
		export.insert_form_into_list(retval, call_map_function_obj(form, fun))
	end
	return retval
end


--[==[
Map a list-returning function over the form values in ``forms`` (a list of form objects in "general list form"; see
above). If an input form value is {"?"}, it is preserved on output and the function is not called. Otherwise, the
function is called with two arguments, the original form and manual translit; if manual translit isn't relevant, it's
fine to declare the function with only one argument. The return value of the function can be {nil} or an abbreviated
form list (i.e. anything that is convertible into a general list form, such as a single form value, a list of form
values, a form object or a list of form objects). For each form object in the return value, the footnotes of that form
object (if any) are combined with any footnotes from the input form object, and the result inserted into the returned
list using `insert_form_into_list()` in case two different forms map to the same thing.

FIXME: Expand this to correctly handle metadata, or create a variant that correctly handles metadata.
]==]
function export.flatmap_forms(forms, fun)
	if not forms then
		return nil
	end
	local retval = {}
	for _, form in ipairs(forms) do
		local funret = form.form == "?" and {"?"} or fun(form.form, form.translit)
		if funret then
			funret = export.convert_to_general_list_form(funret)
			for _, fr in ipairs(funret) do
				local newform = {
					form = fr.form,
					translit = fr.translit,
					footnotes = export.combine_footnotes(form.footnotes, fr.footnotes)
				}
				export.insert_form_into_list(retval, newform)
			end
		end
	end
	return retval
end


--[==[
Map a function over the form values in ``abforms`` (an abbreviated form list). If the input form value is {"?"}, it is
preserved on output and the function is not called. If ``first_only`` is given and ``abforms`` is a list, only map over
the first element. Return value is of the same form as ``abforms``, unless ``abforms`` is a string and the function
returns both form value and manual translit (in which case the return value is a form object). The function is called
with two arguments, the original form value and manual translit; if manual translit isn't relevant, it's fine to declare
the function with only one argument. The return value is either a single value (the new form value) or two values (the
new form value and new manual translit). The footnotes (if any) from the input form objects are preserved on output.

FIXME: This function is used only in [[Module:bg-verb]] and should be moved into that module.
]==]
function export.map_form_or_forms(abforms, fun, first_only)
	if not abforms then
		return nil
	elseif type(abforms) == "string" then
		return call_map_function_str(abforms, fun)
	elseif abforms.form then
		return call_map_function_obj(abforms, fun)
	else
		local retval = {}
		for i, abform in ipairs(abforms) do
			if first_only then
				return export.map_form_or_forms(abform, fun)
			end
			table.insert(retval, export.map_form_or_forms(abform, fun))
		end
		return retval
	end
end


--[==[
Combine two sets of footnotes. If either is {nil}, just return the other, and if both are {nil}, return {nil}.
]==]
function export.combine_footnotes(notes1, notes2)
	if not notes1 and not notes2 then
		return nil
	end
	if not notes1 then
		return notes2
	end
	if not notes2 then
		return notes1
	end
	local combined = m_table.shallowcopy(notes1)
	for _, note in ipairs(notes2) do
		m_table.insertIfNot(combined, note)
	end
	return combined
end


--[==[
Expand a given footnote (as specified by the user, including the surrounding brackets) into the form to be inserted
into the final generated table. If ``no_parse_refs`` is not given and the footnote is a reference (of the form
{"[ref:...]"}), parse and return the specified reference(s). Two values are returned, `footnote_string` (the expanded
footnote, or nil if the second value is present) and `references` (a list of objects of the form
`{text = ``text``, name = ``name``, group = ``group``}` if the footnote is a reference and ``no_parse_refs`` is not
given, otherwise {nil}). Unless	``return_raw`` is given, the returned footnote string is capitalized and has a final
period added.
]==]
function export.expand_footnote_or_references(note, return_raw, no_parse_refs)
	local _, notetext = extract_footnote_modifiers(note)
	if not no_parse_refs and notetext:find("^ref:") then
		-- a reference
		notetext = rsub(notetext, "^ref:", "")
		local parsed_refs = require("Module:references").parse_references(notetext)
		for i, ref in ipairs(parsed_refs) do
			if type(ref) == "string" then
				parsed_refs[i] = {text = ref}
			end
		end
		return nil, parsed_refs
	end
	if footnote_abbrevs[notetext] then
		notetext = footnote_abbrevs[notetext]
		track("footnote-whole-abbrev")
	else
		local split_notes = split(notetext, "<(.-)>")
		for i, split_note in ipairs(split_notes) do
			if i % 2 == 0 then
				split_notes[i] = footnote_abbrevs[split_note]
				track("footnote-angle-bracket-abbrev")
				if not split_notes[i] then
					-- Don't error for now, because HTML might be in the footnote.
					-- Instead we should switch the syntax here to e.g. <<a>> to avoid
					-- conflicting with HTML.
					split_notes[i] = "<" .. split_note .. ">"
					track("footnote-unrecognized-angle-bracket-abbrev")
					--error("Unrecognized footnote abbrev: <" .. split_note .. ">")
				else
					track("footnote-recognized-angle-bracket-abbrev")
				end
			end
		end
		notetext = table.concat(split_notes)
	end
	return return_raw and notetext or ucfirst(notetext) .. "."
end


--[==[
Older entry point. Equivalent to `expand_footnote_or_references(note, true)`. FIXME: Convert all uses to use
`expand_footnote_or_references()` instead.
]==]
function export.expand_footnote(note)
	track("expand-footnote")
	return export.expand_footnote_or_references(note, false, "no parse refs")
end


--[==[
Convert a list of foonotes to qualifiers and references for use in [[Module:headword]] or similar. Returns two values,
a list of qualifiers (possibly {nil}) and a list of reference structures (possibly {nil}), following the structure
defined in [[Module:references]]).
]==]
function export.convert_footnotes_to_qualifiers_and_references(footnotes)
	if not footnotes then
		return nil
	end
	local quals, refs
	for _, qualifier in ipairs(footnotes) do
		local this_footnote, this_refs = export.expand_footnote_or_references(qualifier, "return raw")
		if this_refs then
			if not refs then
				refs = this_refs
			else
				for _, ref in ipairs(this_refs) do
					table.insert(refs, ref)
				end
			end
		else
			if not quals then
				quals = {this_footnote}
			else
				table.insert(quals, this_footnote)
			end
		end
	end
	return quals, refs
end


--[==[
Older entry point. FIXME: Convert to `export.convert_footnotes_to_qualifiers_and_references`.
]==]
function export.fetch_headword_qualifiers_and_references(footnotes)
	track("fetch-headword-qualifiers-and-references")
	return export.convert_footnotes_to_qualifiers_and_references(footnotes)
end


--[==[
Combine an abbreviated form object (either a string or a table) with additional footnotes, possibly replacing the form
value and/or translit in the process. Normally called in one of two ways:
(1) `combine_form_and_footnotes(``form_obj``, ``addl_footnotes``, ``new_form``, ``new_translit``)` where ``form_obj``
	is an existing abbreviated form object; ``addl_footnotes`` is either {nil}, a single string (a footnote) or a list
	of footnotes; ``new_formval`` is either {nil} or the new form value to substitute; and ``new_translit`` is either
	{nil} or the new translit string to substitute.
(2) `combine_form_and_footnotes(``form_value``, ``footnotes``)`, where ``form_value`` is a form value (a string) and
	``footnotes`` is either {nil}, a single string (a footnote) or a list of footnotes.

In either case, a form object is returned, preserving as many properties as possible from any existing form object in
``abform``. Do the minimal amount of work; e.g. if ``abform`` is a form object and ``addl_footnotes``, ``new_formval``
and ``new_translit`` are all {nil}, the same object as passed in is returned. Under no circumstances is the existing
form object side-effected.

'''FIXME:''' This does not correctly preserve metadata.
]==]
function export.combine_form_and_footnotes(abform, addl_footnotes, new_formval, new_translit)
	if type(addl_footnotes) == "string" then
		addl_footnotes = {addl_footnotes}
	end
	if not addl_footnotes and not new_formval and not new_translit then
		return abform
	end
	if type(abform) == "string" then
		new_formval = new_formval or abform
		return {form = new_formval, translit = new_translit, footnotes = addl_footnotes}
	end
	abform = m_table.shallowcopy(abform)
	if new_formval then
		abform.form = new_formval
	end
	if new_translit then
		abform.translit = new_translit
	end
	if addl_footnotes then
		abform.footnotes = export.combine_footnotes(abform.footnotes, addl_footnotes)
	end
	return abform
end


--[==[
Convert an abbreviated form list (either a string, form object, or list of either) into general list form. If
``footnotes`` is supplied, then for each form in the form list, combine the form's footnotes with ``footnotes``.
This function does not side-effect any of the objects passed into ``abforms``, but will return ``abforms``
unchanged if already in general list form and ``footnotes`` is {nil}.

'''FIXME:''' This does not correctly preserve metadata.
]==]
function export.convert_to_general_list_form(abforms, footnotes)
	if type(footnotes) == "string" then
		footnotes = {footnotes}
	end
	if type(abforms) == "string" then
		return {{form = abforms, footnotes = footnotes}}
	elseif abforms.form then
		return {export.combine_form_and_footnotes(abforms, footnotes)}
	elseif not footnotes then
		-- Check if already in general list form and return directly if so.
		local must_convert = false
		for _, form in ipairs(abforms) do
			if type(form) == "string" then
				must_convert = true
				break
			end
		end
		if not must_convert then
			return abforms
		end
	end
	local retval = {}
	for _, form in ipairs(abforms) do
		if type(form) == "string" then
			table.insert(retval, {form = form, footnotes = footnotes})
		else
			table.insert(retval, export.combine_form_and_footnotes(form, footnotes))
		end
	end
	return retval
end


local function is_table_of_strings(forms)
	for k, v in pairs(forms) do
		if type(k) ~= "number" or type(v) ~= "string" then
			return false
		end
	end
	return true
end


local function lang_or_func_transliterate(func, lang, text)
	local retval
	if func then
		retval = func(text)
	else
		retval = (lang:transliterate(text))
	end
	-- FIXME! Hack to work around bug in ...:transliterate(). Remove me as soon as this bug is fixed.
	if not retval and (text == " " or text == "-" or text == "?") then
		retval = text
	end
	if not retval then
		error(("Unable to transliterate text '%s'"):format(text))
	end
	return retval
end


--[==[
Combine ``stems`` and ``endings`` and store into slot ``slot`` of form table ``formtable``. Either of ``stems`` and
``endings`` can be {nil} or an abbreviated form list. The combination of a given stem and ending happens using
``combine_stem_ending``, which takes two parameters (stem and ending, each a string) and returns one value (a string).
If manual transliteration is present in either ``stems`` or ``endings``, ``lang`` (a language object or a function of
one argument to transliterate a string) along with ``combine_stem_ending_tr`` (a function for combining manual
transliterations that works much like ``combine_stem_ending``) must be given. ``footnotes``, if specified, is a list of
additional footnotes to attach to the resulting inflections (stem+ending combinations). The resulting inflections are
inserted into the form table using `insert_form()`, in case of duplication.
]==]
function export.add_forms(formtable, slot, stems, endings, combine_stem_ending, lang, combine_stem_ending_tr, footnotes)
	if stems == nil or endings == nil then
		return
	end
	local function combine(stem, ending)
		if stem == "?" or ending == "?" then
			return "?"
		end
		return combine_stem_ending(stem, ending)
	end
	local function transliterate(text)
		return lang_or_func_transliterate(type(lang) == "function" and lang or nil, lang, text)
	end
	if type(stems) == "string" and type(endings) == "string" then
		export.insert_form(formtable, slot, {form = combine(stems, endings), footnotes = footnotes})
	elseif type(stems) == "string" and is_table_of_strings(endings) then
		for _, ending in ipairs(endings) do
			export.insert_form(formtable, slot, {form = combine(stems, ending), footnotes = footnotes})
		end
	else
		stems = export.convert_to_general_list_form(stems)
		endings = export.convert_to_general_list_form(endings, footnotes)
		for _, stem in ipairs(stems) do
			for _, ending in ipairs(endings) do
				local footnotes = nil
				if stem.footnotes and ending.footnotes then
					footnotes = m_table.shallowcopy(stem.footnotes)
					for _, footnote in ipairs(ending.footnotes) do
						m_table.insertIfNot(footnotes, footnote)
					end
				elseif stem.footnotes then
					footnotes = stem.footnotes
				elseif ending.footnotes then
					footnotes = ending.footnotes
				end
				local new_form = combine(stem.form, ending.form)
				local new_translit
				if new_form ~= "?" and (stem.translit or ending.translit) then
					if not lang or not combine_stem_ending_tr then
						error("Internal error: With manual translit, 'lang' and 'combine_stem_ending_tr' must be passed to 'add_forms'")
					end
					local stem_tr = stem.translit or transliterate(m_links.remove_links(stem.form))
					local ending_tr = ending.translit or transliterate(m_links.remove_links(ending.form))
					new_translit = combine_stem_ending_tr(stem_tr, ending_tr)
				end
				export.insert_form(formtable, slot, {form = new_form, translit = new_translit, footnotes = footnotes})
			end
		end
	end
end


--[==[
Combine any number of form components and store into slot ``slot`` of form table ``formtable``. ``components`` is a list of abbreviated form
lists which should be concatenated similarly to how `add_forms()` does it, and stored in ``slot`` along with any footnotes in ``footnotes``.
More specifically:
# If there are no components, nothing happens.
# If there is one component, it is converted to general list form and `insert_forms()` called.
# If there are two components, they are treated as stems and endings respectively and `add_forms()` is called.
# If there are three or more components, they are concatenated left-to-right in the manner of a `reduce()` operation: the first two components
  are combined using `add_forms()` and stored into a temporary table, then the next component is combined with the result of the previous
  operation, etc. In the last combination, footnotes in `footnotes` are combined in, and the result stored into `formtable`.
This should generally be used when you are likely to have three or more components, as in [[Module:ar-verb]] (prefixes, stems and endings)
and [[Module:de-verb]] (which in some situations has five components combined together). ``combine_stem_ending``, ``lang``,
``combine_stem_ending_tr`` and ``footnotes`` are as in `add_forms()`.
]==]
function export.add_multiple_forms(formtable, slot, components, combine_stem_ending, lang, combine_stem_ending_tr, footnotes)
	if #components == 0 then
		return
	elseif #components == 1 then
		local forms = export.convert_to_general_list_form(components[1], footnotes)
		export.insert_forms(formtable, slot, forms)
	elseif #components == 2 then
		local stems = components[1]
		local endings = components[2]
		export.add_forms(formtable, slot, stems, endings, combine_stem_ending, lang, combine_stem_ending_tr, footnotes)
	else
		local prev = components[1]
		for i=2, #components do
			local temptable = {}
			export.add_forms(temptable, slot, prev, components[i], combine_stem_ending, lang, combine_stem_ending_tr,
				i == #components and footnotes or nil)
			prev = temptable[slot]
		end
		export.insert_forms(formtable, slot, prev)
	end
end
		

local function iterate_slot_list_or_table(props, do_slot)
	if props.slot_list then
		for _, slot_and_accel_tag_set in ipairs(props.slot_list) do
			local slot, accel_tag_set = unpack(slot_and_accel_tag_set)
			do_slot(slot, accel_tag_set)
		end
	else
		for slot, accel_tag_set in pairs(props.slot_table) do
			do_slot(slot, accel_tag_set)
		end
	end
end


function export.default_split_bracketed_runs_into_words(bracketed_runs)
	-- If the text begins with a hyphen, include the hyphen in the set of allowed characters
	-- for an inflected segment. This way, e.g. conjugating "-ir" is treated as a regular
	-- -ir verb rather than a hyphen + irregular [[ir]].
	local is_suffix = rfind(bracketed_runs[1], "^%-")
	local split_pattern = is_suffix and " " or "[ %-]"
	return put.split_alternating_runs(bracketed_runs, split_pattern, "preserve splitchar")
end


local function props_transliterate(props, text)
	return lang_or_func_transliterate(props.transliterate, props.lang, text)
end


local function parse_before_or_post_text(props, text, segments, lemma_is_last)
	-- Call parse_balanced_segment_run() to keep multiword links together.
	local bracketed_runs = put.parse_balanced_segment_run(text, "[", "]")
	-- Split normally on space or hyphen (but customizable). Use preserve_splitchar so we know whether the separator was
	-- a space or hyphen.
	local space_separated_groups
	if props.split_bracketed_runs_into_words then
		space_separated_groups = props.split_bracketed_runs_into_words(bracketed_runs)
	end
	if not space_separated_groups then
		space_separated_groups = export.default_split_bracketed_runs_into_words(bracketed_runs)
	end

	local parsed_components = {}
	local parsed_components_translit = {}
	local saw_manual_translit = false
	local lemma
	for j, space_separated_group in ipairs(space_separated_groups) do
		local component = table.concat(space_separated_group)
		if lemma_is_last and j == #space_separated_groups then
			lemma = component
			if lemma == "" and not props.allow_blank_lemma then
				error("Word is blank: '" .. table.concat(segments) .. "'")
			end
		elseif rfind(component, "//") then
			-- Manual translit or respelling specified.
			if not props.lang then
				error("Manual translit not allowed for this language; if this is incorrect, 'props.lang' must be set internally")
			end
			saw_manual_translit = true
			local split = split(component, "//", "plain")
			if #split ~= 2 then
				error("Term with translit or respelling should have only one // in it: " .. component)
			end
			local translit
			component, translit = unpack(split)
			if props.transliterate_respelling then
				translit = props.transliterate_respelling(translit)
			end
			table.insert(parsed_components, component)
			table.insert(parsed_components_translit, translit)
		else
			table.insert(parsed_components, component)
			table.insert(parsed_components_translit, false) -- signal that it may need later transliteration
		end
	end

	if saw_manual_translit then
		for j, parsed_component in ipairs(parsed_components) do
			if not parsed_components_translit[j] then
				parsed_components_translit[j] = props_transliterate(props, m_links.remove_links(parsed_component))
			end
		end
	end

	text = table.concat(parsed_components)
	local translit
	if saw_manual_translit then
		translit = table.concat(parsed_components_translit)
	end
	return text, translit, lemma
end


--[=[
Parse a segmented multiword spec such as "[[медичний|меди́чна]]<+> [[сестра́]]<*,*#.pr>" (in Ukrainian).
"Segmented" here means it is broken up on <...> segments using parse_balanced_segment_run(text, "<", ">"),
e.g. the above text would be passed in as {"[[медичний|меди́чна]]", "<+>", " [[сестра́]]", "<*,*#.pr>", ""}.

The return value is a table of the form
{
  word_specs = {``word_spec``, ``word_spec``, ...},
  post_text = "``text-at-end``",
  post_text_no_links = "``text-at-end-no-links``",
  post_text_translit = "``manual-translit-of-text-at-end``" or nil (if no manual translit or respelling was specified in the post-text)
}

where ``word_spec`` describes an individual inflected word and "``text-at-end``" is any raw text that may occur
after all inflected words. Individual words or linked text (including multiword text) may be given manual
transliteration or respelling in languages that support this using ``text``//``translit`` or ``text``//``respelling``.
Each ``word_spec`` is of the form returned by parse_indicator_spec():

{
  lemma = "``lemma``",
  before_text = "``text-before-word``",
  before_text_no_links = "``text-before-word-no-links``",
  before_text_translit = "``manual-translit-of-text-before-word``" or nil (if no manual translit or respelling was specified in the before-text)
  -- Fields as described in parse_indicator_spec()
  ...
}

For example, the return value for "[[медичний|меди́чна]]<+> [[сестра́]]<*,*#.pr>" is
{
  word_specs = {
    {
      lemma = "[[медичний|меди́чна]]",
      overrides = {},
      adj = true,
      before_text = "",
      before_text_no_links = "",
      forms = {},
    },
    {
      lemma = "[[сестра́]]",
      overrides = {},
	  stresses = {
		{
		  reducible = true,
		  genpl_reversed = false,
		},
		{
		  reducible = true,
		  genpl_reversed = true,
		},
	  },
	  animacy = "pr",
      before_text = " ",
      before_text_no_links = " ",
      forms = {},
    },
  },
  post_text = "",
  post_text_no_links = "",
}
]=]
local function parse_multiword_spec(segments, props, disable_allow_default_indicator)
	local multiword_spec = {
		word_specs = {}
	}
	if not disable_allow_default_indicator then
		if #segments == 1 then
			if props.allow_default_indicator then
				table.insert(segments, "<>")
				table.insert(segments, "")
			elseif props.angle_brackets_omittable then
				segments[1] = "<" .. segments[1] .. ">"
				table.insert(segments, 1, "")
				table.insert(segments, "")
			end
		end
	end
	-- Loop over every other segment. The even-numbered segments are angle-bracket specs while
	-- the odd-numbered segments are the text between them.
	for i = 2, #segments - 1, 2 do
		local before_text, before_text_translit, lemma =
			parse_before_or_post_text(props, segments[i - 1], segments, "lemma is last")
		local base = props.parse_indicator_spec(segments[i], lemma)
		base.before_text = before_text
		base.before_text_no_links = m_links.remove_links(base.before_text)
		base.before_text_translit = before_text_translit
		base.lemma = base.lemma or lemma
		table.insert(multiword_spec.word_specs, base)
	end
	multiword_spec.post_text, multiword_spec.post_text_translit =
		parse_before_or_post_text(props, segments[#segments], segments)
	multiword_spec.post_text_no_links = m_links.remove_links(multiword_spec.post_text)
	return multiword_spec
end


--[=[
Parse an alternant, e.g. "((родо́вий,родови́й))" or "((ру́син<pr>,руси́н<b.pr>))" (both in Ukrainian).
The return value is a table of the form
{
  alternants = {``multiword_spec``, ``multiword_spec``, ...}
}

where ``multiword_spec`` describes a given alternant and is as returned by parse_multiword_spec().
]=]
local function parse_alternant(alternant, props)
	local parsed_alternants = {}
	local alternant_text = rmatch(alternant, "^%(%((.*)%)%)$")
	local segments = put.parse_balanced_segment_run(alternant_text, "<", ">")
	local comma_separated_groups = put.split_alternating_runs(segments, "%s*,%s*")
	local alternant_spec = {alternants = {}}
	for _, comma_separated_group in ipairs(comma_separated_groups) do
		table.insert(alternant_spec.alternants, parse_multiword_spec(comma_separated_group, props))
	end
	return alternant_spec
end


--[==[
Top-level parsing function. Parse text describing one or more inflected words. `text` is the inflected text to parse,
which generally has `<...>` specs following words to be inflected, and may have alternants indicated using double
parens. Examples:

* {"[[медичний|меди́чна]]<+> [[сестра́]]<*,*#.pr>"} (Ukrainian, for {{m|uk|меди́чна сестра́||nurse|lit=medical sister}});
* {"((ру́син<pr>,руси́н<b.pr>))"} (Ukrainian, for {{m|uk|русин||Rusyn}}, with two possible stress patterns);
* {"पंचायती//पंचाय*ती राज<M>"} (Hindi, for {{m|hi|पंचायती राज||village council}}, with phonetic respelling in the
  before-text component);
* {"((<M>,<M.plstem:फ़तूह.dirpl:फ़तूह>))"} (Hindi, for {{m|hi|फ़तह||win, victory}} when used on that page, where the lemma
  is omitted and taken from the pagename);
* {""} (for any number of Hindi adjectives, where the lemma is omitted and taken from the pagename, and the angle
  bracket spec <> is assumed);
* {"काला<+>धन<M>"} (Hindi, for {{m|hi|कालाधन||black money}}, showing that closed compounds where each part is declined
  can be correctly handled).

`props` is an object specifying properties used during parsing, as follows:

```{
  parse_indicator_spec = __function__(``angle_bracket_spec``, ``lemma``) `''(required)''`,
  lang = __lang object__,
  transliterate_respelling = __function__(``respelling_or_translit``) `''(optional)''`,
  split_bracketed_runs_into_words = __function__(``bracket_split_runs``) `''(optional)''`,
  allow_default_indicator = __boolean__,
  angle_brackets_omittable = __boolean__,
  allow_blank_lemma = __boolean__,
}```

`parse_indicator_spec` is a required function that takes two arguments, a string surrounded by angle brackets and the
lemma, and should return an arbitrary object containing properties describing the indicators inside of the angle
brackets). This object is often called a '''base''' and given the argument name `base` in inflection code.

`lang` is the language object for the language in question; only needed if manual translit or respelling may be present
using `//`.

`transliterate_respelling` is a function that is only needed if respelling is allowed in place of manual translit after
`//`. It takes one argument, the respelling or translit, and should return the transliteration of any respelling but
return any translit unchanged.

`split_bracketed_runs_into_words` is an optional function to split the passed-in text into words. It is used, for
example, to determine what text constitutes a word when followed by an angle-bracket spec, i.e. what the lemma to be
inflected is vs. surrounding fixed text. It takes one argument, the result of splitting the original text on brackets,
and should return alternating runs of words and split characters, or nil to apply the default algorithm. Specifically,
the value passed in is the result of calling `parse_balanced_segment_run(``text``, "[", "]")` from
[[Module:parse utilities]] on the original text, and the default version of this function calls
`split_alternating_runs(``bracketed_runs``, ``pattern``, "preserve splitchar")`, where ``bracketed_runs`` is the value
passed in and ``pattern`` splits on either spaces or hyphens (unless the text begins with a hyphen, in which case
splitting is only on spaces, so that suffixes can be inflected).

`allow_default_indicator` should be {true} if an empty indicator in angle brackets `<>` can be omitted and should be
automatically added at the end of the multiword text (if no alternants) or at the end of each alternant (if alternants
present).

`angle_brackets_omittable` should be {true} if angle brackets can be omitted around a non-empty indicator in the
presence of a blank lemma. In this case, if the combined indicator spec has no angle brackets, they will be added around
the indicator (or around all indicators, if alternants are present). This only makes sense when `allow_blank_lemma` is
specified.

`allow_blank_lemma` should be {true} of if a blank lemma is allowed; in such a case, the calling function should
substitute a default lemma, typically taken from the pagename.

The return value is a table referred to as an '''alternant multiword spec''', and is of the form

```{
  alternant_or_word_specs = {``alternant_or_word_spec``, ``alternant_or_word_spec``, ...},
  post_text = "``text_at_end``",
  post_text_no_links = "``text_at_end_no_links``",
  post_text_translit = "``translit_of_text_at_end``" `(or nil)`,
}```

where `alternant_or_word_spec` is either an '''alternant spec''' as returned by `parse_alternant()` or a
'''multiword spec''' as described in the comment above `parse_multiword_spec()`. An alternant spec looks as follows:

```{
  alternants = {``multiword_spec``, ``multiword_spec``, ...},
  before_text = "``text_before_alternant``",
  before_text_no_links = "``text_before_alternant``",
  before_text_translit = "``translit_of_text_before_alternant``" `(or nil)`,
}```

i.e. it is like what is returned by `parse_alternant()` but has extra `before_text` and `before_text_no_links` fields.
]==]
function export.parse_inflected_text(text, props)
	if props.angle_brackets_omittable and not props.allow_blank_lemma then
		error("If 'angle_brackets_omittable' is specified, so should 'allow_blank_lemma'")
	end
	local alternant_multiword_spec = {alternant_or_word_specs = {}}
	local alternant_segments = split(text, "(%(%(.-%)%))")
	local last_post_text, last_post_text_no_links, last_post_text_translit
	for i = 1, #alternant_segments do
		if i % 2 == 1 then
			local segments = put.parse_balanced_segment_run(alternant_segments[i], "<", ">")
			-- Disable allow_default_indicator if alternants are present and we're processing
			-- the non-alternant text. Otherwise we will try to treat the non-alternant text
			-- surrounding the alternants as an inflected word rather than as raw text.
			local multiword_spec = parse_multiword_spec(segments, props, #alternant_segments ~= 1)
			for _, word_spec in ipairs(multiword_spec.word_specs) do
				table.insert(alternant_multiword_spec.alternant_or_word_specs, word_spec)
			end
			last_post_text = multiword_spec.post_text
			last_post_text_no_links = multiword_spec.post_text_no_links
			last_post_text_translit = multiword_spec.post_text_translit
		else
			local alternant_spec = parse_alternant(alternant_segments[i], props)
			alternant_spec.before_text = last_post_text
			alternant_spec.before_text_no_links = last_post_text_no_links
			alternant_spec.before_text_translit = last_post_text_translit
			table.insert(alternant_multiword_spec.alternant_or_word_specs, alternant_spec)
		end
	end
	alternant_multiword_spec.post_text = last_post_text
	alternant_multiword_spec.post_text_no_links = last_post_text_no_links
	alternant_multiword_spec.post_text_translit = last_post_text_translit
	-- Save boolean properties from `props`. We need at least `allow_default_indicator` when implementing
	-- `reconstruct_original_spec()`.
	alternant_multiword_spec.allow_default_indicator = props.allow_default_indicator
	alternant_multiword_spec.angle_brackets_omittable = props.angle_brackets_omittable
	alternant_multiword_spec.allow_blank_lemma = props.allow_blank_lemma
	return alternant_multiword_spec
end


-- Inflect alternants in ``alternant_spec`` (an object as returned by parse_alternant()).
-- This sets the form values in ```alternant_spec``.forms` for all slots.
-- (If a given slot has no values, it will not be present in ```alternant_spec``.forms`).
local function inflect_alternants(alternant_spec, props)
	alternant_spec.forms = {}
	for _, multiword_spec in ipairs(alternant_spec.alternants) do
		export.inflect_multiword_or_alternant_multiword_spec(multiword_spec, props)
		iterate_slot_list_or_table(props, function(slot)
			if not props.skip_slot or not props.skip_slot(slot) then
				export.insert_forms(alternant_spec.forms, slot, multiword_spec.forms[slot])
			end
		end)
	end
end



--[=[
Subfunction of `inflect_multiword_or_alternant_multiword_spec()`. This is used in building up the inflections of
multiword expressions. The basic purpose of this function is to append a set of forms representing the inflections of
a given inflected term in a given slot onto the existing forms for that slot. Given a multiword expression potentially
consisting of several inflected terms along with fixed text in between, we work iteratively from left to right, adding
the new forms onto the existing ones. Normally, all combinations of new and existing forms are created, meaning if
there are M existing forms and N new ones, we will end up with M*N forms. However, some of these combinations can be
rejected using the variant mechanism (see the description of get_variants below).

Specifically, `formtable` is a table of per-slot forms, where the key is a slot and the value is a list of form objects
(objects of the form {form=``form``, translit=``manual_translit``, footnotes=``footnotes``}). `slot` is the slot in question.
`forms` specifies the forms to be appended onto the existing forms, and is likewise a list of form objects. `props`
is the same as in `inflect_multiword_or_alternant_multiword_spec()`. `before_text` is the fixed text that goes before
the forms to be added. `before_text_no_links` is the same as `before_text` but with any links (i.e. hyperlinks of the
form [[``term``]] or [[``term``|``display``]]) converted into raw terms using remove_links() in [[Module:links]], and
`before_text_translit` is optional manual translit of `before_text_no_links`.

Note that the value "?" in a form is "infectious" in that if either the existing or new form has the value "?", the
resulting combination will also be "?". This allows "?" to be used to mean "unknown".
]=]
local function append_forms(props, formtable, slot, forms, before_text, before_text_no_links, before_text_translit)
	if not forms then
		return
	end
	local old_forms = formtable[slot] or {{form = ""}}
	local ret_forms = {}
	for _, old_form in ipairs(old_forms) do
		for _, form in ipairs(forms) do
			local old_form_vars = props.get_variants and props.get_variants(old_form.form) or ""
			local form_vars = props.get_variants and props.get_variants(form.form) or ""
			if old_form_vars ~= "" and form_vars ~= "" and old_form_vars ~= form_vars then
				-- Reject combination due to non-matching variant codes.
			else
				local new_formval
				local new_translit
				if old_form.form == "?" or form.from == "?" then
					new_formval = "?"
				else
					new_formval = old_form.form .. before_text .. form.form
					if old_form.translit or before_text_translit or form.translit then
						if not props.lang then
							error("Internal error: If manual translit is given, 'props.lang' must be set")
						end
						if not before_text_translit then
							before_text_translit = props_transliterate(props, before_text_no_links) or ""
						end
						local old_translit =
							old_form.translit or props_transliterate(props, m_links.remove_links(old_form.form)) or ""
						local translit =
							form.translit or props_transliterate(props, m_links.remove_links(form.form)) or ""
						new_translit = old_translit .. before_text_translit .. translit
					end
				end
				local new_formobj
				local new_footnotes = export.combine_footnotes(old_form.footnotes, form.footnotes)
				if new_formval == form.form and new_translit == form.translit then
					-- Automatically preserve metadata when possible.
					new_formobj = m_table.shallowcopy(form)
					new_formobj.footnotes = new_footnotes
				else
					local new_footnotes = export.combine_footnotes(old_form.footnotes, form.footnotes)
					new_formobj = {form=new_formval, translit=new_translit, footnotes=new_footnotes}
					if props.combine_metadata then
						props.combine_metadata {
							slot = slot,
							dest_form = new_formobj,
							form1 = old_form,
							form2 = form,
							between_text = before_text,
							between_text_no_links = before_text_no_links,
							between_text_translit = before_text_translit,
						}
					end
				end
				table.insert(ret_forms, new_formobj)
			end
		end
	end
	formtable[slot] = ret_forms
end


--[==[
Top-level inflection function. Create the inflections of a noun, verb, adjective or similar. `alternant_multiword_spec`
is as
returned by `parse_inflected_text` and describes the properties of the term to be inflected, including all the
user-provided inflection specifications (e.g. the number, gender, conjugation/declension/etc. of each word) and the
surrounding text. `props` indicates how to do the actual inflection (see below). The resulting inflected forms are
stored into the `.forms` property of `multiword_spec`. This property holds a table whose keys are slots (i.e. ID's
of individual inflected forms, such as "pres_1sg" for the first-person singular present indicative tense of a verb)
and whose values are lists of the form `{ form = ``form``, translit = ``manual_translit_or_nil``, footnotes = ``footnote_list_or_nil``}`,
where ``form`` is a string specifying the value of the form (e.g. "ouço" for the first-person singular present indicative
of the Portuguese verb [[ouvir]]); ``manual_translit_or_nil`` is the corresponding manual transliteration if needed (i.e.
if the form is in a non-Latin script and the automatic transliteration is incorrect or unavailable), otherwise nil;
and ``footnote_list_or_nil`` is a list of footnotes to be attached to the form, or nil for no footnotes. Note that
currently footnotes must be surrounded by brackets, e.g "[archaic]", and should not begin with a capital letter or end
with a period. (Conversion from "[archaic]" to "Archaic." happens automatically.)

This function has no return value, but modifies `multiword_spec` in-place, adding the `forms` table as described above.
After calling this function, call show_forms() on the `forms` table to convert the forms and footnotes given in this
table to strings suitable for display.

`props` is an object specifying properties used during inflection, as follows:

```{
  slot_list = {{"``slot``", "``accel``"}, {"``slot``", "``accel``"}, ...},
  slot_table = {``slot`` = "``accel``", ``slot`` = "``accel``", ...},
  skip_slot = nil `or` __function__(slot),
  lang = nil `or` __lang_object__,
  inflect_word_spec = __function__(base),
  get_variants = nil 'or` __function__(formval),
  combine_metadata = nil `or` __function__(data),
  include_user_specified_links = __boolean__,
}```

`slot_list` is a list of two-element lists of slots and associated accelerator tags. ``slot`` is arbitrary but should
correspond with slot names as generated by `inflect_word_spec`. ``accel`` is the corresponding accelerator tags; e.g. if
``slot`` is "pres_1sg", ``accel`` might be "1|s|pres|ind". ``accel`` is actually unused during inflection, but is used
during `show_forms()`, which takes the same `slot_list` as a property upon input.

`slot_table` is a table mapping slots to associated accelerator tags and serves the same function as `slot_list`. Only
one of `slot_list` or `slot_table` must be given. For new code it is preferable to use `slot_list` because this allows
you to control the order of processing slots, which may occasionally be important.

`skip_slot` is a function of one argument, a slot name, and should return a boolean indicating whether to skip the
given slot during inflection. It can be used, for example, to skip singular slots if the overall term being inflected
is plural-only, and vice-versa.

`lang` is a language object. This is only used to generate manual transliteration. If the language is written in the
Latin script or manual transliteration cannot be specified in the input to parse_inflected_text(), this can be omitted.
(Manual transliteration is allowed if the `lang` object is set in the `props` passed to parse_inflected_text().)

`inflect_word_spec` is the function to do the actual inflection. It is passed a single argument, which is a ``word_spec``
object describing the word to be inflected and the user-provided inflection specifications. It is exactly the same as
was returned by the `parse_indicator_spec` function provided in the `props` sent on input to `parse_inflected_text`, but
has additional fields describing the word to be inflected and the surrounding text, as follows:

```{
  lemma = "``lemma``",
  before_text = "``text-before-word``",
  before_text_no_links = "``text-before-word-no-links``",
  before_text_translit = "``manual-translit-of-text-before-word``" or nil (if no manual translit or respelling was specified in the before-text)
  -- Fields as described in parse_indicator_spec()
  ...
}```

Here ``lemma`` is the word to be inflected as specified by the user (including any links if so given), and the
`before_text*` fields describe the raw text preceding the word to be inflected. Any other fields in this object are as
set by `parse_inflected_text`, and describe things like the gender, number, conjugation/declension, etc. as specified
by the user in the <...> spec following the word to be inflected.

`inflect_word_spec` should initialize the `.forms` property of the passed-in ``word_spec`` object to the inflected forms of
the word in question. The value of this property is a table of the same format as the `.forms` property that is
ultimately generated by inflect_multiword_or_alternant_multiword_spec() and described above near the top of this
documentation: i.e. a table whose keys are slots and whose values are lists of the form
  `{ form = ``form``, translit = ``manual_translit_or_nil``, footnotes = ``footnote_list_or_nil``}`.

`get_variants` is either {nil} or a function of one argument (a string, a form value). The purpose of
this function is to ensure that in a multiword term where a given slot has more than one possible variant, the final
output has only parallel variants in it. For example, feminine nouns and adjectives in Russian have two possible
endings, one typically in -ой (-oj) and the other in -ою (-oju). If we have a feminine adjective-noun combination (or
a hyphenated feminine noun-noun combination, or similar), and we don't specify `get_variants`, we'll end up with four
values for the instrumental singular: one where both adjective and noun end in -ой, one where both end in -ою, and
two where one of the words ends in -ой and the other in -ою. In general if we have N words each with K variants, we'll
end up with an explosion of N^K possibilities. `get_variants` avoids this by returning a variant code (an arbitary
string) for each variant. If two words each have a non-empty variant code, and the variant codes disagree, the
combination will be rejected. If `get_variants` is not provided, or either variant code is an empty string, or the
variant codes agree, the combination is allowed.

The recommended way to use `get_variants` is as follows:
1. During inflection in `inflect_word_spec`, add a special character or string to each of the variants generated for a
   given slot when there is more than one. (As an optimization, do this only when there is more than one word being
   inflected.) Special Unicode characters can be used for this purpose, e.g. U+FFF0, U+FFF1, ..., U+FFFD, which have
   no meaning in Unicode.
2. Specify `get_variants` as a function that pulls out and returns the special character(s) or string included in the
   variant forms.
3. When calling show_forms(), specify a `canonicalize` function that removes the variant code character(s) or string
   from each form before converting to the display form.

See [[Module:hi-verb]] and [[Module:hi-common]] for an example of doing this in a generalized fashion. (Look for
add_variant_codes(), get_variants() and remove_variant_codes().)

`combine_metadata` is a function that is invoked when combining two form objects along along with in-between text and
storing into a destination form object. When this happens, if the the form value and translit in the first form object
is empty and the in-between text is likewise empty (which regularly happens when appending the form object describing
the first word in a multiword expression to empty base text), the second form object is simply shallow-copied along with
all of its metadata, and any footnotes are combined appropriately (normally the first form object is such a case won't
have footnotes). Otherwise, a new form object is constructed by combining the form values, translit and footnotes from
the two objects and in-between text, and calling `combine_metadata` to combine any other metadata. Leave this
unspecified if there is no additional metadata or if you don't want any metadata carried over. (Examples of metadata
that should generally not be carried over are glosses of individual words, sense ID's and similar word-level properties
that can't easily be combined to generate a multiword equivalent. Examples of metadata that should be carried over and
combined are qualifiers, labels and certain boolean properties such as an uncertainty flag indicating that a given form
is uncertain. For some metadata, it is more complex; for example, if both source words have the same gender or part of
speech, the destination should keep that value, but if they differ, it may be safest to leave the field blank.) This
function, if specified, is called with a single argument as follows:

```{
  slot = "__string__",
  dest_form = __formobj__,
  form1 = __formobj__,
  form2 = __formobj__,
  between_text = "__string__",
  between_text_no_links = "__string__",
  between_text_translit = "__string__" `or` nil
}```

Here, `slot` is the slot whose forms are being constructed. `dest_form` is the destination form object into which the
combined metadata should be written, and is pre-populated with appropriate `form`, `translit` and `footnotes` fields.
`form1` and `form2` are the two source forms being combined, and `between_text` is the text to be inserted between the
two source forms. `between_text_no_links` is the same as `between_text` but with double-bracket links removed, and
`between_text_translit` is the manual transliteration of `between_text_no_links`, if specified. The function should
return nothing, but should side-effect `dest_form` as appropriate.

`include_user_specified_links`, if given, ensures that user-specified links in the raw text surrounding a given word
are preserved in the output. If omitted or set to false, such links will be removed and the whole multiword expression
will be linked.
]==]
function export.inflect_multiword_or_alternant_multiword_spec(multiword_spec, props)
	multiword_spec.forms = {}

	local is_alternant_multiword = not not multiword_spec.alternant_or_word_specs
	for _, word_spec in ipairs(is_alternant_multiword and multiword_spec.alternant_or_word_specs or multiword_spec.word_specs) do
		if word_spec.alternants then
			inflect_alternants(word_spec, props)
		else
			props.inflect_word_spec(word_spec)
		end
		iterate_slot_list_or_table(props, function(slot)
			if not props.skip_slot or not props.skip_slot(slot) then
				append_forms(props, multiword_spec.forms, slot, word_spec.forms[slot],
					(rfind(slot, "linked") or props.include_user_specified_links) and
					word_spec.before_text or word_spec.before_text_no_links,
					word_spec.before_text_no_links, word_spec.before_text_translit
				)
			end
		end)
	end
	if multiword_spec.post_text ~= "" then
		local pseudoform = {{form=""}}
		iterate_slot_list_or_table(props, function(slot)
			-- If slot is empty or should be skipped, don't try to append post-text.
			if (not props.skip_slot or not props.skip_slot(slot)) and multiword_spec.forms[slot] then
				append_forms(props, multiword_spec.forms, slot, pseudoform,
					(rfind(slot, "linked") or props.include_user_specified_links) and
					multiword_spec.post_text or multiword_spec.post_text_no_links,
					multiword_spec.post_text_no_links, multiword_spec.post_text_translit
				)
			end
		end)
	end
end


function export.map_word_specs(alternant_multiword_spec, fun)
	for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		if alternant_or_word_spec.alternants then
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				for _, word_spec in ipairs(multiword_spec.word_specs) do
					fun(word_spec)
				end
			end
		else
			fun(alternant_or_word_spec)
		end
	end
end


function export.create_footnote_obj()
	return {
		notes = {},
		seen_notes = {},
		noteindex = 1,
		seen_refs = {},
	}
end


function export.get_footnote_text(footnotes, footnote_obj)
	if not footnotes then
		return ""
	end
	-- FIXME: Compatibility code for old callers that passed in a form object instead of the footnotes directly.
	-- Convert callers and remove this code.
	if footnotes.footnotes then
		track("get-footnote-text-old-calling-convention")
		footnotes = footnotes.footnotes
	end
	local link_indices = {}
	local all_refs = {}
	for _, footnote in ipairs(footnotes) do
		local refs
		footnote, refs = export.expand_footnote_or_references(footnote)
		if footnote then
			local this_noteindex = footnote_obj.seen_notes[footnote]
			if not this_noteindex then
				-- Generate a footnote index.
				this_noteindex = footnote_obj.noteindex
				footnote_obj.noteindex = footnote_obj.noteindex + 1
				table.insert(footnote_obj.notes, '<sup style="color: red">' .. this_noteindex .. '</sup>' .. footnote)
				footnote_obj.seen_notes[footnote] = this_noteindex
			end
			m_table.insertIfNot(link_indices, this_noteindex)
		end
		if refs then
			for _, ref in ipairs(refs) do
				if not ref.name then
					local this_refhash = footnote_obj.seen_refs[ref.text]
					if not this_refhash then
						-- Different text needs to have different auto-generated names, globally across the entire page,
						-- including across different invocations of {{it-verb}} or {{it-conj}}. The easiest way to accomplish
						-- this is to use a message-digest hashing function. It does not have to be cryptographically secure
						-- (MD5 is insecure); it just needs to have low probability of collisions.
						this_refhash = mw.hash.hashValue("md5", ref.text)
						footnote_obj.seen_refs[ref.text] = this_refhash
					end
					ref.autoname = this_refhash
				end
				-- I considered using "n" as the default group rather than nothing, to more clearly distinguish regular
				-- footnotes from references, but this requires referencing group "n" as <references group="n"> below,
				-- which is non-obvious.
				m_table.insertIfNot(all_refs, ref)
			end
		end
	end
	table.sort(link_indices)
	local function sort_refs(r1, r2)
		-- FIXME, we are now sorting on an arbitrary hash. Should we keep track of the order we
		-- saw the autonamed references and sort on that?
		if r1.autoname and r2.name then
			return true
		elseif r1.name and r2.autoname then
			return false
		elseif r1.name and r2.name then
			return r1.name < r2.name
		else
			return r1.autoname < r2.autoname
		end
	end
	table.sort(all_refs, sort_refs)
	for i, ref in ipairs(all_refs) do
		local refargs = {name = ref.name or ref.autoname, group = ref.group}
		all_refs[i] = mw.getCurrentFrame():extensionTag("ref", ref.text, refargs)
	end
	local link_text
	if #link_indices > 0 then
		link_text = '<sup style="color: red">' .. table.concat(link_indices, ",") .. '</sup>'
	else
		link_text = ""
	end
	local ref_text = table.concat(all_refs)
	if link_text ~= "" and ref_text ~= "" then
		return link_text .. "<sup>,</sup>" .. ref_text
	else
		return link_text .. ref_text
	end
end


--[==[
Add links around words in a term. If multiword_only, do it only in multiword terms.
]==]
function export.add_links(form, multiword_only)
	if form == "" or form == " " then
		return form
	end
	if not form:find("%[%[") then
		if rfind(form, "[%s%p]") then --optimization to avoid loading [[Module:headword]] on single-word forms
			local m_headword = require("Module:headword")
			if m_headword.head_is_multiword(form) then
				form = m_headword.add_multiword_links(form)
			end
		end
		if not multiword_only and not form:find("%[%[") then
			form = "[[" .. form .. "]]"
		end
	end
	return form
end


--[==[
Remove redundant link surrounding entire term.
]==]
function export.remove_redundant_links(term)
	return rsub(term, "^%[%[([^%[%]|]*)%]%]$", "%1")
end


--[==[
Add links to all before and after text; for use in inflection modules that preserve links in multiword lemmas and
include links in non-lemma forms rather than allowing the entire form to be a link. If `remember_original`, remember
the original user-specified before/after text so we can reconstruct the original spec later. `add_links` is a
function of one argument to add links to a given piece of text; if unspecified, it defaults to `export.add_links`.
]==]
function export.add_links_to_before_and_after_text(alternant_multiword_spec, remember_original, add_links)
	add_links = add_links or export.add_links
	local function add_links_remember_original(object, field)
		if remember_original then
			object["user_specified_" .. field] = object[field]
		end
		object[field] = add_links(object[field])
	end

	for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		add_links_remember_original(alternant_or_word_spec, "before_text")
		if alternant_or_word_spec.alternants then
			for _, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				for _, word_spec in ipairs(multiword_spec.word_specs) do
					add_links_remember_original(word_spec, "before_text")
				end
				add_links_remember_original(multiword_spec, "post_text")
			end
		end
	end
	add_links_remember_original(alternant_multiword_spec, "post_text")
end


--[==[
Reconstruct the original overall spec from the output of parse_inflected_text(), so we can use it in the
language-specific acceleration module in the implementation of {{tl|pt-verb form of}} and the like. `props` is an
optional table of properties. Currently only `preprocess_angle_bracket_spec` is recognized, and is an optional function
of one argument that is called to process an angle-bracket spec before inserting into the reconstructed spec.
]==]
function export.reconstruct_original_spec(alternant_multiword_spec, props)
	local parts = {}
	props = props or {}

	local function ins(txt)
		table.insert(parts, txt)
	end

	local function insert_angle_bracket_spec(spec)
		if props.preprocess_angle_bracket_spec then
			spec = props.preprocess_angle_bracket_spec(spec)
		end
		ins(spec)
	end

	for _, alternant_or_word_spec in ipairs(alternant_multiword_spec.alternant_or_word_specs) do
		ins(alternant_or_word_spec.user_specified_before_text)
		if alternant_or_word_spec.alternants then
			ins("((")
			for i, multiword_spec in ipairs(alternant_or_word_spec.alternants) do
				if i > 1 then
					ins(",")
				end
				for _, word_spec in ipairs(multiword_spec.word_specs) do
					ins(word_spec.user_specified_before_text)
					ins(word_spec.user_specified_lemma)
					insert_angle_bracket_spec(word_spec.angle_bracket_spec)
				end
				ins(multiword_spec.user_specified_post_text)
			end
			ins("))")
		else
			ins(alternant_or_word_spec.user_specified_lemma)
			insert_angle_bracket_spec(alternant_or_word_spec.angle_bracket_spec)
		end
	end
	ins(alternant_multiword_spec.user_specified_post_text)

	local retval = table.concat(parts)

	if alternant_multiword_spec.allow_default_indicator then
		-- As a special case, if we see e.g. "amar<>", remove the <>. Don't do this if there are spaces or alternants.
		if not retval:find(" ") and not retval:find("%(%(") then
			local retval_no_angle_brackets = retval:match("^(.*)<>$")
			if retval_no_angle_brackets then
				return retval_no_angle_brackets
			end
		end
	end
	return retval
end


--[==[
Convert the forms in ``formtable`` (a form table, whose keys are slots and whose values are lists of form objects, each
of which is a table of the form `form = ``form``, translit = ``manual_translit_or_nil``, footnotes = ``footnote_list_or_nil``, no_accel = ``true_to_suppress_accelerators``, ... `)
into strings. The form table is side-effected. Each form list turns into a string consisting of a comma-separated list
of linked forms, with accelerators (unless `no_accel` is set in a given form object). If `include_translit` is
specified, each string consists of a comma-separated list of form values (each formatted as a link), an HTML
`&lt;br/>`, and a comma-separated list of transliterations. `props` is a table used in generating the strings, as
follows:

```{
  lang = __lang_object__,
  lemmas = {"``lemma``", "``lemma``", ...},
  slot_list = {{"``slot``", "``accel``"}, {"``slot``", "``accel``"}, ...},
  slot_table = {``slot`` = "``accel``", ``slot`` = "``accel``", ...},
  include_translit = __boolean__,
  create_footnote_obj = nil `or` __function__(),
  canonicalize = nil or __function__(formval),
  preprocess_forms = nil `or` __function__(data),
  no_deduplicate_forms = __boolean__,
  combine_metadata_during_dedup = nil `or` __function__(data),
  transform_accel_obj = nil `or` __function__(slot, form, accel_obj),
  format_forms = nil `or` __function__(data),
  generate_link = nil `or` __function__(data),
  format_tr = nil `or` __function__(data),
  join_spans = nil `or` __function__(data),
  allow_footnote_symbols = __boolean__,
  footnotes = nil or {"``extra_footnote``", "``extra_footnote``", ...},
}```

`lemmas` is the list of lemmas, used in the accelerators.

`slot_list` is a list of two-element lists of slots and associated accelerator tag sets. ``slot`` should correspond
to slots generated during `inflect_multiword_or_alternant_multiword_spec()`. ``accel`` is the corresponding accelerator
tag set; e.g. if ``slot`` is "pres_1sg", ``accel`` might be "1|s|pres|ind". ``accel`` is used in generating entries for
accelerator support (see [[WT:ACCEL]]).

`slot_table` is a table mapping slots to associated accelerator tag sets and serves the same function as `slot_list`.
Only one of `slot_list` or `slot_table` must be given. For new code it is preferable to use `slot_list` because this
allows you to control the order of processing slots, which may occasionally be important.

`include_translit`, if given, causes transliteration to be included in the generated strings.

The function works as follows:
# Create an object to hold footnotes (customizable using `create_footnote_obj`).
# Generate the comma-separated lemma form values and store in `.lemma` in the form table.
# Loop over the slots specified using `slot_list` or `slot_table`. For each slot:
## Canonicalize the form values (customizable using `canonicalize`; by default does nothing).
## Preprocess the forms (customizable using `preprocess_forms`; by default does nothing).
## Unless `no_deduplicate_forms` is set, deduplicate forms in a slot sharing the same form value but possibly different
   transliteration. (This happens e.g. in Russian, where it is relatively common for a given form to have two possible
   transliterations, one reflecting a more nativized pronunciation where Cyrillic е triggers palatalization of the
   preceding consonant, and one reflecting a more "foreign" pronunciation where this palatalization does not happen. In
   such a case, the automatic transliteration would normally suffice for the more nativized pronunciation but the more
   "foreign" pronunciation will need manual transliteration.) As part of deduplication, footnotes will be combined using
   `combine_footnotes`; distinct manual transliterations will be combined into a list (meaning the `translit` field of
   form objects in some subsequent `props` functions may hold a list; this will be noted when possible); and any
   remaining metadata will be combined using the `combine_metadata_during_dedup` method, if provided.
## Add acceleration to all forms. The acceleration tag set associated with a given form comes from `slot_list` or
   `slot_table`, i.e. all forms in a given slot have the same tag set. However, different forms will have different
   associated transliterations stored into the accelerator object associated with the form, as well as possibly
   different lemmas. In particular, when there are multiple lemma forms, this is often due to alternative ways to
   pronounce the lemma (e.g. alternative stress positions or vowel lengths), and there are often associated non-lemma
   forms that match each lemma. An example given in the introduction is {{m+|uk|русин||Rusyn}}, stressed in the lemma
   as ''ру́син'' or ''руси́н'' with associated genitive singulars ''ру́сина'' and ''русина́''. We would like the
   auto-generated accelerator entry for {{m|uk|русина}} to show the variant ''ру́сина'' as having lemma ''ру́син'' and
   the variant ''русина́'' as having the lemma ''руси́н'', rather than showing both variants as having both lemmas,
   which is less accurate. As a result, the code that generates acceleration objects for forms matches up forms and
   lemmas one-to-one if possible. If this is not possible, the matching is usually one lemma to many forms, as in
   {{m+|uk|міст||bridge}} with genitive singular ''мо́сту'' or ''моста́'' (in which case all forms get the same lemma), or
   many lemmas to one form, as in {{m+|uk|черга||turn, queue}} stressed either ''че́рга'' or ''черга́'' with nominative
   singular only ''че́рги'' (in which case the single form gets assicated all lemmas). If there are multiple lemmas and
   multiple forms, the algorithm attempts to align them as evenly as possible (e.g. two lemma variants to four forms
   means the first two forms get assigned the first lemma variant and the last two forms get assigned the second lemma
   variant); this is often going to be incorrect, but (a) there's unlikely to be a single algorithm that works in all
   such circumstances, and (b) these cases are very rare. Finally, note the following:
##* No acceleration is assigned to a form if any of the following apply: (a) there are no lemmas given in
    `props.lemmas`; (b) the `no_accel` key in the form object has a non-falsy value; (c) the form value of the form is
	{"?"} or an em-dash ({"—"}); (d) the accelerator tag set is given as a hyphen {"-"}); or (e) the form value contains
	an internal link.
##* The accelerator code sets the `formval_for_link` key in each form object to the version of the form value that
    should be passed to `full_link()` in [[Module:links]]. This is usually the same as the passed-in form value, but
	differs when `props.allow_footnote_symbols` is specified and an old-style footnote symbol is attached to the form
	(the removed footnote symbol is stored in the `formval_old_style_footnote_symbol` key), and also differs when the
	entire form value is surrounded with a redundant internal link (which is removed).
##* The resulting accelerator object can be modified (or replaced entirely) by the `transform_accel_obj` function. This
    is used, for example, in [[Module:es-verb]], [[Module:pt-verb]] and other Romance-language verb conjugation modules
	(likewise [[Module:ar-verb]]) to replace the tag set with the original verb spec used to generate the verb, so that
	the accelerator code can generate the appropriate call to {{tl|es-verb form of}}, {{tl|pt-verb form of}} or the
	like, which computes the inflections, instead of directly listing the inflections.
## Format the forms into strings. The entire default process can be replaced using `format_forms`; otherwise the default
   algorithm works as follows:
### Generate the '''form value spans''', with one entry (a linked HTML-ized version of the form value) per form. This
    can be customized using `generate_link`. (Various modules do this. For example, the Arabic verb module includes
	qualifiers, labels, ID's and the like that can be specified by the user; the Portuguese and reintegrated Galician
	verb modules italicize certain superseded or otherwise less-desirable forms instead of linking them normally; the
	German verb module adds {{m|de|dass}} to subjunctive forms and optional pronouns to imperative forms; and the German
	adjective module adds articles to adjective forms normally accompanied by articles and the equivalent of "he/she is"
	etc. to predicate forms.) The default uses `full_link()` in [[Module:links]] (with transliteration generation
	disabled) concatenated with the appropriate footnote symbol(s) (if any).
### Generate the '''transliteration spans''', with one entry per distinct translit, auto-generated if manual translit
    isn't available. Note that, due to the earlier form value deduplication step, there may be multiple translits per
	form object. These translits are themselves deduplicated to get the list of spans. (Such duplication can happen, for
	example, in Arabic with terms containing a glottal stop in them; there may be multiple ways of spelling the glottal
	stop or ''hamza'' in Arabic, but only one way of transliterating it.) Each span consists of an object specifying
	the translit minus any attached old-style footnote symbols (which are only allowed if
	`props.allow_footnote_symbols` is set); the attached old-style footnote symbol, which is always an empty string when
	`props.allow_footnote_symbols` is not set; and the list of (new-style) footnotes. These objects are then converted
	to formatted strings, either using `format_tr` if supplied or else calling `tag_translit()` in
	[[Module:script utilities]] and concatenating the appropriate footnote symbol(s) (if any).
### Combine the form value and transliteration spans. If `join_spans` is supplied, use it; otherwise, concatenate the
    form value spans (comma-separated) and (if available) transliteration spans (comma-separated), and (if appropriate)
	combine them using {<br />}.

`create_footnote_obj` is an optional function of no arguments to create the footnote object used to track footnotes;
see `create_footnote_obj()`. Customizing it is useful to prepopulate the footnote table using `get_footnote_text()`.

`canonicalize` is an optional function of one argument (a form value) to canonicalize each form before processing; it
can return nil for no change. The most common purpose of this function is to remove variant codes from the form value.
See the documentation for `inflect_multiword_or_alternant_multiword_spec()` for a description of variant codes and their
purpose.

`preprocess_forms` is an optional function of one argument (a table of properties) to preprocess the form objects as
a whole. It runs after `canonicalize` (meaning that the form values passed in are canonicalized) and before
deduplication and the addition of acceleration info. The property table passed in has the following properties:
* `slot`: The slot being processed.
* `forms`: The list of form objects for this slot.
* `accel_tag_set`: The accelerator tag set for this slot, taken from `slot_list` or `slot_table`.
* `footnote_obj`: The footnote object returned by the `create_footnote_obj` property or the default
  `create_footnote_obj()` function.
`preprocess_forms` should return a list of preprocessed form objects, or {nil} to use the passed-in `forms`. If this
function does deduplication, you should set `no_deduplicate_forms` to disable the default deduplication process.

`no_deduplicate_forms`, if set, disables the deduplication step (see above).

`combine_metadata_during_dedup` is an optional function of one argument (a table of properties) to combine the metadata
of deduplicated form objects. The property table passed in has the following properties:
* `slot`: The slot being processed.
* `existing_form`: The existing form object into which a duplicated form is being combined.
* `dup_form`: The duplicated form being combined into `existing_form`.
* `existing_form_pos`: The one-based position of the existing form in the deduplicated form list (not necessarily its
  original position).
* `dup_form_pos`: The one-based position of the duplicated form in its original list.
The following should be noted about the form objects passed in:
# The form values in `.form` have been canonicalized using `.canonicalize`, if provided.
# The form values in `existing_form` and `dup_form` are always the same.
# The footnotes in `existing_form` have already been combined with those in `dup_form`.
# If there was manual translit either in `existing_form` (prior to deduplication) or in `dup_form`, there will be
  manual translit in `existing_form.translit` that is a list and combines any previous accumulated translits in
  `existing_form` as well as the translit in `dup_form` (even if one of them was specified as {nil} indicating an
  automatic translit). This means that the translit in `existing_form.translit` is always either {nil} or a list of
  strings (and the same applies to `dup_form.translit`).

`transform_accel_obj` is an optional function of three arguments (``slot``, ``formobj``, ``accel_obj``) to transform the
default constructed accelerator object in ``accel_obj`` into an object that should be passed to `full_link()` in
[[Module:links]].  It should return the new accelerator object, or {nil} for no acceleration. (If {nil} is returned,
the corresponding form has no acceleration; this is unlike most customization functions, where returning {nil} causes
the default algorithm to be invoked.) The function can destructively modify the accelerator object passed in.
'''NOTE''': This is called even when the passed-in ``accel_obj`` is {nil} (see the (a) through (e) reasons above why no
acceleration may be assigned to a form). Thus, your code needs to do something sensible in this case. The description
above of how `show_forms()` works inclues various examples of modules that supply a `transform_accel_obj` function and
the reasons for doing so.

`format_forms`, if supplied, is a function that entirely replaces the formatting portion of `show_forms()`. An example
of why you might want to do this is to get a different layout than the default, e.g. one where translit is displayed
next to each form value instead of the form values and translits grouped and displayed on separate lines. Under normal
circumstances, you should not do this, but instead customize the functions that replace specific parts of the default
formatting algorithm (see below). This function is passed one argument (a table of properties) and should return a
string (the formatted forms, ready to store into the slot in the form table) or {nil} to proceed with the default
algorithm (see above). The property table passed in has the following properties:
* `slot`: The slot being processed.
* `forms`: The list of form objects, deduplicated and with accelerator info added.
* `footnote_obj`: The footnote object returned by the `create_footnote_obj` property or the default
  `create_footnote_obj()` function.
The following should be noted about the form objects in `forms`:
# There are extra fields `formval_for_link`, `formval_old_style_footnote_symbol` and `accel_obj`. The first two are as
described above under the paragraph beginning "Add acceleration to all forms" under "The function works as follows".
The third one is the accelerator object in the format expected by [[Module:links]].
# The `translit` field, if non-{nil}, is a list of transliterations rather than a single transliteration; this is due to
the form value deduplication step.

`generate_link` is an optional function to generate the link text for a given form value. It is passed a single argument
(a table of properties) and should return a string, the formatted link. If it returns {nil}, the default algorithm (see
above) is invoked. The property table passed in has the following properties:
* `slot`: The slot being processed.
* `form`: The form to be converted to a formatted link. As with the `format_forms` function described above, the form
  objects passed in contain extra fields `formval_for_link`, `formval_old_style_footnote_symbol` and `accel_obj` (all
  of which will normally be used), and the `translit` field, if non-{nil}, is a list.
* `pos`: The one-based position of the form being processed, in the list of form value spans. Rarely used.
* `footnote_obj`: The footnote object returned by the `create_footnote_obj` property or the default
  `create_footnote_obj()` function. Normally used in order to get the (new-style) footnote symbol associated with any
  footnotes in `footnotes`.
The description above of how `show_forms()` works inclues various examples of modules that supply a `generate_link`
function and the reasons for doing so.

`format_tr` is an optional function to generate the formatted text for a given transliteration. It is passed a single
argument (a table of properties) and should return a string, the formatted transliteration text. If it returns {nil},
the default algorithm (see above) is invoked. The property table passed in has the following properties:
* `slot`: The slot being processed.
* `tr_for_tag`: The transliteration to process, where old-style footnote symbols have been removed.
* `old_style_footnote_symbol`: The removed old-style footnote symbol, or a blank string if no symbol was removed.
* `pos`: The one-based position of the transliteration being processed, in the list of transliteration spans. Rarely
  used.
* `footnotes`: The list of footnotes associated with all form objects with this transliteration. (If there were multiple
  form objects with the same transliteration, the list of footnotes will have been generated using
  `combine_footnotes()`.)
* `footnote_obj`: The footnote object returned by the `create_footnote_obj` property or the default
  `create_footnote_obj()` function. Normally used in order to get the (new-style) footnote symbol associated with any
  footnotes in `footnotes`.

`join_spans` is an optional function to join the processed form value and transliteration spans into a formatted string.
It is passed a single argument (a table of properties) and should return the final string to store into the form table
slot. If it returns {nil}, the default algorithm (see above) is invoked. The property table passed in has the following
properties:
* `slot`: The slot being processed.
* `formval_spans`: A list of strings, the formatted form value spans.
* `tr_spans`: A list of strings, the formatted transliteration spans. If there is no transliteration, this will be an
  empty list.
A custom `join_spans` is provided by [[Module:de-verb]], which concatenates the form value spans vertically (using
{"<br />"}) instead of horizontally using a comma, as is normal; this is because there is no translit and the form
values are often long, containing extra words attached during `generate_link()`. The only exception is the `aux` slot
holding the auxiliaries, which is concatenated horizontally using {" or "}. [[Module:de-adjective]] similarly provides
a custom `join_spans` function that concatenates the form value spans vertically.

`allow_footnote_symbols`, if given, causes any old-style footnote symbols attached to forms (e.g. numbers, asterisk) to
be separated off, placed outside the links, and superscripted. In this case, `footnotes` should be a list of footnotes
(preceded by footnote symbols, which are superscripted). These footnotes are combined with any footnotes found in the
forms and placed into `forms.footnotes`. This mechanism of specifying footnotes is provided for backward compatibility
with certain existing inflection modules and should not be used for new modules. Instead, use the regular footnote
mechanism specified using the `footnotes` property attached to each form object.
]==]
function export.show_forms(formtable, props)
	local footnote_obj = props.create_footnote_obj and props.create_footnote_obj() or export.create_footnote_obj()
	local function fetch_formval_and_translit(entry, remove_links)
		local formval, translit
		if type(entry) == "table" then
			formval, translit = entry.form, entry.translit
		else
			formval = entry
		end
		if remove_links then
			formval = m_links.remove_links(formval)
		end
		return formval, translit
	end

	local lemma_formvals = {}
	for _, lemma in ipairs(props.lemmas) do
		local lemma_formval, _ = fetch_formval_and_translit(lemma)
		m_table.insertIfNot(lemma_formvals, lemma_formval)
	end
	formtable.lemma = #lemma_formvals > 0 and table.concat(lemma_formvals, ", ") or
		mw.loadData(headword_data_module).pagename
	-- For safety, since we in-place modify `lemmas` usually before processing a given slot, make a copy.
	local props_lemmas = m_table.shallowcopy(props.lemmas)
	for i, lemma in ipairs(props_lemmas) do
		props_lemmas[i] = m_table.shallowcopy(lemma)
	end

	local function do_slot(slot, accel_tag_set)
		local formobjs = formtable[slot]
		if formobjs then
			if type(formobjs) ~= "table" then
				error("Internal error: For slot '" .. slot .. "', expected table but saw " .. dump(formobjs))
			end

			-- Maybe canonicalize the form values (e.g. remove variant codes and monosyllabic accents).
			if props.canonicalize then
				for _, form in ipairs(formobjs) do
					form.form = props.canonicalize(form.form) or form.form
				end
			end

			-- Preprocess the forms as a whole if called for.
			if props.preprocess_forms then
				formobjs = props.preprocess_forms {
					slot = slot,
					forms = formobjs,
					accel_tag_set = accel_tag_set,
					footnote_obj = footnote_obj,
				} or formobjs
			end

			-- Maybe deduplicate form values (happens e.g. in Russian with two terms with the same Russian form but
			-- different translits).
			if not props.no_deduplicate_forms then
				local deduped_formobjs = {}
				for i, form in ipairs(formobjs) do
					local function combine_forms(existing_form, dup_form, pos)
						assert(existing_form.form == dup_form.form)
						-- Combine footnotes.
						existing_form.footnotes = export.combine_footnotes(existing_form.footnotes, dup_form.footnotes)
						-- If translit is being generated, and there's manual translit associated with either form, we
						-- need to generate any missing translits and combine them, taking into account the fact that a
						-- translit value may actually be a list of translits (particularly with the existing form if we
						-- already combined an item with manual translit into it).
						if props.include_translit and form_value_transliterable(existing_form.form) and (
								existing_form.translit or dup_form.translit) then
							local combined_translit
							if not existing_form.translit then
								combined_translit = {
									props_transliterate(props, m_links.remove_links(existing_form.form))
								}
							elseif type(existing_form.translit) == "string" then
								combined_translit = {existing_form.translit}
							else
								combined_translit = existing_form.translit
							end
							local dup_form_translit = dup_form.translit
							if not dup_form_translit then
								-- dup_form.form is the same as existing_form.form (see assert above), but this is
								-- defensive programming in case that changes
								dup_form_translit = {props_transliterate(props, m_links.remove_links(dup_form.form))}
							elseif type(dup_form_translit) == "string" then
								dup_form_translit = {dup_form_translit}
							end
							for _, translit in ipairs(dup_form_translit) do
								m_table.insertIfNot(combined_translit, translit)
							end
							existing_form.translit = combined_translit
						end
						if props.combine_metadata_during_dedup then
							props.combine_metadata_during_dedup {
								slot = slot,
								existing_form = existing_form,
								existing_form_pos = pos,
								dup_form = dup_form,
								dup_form_pos = i,
							}
						end
					end
					m_table.insertIfNot(deduped_formobjs, form, {
						key = function(form) return form.form end,
						combine = combine_forms,
					})
				end
				formobjs = deduped_formobjs
			end

			-- Add acceleration info to form objects.
			for i, form in ipairs(formobjs) do
				local formval = form.form
				if not form_value_transliterable(formval) then
					form.formval_for_link = formval
					form.formval_old_style_footnote_symbol = ""
				else
					local formval_for_link, formval_old_style_footnote_symbol
					if props.allow_footnote_symbols then
						formval_for_link, formval_old_style_footnote_symbol =
							require(table_tools_module).get_notes(formval)
						if formval_old_style_footnote_symbol ~= "" then
							track("old-style-footnote-symbol")
						end
					else
						formval_for_link = formval
						formval_old_style_footnote_symbol = ""
					end
					-- remove redundant link surrounding entire form
					formval_for_link = export.remove_redundant_links(formval_for_link)
					form.formval_for_link = formval_for_link
					form.formval_old_style_footnote_symbol = formval_old_style_footnote_symbol

					-------------------- Compute the accelerator object. -----------------

					local accel_obj
					-- Check if form still has links; if so, don't add accelerators because the resulting entries will
					-- be wrong.
					if props_lemmas[1] and not form.no_accel and accel_tag_set ~= "-" and
						not rfind(formval_for_link, "%[%[") then
						-- If there is more than one form or more than one lemma, things get tricky. Often, there are
						-- the same number of forms as lemmas, e.g. for Ukrainian [[зимовий]] "wintry; winter (rel.)",
						-- which can be stressed зимо́вий or зимови́й with corresponding masculine/neuter genitive
						-- singulars зимо́вого or зимово́го etc. In this case, usually the forms and lemmas match up so
						-- we do this. If there are different numbers of forms than lemmas, it's usually one lemma
						-- against several forms e.g. Ukrainian [[міст]] "bridge" with genitive singular мо́сту or моста́
						-- (accent patterns b or c) or [[ложка|ло́жка]] "spoon" with nominative plural ло́жки or ложки́
						-- (accent patterns a or c). Here, we should assign the same lemma to both forms. The opposite
						-- can happen, e.g. [[черга]] "turn, queue" stressed че́рга or черга́ with nominative plural only
						-- че́рги (accent patterns a or d). Here we should assign both lemmas to the same form. In more
						-- complicated cases, with more than one lemma and form and different numbers of each, we try
						-- to align them as much as possible, e.g. if there are somehow eight forms and three lemmas,
						-- we assign lemma 1 to forms 1-3, lemma 2 to forms 4-6 and lemma 3 to forms 7 and 8, and
						-- conversely if there are somehow three forms and eight lemmas. This is likely to be wrong, but
						-- (a) there's unlikely to be a single algorithm that works in all such circumstances, and (b)
						-- these cases are vanishingly rare or nonexistent. Properly we should try to remember which
						-- form was generated by which lemma, but that is significant extra work for little gain.
						local first_lemma, last_lemma
						if #formobjs >= #props_lemmas then
							-- More forms than lemmas. Try to even out the forms assigned per lemma.
							local forms_per_lemma = math.ceil(#formobjs / #props_lemmas)
							first_lemma = math.floor((i - 1) / forms_per_lemma) + 1
							last_lemma = first_lemma
						else
							-- More lemmas than forms. Try to even out the lemmas assigned per form.
							local lemmas_per_form = math.ceil(#props_lemmas / #formobjs)
							first_lemma = (i - 1) * lemmas_per_form + 1
							last_lemma = math.min(first_lemma + lemmas_per_form - 1, #props_lemmas)
						end
						local accel_lemma, accel_lemma_translit
						if first_lemma == last_lemma then
							accel_lemma, accel_lemma_translit =
								fetch_formval_and_translit(props_lemmas[first_lemma], "remove links")
						else
							accel_lemma = {}
							accel_lemma_translit = {}
							for j=first_lemma, last_lemma do
								local this_lemma = props_lemmas[j]
								local this_accel_lemma, this_accel_lemma_translit =
									fetch_formval_and_translit(props_lemmas[j], "remove links")
								-- Do not use table.insert() especially for the translit because it may be nil and in
								-- that case we want gaps in the array.
								accel_lemma[j - first_lemma + 1] = this_accel_lemma
								accel_lemma_translit[j - first_lemma + 1] = this_accel_lemma_translit
							end
						end

						local accel_translit
						if props.include_translit and form.translit then
							if type(form.translit) == "table" then
								accel_translit = table.concat(form.translit, ", ")
							elseif type(form.translit) == "string" then
								accel_translit = form.translit
							else
								error(("Internal error: For slot '%s', form translit is not a table or string: %s"):
									format(slot, dump(accel_translit)))
							end
						end

						accel_obj = {
							form = accel_tag_set,
							translit = accel_translit,
							lemma = accel_lemma,
							lemma_translit = props.include_translit and accel_lemma_translit or nil,
						}
					end
					-- Postprocess if requested.
					if props.transform_accel_obj then
						accel_obj = props.transform_accel_obj(slot, form, accel_obj)
					end
					form.accel_obj = accel_obj
				end
			end

			-- Format the form objects into a string for insertion into the table.
			local formatted_forms
			if props.format_forms then
				formatted_forms = props.format_forms {
					slot = slot,
					forms = forms,
					footnote_obj = footnote_obj,
				}
			end
			if not formatted_forms then
				-- Default algorithm: Separate form values and translits and concatenate on separate lines.
				-- Form values have already been deduplicated but we may need to deduplicate translits (this happens
				-- e.g. in Arabic where there may be multiple ways of spelling a hamza in the Arabic script but only
				-- one way in transliteration).
				local formval_spans = {}
				local tr_spans = {}
				for i, form in ipairs(formobjs) do
					local link
					if props.generate_link then
						link = props.generate_link {
							slot = slot,
							pos = i,
							form = form,
							footnote_obj = footnote_obj,
						}
					end
					if not link then
						link = m_links.full_link {
							lang = props.lang, term = form.formval_for_link, tr = "-", accel = form.accel_obj
						} .. form.formval_old_style_footnote_symbol ..
						export.get_footnote_text(form.footnotes, footnote_obj)
					end
					formval_spans[i] = link
					if props.include_translit then
						-- Note that if there is an attached old-style footnote symbol, we transliterate it.
						local translits = form.translit or props_transliterate(props, m_links.remove_links(form.form))
						if type(translits) == "string" then
							translits = {translits}
						end
						for _, tr in ipairs(translits) do
							local tr_for_tag, tr_old_style_footnote_symbol
							if props.allow_footnote_symbols then
								tr_for_tag, tr_old_style_footnote_symbol = require(table_tools_module).get_notes(tr)
								if tr_old_style_footnote_symbol ~= "" then
									track("old-style-footnote-symbol")
								end
							else
								tr_for_tag = tr
								tr_old_style_footnote_symbol = ""
							end
							m_table.insertIfNot(tr_spans, {
								tr_for_tag = tr_for_tag,
								old_style_footnote_symbol = tr_old_style_footnote_symbol,
								footnotes = form.footnotes,
							}, {
								key = function(trobj) return trobj.tr_for_tag end,
								combine = function(tr, newtr)
									-- Combine footnotes.
									tr.footnotes = export.combine_footnotes(tr.footnotes, newtr.footnotes)
									tr.old_style_footnote_symbol = tr.old_style_footnote_symbol ..
										newtr.old_style_footnote_symbol
								end,
							})
						end
					end
				end

				for i, tr_span in ipairs(tr_spans) do
					local formatted_tr
					if props.format_tr then
						formatted_tr = props.format_tr {
							slot = slot,
							pos = i,
							tr_for_tag = tr_span.tr_for_tag,
							old_style_footnote_symbol = tr_span.old_style_footnote_symbol,
							footnotes = tr_span.footnotes,
							footnote_obj = footnote_obj,
						}
					end
					if not formatted_tr then
						formatted_tr = require(script_utilities_module).tag_translit(tr_span.tr_for_tag, props.lang,
							"default", " style=\"color: #888;\"") .. tr_span.old_style_footnote_symbol ..
							export.get_footnote_text(tr_span.footnotes, footnote_obj)
					end
					tr_spans[i] = formatted_tr
				end

				if props.join_spans then
					formatted_forms = props.join_spans {
						slot = slot,
						formval_spans = formval_spans,
						tr_spans = tr_spans,
					}
				end
				if not formatted_forms then
					local formval_span = table.concat(formval_spans, ", ")
					local tr_span
					if #tr_spans > 0 then
						tr_span = table.concat(tr_spans, ", ")
					end
					if tr_span then
						formatted_forms = formval_span .. "<br />" .. tr_span
					else
						formatted_forms = formval_span
					end
				end
			end
			formtable[slot] = formatted_forms
		else
			formtable[slot] = "—"
		end
	end

	iterate_slot_list_or_table(props, do_slot)

	local all_notes = footnote_obj.notes
	if props.footnotes then
		for _, note in ipairs(props.footnotes) do
			track("old-style-footnote-symbol")
			local symbol, entry = require(table_tools_module).get_initial_notes(note)
			table.insert(all_notes, symbol .. entry)
		end
	end
	formtable.footnote = table.concat(all_notes, "<br />")
end


--[==[
Given a list of forms (each of which is a table of the form
`{form=``form``, translit=``manual_translit``, footnotes=``footnotes``}`), concatenate into a
`"``slot``=``form``//``translit``,``form``//``translit``,..."` string (or `"``slot``=``form``,``form``,..."` if no translit),
replacing embedded `|` signs with `<!>`.

'''NOTE:''' This function is deprecated. Use an argument {{para|json|1}} to return a JSON encoding of the
alternant multiword spec (including any forms) instead.
]==]
function export.concat_forms_in_slot(forms)
	if forms then
		local new_vals = {}
		for _, v in ipairs(forms) do
			local form = v.form
			if v.translit then
				form = form .. "//" .. v.translit
			end
			table.insert(new_vals, rsub(form, "|", "<!>"))
		end
		return table.concat(new_vals, ",")
	else
		return nil
	end
end


return export
