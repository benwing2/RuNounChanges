local export = {}

local m_str_utils = require("Module:string utilities")
local audio_module = "Module:audio"
local links_module = "Module:links"
local parse_utilities_module = "Module:parse utilities"
local table_module = "Module:table"

local u = m_str_utils.char
local rfind = m_str_utils.find
local rmatch = m_str_utils.match
local rsplit = m_str_utils.split
local rsubn = m_str_utils.gsub
local ulen = m_str_utils.len
local ulower = m_str_utils.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub

local OVERTIE = u(0x361) -- COMBINING DOUBLE INVERTED BREVE

-- In cases where there are two possible stresses (e.g. in words ending in -ika/-yka), we put ALTSTRESS where both
-- stresses can go, and handle this later in multiword().
local ALTSTRESS = u(0xFFF0)
-- Lect data later retrieved in the module.
local data

-- FIXME: Implement optional assimilation across word boundaries.
local assimilate_across_word_boundaries = false

-- Version of rsubn() that discards all but the first return value.
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

-- apply rsub() repeatedly until no change
local function rsub_repeatedly(term, foo, bar)
	while true do
		local new_term = rsub(term, foo, bar)
		if new_term == term then
			return term
		end
		term = new_term
	end
end

-- Flat-map a function `fun` over `items`. This is like `map` over a sequence followed by `flatten`, i.e. the function
-- must itself return a sequence and all of the returned sequences are flattened into a single sequence.
local function flatmap(items, fun)
	local new = {}
	for _, item in ipairs(items) do
		local results = fun(item)
		for _, result in ipairs(results) do
			m_table.insertIfNot(new, result)
		end
	end
	return new
end

-- Combine two sets of qualifiers, either of which may be nil or a list of qualifiers. Remove duplicate qualifiers.
-- Return value is nil or a list of qualifiers.
local function combine_qualifiers(qual1, qual2)
	if not qual1 then
		return qual2
	end
	if not qual2 then
		return qual1
	end
	local qualifiers = m_table.deepcopy(qual1)
	for _, qual in ipairs(qual2) do
		m_table.insertIfNot(qualifiers, qual)
	end
	return qualifiers
end

local function split_on_comma(term)
	if not term then
		return nil
	end
	if term:find(",%s") or term:find("\\") then
		return require(parse_utilities_module).split_on_comma(term)
	else
		return rsplit(term, ",")
	end
end

-- Remove any HTML from the formatted text and resolve links, since the extra characters don't contribute to the
-- displayed length.
local function convert_to_raw_text(text)
	text = rsub(text, "<.->", "")
	if text:find("%[%[") then
		text = require(links_module).remove_links(text)
	end
	return text
end

-- Return the approximate displayed length in characters.
local function textual_len(text)
	return ulen(convert_to_raw_text(text))
end

local function parse_respellings_with_modifiers(respelling, paramname)
	local function generate_obj(respelling, parse_err)
		return {respelling = respelling}
	end

	if respelling:find("[<%[]") then
		local put = require(parse_utilities_module)
		-- Parse balanced segment runs involving either [...] (substitution notation) or <...> (inline modifiers).
		-- We do this because we don't want commas inside of square or angle brackets to count as respelling
		-- delimiters. However, we need to rejoin square-bracketed segments with nearby ones after splitting
		-- alternating runs on comma. For example, if we are given
		-- "a[x]a<q:learned>,[vol:vôl,ks]<q:nonstandard>", after calling
		-- parse_multi_delimiter_balanced_segment_run() we get the following output:
		--
		-- {"a", "[x]", "a", "<q:learned>", ",", "[vol:vôl,ks]", "", "<q:nonstandard>", ""}
		--
		-- After calling split_alternating_runs(), we get the following:
		--
		-- {{"a", "[x]", "a", "<q:learned>", ""}, {"", "[vol:vôl,ks]", "", "<q:nonstandard>", ""}}
		--
		-- We need to rejoin stuff on either side of the square-bracketed portions.
		local segments = put.parse_multi_delimiter_balanced_segment_run(respelling, {{"<", ">"}, {"[", "]"}})

		local comma_separated_groups = put.split_alternating_runs_on_comma(segments)

		-- Process each value.
		local retval = {}
		for i, group in ipairs(comma_separated_groups) do
			-- Rejoin runs that don't involve <...>.
			local j = 2
			while j <= #group do
				if not group[j]:find("^<.*>$") then
					group[j - 1] = group[j - 1] .. group[j] .. group[j + 1]
					table.remove(group, j)
					table.remove(group, j)
				else
					j = j + 2
				end
			end

			local param_mods = {
				q = {type = "qualifier"},
				qq = {type = "qualifier"},
				a = {type = "labels"},
				aa = {type = "labels"},
				ref = {item_dest = "refs", type = "references"},
			}

			table.insert(retval, put.parse_inline_modifiers_from_segments {
				group = group,
				arg = respelling,
				props = {
					paramname = paramname,
					param_mods = param_mods,
					generate_obj = generate_obj,
				},
			})
		end
		return retval
	else
		local retval = {}
		for _, item in ipairs(split_on_comma(respelling)) do
			table.insert(retval, generate_obj(item))
		end
		return retval
	end
end

-- Parse a pronunciation modifier in `arg`, the argument portion in an inline modifier (after the prefix), which
-- specifies a pronunciation property such as rhyme, hyphenation/syllabification, homophones or audio. The argument
-- can itself have inline modifiers, e.g. <audio:Foo.ogg<a:Masovia>>. The allowed inline modifiers are specified
-- by `param_mods` (of the format expected by `parse_inline_modifiers()`); in addition to any modifiers specified
-- there, the modifiers <q:...>, <qq:...>, <a:...>, <aa:...> and <ref:...> are always accepted. `generate_obj` and
-- `parse_err` are like in `parse_inline_modifiers()` and specify respectively a function to generate the object into
-- which modifier properties are stored given the non-modifier part of the argument, and a function to generate an error
-- message (given the message). Normally, a comma-separated list of pronunciation properties is accepted and parsed,
-- where each element in the list can have its own inline modifiers and where no spaces are allowed next to the commas
-- in order for them to be recognized as separators. This can be overridden with `splitchar` (which can actually be a
-- Lua pattern). The return value is a list of property objects.
local function parse_pron_modifier(arg, paramname, generate_obj, param_mods, splitchar)
	splitchar = splitchar or ","
	if arg:find("<") then
		param_mods.q = {type = "qualifier"}
		param_mods.qq = {type = "qualifier"}
		param_mods.a = {type = "labels"}
		param_mods.aa = {type = "labels"}
		param_mods.ref = {item_dest = "refs", type = "references"}
		return require(parse_utilities_module).parse_inline_modifiers(arg, {
			param_mods = param_mods,
			generate_obj = generate_obj,
			paramname = paramname,
			splitchar = splitchar,
		})
	else
		local retval = {}
		local split_arg = splitchar == "," and split_on_comma(arg) or rsplit(arg, splitchar)
		for _, term in ipairs(split_arg) do
			table.insert(retval, generate_obj(term))
		end
		return retval
	end
end


