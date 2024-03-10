local labels = {}


--------------------------------- Nouns/Pronouns/Numerals --------------------------------

labels["consonant-stem nouns"] = {
	description = "{{{langname}}} consonant-stem nouns, deriving from Proto-Indo-European consonant-stem nouns.",
	additional = "This is not a single class in Old Irish, but several related classes, differentiated by the final stem consonant.",
	breadcrumb = "consonant-stem",
	parents = {"nouns by inflection type"},
}

--[=[
Noun declension specifications. The top-level key is the stem class, and the value is an object containing properties of
the stem class. If the stem class contains the word 'GENDER' in it, it expands into labels both for a parent category
that subsumes several genders (obtained by removing the word 'GENDER' and following whitespace) as well as
gender-specific children categories (obtained by replacing the word 'GENDER' with the genders specified in the
`possible_genders` field). The stem class can contain literal Latin-script text (e.g. suffixes), which will be
italicized in breadcrumbs and titles. The fields of the property object for a given stem class are as follows:
* `gender`: The description of the gender(s) of the stem class. If preceded by ~, the description is preceded by
  "most commonly". This appears in the `additional` field of the label properties. It is not used in gender-specific
  children categories; instead the gender of that category is used.
* `possible_genders`: The possible genders this class occurs in. If this is specified, the word 'GENDER' must occur in
  the stem class, and gender-specific variants of the stem class (with GENDER replaced by the possible genders) are
  handled along with a parent category subsuming all genders. 
* `nom_sg`: The nominative singular ending. Use <...> to enclose literal Latin-script text (e.g. suffixes), which will
  be italicized. Certian all-caps terms such as ASPIRATION and UNPALATALIZED will be linked to the appropriate section
  of the Wikipedia entry on Old Irish grammar; see below.
* `GENDER_nom_sg`: The nominative singular ending for the GENDER variant of this stem class. If not specified, the
  value of `nom_sg` is used.
* `gen_sg`: The genitive singular ending. Conventions are the same as for `nom_sg`.
* `GENDER_gen_sg`: The genitive singular ending for the GENDER variant of this stem class. If not specified, the value
  of `gen_sg` is used.
* `nom_pl`: The nominative plural ending. Conventions are the same as for `nom_sg`.
* `GENDER_nom_pl`: The nominative plural ending for the GENDER variant of this stem class. If not specified, the value
  of `nom_pl` is used.
* `breadcrumb`: The breadcrumb for the category, appearing in the trail of breadcrumbs at the top of the page. If this
  stem has gender-specific variants, the breadcrumb specified here is used only for the parent category, while the
  gender-specific child categories use the gender as the breadcrumb. If not specified, it defaults to `sortkey`. If that
  is also not specified, or if the breadcrumb has the value "+", the stem class (without the word 'GENDER') is used.
  (Use "+" when a sortkey is specified but the stem class should be used as the breadcrumb.)
* `parent`: The parent category or categories. If specified, the actual category label is formed by appending the part
  of speech (e.g. "nouns"). Defaults to "POS by inflection type" where POS is the part of speech. Note that
  gender-specific child categories do not use this, but always have the gender-subsuming parent stem class category as
  their parent.
* `sortkey`: The sort key used for sorting this category among its parent's children. Defaults to the stem class
  (without the word 'GENDER'). Note that gender-specific child categories do not use this, but always use the gender
  as the sort key.
]=]
local noun_decls = {
	["GENDER <o>-stem"] = {
		gender = "masculine or neuter",
		possible_genders = {"masculine", "neuter"},
		nom_sg = "the bare stem; when neuter, additionally with NASALIZATION of the following word",
		masculine_nom_sg = "the bare stem",
		neuter_nom_sg = "the bare stem with NASALIZATION of the following word",
		gen_sg = "the bare stem with RAISING of the stem vowel where possible, PALATALIZATION of the last stem consonant and LENITION of the following word",
		nom_pl = "when masculine, same as the genitive singular; when neuter, the bare stem with LENITION of the following word and optionally an <-a> ending (used especially with an indefinite meaning)",
		masculine_nom_pl = "same as the genitive singular",
		neuter_nom_pl = "the bare stem with LENITION of the following word and optionally an <-a> ending (used especially with an indefinite meaning)",
		addl = "These nouns derive from Proto-Celtic masculine {{m|cel-pro|*-os}} (masculine) and {{m|cel-pro|*-om}} " ..
		"(neuter) endings.",
	},
	["GENDER <io>-stem"] = {
		gender = "masculine or neuter",
		possible_genders = {"masculine", "neuter"},
		nom_sg = "<-e>, or <-ae> after an UNPALATALIZED stem; when masculine, with ASPIRATION of the following word; when neuter, with NASALIZATION of the following word",
		masculine_nom_sg = "<-e> (<-ae> after an UNPALATALIZED stem), with ASPIRATION of the following word",
		neuter_nom_sg = "<-e> (<-ae> after an UNPALATALIZED stem), with NASALIZATION of the following word",
		gen_sg = "<-i> (<-ai> after an UNPALATALIZED stem), with LENITION of the following word",
		nom_pl = "when masculine, same as the genitive singular; when neuter, <-e> (<-ae> after an UNPALATALIZED stem), with LENITION of the following word",
		masculine_nom_pl = "same as the genitive singular",
		neuter_nom_pl = "<-e> (<-ae> after an UNPALATALIZED stem), with LENITION of the following word",
		addl = "These nouns derive from Proto-Celtic masculine {{m|cel-pro|*-ios}} (masculine) and " ..
		"{{m|cel-pro|*-iom}} (neuter) endings. Originally the endings were the same as that of the <o>-stems, but " ..
		"later sound changes caused the two classes to diverge significantly.",
	},
	["<ā>-stem"] = {
		gender = "feminine",
		nom_sg = "the bare stem with LENITION of the following word",
		gen_sg = "<-e> with PALATALIZATION of the last stem consonant and ASPIRATION of the following word",
		nom_pl = "<-a> with ASPIRATION of the following word",
		addl = "Sometimes the nominative singular ended in a PALATALIZED consonant by analogy with the dative singular.",
	},
	["<iā>-stem"] = {
		gender = "feminine",
		nom_sg = "<-e> (<-ae> after an UNPALATALIZED stem), with LENITION of the following word",
		gen_sg = "<-e> (<-ae> after an UNPALATALIZED stem), with ASPIRATION of the following word",
		nom_pl = "<-i> (<-ai> after an UNPALATALIZED stem), with ASPIRATION of the following word",
		addl = "These nouns derive from {{m+|cel-pro|*-iā}} endings. Originally the endings were the same as that of " ..
		"the <ā>-stems, but later sound changes caused the two classes to diverge significantly.",
	},
	["<ī>-stem"] = {
		gender = "feminine",
		nom_sg = "the bare stem (always ending in a PALATALIZED consonant), with LENITION of the following word",
		gen_sg = "<-e> (or often <-ae>, with DEPALATALIZATION of the final stem consonant), with ASPIRATION of the following word",
		nom_pl = "<-i> (or often <-ai>, with DEPALATALIZATION of the final stem consonant), with ASPIRATION of the following word",
		addl = "These nouns derive from the Proto-Indo-European so-called ''devī'' or ''ī/yā'' inflection (see " ..
		"[[Reconstruction:Proto-Indo-European/déywih₂]]). Forms with overt endings often delete the final vowel of " ..
		"the stem, e.g. {{m|sga|rígain}} becomes genitive singular {{m|sga|rígnae}}. There were two subvariants, an " ..
		"older \"long\" one with overt endings in the accusative and sometimes dative singular, and a newer " ..
		"\"short\" one with only PALATALIZATION, by analogy with the <ā>-stems.",
		parent = "<iā>-stem",
	},
	["GENDER <i>-stem"] = {
		gender = "masculine, feminine or neuter",
		possible_genders = {"masculine or feminine", "neuter", "unknown gender"},
		nom_sg = "the bare stem (always ending in a PALATALIZED consonant), with LENITION of the following word when feminine, NASALIZATION when neuter",
		["masculine or feminine_nom_sg"] = "the bare stem (always ending in a PALATALIZED consonant), with LENITION of the following word when feminine",
		neuter_nom_sg = "the bare stem (always ending in a PALATALIZED consonant), with NASALIZATION of the following word",
		gen_sg = "<-o> or <-a> (sometimes with LOWERING or other modification of the stem vowel), with DEPALATALIZATION of the final stem consonant and ASPIRATION of the following word",
		nom_pl = "when masculine or feminine, <-i> (or often <-ai>, with DEPALATALIZATION of the final stem consonant), with ASPIRATION of the following word; when neuter, <-e>, with LENITION of the following word",
		["masculine or feminine_nom_pl"] = "<-i> (or often <-ai>, with DEPALATALIZATION of the final stem consonant), with ASPIRATION of the following word",
		neuter_nom_pl = "<-e>, with LENITION of the following word",
	},
	["GENDER <u>-stem"] = {
		gender = "masculine or neuter",
		possible_genders = {"masculine", "neuter"},
		nom_sg = "the bare stem (always ending in an UNPALATALIZED consonant), with NASALIZATION of the following word when neuter",
		masculine_nom_sg = "the bare stem (always ending in an UNPALATALIZED consonant)",
		neuter_nom_sg = "the bare stem (always ending in an UNPALATALIZED consonant), with NASALIZATION of the following word",
		gen_sg = "<-o> or <-a> (with LOWERING of the stem vowel where possible), with ASPIRATION of the following word and sometimes with PALATALIZATION of the final stem consonant",
		nom_pl = "when masculine, <-ae>, <-ai> or <-a> (with LOWERING of the stem vowel where possible), with ASPIRATION of the following word and sometimes with PALATALIZATION of the final stem consonant; when neuter, either (a) the bare stem with LENITION of the following word; or (b) <-a> (used especially with an indefinite meaning), with LOWERING of the stem vowel where possible and sometimes with PALATALIZATION of the final stem consonant",
		masculine_nom_pl = "<-ae>, <-ai> or <-a> (with LOWERING of the stem vowel where possible), with ASPIRATION of the following word and sometimes with PALATALIZATION of the final stem consonant",
		neuter_nom_pl = "either (a) the bare stem with LENITION of the following word; or (b) <-a> (used especially with an indefinite meaning), with LOWERING of the stem vowel where possible and sometimes with PALATALIZATION of the final stem consonant",
	},
	["<g>-stem"] = {
		gender = "masculine or feminine",
		nom_sg = "the bare stem without final ''g'' and preceding unstressed vowel, with ASPIRATION of the following word if ending in a vowel",
		gen_sg = "the bare stem with UNPALATALIZED ''g'' or ''ch'' and LOWERING of the stem vowel where possible",
		nom_pl = "the bare stem with PALATALIZED ''g''",
		parent = "consonant-stem",
	},
	["<k>-stem"] = {
		gender = "masculine or feminine",
		nom_sg = "the bare stem without final ''c'' and preceding unstressed vowel, with ASPIRATION of the following word if ending in a vowel",
		gen_sg = "the bare stem with UNPALATALIZED ''c'' or ''ch'' and LOWERING of the stem vowel where possible",
		nom_pl = "the bare stem with PALATALIZED ''c'' (''g'' when soft)",
		parent = "consonant-stem",
	},
	["<d>-stem"] = {
		gender = "masculine or feminine",
		nom_sg = "the bare stem without final ''d'' and preceding unstressed vowel, with ASPIRATION of the following word if ending in a vowel",
		gen_sg = "the bare stem with UNPALATALIZED ''d'' or ''th'' and LOWERING of the stem vowel where possible",
		nom_pl = "the bare stem with PALATALIZED ''d'' or ''th''",
		parent = "consonant-stem",
	},
	["<t>-stem"] = {
		gender = "masculine or feminine",
		nom_sg = "the bare stem without final ''t'' and preceding unstressed vowel, with ASPIRATION of the following word if ending in a vowel",
		gen_sg = "the bare stem with UNPALATALIZED ''t'' (''d'' or ''th'' when soft) and LOWERING of the stem vowel where possible",
		nom_pl = "the bare stem with PALATALIZED ''t'' (''d'' or ''th'' when soft)",
		parent = "consonant-stem",
	},
	["GENDER <nt>-stem"] = {
		gender = "masculine or feminine (occasionally neuter)",
		possible_genders = {"masculine or feminine", "neuter"},
		nom_sg = "when masculine or feminine, the bare stem without final ''t'', with ASPIRATION of the following word if ending in a vowel; when neuter, the bare stem including final ''t'', with NASALIZATION of the following word",
		["masculine or feminine_nom_sg"] = "the bare stem without final ''t'', with ASPIRATION of the following word if ending in a vowel",
		neuter_nom_sg = "the bare stem including final ''t'', with NASALIZATION of the following word",
		gen_sg = "the bare stem with UNPALATALIZED ''t'' and LOWERING of the stem vowel where possible",
		nom_pl = "when masculine or feminine, the bare stem with PALATALIZED ''t''; when neuter, the bare stem with UNPALATALIZED ''t'' and LENITION of the following word",
		["masculine or feminine_nom_pl"] = "the bare stem with PALATALIZED ''t''",
		neuter_nom_pl = "the bare stem with UNPALATALIZED ''t'' and LENITION of the following word",
		parent = "consonant-stem",
		addl = "In this case, sound changes leading up to Old Irish deleted the underlying ''n'' in all forms.",
	},
	["<r>-stem"] = {
		gender = "masculine or feminine",
		nom_sg = "the bare stem with PALATALIZED final ''r'' and UNPALATALIZED preceding ''th'' (except in {{m|sga|siur||sister}}, which has U-INSERTION)",
		gen_sg = "the bare stem with UNPALATALIZED final ''r''",
		nom_pl = "the bare stem with PALATALIZED final ''r'' and PALATALIZED preceding ''th''",
		parent = "consonant-stem",
	},
	["<s>-stem"] = {
		gender = "neuter",
		nom_sg = "the bare stem with NASALIZATION of the following word",
		gen_sg = "<-e>, usually with RAISING of the stem vowel where possible, along with ASPIRATION of the following word",
		nom_pl = "<-e>, usually with RAISING of the stem vowel where possible, along with LENITION of the following word",
	},
	["GENDER <n>-stem"] = {
		gender = "masculine, feminine or neuter",
		possible_genders = {"masculine or feminine", "neuter", "unknown gender"},
		nom_sg = "when masculine or feminine, either (a) the bare stem without final ''n'', or (b) <-u> or <-e> following the stem without final ''n'', along with ASPIRATION of the following word; when neuter, the bare stem (usually ending in <-(m)m>) without final ''n'', with NASALIZATION of the following word",
		["masculine or feminine_nom_sg"] = "either (a) the bare stem without final ''n'', or (b) <-u> or <-e> following the stem without final ''n'', along with ASPIRATION of the following word",
		neuter_nom_sg = "the bare stem (usually ending in <-(m)m>) without final ''n'', with NASALIZATION of the following word",
		gen_sg = "when masculine or feminine, the bare stem with UNPALATALIZED LENITED final ''n'' or UNPALATALIZED UNLENITED final ''nn''; when neuter, <-e> following the stem without final ''n'', along with ASPIRATION of the following word",
		["masculine or feminine_gen_sg"] = "the bare stem with LENITED final ''n'' or UNLENITED final ''nn''",
		neuter_gen_sg = "<-e> following the stem without final ''n'', along with ASPIRATION of the following word",
		nom_pl = "when masculine or feminine, the bare stem with PALATALIZED LENITED final ''n'' or PALATALIZED UNLENITED final ''nn''; when neuter, the bare stem with UNPALATALIZED UNLENITED final ''nn'' (or rarely UNPALATALIZED LENITED final ''n''), along with LENITION of the following word",
		["masculine or feminine_nom_pl"] = "the bare stem with PALATALIZED LENITED final ''n'' or PALATALIZED UNLENITED final ''nn''",
		neuter_nom_pl = "the bare stem with UNPALATALIZED UNLENITED final ''nn'' (or rarely UNPALATALIZED LENITED final ''n''), along with LENITION of the following word",
	},
}

