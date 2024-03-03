local labels = {}


--------------------------------- Nouns/Pronouns/Numerals --------------------------------

labels["irregularly declined borrowed nouns"] = {
	description = "{{{langname}}} loanwords with irregular declension.",
	breadcrumb = "borrowed nouns",
	parents = {{name = "irregular nouns", sort = "borrowed nouns"}},
}

labels["n-stem nouns"] = {
	description = "{{{langname}}} ''n''-stem nouns, deriving from Proto-Indo-European ''n''-stem nouns.",
	displaytitle = "{{{langname}}} ''n''-stem nouns",
	additional = "This is not a single class in Gothic, but several related gender-differentiated classes.",
	breadcrumb = "''n''-stem",
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
  be italicized. Prefix with an ! to replace the entire text with the specified text; otherwise the ending will be
  prefixed with "end in the nominative singular in ".
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
		addl = "These nouns derive from Proto-Celtic masculine {{m|cel-pro|-os}} (masculine) and {{m|cel-pro|-om}} (neuter) endings.",
	},
	["GENDER <io>-stem"] = {
		gender = "masculine or neuter",
		possible_genders = {"masculine", "neuter"},
		nom_sg = "<-e>, or <-ae> after a non-palatalized stem; when masculine, with ASPIRATION of the following word; when neuter, with NASALIZATION of the following word",
		masculine_nom_sg = "<-e> (<-ae> after a non-palatalized stem), with ASPIRATION of the following word",
		neuter_nom_sg = "<-e> (<-ae> after a non-palatalized stem), with NASALIZATION of the following word",
		gen_sg = "<-i> (<-ai> after a non-palatalized stem), with LENITION of the following word",
		nom_pl = "when masculine, same as the genitive singular; when neuter, <-e> (<-ae> after a non-palatalized stem), with LENITION of the following word",
		masculine_nom_pl = "same as the genitive singular",
		neuter_nom_pl = "<-e> (<-ae> after a non-palatalized stem), with LENITION of the following word",
		addl = "These nouns derive from Proto-Celtic masculine {{m|cel-pro|-ios}} (masculine) and {{m|cel-pro|-iom}} (neuter) endings. Originally the endings were the same as that of the <o>-stems, but later sound changes caused the two classes to diverge significantly.",
	},
	["<ā>-stem"] = {
		gender = "feminine",
		nom_sg = "the bare stem with LENITION of the following word",
		gen_sg = "<-e> with PALATALIZATION of the last stem consonant and ASPIRATION of the following word",
		nom_pl = "<-a> with ASPIRATION of the following word",
		addl = "Sometimes the nominative singular ended in a palatalized consonant by analogy with the dative singular.",
	},
	["<iā>-stem"] = {
		gender = "feminine",
		nom_sg = "<-e> (<-ae> after a non-palatalized stem), with LENITION of the following word",
		gen_sg = "<-e> (<-ae> after a non-palatalized stem), with ASPIRATION of the following word",
		nom_pl = "<-i> (<-ai> after a non-palatalized stem), with ASPIRATION of the following word",
		addl = "These nouns derive from {{m+|cel-pro|-iā}} endings. Originally the endings were the same as that of the <ā>-stems, but later sound changes caused the two classes to diverge significantly.",
	},
	["<ī>-stem"] = {
		gender = "feminine",
		nom_sg = "the bare stem (always ending in a palatalized consonant), with LENITION of the following word",
		gen_sg = "<-e> (or often <-ae>, with DEPALATALIZATION of the final stem consonant), with ASPIRATION of the following word",
		nom_pl = "<-i> (or often <-ai>, with DEPALATALIZATION of the final stem consonant), with ASPIRATION of the following word",
		addl = "These nouns derive from the Proto-Indo-European so-called ''devī'' or ''ī/yā'' inflection (see " ..
		"[[Reconstruction:Proto-Indo-European/déywih₂]]). Forms with overt endings often delete the final vowel of " ..
		"the stem, e.g. {{m|sga|rígain}} becomes genitive singular {{m|sga|rígnae}}. There were two subvariants, an " ..
		"older \"long\" one with overt endings in the accusative and sometimes dative singular, and a newer " ..
		"\"short\" one only palatalization, by analogy with the <ā>-stems.",
		parent = "<iā>-stem",
	},
	["GENDER <i>-stem"] = {
		gender = "masculine, feminine or neuter",
		possible_genders = {"masculine or feminine", "neuter"},
		nom_sg = "the bare stem (always ending in a palatalized consonant), with LENITION of the following word when feminine, NASALIZATION when neuter",
		["masculine or feminine_nom_sg"] = "the bare stem (always ending in a palatalized consonant), with LENITION of the following word when feminine",
		neuter_nom_sg = "the bare stem (always ending in a palatalized consonant), with NASALIZATION of the following word",
		gen_sg = "<-o> or <-a> (sometimes with LOWERING or other modification of the stem vowel), with DEPALATALIZATION of the final stem consonant and ASPIRATION of the following word",
		nom_pl = "when masculine or feminine, <-i> (or often <-ai>, with DEPALATALIZATION of the final stem consonant), with ASPIRATION of the following word; when neuter, <-e>, with LENITION of the following word",
		["masculine or feminine_nom_pl"] = "<-i> (or often <-ai>, with DEPALATALIZATION of the final stem consonant), with ASPIRATION of the following word",
		neuter_nom_pl = "<-e>, with LENITION of the following word",
	},
	["GENDER <u>-stem"] = {
		gender = "masculine or neuter",
		possible_genders = {"masculine", "neuter"},
		nom_sg = "the bare stem (always ending in a non-palatalized consonant), with NASALIZATION of the following word when neuter",
		masculine_nom_sg = "the bare stem (always ending in a non-palatalized consonant)",
		neuter_nom_sg = "the bare stem (always ending in a non-palatalized consonant), with NASALIZATION of the following word",
		gen_sg = "<-o> or <-a> (with LOWERING of the stem vowel where possible), with ASPIRATION of the following word and sometimes with PALATALIZATION of the final stem consonant",
		nom_pl = "when masculine, in <-ae>, <-ai> or <-a> (with LOWERING of the stem vowel where possible), with ASPIRATION of the following word and sometimes with PALATALIZATION of the final stem consonant; when neuter, either (a) the bare stem with LENITION of the following word; or (b) in <-a> (used especially with an indefinite meaning), with LOWERING of the stem vowel where possible and sometimes with PALATALIZATION of the final stem consonant",
		masculine_nom_pl = "in <-ae>, <-ai> or <-a> (with LOWERING of the stem vowel where possible), with ASPIRATION of the following word and sometimes with PALATALIZATION of the final stem consonant",
		neuter_nom_pl = "either (a) the bare stem with LENITION of the following word; or (b) in <-a> (used especially with an indefinite meaning), with LOWERING of the stem vowel where possible and sometimes with PALATALIZATION of the final stem consonant",
	},
	["GENDER <an>-stem"] = {
		gender = "masculine or neuter",
		possible_genders = {"masculine", "neuter"},
		nom_sg = "<-a> when masculine, <-ō> when neuter",
		masculine_nom_sg = "<-a>",
		neuter_nom_sg = "<-ō>",
		gen_sg = "<-ins>",
		nom_pl = "<-ans> when masculine, <-ōna> when neuter",
		masculine_nom_pl = "<-ans>",
		neuter_nom_pl = "<-ōna>",
		parent = "n-stem",
	},
	["<īn>-stem"] = {
		gender = "feminine",
		nom_sg = "<-ei>",
		gen_sg = "<-eins>",
		nom_pl = "<-eins>",
		parent = "n-stem",
	},
	["<ōn>-stem"] = {
		gender = "feminine",
		nom_sg = "<-ō>",
		gen_sg = "<-ōns>",
		nom_pl = "<-ōns>",
		parent = "n-stem",
	},
	["<nd>-stem"] = {
		gender = "masculine",
		nom_sg = "<-nds>",
		gen_sg = "<-ndis>",
		nom_pl = "<-nds>",
	},
	["GENDER <u>-stem"] = {
		gender = "masculine/feminine or neuter",
		possible_genders = {"masculine/feminine", "neuter"},
		nom_sg = "<-us> when masculine or feminine, <-u> when neuter",
		["masculine/feminine_nom_sg"] = "<-us>",
		neuter_nom_sg = "<-u>",
		gen_sg = "<-aus>",
		nom_pl = "<-jus> when masculine or feminine and are unattested in the plural when neuter",
		["masculine/feminine_nom_pl"] = "<-jus>",
		neuter_nom_pl = "!are unattested in the plural",
	},
	["consonant stem"] = {
		gender = "masculine or feminine",
		nom_sg = "<-s>",
		gen_sg = "<-s>",
		nom_pl = "<-s>",
	},
	["<r>-stem"] = {
		gender = "masculine or feminine",
		nom_sg = "<-ar>",
		gen_sg = "<-rs>",
		nom_pl = "<-rjus>",
	},
	["<i>/<ō>-stem"] = {
		gender = "feminine",
		nom_sg = "<-eins>",
		gen_sg = "<-einais>",
		nom_pl = "<-einōs>",
		parent = {"feminine i-stem", "ō-stem"},
	},
}