local function parse_audio(lang, arg, pagename, paramname)
	local param_mods = {
		IPA = {
			sublist = true,
		},
		text = {},
		t = {
			item_dest = "gloss",
		},
		-- No tr=, ts=, or sc=; doesn't make sense for Polish.
		gloss = {},
		pos = {},
		-- No alt=; text= already goes in alt=.
		lit = {},
		-- No id=; text= already goes in alt= and isn't normally linked.
		g = {
			item_dest = "genders",
			sublist = true,
		},
		bad = {},
		cap = {
			item_dest = "caption",
		},
	}

	local function process_special_chars(val)
		if not val then
			return val
		end
		return (val:gsub("[#~]", {
			["#"] = pagename,
			["~"] = pagename .. " się",
		}))
	end

	local function generate_audio_obj(arg)
		return {file = process_special_chars(arg)}
	end

	-- Split on semicolon instead of comma because some filenames have embedded commas not followed by a space
	-- (typically followed by an underscore).
	local retvals = parse_pron_modifier(arg, paramname, generate_audio_obj, param_mods, "%s*;%s*")
	for i, retval in ipairs(retvals) do
		retval.lang = lang
		retval.text = process_special_chars(retval.text)
		retval.caption = process_special_chars(retval.caption)
		local textobj = require(audio_module).construct_audio_textobj(retval)
		retval.text = textobj
		-- Set to nil the fields that were moved into `retval.text`.
		retval.gloss = nil
		retval.pos = nil
		retval.lit = nil
		retval.genders = nil
	end
	return retvals
end

local function parse_homophones(arg, paramname)
	local function generate_obj(term)
		return {term = term}
	end
	local param_mods = {
		t = {
			-- [[Module:links]] expects the gloss in "gloss".
			item_dest = "gloss",
		},
		gloss = {},
		-- No tr=, ts=, or sc=; doesn't make sense for Polish.
		pos = {},
		alt = {},
		lit = {},
		id = {},
		g = {
			-- [[Module:links]] expects the genders in "genders".
			item_dest = "genders",
			sublist = true,
		},
	}

	return parse_pron_modifier(arg, paramname, generate_obj, param_mods)
end


