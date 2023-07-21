--[=[
This module contains lang-specific functions for English.
]=]

local table_module = "Module:table"

local rfind = mw.ustring.find
local rmatch = mw.ustring.match

----------------------- Category functions -----------------------

--[=[
The key `cat` must be specified and is the name of the category following the language name. Suffixes enclosed in
double angle brackets, e.g. <<-ata>>, are italicized (as if written e.g. {{m|en||-ata}}) in the displayed title, but
not in the category name itself. The description of the category comes from the `description` field; if omitted, it is
constructed from the category by adding "English irregular" to the beginning and appending the value of `desc_suffix`
(if given) to the end. Suffixes enclosed in double angle brackets are italicized, as described above, and template
calls are permitted.

The key `matches_plural` must be specified and is either a string or a function. If a string, the string is a Lua
pattern that should match the end of the pagename, and the remainder becomes the stem passed to `matches_lemma` (see
below). If a function, it should accept two arguments, the pagename and the lemma (or more precisely, the words in the
pagename and lemma that differ, if there are multiple words), and should return the stem of the pagename (minus the
ending) if the pagename matches the ending, otherwise nil.

The key `matches_lemma` must be specified and is either a string or a function. If a string, the string is a Lua
pattern that should match the lemma. If a function, it should accept three arguments, the pagename and lemma as in
`matches_plural`, and the stem returned by `matches_plural` or extracted from the pagename and ending. It should return
a boolean indicating whether the lemma matches.

The key `additional`, if given, is additional text to include in the category description as displayed on the page
itself, but not in the summary of the category as displayed on other pages. For further information, see the
`additional` field in [[Module:category tree/poscatboiler/data/documentation]].

The key `breadcrumb`, if given, is the breadcrumb text. See [[Module:category tree/poscatboiler/data/documentation]].
If omitted, the breadcrumb is constructed from the category name by remvoing "plurals in" from the beginning of the
category name.

If a plural doesn't match any of the entries, it goes into [[:Category:English miscellaneous irregular plurals]]. Note
that before checking these entries, plurals that are the same as the singular are excluded (i.e. not considered
irregular), as are plurals formed from the singular by adding [[-s]], [[-es]], [[-'s]] or [[-ses]] (if the singular ends
in '-s'; cf. [[bus]] -> 'busses', [[dis]] -> 'disses'), or by replacing final [[-y]] with [[-ies]].
]=]
local irregular_plurals = {
	{
		cat = "plurals in <<-ata>> with singular in <<-a>>",
		desc_suffix = ", mostly originating from Greek neuter nouns in {{m|grc|-μᾰ}}",
		matches_plural = "ata$",
		matches_lemma = function(pagename, lemma, stem)
			return lemma == stem .. "a"
		end,
	},
	{
		cat = "plurals in <<-ina>> with singular in <<-en>>",
		desc_suffix = ", mostly originating from Latin neuter nouns",
		additional = "Plurals formed by replacing a final <<-inum>> or <<-inon>> with a final <<-ina>> are found in [[:Category:English plurals in -a with singular in -um or -on]].",
		matches_plural = "ina$",
		matches_lemma = "en$",
	},
	{
		cat = "plurals in <<-ra>> with singular in <<-s>>",
		desc_suffix = ", mostly originating from Latin neuter nouns",
		additional = "Sometimes the preceding vowel changes; e.g. <<-us>> commonly changes to <<-era>> or <<-ora>> in the plural. Plurals formed by replacing a final <<-rum>> or <<-ron>> with a final <<-ra>> are found in [[:Category:English plurals in -a with singular in -um or -on]].",
		matches_plural = "ra$",
		matches_lemma = function(pagename, lemma, stem)
			return lemma:find("s$")
		end,
	},	
	{
		cat = "plurals in <<-a>> with singular in <<-um>> or <<-on>>",
		desc_suffix = ", mostly originating from Latin or Greek neuter nouns",
		additional = "Plurals formed by replacing a final <<-a>> with a final <<-ata>> are found in [[:Category:English plurals in -ata with singular in -a]].",
		matches_plural = "a$",
		matches_lemma = function(pagename, lemma, stem)
			return lemma:find("um$") or lemma:find("on$")
		end,
	},
	{
		cat = "plurals in <<-ae>> with singular in <<-a>>",
		desc_suffix = ", mostly originating from Latin feminine nouns",
		additional = "The <<-ae>> can also be written as a ligature <<-æ>>.",
		matches_plural = function(pagename, lemma)
			return pagename:match("^(.*)ae$") or pagename:match("^(.*)æ$")
		end,
		matches_lemma = function(pagename, lemma, stem)
			return lemma == stem .. "a"
		end,
	},
	{
		cat = "plurals in <<-e>> with singular in <<-a>>",
		desc_suffix = ", mostly originating from Italian feminine nouns",
		additional = "This category does not contain English invariant plurals ending in an <<-e>>, such as {{m|en|moose}} or {{m|en|Japanese}}, for which no letters are changed.",
		matches_plural = "e$",
		matches_lemma = function(pagename, lemma, stem)
			return lemma == stem .. "a"
		end,
	},
	{
		cat = "plurals in <<-oi>> with singular in <<-os>>",
		desc_suffix = ", mostly originating from Greek masculine nouns",
		matches_plural = "oi$",
		matches_lemma = function(pagename, lemma, stem)
			return lemma == stem .. "os"
		end,
	},
	{
		cat = "plurals in <<-i>> with singular in <<-us>>, <<-os>> or <<-o>>",
		desc_suffix = ", mostly originating from Latin or Italian masculine nouns",
		additional = "Note that not all of these plurals are considered correct by all speakers.",
		matches_plural = "i$",
		matches_lemma = function(pagename, lemma, stem)
			-- don't check just for stem matching because of cases like virus -> virii that we want included.
			return lemma:find("us$") or lemma:find("os$") or lemma:find("o$")
		end,
	},
	{ -- siphon off most of the "umlaut" plurals that will otherwise end up in 'English miscellaneous irregular plurals'
		cat = "plurals in <<-men>> with singular in <<-man>>",
		desc_suffix = " (and likewise plurals in <<-women>> with singular in <<-woman>>)",
		matches_plural = "men$",
		matches_lemma = "man$",
	},
	{
		cat = "plurals in <<-en>>",
		additional = "Plurals formed by replacing a final <<-man>> with <<-men>> are found in [[:Category:English plurals in -men with singular in -man]].",
		matches_plural = "en$",
		matches_lemma = function(pagename, lemma, stem)
			return not lemma:find("en$")
		end,
	},
	{
		cat = "plurals in <<-x>>",
		desc_suffix = ", mostly originating from French masculine nouns",
		additional = "Generally these are formed by adding <<-x>> to a noun ending in <<-u>>; changing final <<-al>> or <<-ail>> to <<-aux>>; or changing final <<-el>> to <<-eaux>>.",
		matches_plural = "x$",
		matches_lemma = "[lu]$",
	},
	{
		cat = "plurals in <<-ces>> with singular in <<-x>>",
		desc_suffix = ", mostly originating from Latin masculine or feminine nouns",
		additional = "Generally these are formed by changing a final <<-x>> into <<-ces>> or a final <<-ex>> into <<-ices>>.",
		matches_plural = "ces$",
		matches_lemma = "x$",
	},
	{
		cat = "plurals in <<-des>> with singular in <<-s>>",
		desc_suffix = ", mostly originating from Latin or Greek masculine or feminine nouns",
		matches_plural = "des$",
		matches_lemma = "s$",
	},
	{
		cat = "plurals in <<-ges>> with singular in <<-x>>",
		desc_suffix = ", mostly originating from Greek masculine or feminine nouns",
		matches_plural = "ges$",
		matches_lemma = "x$",
	},
	{
		cat = "plurals in <<-ves>> with singular in <<-f>> or <<-fe>>",
		desc_suffix = ", mostly originating from native English formations",
		matches_plural = "ves$",
		matches_lemma = "fe?$",
	},
	{
		cat = "plurals in <<-ores>> with singular in <<-or>>",
		desc_suffix = ", mostly originating from Latin masculine nouns",
		matches_plural = "ores$",
		matches_lemma = function(pagename, lemma, stem)
			return lemma == stem .. "or"
		end,
	},
	{
		cat = "plurals in <<-es>> with singular in <<-is>>",
		desc_suffix = ", mostly originating from Greek feminine nouns, or analogous formations",
		matches_plural = "es$",
		matches_lemma = function(pagename, lemma, stem)
			return lemma == stem .. "is"
		end,
	},
}


-- Find the single word that differs between `pagename` and `lemma`, assuming there are the same number of words in
-- both and the spaces and hyphens match. If there is a single word difference, return two values, the pagename word
-- and the lemma word. Otherwise return nil.
local function extract_non_matching_word(pagename, lemma)
	if not pagename:find("[ -]") and not lemma:find("[ -]") then
		return pagename, lemma
	end
	m_strutil = require("Module:string utilities")
	local pagename_words = m_strutil.capturing_split(pagename, "([ -])")
	local lemma_words = m_strutil.capturing_split(lemma, "([ -])")
	-- Make sure same number of words.
	if #pagename_words ~= #lemma_words then
		return nil
	end
	-- Make sure all the spaces and hyphens match.
	for i = 2, #pagename_words - 1, 2 do
		if pagename_words[i] ~= lemma_words[i] then
			return nil
		end
	end
	-- From the left, find first non-matching word.
	local non_matching_i, non_matching_j
	for i = 1, #pagename_words, 2 do
		if pagename_words[i] ~= lemma_words[i] then
			non_matching_i = i
			break
		end
	end
	-- From the right, find first non-matching word.
	for j = #pagename_words, 1, -2 do
		if pagename_words[j] ~= lemma_words[j] then
			non_matching_j = j
			break
		end
	end

	-- If pointers are the same, there's a single non-matching word.
	if non_matching_i == non_matching_j then
		return pagename_words[non_matching_i], lemma_words[non_matching_i]
	else
		return nil
	end
end


local function irregular_plural_categories(data)
	if not data.pagename or not data.lemmas then
		return nil
	end
	local categories = nil
	local function add_category(cat)
		if categories == nil then
			categories = cat
		elseif categories == cat then
			return
		else
			if type(categories) == "string" then
				categories = {"multi", categories}
			end
			require(table_module).insertIfNot(categories, cat)
		end
	end
	for _, lemma_obj in ipairs(data.lemmas) do
		if lemma_obj.term then
			local lemma = lemma_obj.term:gsub("#.*", "") -- trim #Noun and similar
			if lemma == data.pagename then
				-- no category
			else
				local pagename_word, lemma_word = extract_non_matching_word(data.pagename, lemma)
				if pagename_word == nil then
					-- more than one word differs between singular and plural, or different numbers of words in
					-- singular vs. plural, or spaces/hyphens differ
					add_category("miscellaneous irregular plurals")
				elseif pagename_word == lemma_word .. "s" or pagename_word == lemma_word .. "es" or
					pagename_word == lemma_word .. "'s" or
					lemma_word:find("y$") and pagename_word == (lemma_word:gsub("y$", "ies")) or
					lemma_word:find("s$") and pagename_word == lemma_word .. "ses" then
					-- regular plural, do nothing
				else
					local matches_lemma
					for _, irreg_plural in ipairs(irregular_plurals) do
						local stem
						if type(irreg_plural.matches_plural) == "string" then
							stem = rmatch(pagename_word, "^(.*)" .. irreg_plural.matches_plural)
						else
							stem = irreg_plural.matches_plural(pagename_word, lemma_word)
						end
						if stem then
							if type(irreg_plural.matches_lemma) == "string" then
								matches_lemma = rfind(lemma_word, irreg_plural.matches_lemma)
							else
								matches_lemma = irreg_plural.matches_lemma(pagename_word, lemma_word, stem)
							end
							if matches_lemma then
								local cat = irreg_plural.cat:gsub("<<(.-)>>", "%1") -- discard second retval
								add_category(cat)
								break
							end
						end
					end
					if not matches_lemma then
						add_category("miscellaneous irregular plurals")
					end
				end
			end
		end
	end

	return categories
end

local cat_functions = {
	-- This function is invoked for plurals by an entry in [[Module:form of/cats]].
	["en-irregular-plural-categories"] = irregular_plural_categories,
}

-- We need to return the irreg_plurals structure so that the category handler in
-- [[Module:category tree/poscatboiler/data/lang-specific/en]] can access it.
return {cat_functions = cat_functions, irreg_plurals = irreg_plurals}