for _, pos in ipairs({"nouns"}) do
	local sgpos = pos:gsub("s$", "")
	local function mark_spec_with_literal_text(ending_spec)
		return ending_spec:gsub("<(.-)>", "''%1''")
	end
	local function make_spec_bare(ending_spec)
		return ending_spec:gsub("<(.-)>", "%1")
	end
	local function process_ending(ending_spec, slot)
		local no_prefix, bare_ending = ending_spec:match("^(!?)(.*)$")
		if no_prefix == "!" then
			pretext = ""
		else
			pretext = ("end in the %s in "):format(slot)
		end
		return pretext .. mark_spec_with_literal_text(bare_ending)
	end
	for full_decl, spec in pairs(noun_decls) do
		local most_commonly, gender = spec.gender:match("^(~)(.*)$")
		gender = gender or spec.gender
		local subgenders = spec.possible_genders
		local decl
		if subgenders then
			if not full_decl:find("GENDER") then
				error(("Internal error: Declension spec '%s' needs to have the word 'GENDER' in it, in all caps"):format(full_decl))
			end
			decl = full_decl:gsub("GENDER ", "")
		else
			decl = full_decl
		end
		local breadcrumb = spec.breadcrumb or spec.sortkey or "+"
		if breadcrumb == "+" then
			breadcrumb = decl
		end
		local marked_up_desc = "{{{langname}}} " .. mark_spec_with_literal_text(decl) .. " " .. pos
		local parents = {}
		local spec_parents = spec.parent
		if type(spec_parents) == "string" then
			spec_parents = {spec_parents}
		end
		local parent_sort = make_spec_bare(spec.sortkey or decl)
		if spec_parents then
			for _, parent in ipairs(spec_parents) do
				table.insert(parents, {name = parent .. " " .. pos, sort = parent_sort})
			end
		else
			table.insert(parents, {name = pos .. " by inflection type", sort = parent_sort})
		end
		labels[make_spec_bare(decl) .. " " .. pos] = {
			description = marked_up_desc .. ".",
			displaytitle = marked_up_desc,
			additional = ("These %s normally %s; %s; %s; and are %s%s."):format(pos,
				process_ending(spec.nom_sg, "nominative singular"),
				process_ending(spec.gen_sg, "genitive singular"),
				process_ending(spec.nom_pl, "nominative plural"),
				most_commonly and "most commonly " or "", mark_spec_with_literal_text(gender)),
			breadcrumb = mark_spec_with_literal_text(breadcrumb),
			parents = parents,
		}
		if subgenders then
			for _, subgender in ipairs(subgenders) do
				local gender_decl = full_decl:gsub("GENDER", subgender)
				local marked_up_gender_desc = "{{{langname}}} " .. mark_spec_with_literal_text(gender_decl) .. " " ..
					pos
				labels[make_spec_bare(gender_decl) .. " " .. pos] = {
					description = marked_up_gender_desc .. ".",
					displaytitle = marked_up_gender_desc,
					additional = ("These %s normally %s; %s; %s; and are %s."):format(pos,
						process_ending(spec[subgender .. "_nom_sg"] or spec.nom_sg, "nominative singular"),
						process_ending(spec[subgender .. "_gen_sg"] or spec.gen_sg, "genitive singular"),
						process_ending(spec[subgender .. "_nom_pl"] or spec.gen_sg, "nominative plural"),
						subgender),
					breadcrumb = subgender,
					parents = {{
						name = make_spec_bare(decl) .. " " .. pos,
						sort = subgender,
					}},
				}
			end
		end
	end
end


return {LABELS = labels}