--[[
	As can be seen from the last lines of the function, this returns a table of transcriptions,
	and if do_hyph, also a string being the hyphenation. These are based on a single spelling given,
	so the reason why the transcriptions are multiple is only because of the -yka alternating stress
	et sim. This only accepts single-word terms. Multiword terms are handled by multiword().
--]]
local function single_word(txt, do_hyph, lang, is_prep, period, lect)
	-- This is the number of syllables before the penultimate syllable onto which to add the stress.
	local antepenultimate_stress = 0
	local unstressed = is_prep or false
	-- If antepenultimate_stress > 0, add a second stress onto the penult.
	local double_stress = true

	function tsub(s, r)
		local c
		txt, c = rsubn(txt, s, r)
		return c > 0
	end
	function tsub_repeatedly(s, r)
		txt = rsub_repeatedly(txt, s, r)
	end
	function lg(s) return s[lang] or s[1] end
	function tfind(s) return rfind(txt, s) end

	if tfind("[Åå]") then error("Please replace å with á") end

	-- Save indices of uppercase characters before setting everything lowercase.
	local uppercase_indices
	if do_hyph then
		uppercase_indices = {}
		local capitals = ("[A-Z%s]"):format(lg {
			pl = "ĄĆĘŁŃÓŚŹŻ" --[[and the dialectal]] .. "ÁÉÔÛÝ" --[[and the MPl]] .. "ḾṔẂ",
			szl = "ÃĆŁŃŌŎÔÕŚŹŻ",
			csb = "ÔÒÃËÙÉÓĄŚŁŻŹĆŃ",
			["zlw-slv"] = "ÃÉËÊÓÕÔÚÙŃŻ",
		})
		if tfind(capitals) then
			local i = 1
			local str = rsub(txt, "[.'^*+]", "")
			while rfind(str, capitals, i) do
				local r, _ = rfind(str, capitals, i)
				table.insert(uppercase_indices, r)
				i = r + 1
			end
		end
		if #uppercase_indices == 0 then
			uppercase_indices = nil
		end
	end

	txt = ulower(txt)

	-- Replace digraphs with single capital letters to simplify the code below.
	tsub("[crsd][hzżź]", {
		cz = "C",
		rz = "R",
		sz = "S",
		dz = "D",
		ch = "H",
		["dż"] = "Ż",
		["dź"] = "Ź",
	})
	if lect == "mpl" then
		tsub("b́", "B")
	end
	if lang == "zlw-slv" then
		tsub("gh", "G")
		tsub("y̆", "Y")
	end

	local function undo_digraph_replacement(txt)
		return rsub(txt, "[CRSDHŻŹBG]", {
			C = "cz",
			R = "rz",
			S = "sz",
			D = "dz",
			H = "ch",
			["Ż"] = "dż",
			["Ź"] = "dź",
			B = "b́",
			G = "gh",
			Y = "y̆",
		})
	end

	local V_no_IU = lg {
		pl = "aąeęioóuy" .. "áéôûý",
		szl = "aãeéioōŏôõuy",
		csb = "ôòãëùéóąeyuioa",
		["zlw-slv"] = "aãeéëêioóõôuúùyăĭŏŭŭùāY",
	}
	local V = V_no_IU .. "IU"
	local C = ("[^%sU.']"):format(V_no_IU)

	if txt:find("^*") then
		-- The symbol <*> before a word indicates it is unstressed.
		unstressed = true
		txt = txt:sub(2)
	elseif txt:find("^%^+") then
		-- The symbol <^> before a word indicates it is stressed on the antepenult,
		-- <^^> on the ante-antepenult, etc.
		antepenultimate_stress = txt:gsub("(%^).*", "%1"):len()
		txt = txt:sub(antepenultimate_stress + 1)
	elseif txt:find("^%+") then
		-- The symbol <+> indicates the word is stressed regularly on the penult. This is useful
		-- for avoiding the following checks to come into place.
		txt = txt:sub(2)
	else
		if tfind(".+[łlb][iy].+") then
			-- Some words endings trigger stress on the antepenult or ante-antepenult regularly.
			if tfind("liśmy$") or tfind("[bł]yśmy$") or tfind("liście$") or tfind("[bł]yście$") then
				antepenultimate_stress = 2
			elseif tfind("by[mś]?$") and not tfind("ła?by[mś]?$") then
				antepenultimate_stress = 1
				double_stress = false
			end
		end
		-- Recognise <-yka> and its declined form and automatically assign it an antepenultimate stress.
		if tfind(".+[yi][kc].+") and lect == nil then
			local endings = lg {
				{ "k[aąęio]", "ce", "kach", "kom" },
				szl = { "k[aãio]", "ce", "kacj", "kōm", "kach" },
				csb = { "k[aeąãùóoô]", "ce", "kacj", "kóm", "kama", "kach" },
				["zlw-slv"] = { "k[aãêúóoôõ]", "cê", "kacj", "kji", "kóm", "kóma", "kamy", "kach" }
			}
			for _, v in ipairs(endings) do
				if tfind(("[yi]%s$"):format(v)) then
					antepenultimate_stress = 1
					break
				end
			end
		end
		if lect == "mpl" then
			if tfind(".+[yi]j.+") then
				local endings = { "[ąáéo]", "[ée]j", "[áo]m", "ach" }
				for _, v in ipairs(endings) do
					if tfind(("[yi]j%s$"):format(v)) then
						antepenultimate_stress = 1
					end
				end
			end
		end
	end

	-- TODO: mpl, csb, szl, zlw-slv
	-- FIXME: The following condition is not correct. A manual syllable division shouldn't disable prefix/suffix
	-- checking.
	-- Don't recognise affixes whenever there's only one vowel (or dipthong).
	local _, n_vowels = rsubn(txt, ("[%s]"):format(V), "")
	if n_vowels > 1 then

		-- syllabify common prefixes as separate; note that since we replaced digraphs above with single
		-- chars, we need to use the replacement chars here
		local prefixes = {
			"do", "wy",
			"arHeo", "arcy", "areo", "arytmo", "audio", "balneo", "biblio",
			"Ctero", "ćwierć",
			"diafano", "dwu", "niby",
			"nowo", "około", "pierwo", "pięcio",
			"staro",
			"aero", "[pt]Ry", "pRed?", "wielk?o",
			"mało",
			-- <na-, po-, o-, u-> would hit too many false positives
		}
		for _, v in ipairs(prefixes) do
			if tfind("^" .. v) then
				local _, other_vowels = rsubn(v, ("[%s]"):format(V), "")
				if (n_vowels - other_vowels) > 0 then
					-- Make sure the suffix is followed by zero or more consonants (including - but not
					-- including a syllable divider) followed by a vowel. We do this so that we don't put
					-- a syllable divider when the user specified the divider in a different place.
					tsub(("^(%s)(%s*[%s])"):format(v, C, V), "%1.%2")
					break
				end
			end
		end

		-- nie + vowel should be broken but only -eu- is a diphthong
		tsub("^nieu", "nie.u")

		-- syllabify common suffixes as separate
		local suffixes = lg {
			pl = {
				"nąć",
				"[sc]tw[aou]", "[sc]twie", "[sc]tw[eo]m", "[sc]twami", "[sc]twach",
				"dztw[aou]", "dztwie", "dztw[eo]m", "dztwami", "dztwach",
				"dł[aou]", "dł[eo]m", "dłami", "dłach",
				"[czs]j[aeięąo]", "[czs]jom", "[czs]jami", "[czs]jach",
			}, szl = {
				"nōńć", "dło",
			}, csb = {
				"nąc", "dło"
			}, ["zlw-slv"] = {
				"nõc", "dlô"
			},
		}

		for _, v in ipairs(suffixes) do
			-- Make sure there's no syllable divider elsewhere in the consonant cluster
			-- preceding the suffix. Same logic as above for prefixes.
			if tsub(("([%s]%s*)(%s)$"):format(V, C, v), "%1.%2") then break end
		end

		-- syllabify <istka> as /ist.ka/; same for [[haftka]], [[adiunktka]], [[abiturientka]], [[ćwiartka]],
		-- [[adeptka]], etc.
		if txt:find(("[%s][rfnskp]+t[kc]"):format(V)) then
			local endings = lg {
				{ "k[aąęio]", "ce", "kach", "kom", "kami" },
				szl = { "k[aãio]", "ce", "kami", "kacj", "kacach", "kōma" },
				csb = { "k[aãąioôòùó]", "ce", "kami", "kacj", "kacach", },
			}
			for _, v in ipairs(endings) do
				-- Make sure there's no syllable divider elsewhere in the consonant cluster
				-- preceding the suffix. Same logic as above for prefixes.
				if tsub(("([%s][rfnskp]+t)(%s)$"):format(V, v), "%1.%2") then break end
			end
		end
	end

	-- falling diphthongs <au> and <eu>, and diacriticised variants
	tsub(lg { "([aeáé])u", csb = "([ae])ù" }, "%1U")

	-- rising diphthongs with <iV>
	tsub(("([^%s])" .. (lang == "zlw-slv" and "j" or "i") .. "([%s])"):format(V, V), "%1I%2")

	-- Prevent palatalization of the special case kwazi-.
	tsub("^kwazi", "kwaz-i")

	-- Syllabify by adding a period (.) between syllables. There may already be user-supplied syllable divisions
	-- (period or single quote), which we need to respect. This works by replacing each sequence of VC*V with
	-- V.V, V.CV, V.TRV (where T is an obstruent and R is a liquid) or otherwise VTR.C+V or VC.C+V, i.e. if there are
	-- multiple consonants, place the syllable boundary after the first TR sequence or otherwise the first consonant.
	-- We need to repeat since each VC*V sequence overlaps the next one. Digraphs have already been replaced by single
	-- capital letters.
	--
	-- FIXME: I don't believe it's necessarily correct in a sequence of obstruents to place the boundary after the
	-- first one. I think we should respect the possible onsets.

	-- List of obstruents and liquids, including capital letters representing digraphs. We count rz as a liquid even
	-- in Polish.
	local obstruent = "bBcćCdDfgGhHkpṕqsSśtxzźżŹŻ"
	local liquid_no_w = "IjlrR"
	local liquid = liquid_no_w .. "łwẃ"
	-- We need to treat I (<i> in hiatus) as a consonant, and since we check for two vowels in a row, we don't want
	-- U to be one of the second vowels.
	tsub_repeatedly(("([%sU])(%s*)([%s])"):format(V_no_IU, C, V_no_IU), function(v1, cons, v2)
		local cons_no_hyphen = cons:gsub("%-", "")
		if ulen(cons_no_hyphen) < 2 or rfind(cons_no_hyphen, ("^[%s][%s]I?$"):format(obstruent, liquid)) or
			rfind(cons_no_hyphen, ("^%sI$"):format(C)) then
			cons = "." .. cons
		else
			local nsubs
			-- Don't syllabify [[niósłby]] as niósł.by or [[jabłczan]] as jabłczan.
			-- FIXME: Not sure if this is quite right.
			cons, nsubs = rsubn(cons, ("^(%%-?[%s]%%-?[%s])"):format(obstruent, liquid_no_w), "%1.")
			if nsubs == 0 then
				cons = rsub(cons, "^(%-?.)", "%1.")
			end
		end
		return ("%s%s%s"):format(v1, cons, v2)
	end)

	local hyph
	if do_hyph then
		-- Ignore certain symbols and diacritics for the hyphenation.
		hyph = txt:gsub("'", "."):gsub("-", ""):gsub(",", "")
		if lang == "zlw-slv" then
			hyph = rsubn(hyph, "[IăĭŏŭYā]", {
				["I"] = "j",
				["ă"] = "a", ["ĭ"] = "i", ["ŏ"] = "o",
				["ŭ"] = "u", ["Y"] = "y", ["ā"] = "a",
			})
		end
		hyph = undo_digraph_replacement(hyph)
		hyph = hyph:lower()
		-- Restore uppercase characters.
		if uppercase_indices then
			-- str_i loops through all the characters of the string
			-- list_i loops as above but doesn't count dots
			-- array_i loops through the indices at which the capital letters are
			local str_i, list_i, array_i = 1, 1, 1
			function h_sub(x, y) return usub(hyph, x, y) end
			while array_i <= #uppercase_indices do
				if h_sub(str_i, str_i) ~= "." then
					if list_i == uppercase_indices[array_i] then
						hyph = ("%s%s%s"):format(h_sub(1,str_i-1), uupper(h_sub(str_i,str_i)), h_sub(str_i+1))
						array_i = array_i + 1
					end
					list_i = list_i + 1
				end
				str_i = str_i + 1
			end
		end
	end

	tsub("'", "ˈ")

	txt = undo_digraph_replacement(txt)

	-- handle <x>; must precede ch -> [x]
	tsub("x", "ks")
	-- move syllable boundary between [ks] if preceded by a vowel
	tsub(("([%s])([.ˈ])ks"):format(V), "%1k%2s")

	-- handle digraphs
	tsub("ch", "x")
	tsub("[cs]z", { ["cz"]="t_ʂ", ["sz"]="ʂ" })
	tsub("rz", "R")
	tsub("d([zżź])", "d_%1")
	tsub("qu", "kw")
	if lect == "mpl" then tsub("b́", "bʲ") end
	if lang == "zlw-slv" then tsub("gh", "ɣ") end

	-- basic orthographical rules

	-- replacements that are the same (almost) everywhere; can be overridden
	local replacements = {
		-- vowels
		["e"]="ɛ", ["o"]="ɔ",

		-- consonants
		["c"]="t_s", ["ć"]="t_ɕ",
		["ń"]="ɲ", ["ś"]="ɕ", ["ź"]="ʑ",
		["ł"]="w", ["w"]="v", ["ż"]="ʐ",
		["g"]="ɡ", ["h"]="x",
	}

	local function override(tbl)
		for k, v in pairs(tbl) do
			replacements[k] = v
		end
	end

	-- not using lg() here for speed
	if lang == "pl" then
		override {
			-- vowels
			["ą"]="ɔN", ["ę"]="ɛN",
			["ó"]="u", ["y"]="ɘ",
		}
		if lect then
			override {
				["é"] = "e", ["á"] = "ɒ",
			}
			if lect == "mpl" then
				override {
					["ę"] = "ɛ̃",
					["ą"] = "ɔ̃",
					["y"] = "ɨ",
					["ó"] = "o",
					["ł"] = "ɫ",
					["ṕ"] = "pʲ",
					["ḿ"] = "mʲ",
					["ẃ"] = "vʲ",
				}
				-- <b́> has no unicode character and hence is handled above
			else
				override {
					["ô"] = "wɔ",
					["û"] = "wu",
					["ý"] = "Y",
				}
				if data.lects[lect].mid_o then
					replacements["ó"] = "o"
				elseif lect == "ekr" then
					replacements["ó"] = "O"
				end
				if data.lects[lect].front_y then
					replacements["y"] = "Y"
				end
				if data.lects[lect].dark_l then
					replacements["ł"] = "ɫ"
					replacements["l"] = "lʲ"
				end
				if data.lects[lect].glottal_h then
					replacements["h"] = "h"
				end
			end
		end
		tsub(".", replacements)
	elseif lang == "szl" then
		override {
			-- vowels
			["ō"]="o", ["ŏ"]="O",
			["ô"]="wɔ", ["õ"] = "ɔ̃",
			["y"] = "ɪ",
		}
		tsub(".", replacements)
	elseif lang == "csb" then
		override {
			-- vowels
			["é"]="e",
			["ó"]="o", ["ô"]="ɞ", ["ë"]="ɜ",
			["ò"]="wɛ", ["ù"]="wu", ["y"] = "Y",
			["ą"] = "ɔ̃",
		}
		tsub(".", replacements)
	elseif lang == "zlw-slv" then
		override {
			-- vowels
			["é"]="e",
			["ó"]="o", ["ô"]="ɵ", ["ë"]="ə", ["ê"]="E",
			["y"]="ɪ", ["ú"]="ʉ", ["ù"]="y",
			["õ"]="ɔ̃", ["ā"]="aː", -- ãăĭŏŭ
			-- breves remain (FIXME: correct?)
		}
		tsub(".", replacements)
	end

	if lang == "csb" or lang == "zlw-slv" then
		tsub("ʂ", "ʃ")
		tsub("ʐ", "ʒ")
	end

	-- palatalization
	local palatalize_into = { ["n"] = "ɲ", ["s"] = "ɕ", ["z"] = "ʑ" }
	tsub("([nsz])I", function (c) return palatalize_into[c] end)
	tsub("([nsz])i", function (c) return palatalize_into[c] .. "i" end)

	-- velar assimilation
	tsub("n([.ˈ]?[kɡx])", "ŋ%1")

	-- voicing and devoicing

	local devoice = {
		["b"] = "p",
		["d"] = "t",
		["ɡ"] = "k",
		["z"] = "s",
		["v"] = "f",
		["ʑ"] = "ɕ",
		["ʐ"] = "ʂ",
		["ʒ"] = "ʃ",
		-- NOTE: was not here before but I think we need it for Polish; if we remove it, we have
		-- to add x manually to `T` below, the list of unvoiced obstruents
		["ɣ"] = "x",
		["R"] = "S",
	}

	local trilled_rz = lang == "csb" or lang == "zlw-slv"
	if not trilled_rz and lect then
		trilled_rz = data.lects[lect].trilled_rz
	end

	if trilled_rz then
		devoice["R"] = nil
	end

	--if lang == "zlw-slv" then
	--	devoice["ɣ"] = "x"
	--end

	local voice = {}
	for k, v in pairs(devoice) do
		voice[v] = k
	end

	local function concat_keys(tbl, exclude)
		local keys = {}
		for k, _ in pairs(tbl) do
			if not exclude or not exclude[k] then
				table.insert(keys, k)
			end
		end
		return table.concat(keys)
	end

	-- Forward assimilation is only devoicing of <w> and <rz>. Backward assimilation both voices and devoices,
	-- but <w> and <rz> do not cause backward assimilation. (Since we do forward assimilation first, occurrences
	-- of <w> and <rz> following a voiceless obstruent should not occur in standard Polish when we do backward
	-- assimilation, but <rz> may occur in lects that have trilled <rz>.) Note that in the event of <w> and <rz>
	-- between a voiceless obstruent and a voiced one, forward assimilation will devoice them and then they will
	-- get voiced again by backward assimilation.
	local T_causes_forward_assim = concat_keys(voice)
	local T_causes_backward_assim = T_causes_forward_assim
	local T_gets_backward_assim = T_causes_forward_assim
	local D_causes_backward_assim = concat_keys(devoice, {v = true, R = true})
	local D_gets_backward_assim = concat_keys(devoice)
	-- FIXME! The following operates only in Slovincian and I assume <w> and <rz> do not cause forward voicing
	-- assimilation.
	local D_causes_forward_assim = D_causes_backward_assim

	local transparent_liquid = "rlɫw"
	if trilled_rz then
		-- FIXME! I hope this is correct.
		transparent_liquid = transparent_liquid .. "R"
	end
	-- forward (progressive) assimilation of <w> and <rz>; proceeds left to right
	tsub_repeatedly(("([%s]ʲ?[.ˈ]?[%s]?ʲ?[.ˈ]?)([vR])"):format(T_causes_forward_assim, transparent_liquid),
		function(prev, cons)
			return prev .. (cons == "v" and "f" or "S")
		end
	)

	-- forward (progressive) assimilation of [ɣ] and [x] in Slovincian; proceeds left to right
	if lang == "zlw-slv" then
		-- FIXME! Does this occur across an intervening liquid, as in Polish?
		tsub(("([%s][.ˈ]?)ɣ"):format(T_causes_forward_assim), "%1x")
		tsub(("([%s][.ˈ]?)x"):format(D_causes_forward_assim), "%1ɣ")
	end

	-- final devoicing
	if not is_prep then
		tsub(("([%s])(ʲ?)$"):format(D_gets_backward_assim), function (a, b)
			return devoice[a] .. b
		end)
	end

	-- Backward (regressive) assimilation. It both voices and devoices, and needs to proceed right to left
	-- in case of sequences of obstruents. The way to do that is to add a .* at the beginning of each pattern
	-- to replace so we do the rightmost cluster first, and then repeat till nothing changes.
	local prev_txt
	local devoice_string = ("^(.*)([%s])(ʲ?[._ˈ]?[%s])"):format(
		D_gets_backward_assim, T_causes_backward_assim)
	local voice_string = ("^(.*)([%s])(ʲ?[._ˈ]?[%s])"):format(
		T_gets_backward_assim, D_causes_backward_assim)
	local function devoice_func(prev, c1, c2) return prev .. devoice[c1] .. c2 end
	local function voice_func(prev, c1, c2) return prev .. voice[c1] .. c2 end
	while txt ~= prev_txt do
		prev_txt = txt
		tsub(devoice_string, devoice_func)
		tsub(voice_string, voice_func)
	end

	tsub("Y", "i")

	if lang == "csb" then
		tsub("([pbmfvkɡx])o", "%1wo")
		tsub("vw", "w")
	end

	if lang == "zlw-slv" then
		local V = "aɛeɔ̃oɵəEɪiʉuyã"
		tsub("nj$", "n")
		tsub("nj([^" .. V .. "])", "n%1")
		tsub("ɲ([" .. V .. "])", "nj%1")
		tsub("ɛ$", "ə")
	end

	if trilled_rz then
		tsub("R", "r̝")
	end

	if lect ~= "mpl" then
		tsub("S", "ʂ")
		tsub("R", "ʐ")
	end

	if lang == "pl" then
		-- nasal vowels
		tsub("N([.ˈ]?[pb])", "m%1")
		tsub("N([.ˈ]?[ɕʑ])", "ɲ%1")
		tsub("N([.ˈ]?[td]_[ɕʑ])", "ɲ%1")
		tsub("N([.ˈ]?[td])", "n%1")
		tsub("N([.ˈ]?[kɡxɣ])", "ŋ%1")
		tsub("N([.ˈ]?[wl])", "%1")
		tsub("ɛN$", "ɛ")
		tsub("N", "w̃")
	end

	-- Hyphen separator, e.g. to prevent palatalization of <kwazi->.
	tsub("-", "")

	tsub("_", OVERTIE)
	tsub("I", "j")
	tsub("U", "w")

	-- Handles stress.
	local function add_stress(penultimate_offset, force_initial_stress)
		local stressed_txt
		if force_initial_stress or (lect and data.lects[lect].initial_stress) then
			-- Deals with initially stressed lects.
			stressed_txt = "ˈ" .. txt
		else
			-- Accent elsewhere, usually antepenult although can vary depending on
			-- the <penultimate_offset> value, counting backwards.
			local regex = ""
			for _ = 0, penultimate_offset do
				regex = regex .. "[^.]+%."
			end
			stressed_txt = rsub(txt, "%.(" .. regex .. "[^.]+)$", "ˈ%1")
			-- If no stress mark could have been placed, it can only be initial,
			-- e.g. in monosyllables.
			if not stressed_txt:find("ˈ") then
				stressed_txt = "ˈ" .. stressed_txt
			elseif penultimate_offset > 0 and double_stress then
				stressed_txt = rsub("ˈ(.+)%.([^.]+%.[^.]+)$", ALTSTRESS .. "%1" .. ALTSTRESS .. "%2", stressed_txt)
			end
		end
		return stressed_txt
	end

	local should_stress = not (unstressed or txt:find("ˈ"))
	local prons = should_stress and add_stress(antepenultimate_stress) or txt

	if is_prep then
		prons = prons .. "$"
	end

	if lang == "pl" then
		if lect then
			if lect == "ekr" then
				if tfind("O") then
					prons = { (prons:gsub("O", "o")), (prons:gsub("O", "u")) }
				end
			elseif lect == "ora" or lect == "zag" then
				local stressed_initially = add_stress(0, true)
				if stressed_initially ~= prons then
					prons = lect == "ora" and { stressed_initially, prons } or { prons, stressed_initially }
				end
			elseif lect == "mpl" then
				if tfind("[RS]") then
					local mp_early = prons:gsub("[RS]", "r̝")
					local mp_late = prons:gsub("R", "ʐ"):gsub("S", "ʂ")
					if period == "early" then
						prons = mp_early
					elseif period == "late" then
						prons = mp_late
					elseif not period then
						prons = {
							mp_early, mp_late,
						}
					else
						error(("'%s' is not a supported Middle Polish period; try with 'early' or 'late'"):format(period))
					end
				end
			end
		else
			if should_stress and antepenultimate_stress > 0 and double_stress then
				local stressed_penult = add_stress(0)
				if stressed_penult ~= prons then
					prons = { prons, stressed_penult }
				end
			end
		end
	elseif lang == "szl" then
		if tfind("O") then
			prons = {
				(prons:gsub("O", "ɔ")),
				(prons:gsub("O", "ɔw")),
				(prons:gsub("O", "ɛw")),
			}
		end
	elseif lang == "zlw-slv" then
		if tfind("E") then
			local V = "aɛeɔ̃oɵəEɪiʉuyã"
			prons = prons:gsub("ˈ([^" .. V .. "]*)E", "ˈ%1i̯ɛ")
			prons = prons:gsub("E$", "ə")
			prons = prons:gsub("E", "ɛ")
		end
	end

	if do_hyph then
		return prons, hyph
	else
		return prons
	end