require("Module:category tree/poscatboiler/utilities").add_inflection_labels {
	labels = labels,
	pos = "noun",
	stem_classes = noun_decls,
	mark_up_spec = function(spec, nolink)
		-- mutations
		spec = spec:gsub("LENITION", "{{w|Old Irish grammar#Lenition|lenition}}")
		spec = spec:gsub("UNLENITED", "{{w|Old Irish grammar#Lenition|unlenited}}")
		spec = spec:gsub("LENITED", "{{w|Old Irish grammar#Lenition|lenited}}")
		spec = spec:gsub("NASALIZATION", "{{w|Old Irish grammar#Nasalisation|nasalization}}")
		spec = spec:gsub("ASPIRATION", "{{w|Old Irish grammar#Aspiration and gemination|aspiration/gemination}}")
		-- palatalization
		spec = spec:gsub("DEPALATALIZATION", "{{w|Old Irish grammar#Palatalisation|depalatalization}}")
		spec = spec:gsub("PALATALIZATION", "{{w|Old Irish grammar#Palatalisation|palatalization}}")
		spec = spec:gsub("UNPALATALIZED", "{{w|Old Irish grammar#Palatalisation|unpalatalized}}")
		spec = spec:gsub("PALATALIZED", "{{w|Old Irish grammar#Palatalisation|palatalized}}")
		-- affection
		spec = spec:gsub("LOWERING", "{{w|Old Irish grammar#Vowel affection|lowering}}")
		spec = spec:gsub("RAISING", "{{w|Old Irish grammar#Vowel affection|raising}}")
		spec = spec:gsub("U%-INSERTION", "{{w|Old Irish grammar#Vowel affection|u-insertion}}")
		if nolink then
			spec = require("Module:links").remove_links(spec)
		end
		return (spec:gsub("<(.-)>", "''%1''"))
	end,
	principal_parts = {
		{"nom_sg", "nominative singular"},
		{"gen_sg", "genitive singular"},
		{"nom_pl", "nominative plural"},
	},
	addl = "The stem classes are named from the perspective of [[:Category:Proto-Celtic language|Proto-Celtic]] " ..
	"and may not still be visible in {{{langname}}} inflections.",
}

return {LABELS = labels}
