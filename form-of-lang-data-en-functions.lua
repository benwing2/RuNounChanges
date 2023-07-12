--[=[
This module contains lang-specific functions for English.
]=]

local table_module = "Module:table"

local rfind = mw.ustring.find
local rmatch = mw.ustring.match

----------------------- Category functions -----------------------

--[=[
In each entry, [1] is the plural ending.

The key `matches_plural`, if specified, is a function of two arguments, the pagename and the lemma (or more precisely,
the words in the pagename and lemma that differ, if there are multiple words), and should return the stem of the
pagename (minus the ending) if the pagename matches the ending, otherwise nil. If `matches_plural` is omitted, the
stem is constructed by removing the ending in [1] from the pagename.

The key `matches_lemma`, if specified, is either a string or a function. In the former case, the string is a regex
that should match the lemma. If a function, it should accept three arguments, the pagename and lemma as in
`matches_plural`, and the stem returned by `matches_plural` or extracted from the pagename and ending. It should return
a boolean indicating whether the lemma matches. If `matches_lemma` is omitted, the lemma matches if it doesn't end in
the ending in [1].

If a plural doesn't match any of the entries, it goes into [[:Category:English miscellaneous irregular plurals]]. Note
that before checking these entries, plurals that are the same as the singular are excluded (i.e. not considered
irregular), as are plurals formed from the singular by adding [[-s]], [[-es]], [[-'s]] or [[-ses]] (if the singular ends
in '-s'; cf. [[bus]] -> 'busses', [[dis]] -> 'disses'), or by replacing final [[-y]] with [[-ies]].
]=]
local irregular_plurals = {
	{"ata",
		matches_lemma = function(pagename, lemma, stem)
			return lemma == stem .. "a"
		end,
	},
	{"ina",
		matches_lemma = "en$",
	},
	{"ra",
		matches_lemma = function(pagename, lemma, stem)
			return not lemma:find("ra$") and not lemma:find("rum$") and not lemma:find("ron$")
		end,
	},	
	{"a",
		matches_lemma = function(pagename, lemma, stem)
			return lemma:find("um$") or lemma:find("on$")
		end,
	},
	{"ae",
		matches_plural = function(pagename, lemma)
			return pagename:match("^(.*)ae$") or pagename:match("^(.*)æ$")
		end,
		matches_lemma = function(pagename, lemma, stem)
			return lemma == stem .. "a"
		end,
	},
	{"e",
		matches_lemma = function(pagename, lemma, stem)
			return lemma == stem .. "a"
		end,
	},
	{"oi"},
	{"i",
		matches_lemma = function(pagename, lemma, stem)
			-- don't check just for stem matching because of cases like virus -> virii that we want included.
			return lemma:find("us$") or lemma:find("os$") or lemma:find("o$")
		end,
	},
	{"men", -- siphon off most of the "umlaut" plurals that will otherwise end up in 'English miscellaneous irregular plurals'
		matches_lemma = "man$",
	},
	{"en"},
	{"x"},
	{"ces",
		matches_lemma = "x$",
	},
	{"des",
		matches_lemma = "s$",
	},
	{"ges",
		matches_lemma = "x$",
	},
	{"ves",
		matches_lemma = "fe?$",
	},
	{"ores",
		matches_lemma = function(pagename, lemma, stem)
			return lemma == stem .. "or"
		end,
	},
	{"es",
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
						local pl_ending = irreg_plural[1]
						local stem
						if irreg_plural.matches_plural then
							stem = irreg_plural.matches_plural(pagename_word, lemma_word)
						else
							stem = rmatch(pagename_word, "^(.*)" .. pl_ending .. "$")
						end
						if stem then
							if not irreg_plural.matches_lemma then
								matches_lemma = not rfind(lemma_word, pl_ending .. "$")
							elseif type(irreg_plural.matches_lemma) == "string" then
								matches_lemma = rfind(lemma_word, irreg_plural.matches_lemma)
							else
								matches_lemma = irreg_plural.matches_lemma(pagename_word, lemma_word, stem)
							end
							if matches_lemma then
								add_category(('irregular plurals ending in "-%s"'):format(pl_ending))
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

return {cat_functions = cat_functions}