end

-- Returns rhyme from a transcription.
local function do_rhyme(pron, lang)
	-- No rhymes for multiword terms.
	if pron:find(" ") then
		return nil
	end
	local V = ({ pl = "aɛiɔuɘ", szl = "aãɛiɔouɪ", csb = "aãɛeɜiɔoõɞu", ["zlw-slv"] = "aãɛeĭɪŏɔɵŭʉy"})[lang]
	return {
		rhyme = rsub(rsub(rsub(pron, "^.*ˈ", ""), ("^[^%s]-([%s])"):format(V, V), "%1"), "%.", ""),
		num_syl = { select(2, rsubn(pron, ("[%s]"):format(V), "")) }
	}
end

--[[
	Handles a single input, returning a table of transcriptions. Returns also a string of
	hyphenation and a table of rhymes if it is a single-word term.
--]]
local function multiword(term, lang, period, lect)
	if term:find("^raw:%[.+%]$") then
		return { phonetic = term:gsub("^raw:", "") }
	end
	term = rsub(term, "%s*,%s*", " | ")
	if term:find(" ") then
		-- TODO: repeated
		function lg(s)
			return s[lang] or s[1]
		end

		local prepositions = lg {
			{
				"beze?", "na", "dla", "do", "ku", "nade?", "o", "ode?", "po", "pode?", "przede?", "przeze?", "przy",
				"spode?", "u", "we?", "z[ae]?", "znade?", "zza",
				-- clitics
				"a", "i", "nie",
			}, szl = {
				"bezy?", "na", "dlŏ", "d[oō]", "ku", "nady?", "ô", "ôdy?", "po", "pody?", "przedy?", "przezy?", "przi",
				"spody?", "u", "w[ey]?", "z[aey]?", "[śs]", "znady?"
			}, csb = {
				"beze?", "na", "dlô", "do", "kù", "nade?", "ò", "òde?", "pò", "pòde?", "przede?", "przeze?", "przë",
				"spòde?", "ù", "we?", "wew", "z[ae]?", "zez", "zeza", "zó", "znade?"
			}, ["zlw-slv"] = {
				"dlo", "dô", "na", "nade?", "przêde?", "przêze?", "przë", "pô", "pôde?", "sê?", "vô", "we?", "wôde?",
				"wù", "za"
			},
		}

		local p
		local contains_preps = false

		for word in term:gmatch("[^ ]+") do
			local v
			if word == "|" then
				-- foot boundary
				v = word
			else
				local is_prep = false
				for _, prep in ipairs(prepositions) do
					if (rfind(word, ("^%s$"):format(prep))) then
						is_prep = true
						contains_preps = true
						break
					end
				end
				v = single_word(word, false, lang, is_prep, period, lect)
			end
			local sep = "%s %s"
			if p == nil then
				p = v
			elseif type(p) == "string" then
				if type(v) == "string" then
					p = sep:format(p, v)
				else
					p = { sep:format(p, v[1]), sep:format(p, v[2]) }
				end
			else
				if type(v) == "string" then
					p = { sep:format(p[1], v), sep:format(p[2], v) }
				else
					p = { sep:format(p[1], v[1]), sep:format(p[2], v[2]) }
				end
			end
		end

		local function assimilate_preps(str)
			local function assim(from, to, before)
				str = rsub(str, ("%s(%%$ ˈ?[%s])"):format(from, before), to .. "%1")
			end
			local T = "ptsʂɕkx"
			assim("d", "t", T)
			assim("v", "f", T)
			assim("z", "s", T)
			if lang == "szl" then
				local D = "bdzʐʑɡ"
				assim("s", "z", D)
				assim("ɕ", "ʑ", D)
			end
			return rsub(str, "%$", "")
		end

		if contains_preps then
			if type(p) == "string" then
				p = assimilate_preps(p)
			else
				p[1] = assimilate_preps(p[1])
				p[2] = assimilate_preps(p[2])
			end
		end

		return p

	else
		return single_word(term, lect ~= "mpl", lang, false, period, lect)
	end

end

-- Given a single substitution spec, `to`, figure out the corresponding value of `from` used in a complete
-- substitution spec. `pagename` is the name of the page, either the actual one or taken from the `pagename` param.
-- `whole_word`, if set, indicates that the match must be to a whole word (it was preceded by ~).
local function convert_single_substitution_to_original(to, pagename, whole_word)
	-- Replace specially-handled characters with a class matching the character and possible replacements.
	local escaped_from = to
	escaped_from = escaped_from:gsub("[.']", "")
	escaped_from = m_str_utils.pattern_escape(escaped_from)
	-- j can match against i in e.g. [[aikido]] respelled <ajkido> and [[apeiron]] respelled <apejron>
	escaped_from = escaped_from:gsub("j", "[ji]")
	-- ń can match against n; in combination with the preceding, ńj can match against ni in e.g. [[Albania]] respelled
	-- <Albańja>.
	escaped_from = escaped_from:gsub("ń", "[ńn]")
	-- k can match against c or cc in e.g. [[altocumulus]] respelled <altokumulus> or [[piccolo]] respelled <pikolo>
	escaped_from = escaped_from:gsub("k", "[kc]+")
	-- This is tricky, because we already passed `escaped_from` through pattern_escape() causing a hyphen to get a
	-- % sign before it, and have to double up the percent signs to match and replace a literal %.
	escaped_from = escaped_from:gsub("%%%-", "%%-?")
	escaped_from = "(" .. escaped_from .. ")"
	if whole_word then
		escaped_from = "%f[%a]" .. escaped_from .. "%f[%A]"
	end
	local match = rmatch(pagename, escaped_from)
	if match then
		if match == to then
			error(("Single substitution spec '%s' found in pagename '%s', replacement would have no effect"):
				format(to, pagename))
		end
		return match
	end
	error(("Single substitution spec '%s' couldn't be matched to pagename '%s'"):format(to, pagename))
end


local function apply_substitution_spec(respelling, pagename, parse_err)
	local subs = split_on_comma(rmatch(respelling, "^%[(.*)%]$"))
	respelling = pagename
	for _, sub in ipairs(subs) do
		local from, escaped_from, to, escaped_to, whole_word
		if sub:find("^~") then
			-- whole-word match
			sub = rmatch(sub, "^~(.*)$")
			whole_word = true
		end
		if sub:find(":") then
			from, to = rmatch(sub, "^(.-):(.*)$")
		else
			to = sub
			from = convert_single_substitution_to_original(to, pagename, whole_word)
		end
		if from then
			escaped_from = m_str_utils.pattern_escape(from)
			if whole_word then
				escaped_from = "%f[%a]" .. escaped_from .. "%f[%A]"
			end
			escaped_to = m_str_utils.replacement_escape(to)
			local subbed_respelling, nsubs = rsubn(respelling, escaped_from, escaped_to)
			if nsubs == 0 then
				parse_err(("Substitution spec %s -> %s didn't match processed pagename '%s'"):format(
					from, to, respelling))
			elseif nsubs > 1 then
				parse_err(("Substitution spec %s -> %s matched multiple substrings in processed pagename '%s', add " ..
					"more context"):format(from, to, respelling))
			else
				respelling = subbed_respelling
			end
		end
	end

	return respelling
end


-- This handles all the magic characters <*>, <^>, <+>, <.>, <#>.
local function normalise_input(term, pagename, paramname)
	local function check_af(str, af, reg, repl, err_msg)
		reg = reg:format(af)
		if not rfind(str, reg) then
			error(("The word %s does not %s with %s"):format(str, err_msg, af))
		end
		return str:gsub(reg, repl)
	end

	local function check_pref(str, pref) return check_af(str, pref, "^(%s)", "%1.", "start") end
	local function check_suf(str, suf) return check_af(str, suf, "(%s)$", ".%1", "end") end

	if term:find("^%[.*%]$") then
		local function parse_err(msg)
			-- Don't call make_parse_err() until we actually need to throw an error, to avoid unnecessarily loading
			-- [[Module:parse utilities]].
			require(parse_utilities_module).make_parse_err(paramname)(msg)
		end
		return apply_substitution_spec(term, pagename, parse_err)
	end
	if term == "#" then
		-- The diesis stands simply for {{PAGENAME}}.
		return pagename
	elseif (term == "+") or term:find("^%^+$") or (term == "*") then
		-- Inputs that are just '+', '*', '^', '^^', etc. are treated as
		-- if they contained the pagename with those symbols preceding it.
		return term .. pagename
	-- Handle syntax like <po.>, <.ka> and <po..ka>. This allows to not respell
	-- the entire word when all is needed is to specify syllabification of a prefix
	-- and/or a suffix.
	elseif term:find(".+%.$") then
		return check_pref(pagename, term:sub(1, -2))
	elseif term:find("^%..+") then
		return check_suf(pagename, term:sub(2))
	elseif term:find(".+%.%..+") then
		return check_suf(check_pref(pagename, term:gsub("%.%..+", "")), term:gsub(".+%.%.", ""))
	end

	return term

end

-- This converts the raw information, the arguments and pagename, into tables to be handed over to the IPA module.
-- It is called externally by [[Module:zlw-lch-IPA/testcases/driver]].
function export.get_lect_pron_info(terms, pagename, paramname, lang, lect, period)
	if #terms == 1 and terms[1].respelling == "-" then
		return {
			pron_list = nil,
			rhyme_list = {},
			hyph_list = {},
			do_hyph = false,
		}
	end

	local pron_list = {{}}
	local rhyme_list = {{}}
	local hyph_list = {}
	local do_hyph = false

	local brackets = "/%s/"
	if lect then
		if data.lects[lect].phonetic then
			brackets = "[%s]"
		end
	end

	-- Loops over the terms given as arguments.
	for _, term in ipairs(terms) do
		local respelling = term.respelling
		-- Handles magic symbols in the input.
		respelling = normalise_input(respelling, pagename, paramname)
		-- Obtains the transcription and hyphenation for the current index.
		local prons, hyph = multiword(respelling, lang, period, lect)

		-- Return a single phonemic transcription with qualifiers and references
		-- attached to it. An additional qualifier may be specified, which is for the
		-- regular oscillations (e.g. Middle Polish <rz>, etc.). The references can
		-- be omitted (if it's the second transcription of a regular oscillation).
		local function new_pron(pron, additional_qualifier, dont_refs)
			local bracketed_pron = brackets:format(pron)
			-- Strip away syllable dividers, but return a version with the syllable dividers for
			-- comparison purposes with the old {{pl-p}}. FIXME: IMO we should be including the
			-- syllable dividers in the phonemic output. [Benwing]
			local bracketed_pron_no_syldivs = bracketed_pron:gsub("%.", "")
			local merged_qualifiers = term.q or {}
			if additional_qualifier then
				merged_qualifiers = m_table.shallowcopy(merged_qualifiers)
				table.insert(merged_qualifiers, additional_qualifier)
			end
			local ret = {
				pron = bracketed_pron_no_syldivs,
				pron_with_syldivs = bracketed_pron,
				q = merged_qualifiers,
				qq = term.qq,
				a = term.a,
				aa = term.aa,
				refs = not dont_refs and term.refs or nil,
			}
			return ret
		end

		-- If the <prons> variable is a string it means only one transcription
		-- was given.
		if type(prons) == "string" then
			table.insert(pron_list[1], new_pron(prons))
			table.insert(rhyme_list[1], do_rhyme(prons, lang))
		-- If the <pron> variable is a table and has a <phonetic> value, then simply return that.
		elseif prons.phonetic then
			table.insert(pron_list[1], {
				pron = prons.phonetic,
				pron_with_syldivs = prons.phonetic,
				q = term.q,
				qq = term.qq,
				a = term.a,
				aa = term.aa,
				refs = term.refs,
			})
		-- If the <prons> variably is a table and does not have a <phonetic> value, it is
		-- a list of transcriptions.
		else
			local multiple_transcript = ({
				pl = { "prescribed", "casual" },
				szl = { nil, "Western", "Głogówek"},
			})[lang]
			if lang == "pl" and lect then
				multiple_transcript = ({
					mpl = { "16<sup>th</sup> c.", "17<sup>th</sup>–18<sup>th</sup> c." },
					ekr = { "pre-21<sup>st</sup> c.", "21<sup>st</sup> c."},
					ora = { "Poland", "Slovakia" },
					zag = { "north", "south" },
				})[lect]
			end
			for i, v in ipairs(prons) do
				if #pron_list < (i + 1) then pron_list[i + 1] = {} end
				table.insert(pron_list[i + 1], new_pron(v, multiple_transcript[i], i ~= 1))
				if #rhyme_list < (i + 1) then rhyme_list[i + 1] = {} end
				table.insert(rhyme_list[i + 1], do_rhyme(v, lang))
			end
		end

		-- If a hyphenation value had been returned by the <multiword> function, it means
		-- that in any case a hyphenation is required (i.e. it is not a multiword term nor is
		-- the hyphenation manually turned off, etc.). If the hyphenation value acquired however
		-- does not match the pagename, it is not added to the table.
		if hyph then
			do_hyph = true
			if hyph:gsub("%.", "") == pagename then
				m_table.insertIfNot(hyph_list, hyph)
			end
		end
	end

	-- TODO: looks rather slow.
	local function merge_subtables(t)
		if #t == 1 then
			return t[1]
		end
		local r = {}
		for _, subtable in ipairs(t) do
			for _, value in ipairs(subtable) do
				table.insert(r, value)
			end
		end
		return r
	end

	pron_list = merge_subtables(pron_list)
	rhyme_list = merge_subtables(rhyme_list)

	return {
		pron_list = pron_list,
		hyph_list = hyph_list,
		rhyme_list = rhyme_list,
		do_hyph = do_hyph,
	}
end

function export.get_lect_pron_info_bot(frame)
	local iargs = require("Module:parameters").process(frame.args, {
		[1] = {},
		["lang"] = { default = "pl" },
		["lect"] = {},
		["period"] = {},
		["pagename"] = {}, -- for debugging or demonstration only
		["plp"] = { list = true },
	})

	local termspec = iargs[1] or "#"
	local terms = parse_respellings_with_modifiers(termspec, 1)

	local retval = export.get_lect_pron_info(
		terms,
		iargs.pagename or mw.loadData("Module:headword/data").pagename,
		"[from bot]",
		iargs.lang,
		iargs.lect,
		iargs.period
	)

	if iargs.plp[1] then
		retval.plp_prons = {}
		for _, plp in ipairs(iargs.plp) do
			table.insert(retval.plp_prons, "/" .. require("Module:pl-IPA").convert_to_IPA(plp) .. "/")
		end
	end

	return require("Module:JSON").toJSON(retval)
end

function export.show(frame)
	local ilang = frame.args.lang

	if ilang == "pl" then
		data = require("Module:zlw-lch-IPA/data/pl")
	end

	local process_args = {
		[1] = {},
		["hyphs"] = {}, ["h"] = { alias_of = "hyphs" },
		["rhymes"] = {}, ["r"] = { alias_of = "rhymes" },
		["audios"] = {}, ["a"] = { alias_of = "audios" },
		["homophones"] = {}, ["hh"] = { alias_of = "homophones" },
		["pagename"] = {}, -- for debugging or demonstration only
	}

	if ilang == "pl" then
		process_args["mpl_period"] = {}
		process_args["mp_period"] = { alias_of = "mpl_period" }

		for lect, _ in pairs(data.lects) do
			process_args[lect] = {}
		end

		for alias, lect in pairs(data.lect_aliases) do
			process_args[alias] = { alias_of = lect }
		end
	end

	local args = require("Module:parameters").process(frame:getParent().args, process_args)

	local lang = require("Module:languages").getByCode(ilang, true, "allow etym")

	local termspec = args[1] or "#"
	local terms = parse_respellings_with_modifiers(termspec, 1)
	local pagename = args.pagename or mw.loadData("Module:headword/data").pagename

	local pronobj = export.get_lect_pron_info(terms, pagename, 1, ilang)
	local hyph_list, rhyme_list, do_hyph = pronobj.hyph_list, pronobj.rhyme_list, pronobj.do_hyph

	local pl_lect_prons

	if ilang == "pl" then
		for lect, _ in pairs(data.lects) do
			if args[lect] then
				if pl_lect_prons == nil then pl_lect_prons = {} end
				pl_lect_prons[lect] = export.get_lect_pron_info(
					parse_respellings_with_modifiers(args[lect], lect), pagename, lect, "pl", lect,
					args[lect .. "_period"]
				).pron_list
			end
		end
	end

	if args.hyphs then
		if args.hyphs == "-" then
			do_hyph = false
		else
			hyph_list = split_on_comma(args.hyphs)
			do_hyph = true
		end
	end

	if args.rhymes then
		if args.rhymes == "-" then
			rhyme_list = {}
		elseif args.rhymes ~= "+" then
			rhyme_list = {}
			for _, v in ipairs(split_on_comma(args.rhymes)) do
				if rfind(v, ".+/.+") then
					table.insert(rhyme_list, {
						rhyme = rsub(v, "/.+", ""),
						num_syl = { tonumber(rsub(v, ".+/", "")) },
					})
				else
					error(("The manual rhyme %s did not specify syllable number as RHYME/NUM_SYL"):format(v))
				end
			end
		end
	end

	-- This deals with duplicate values in rhymes.
	if #rhyme_list > 0 then
		local temp_rhyme_list = {}
		local indices = {}
		for _, v in ipairs(rhyme_list) do
			local index = indices[v.rhyme]
			if index == nil then
				table.insert(temp_rhyme_list, v)
				indices[v.rhyme] = #temp_rhyme_list
			else
				local different_num_syl = true
				for _, ns in ipairs(temp_rhyme_list[index].num_syl) do
					if ns == v.num_syl[1] then
						different_num_syl = false
						break
					end
				end
				if different_num_syl then
					table.insert(temp_rhyme_list[index].num_syl, v.num_syl[1])
				end
			end
		end
		rhyme_list = temp_rhyme_list
	end

	local m_IPA_format = require("Module:IPA").format_IPA_full
	local parts = {}
	local function ins(text)
		table.insert(parts, text)
	end

	local do_collapse = false

	if pronobj.pron_list then
		if pl_lect_prons then
			do_collapse = true
			ins('<div class="vsSwitcher" data-toggle-category="pronunciations" style="width: {width}em; max-width:100%;"><span class="vsToggleElement" style="float: right;">&nbsp;</span>\n')
		end
		ins("*" .. m_IPA_format { lang = lang, items = pronobj.pron_list })
	end

	local em_length

	if pl_lect_prons then
		if do_collapse then
			ins('\n<div class="vsHide">\n')
		end
		local m_format_qualifiers = require("Module:accent qualifier").format_qualifiers
		-- First groups the lects into their lect groups.
		local grouped_lects = {}
		for lect, lect_prons in pairs(pl_lect_prons) do
			local lect_group = data.lects[lect].group
			if grouped_lects[lect_group] == nil then grouped_lects[lect_group] = {} end
			table.insert(grouped_lects[lect_group], { code = lect, prons = lect_prons })
		end
		-- And then displays each group in order.

		local maxlen = 0

		local function display_lect(value, indentation)
			local formatted = ("%s%s %s"):format(indentation,
				m_format_qualifiers(lang, { data.lects[value.code].name }),
				m_IPA_format { lang = lang, items = value.prons }
			)
			maxlen = math.max(maxlen, textual_len(formatted))
			ins("\n" .. formatted)
		end

		for group_index = 1, #data.lect_groups do
			local lects = grouped_lects[group_index]
			local group = data.lect_groups[group_index]
			if lects ~= nil then
				if group.single_lect then
					display_lect(lects[1], "*")
				else
					-- Checks to indent Goral under Lesser Polish.
					additional_indent = ""
					if group.indent_with_prec then
						additional_indent = "*"
						if grouped_lects[group_index - 1] == nil then
							ins("\n*" .. m_format_qualifiers(lang, { data.lect_groups[group_index - 1].name }) .. ":")
						end
					end
					-- Lect group header.
					ins("\n*" .. additional_indent .. m_format_qualifiers(lang, { group.name }) .. ":")
					-- The lects are sorted according to their <index> value.
					table.sort(lects, function (a, b) return data.lects[a.code].index < data.lects[b.code].index end)
					for _, lect in ipairs(lects) do
						display_lect(lect, "**" .. additional_indent)
					end
				end
			end
		end

		if do_collapse then
			ins('\n</div></div>\n')
		end

		em_length = math.floor(maxlen * 0.68)
	end

	if args.audios then
		local format_audio = require("Module:audio").format_audio
		local audio_objs = parse_audio(lang, args.audios, pagename, "audios")
		local num_audios = #audio_objs
		for i, audio_obj in ipairs(audio_objs) do
			if num_audios > 1 and not audio_obj.caption then
				audio_obj.caption = "Audio " .. i
			end
			ins("\n* " .. format_audio(audio_obj))
		end
	end

	if #rhyme_list > 0 then
		ins("\n* " .. require("Module:rhymes").format_rhymes { lang = lang, rhymes = rhyme_list })
	end

	if do_hyph then
		ins("\n* ")
		if #hyph_list > 0 then
			local hyphs = {}
			for hyph_i, hyph_v in ipairs(hyph_list) do
				hyphs[hyph_i] = { hyph = {} }
				for syl_v in hyph_v:gmatch("[^.]+") do
					table.insert(hyphs[hyph_i].hyph, syl_v)
				end
			end
			ins(require("Module:hyphenation").format_hyphenations {
				lang = lang, hyphs = hyphs, caption = "Syllabification"
			})
		else
			ins("Syllabification: <small>[please specify syllabification manually]</small>")
			if mw.title.getCurrentTitle().nsText == "" then
				ins(("[[Category:%s entries with Template:%s-pr without syllabification]]"):format(
					lang:getFullName(), ilang))
			end
		end
	end

	if args.homophones then
		local homophone_list = parse_homophones(args.homophones, "homophones")
		ins("\n* " .. require("Module:homophones").format_homophones {
			lang = lang,
			homophones = homophone_list,
		})
	end

	local ret = table.concat(parts)
	if em_length then
		ret = m_str_utils.gsub(ret, "{width}", em_length)
	end

	return ret
end

return export
