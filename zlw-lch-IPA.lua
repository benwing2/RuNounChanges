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

-- Lect data later retrieved in the module.
local data

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local OVERTIE = u(0x361) -- COMBINING DOUBLE INVERTED BREVE

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
local function parse_pron_modifier(arg, parse_err, generate_obj, param_mods, splitchar)
	if arg:find("<") then
		param_mods.q = {type = "qualifier"}
		param_mods.qq = {type = "qualifier"}
		param_mods.a = {type = "labels"}
		param_mods.aa = {type = "labels"}
		param_mods.ref = {item_dest = "refs", type = "references"}
		return require(parse_utilities_module).parse_inline_modifiers(arg, {
			param_mods = param_mods,
			generate_obj = generate_obj,
			parse_err = parse_err,
			splitchar = splitchar or ",",
		})
		return retval
	else
		local retval = {}
		local split_arg = splitchar == "," and split_on_comma(arg) or rsplit(arg, splitchar)
		for _, term in ipairs(split_arg) do
			table.insert(retval, generate_obj(term))
		end
		return retval
	end
end


local function generate_audio_obj(arg)
	return {file = arg}
end


local function parse_audio(arg, parse_err)
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

	-- Split on semicolon instead of comma because some filenames have embedded commas not followed by a space
	-- (typically followed by an underscore).
	local retvals = parse_pron_modifier(arg, parse_err, generate_audio_obj, param_mods, "%s*;%s*")
	for i, retval in ipairs(retvals) do
		retval.lang = lang
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

--[[
	As can be seen from the last lines of the function, this returns a table of transcriptions,
	and if do_hyph, also a string being the hyphenation. These are based on a single spelling given,
	so the reason why the transcriptions are multiple is only because of the -yka alternating stress
	et sim. This only accepts single-word terms. Multiword terms are handled by multiword().
--]]
local function phonemic(txt, do_hyph, lang, is_prep, period, lect)
	local ante = 0
	local unstressed = is_prep or false
	local colloquial = true

	function tsub(s, r)
		txt, c = rsubn(txt, s, r)
		return c > 0
	end
	function lg(s) return s[lang] or s[1] end
	function tfind(s) return rfind(txt, s) end

	if tfind("[Åå]") then error("Please replace å with á.") end

	-- Save indices of uppercase characters before setting everything lowercase.
	local uppercase_indices
	if do_hyph then
		uppercase_indices = {}
		local capitals = ("[A-Z%s]"):format(lg {
			pl = "ĄĆĘŁŃÓŚŹŻ" --[[and the dialectal]] .. "ÁÉÔÛÝ" --[[and the MPl]] .. "ḾṔẂ",
			szl = "ÃĆŁŃŌŎÔÕŚŹŻ",
			csb = "ÔÒÃËÙÉÓĄŚŁŻŹĆŃ",
			["zlw-slv"] = "ÃÉËÊÓÕÔÚÙŃŻ",
			["pl-mas"] = "ÁÄÉŁŃÓÔŚÛŸŻŹ"
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

	-- Prevent palatisation of the special case kwazi-.
	tsub("^kwazi", "kwaz-i")

	-- falling diphthongs <au> and <eu>, and diacriticised variants
	tsub(lg { "([aeáé])u", csb = "([ae])ù" }, "%1U")

	-- rising diphthongs with <iV>
	local V = lg {
		pl = "aąeęioóuy" .. "áéôûý",
		szl = "aãeéioōŏôõuy",
		csb = "ôòãëùéóąeyuioa",
		["zlw-slv"] = "aãeéëêioóõôuúùyăĭŏŭŭùy̆ā",
		["pl-mas"] = "aáäeéioóôuûÿ"
	}
	tsub(("([^%s])" .. (lang == "zlw-slv" and "j" or "i") .. "([%s])"):format(V, V), "%1I%2")

	if txt:find("^*") then
		-- The symbol <*> before a word indicates it is unstressed.
		unstressed = true
		txt = txt:sub(2)
	elseif txt:find("^%^+") then
		-- The symbol <^> before a word indicates it is stressed on the ante-penult,
		-- <^^> on the ante-ante-penult, etc.
		ante = txt:gsub("(%^).*", "%1"):len()
		txt = txt:sub(ante + 1)
	elseif txt:find("^%+") then
		-- The symbol <+> indicates the word is stressed regularly on the penult. This is useful
		-- for avoiding the following checks to come into place.
		txt = txt:sub(2)
	else
		if tfind(".+[łlb][iy].+") then
			-- Some words endings trigger stress on the ante-penult or ante-ante-penult regularly.
			if tfind("liśmy$") or tfind("[bł]yśmy$") or tfind("liście$") or tfind("[bł]yście$") then
				ante = 2
			elseif tfind("by[mś]?$") and not tfind("ła?by[mś]?$") then
				ante = 1
				colloquial = false
			end
		end
		-- Recognise <-yka> and its declined form and automatically assign it an antepenult stress.
		if tfind(".+[yi][kc].+") and lect == nil then
			local endings = lg {
				{ "k[aąęio]", "ce", "kach", "kom" },
				szl = { "k[aãio]", "ce", "kacj", "kōm", "kach" },
				csb = { "k[aeąãùóoô]", "ce", "kacj", "kóm", "kama", "kach" },
				["zlw-slv"] = { "k[aãêúóoôõ]", "cê", "kacj", "kji", "kóm", "kóma", "kamy", "kach" }
			}
			for _, v in ipairs(endings) do
				if tfind(("[yi]%s$"):format(v)) then
					ante = 1
					break
				end
			end
		end
		if lect == "mpl" then
			if tfind(".+[yi]j.+") then
				local endings = { "[ąáéo]", "[ée]j", "[áo]m", "ach" }
				for _, v in ipairs(endings) do
					if tfind(("[yi]j%s$"):format(v)) then
						ante = 1
					end
				end
			end
		end
	end

	-- TODO: mpl, csb, szl, slv, mas
	if not txt:find("%.") then
		-- Don't recognise affixes whenever there's only one vowel (or dipthong).
		local _, n_vowels = rsubn(txt, ("[%s]"):format(V), "")
		if n_vowels > 1 then

			-- syllabify common prefixes as separate
			local prefixes = {
				"do", "wy", "za", "aktyno", "akusto", "akwa", "anarcho", "andro", "anemo", "antropo", "arachno",
				"archeo", "archi", "arcy", "areo", "arytmo", "audio", "awio", "balneo", "biblio", "brachy", "broncho",
				"ceno", "centro", "centy", "chalko", "chiro", "chloro", "chole", "chondro", "choreo", "chromato",
				"chrysto", "cyber", "cyklo", "cztero", "ćwierć", "daktylo", "decy", "deka", "dendro", "dermato",
				"diafano", "dwu", "dynamo", "egzo", "ekstra", "elektro", "encefalo", "endo", "entero", "entomo", "ergo",
				"erytro", "etno", "farmako", "femto", "ferro", "fizjo", "flebo", "franko", "ftyzjo", "galakto",
				"galwano", "germano", "geronto", "giganto", "giga", "gineko", "giro", "gliko", "gloso", "glotto",
				"grafo", "granulo", "grawi", "haplo", "helio", "hemato", "hepta", "hetero", "hiper", "histo", "hydro",
				"info", "inter", "jedno", "kardio", "kortyko", "kosmo", "krypto", "kseno", "logo", "magneto", "między",
				"niby", "nie", "nowo", "około", "oksy", "onto", "ornito", "para", "pierwo", "pięcio", "pneumo", "poli",
				"ponad", "post", "poza", "proto", "pseudo", "psycho", "radio", "samo", "sfigmo", "sklero", "staro",
				"stereo", "tele", "tetra", "wice", "zoo", "żyro", "am[bf]i", "ang[il]o", "ant[ey]", "a?steno",
				"[be]lasto", "chro[mn]o", "cys?to", "de[rs]mo", "h?ekto", "[gn]eo", "hi[ge]ro", "kontra?", "me[gt]a",
				"mi[nl]i", "a[efg]ro", "[pt]rzy", "przed?", "wielk?o", "mi?elo", "eur[oy]", "ne[ku]ro", "allo", "astro",
				"atto", "brio", "heksa", "all?o", "at[mt]o", "a[rs]tro", "br?io", "heksa?", "pato", "ba[tr][oy]", "izo",
				"myzo", "m[ai]kro", "mi[mzk]o", "chemo", "gono", "kilo", "lipo", "nano", "kilk[ou]", "hem[io]",
				"home?o", "fi[lt]o", "ma[łn]o", "h[ioy]lo", "hip[ns]?o", "[fm]o[nt]o",
				-- <na-, po-, o-, u-> would hit too many false positives
			}
			for _, v in ipairs(prefixes) do
				if tfind("^" .. v) then
					local _, other_vowels = rsubn(v, ("[%s]"):format(V), "")
					if (n_vowels - other_vowels) > 0 then
						tsub(("^(%s)"):format(v), "%1.")
						break
					end
				end
			end

			if do_hyph then
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
					}, ["pl-mas"] = {
						"nóncz", "dło"
					}
				}

				for _, v in ipairs(suffixes) do
					if tsub(("(%s)$"):format(v), ".%1") then break end
				end

				-- syllabify <istka> as /ist.ka/
				if txt:find("[iy]st[kc]") then
					local endings = lg {
						{ "k[aąęio]", "ce", "kach", "kom", "kami" },
						szl = { "k[aãio]", "ce", "kami", "kacj", "kacach", "kōma" },
						csb = { "k[aãąioôòùó]", "ce", "kami", "kacj", "kacach", },
					}
					for _, v in ipairs(endings) do
						if tsub(("([iy])st(%s)$"):format(v), "%1st.%2") then break end
					end
				end
			end
		end
	end

	-- syllabification
	for _ = 0, 1 do
		tsub(("([%sU])([^%sU.']*)([%s])"):format(V, V, V), function (a, b, c)
			local function find(x) return rfind(b, x) end
			local function is_diagraph(thing)
				local r = find(thing:format("[crsd]z")) or find(thing:format("ch")) or find(thing:format("d[żź]"))
				if lect == "mpl" then return r or find(thing:format("b́")) end
				if lang == "zlw-slv" then return r or find(thing:format("gh")) end
				if lang == "pl-mas" then return r or find(thing:format("rż")) end
				return r
			end
			if ((ulen(b) < 2) or is_diagraph("^%s$")) then
				b = "." .. b
			else
				local i = 2
				if is_diagraph("^%s") then i = 3 end
				if usub(b, i, i):find("^[rlłI-]$") then
					b = "." .. b
				else
					b = ("%s.%s"):format(usub(b, 0, i - 1), usub(b, i))
				end
			end
			return ("%s%s%s"):format(a, b, c)
		end)
	end

	local hyph
	if do_hyph then
		-- Ignore certain symbols and diacritics for the hyphenation.
		hyph = txt:gsub("'", "."):gsub("-", "")
		if lang == "zlw-slv" then
			local BREVE = u(0x306)
			hyph = rsubn(hyph, "[Iăĭŏŭ" .. BREVE .. "ā]", {
				["I"] = "j",
				["ă"] = "a", ["ĭ"] = "i", ["ŏ"] = "o",
				["ŭ"] = "u", [BREVE] = "", ["ā"] = "a",
			})
		end
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

	-- handle digraphs
	tsub("ch", "x")
	tsub("[cs]z", { ["cz"]="t_ʂ", ["sz"]="ʂ" })
	tsub(lg { "rz", ["pl-mas"] = "rż" }, "R")
	tsub("d([zżź])", "d_%1")
	if lect == "mpl" then tsub("b́", "bʲ") end
	if lang == "zlw-slv" then tsub("gh", "ɣ") end

	-- basic orthographical rules
	-- not using lg() here for speed
	if lang == "pl" then
		local replacements = {
			-- vowels
			["e"]="ɛ", ["o"]="ɔ",
			["ą"]="ɔN", ["ę"]="ɛN",
			["ó"]="u", ["y"]="ɘ",
			-- consonants
			["c"]="t_s", ["ć"]="t_ɕ",
			["ń"]="ɲ", ["ś"]="ɕ", ["ź"]="ʑ",
			["ł"]="w", ["w"]="v", ["ż"]="ʐ",
			["g"]="ɡ", ["h"]="x",
		}
		if lect then
			replacements["é"] = "e"
			replacements["á"] = "ɒ"
			if lect == "mpl" then
				replacements["ę"] = "ɛ̃"
				replacements["ą"] = "ɔ̃"
				replacements["y"] = "ɨ"
				replacements["ó"] = "o"
				replacements["ł"] = "ɫ"
				replacements["ṕ"] = "pʲ"
				replacements["ḿ"] = "mʲ"
				replacements["ẃ"] = "vʲ"
				-- <b́> has no unicode character and is hence handled above
			else
				replacements["ô"] = "wɔ"
				replacements["û"] = "wu"
				replacements["ý"] = "Y"
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
		tsub(".", {
			-- vowels
			["e"]="ɛ", ["o"]="ɔ",
			["ō"]="o", ["ŏ"]="O",
			["ô"]="wɔ", ["õ"] = "ɔ̃",
			["y"] = "ɪ",
			-- consonants
			["c"]="t_s", ["ć"]="t_ɕ",
			["ń"]="ɲ", ["ś"]="ɕ", ["ź"]="ʑ",
			["ł"]="w", ["w"]="v", ["ż"]="ʐ",
			["g"]="ɡ", ["h"]="x",
		})
	elseif lang == "csb" then
		tsub(".", {
			-- vowels
			["e"]="ɛ", ["é"]="e", ["o"]="ɔ",
			["ó"]="o", ["ô"]="ɞ", ["ë"]="ɜ",
			["ò"]="wɛ", ["ù"]="wu", ["y"] = "Y",
			["ą"] = "ɔ̃",
			-- consonants
			["c"]="t_s", ["ć"]="t_ɕ",
			["ń"]="ɲ", ["ś"]="ɕ", ["ź"]="ʑ",
			["ł"]="w", ["w"]="v", ["ż"]="ʒ",
			["g"]="ɡ", ["h"]="x",
		})
	elseif lang == "zlw-slv" then
		tsub(".", {
			-- vowels
			["e"]="ɛ", ["é"]="e", ["o"]="ɔ",
			["ó"]="o", ["ô"]="ɵ", ["ë"]="ə", ["ê"]="E",
			["y"]="ɪ", ["ú"]="ʉ", ["ù"]="y",
			["õ"]="ɔ̃", ["ù̆"]="y̆", ["ā"]="aː", -- ãăĭŏŭ
			-- consonants
			["c"]="t_s",
			["ń"]="n",
			["w"]="v", ["ż"]="ʒ",
			["g"]="ɡ", ["h"]="x",
		})
	elseif lang == "pl-mas" then
		tsub(".", {
			-- vowels
			["á"]="ɒ", ["ä"]="æ",
			["e"]="ɛ", ["é"]="e",
			["o"]="ɔ", ["ó"]="o",
			["ô"]="wɔ", ["ÿ"]="Y",
			["y"]="Y", ["û"]="wu",
			-- consonants
			["c"]="t_s",
			["ń"]="ɲ", ["ś"]="ʃ",
			["ł"]="w", ["w"]="v", ["ż"]="ʒ",
			["g"]="ɡ", ["h"]="x", ["ź"]="ʑ",
		})
	end

	if lang == "csb" or lang == "zlw-slv" or lang == "pl-mas" then
		tsub("ʂ", "ʃ")
		tsub("ʐ", "ʒ")
	end

	-- palatalisation
	local palatise_into = { ["n"] = "ɲ", ["s"] = "ɕ", ["z"] = "ʑ" }
	tsub("([nsz])I", function (c) return palatise_into[c] end)
	tsub("([nsz])i", function (c) return palatise_into[c] .. "i" end)

	-- voicing and devoicing

	local T = "pftsʂɕkxʃx"
	local D = "bdzʐʑɡʒɣ"

	tsub(("([%s][.ˈ]?)v"):format(T), "%1f")
	tsub(("([%s][.ˈ]?)R"):format(T), "%1S")

	if lang == "zlw-slv" then
		tsub(("([%s][.ˈ]?)ɣ"):format(T), "%1x")
		tsub(("([%s][.ˈ]?)x"):format(D), "%1ɣ")
	end

	local function arr_list(x)
		local r = ""
		for i in pairs(x) do
			r = r .. i
		end
		return r
	end

	local devoice = {
		["b"] = "p",
		["d"] = "t",
		["ɡ"] = "k",
		["z"] = "s",
		["v"] = "f",
		["ʑ"] = "ɕ",
		["ʐ"] = "ʂ",
		["ʒ"] = "ʃ",
		["R"] = "S",
	}

	local trilled_rz = lang == "csb" or lang == "zlw-slv" or lang == "pl-mas"
	if not trilled_rz and lect then
		trilled_rz = data.lects[lect].trilled_rz
	end

	if trilled_rz then
		devoice["R"] = nil
	end

	if lang == "zlw-slv" then
		devoice["ɣ"] = "x"
	end

	local mpl_J = lect == "mpl" and "ʲ?" or ""

	local arr_list_devoice = arr_list(devoice)

	if not is_prep then
		tsub(("([%s])(%s)$"):format(arr_list_devoice, mpl_J), function (a, b)
			return devoice[a] .. (type(b) == "string" and b or "")
		end)
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

	local voice = {}
	for i, v in pairs(devoice) do
		voice[v] = i
	end

	local new_text
	local devoice_string = ("([%s])(%s[._ˈ]?[%s])"):format(arr_list_devoice, mpl_J, T)
	local voice_string = ("([%s])(%s[._ˈ]?[%s])"):format(arr_list(voice), mpl_J, D)
	local function devoice_func(a, b) return devoice[a] .. b end
	local function voice_func(a, b) return voice[a] .. b end
	while txt ~= new_txt do
		new_txt = txt
		tsub(devoice_string, devoice_func)
		tsub(voice_string, voice_func)
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

	-- Hyphen separator, e.g. to prevent palatisation of <kwazi->.
	tsub("-", "")

	tsub("_", OVERTIE)
	tsub("I", "j")
	tsub("U", "w")

	-- Handles stress.
	local function add_stress(stressed_syllable, force_initial_stress)
		local stressed_txt
		if force_initial_stress or (lect and data.lects[lect].initial_stress) then
			-- Deals with initially stressed lects.
			stressed_txt = "ˈ" .. txt
		else
			-- Accent elsewhere, usually ante-penult although can vary depending on
			-- the <stressed_syllable> value, counting backwards.
			local regex = ""
			for _ = 0, stressed_syllable do
				regex = regex .. "[^.]+%."
			end
			stressed_txt = rsub(txt, "%.(" .. regex .. "[^.]+)$", "ˈ%1")
			-- If no stress mark could have been placed, it can only be initial,
			-- e.g. in monosyllables.
			if not rfind(stressed_txt, "ˈ") then
				stressed_txt = "ˈ" .. stressed_txt
			end
		end
		return stressed_txt
	end

	local should_stress = not (unstressed or txt:find("ˈ"))
	local prons = should_stress and add_stress(ante) or txt

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
						error(("'%s' is not a supported Middle Polish period, try with 'early' or 'late'."):format(period))
					end
				end
			end
		else
			if should_stress and ante > 0 and colloquial then
				local stressed_antepenult = add_stress(0)
				if stressed_antepenult ~= prons then
					prons = { prons, stressed_antepenult }
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

-- TODO: This might slow things down if used too much?
local function table_insert_if_absent(t, s)
	for _, v in ipairs(t) do
		if v == s then return end
	end
	table.insert(t, s)
end

-- Returns rhyme from a transcription.
local function do_rhyme(pron, lang)
	local V = ({ pl = "aɛiɔuɘ", szl = "aãɛiɔouɪ", csb = "aãɛeɜiɔoõɞu", ["zlw-slv"] = "aãɛeĭɪŏɔɵŭʉy", ["pl-mas"] = "aɒæɛeiɔou"})[lang]
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
	elseif term:find(" ") then

		-- TODO: repeated
		function lg(s)
			return s[lang] or s[1]
		end

		local prepositions = lg {
			{
				"beze?", "na", "dla", "do", "ku", "nade?", "o", "ode?", "po", "pode?", "przede?", "przeze?", "przy",
				"spode?", "u", "we?", "z[ae]?", "znade?", "zza",
			}, szl = {
				"bezy?", "na", "dlŏ", "d[oō]", "ku", "nady?", "ô", "ôdy?", "po", "pody?", "przedy?", "przezy?", "przi",
				"spody?", "u", "w[ey]?", "z[aey]?", "[śs]", "znady?"
			}, csb = {
				"beze?", "na", "dlô", "do", "kù", "nade?", "ò", "òde?", "pò", "pòde?", "przede?", "przeze?", "przë",
				"spòde?", "ù", "we?", "wew", "z[ae]?", "zez", "zeza", "zó", "znade?"
			}, ["zlw-slv"] = {
				"dlo", "dô", "na", "nade?", "przêde?", "przêze?", "przë", "pô", "pôde?", "sê?", "vô", "we?", "wôde?",
				"wù", "za"
			}, ["pl-mas"] = {
				"dlá", "do", "ku", "na", "nade?", "po", "pode?", "ponade?", "poza", "prżede?", "prżeze", "prżi", "we?",
				"ze?", "za", "ô", "ôde?", "û", "beze?"
			}
		}

		local p
		local contains_preps = false

		for word in term:gmatch("[^ ]+") do
			local is_prep = false
			for _, prep in ipairs(prepositions) do
				if (rfind(word, ("^%s$"):format(prep))) then
					is_prep = true
					contains_preps = true
					break
				end
			end
			local v = phonemic(word, false, lang, is_prep, period, lect)
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
		return phonemic(term, lect ~= "mpl", lang, false, period, lect)
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
		if rfind(sub, "^~") then
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
local function normalise_input(term, pagename)
	local function check_af(str, af, reg, repl, err_msg)
		reg = reg:format(af)
		if not rfind(str, reg) then
			error(("the word does not %s with %s!"):format(err_msg, af))
		end
		return str:gsub(reg, repl)
	end

	local function check_pref(str, pref) return check_af(str, pref, "^(%s)", "%1.", "start") end
	local function check_suf(str, suf) return check_af(str, suf, "(%s)$", ".%1", "end") end

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
function export.get_lect_pron_info(terms, pagename, lang, lect, period)
	if #terms == 1 and terms[1].pron == "-" then
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
		respelling = normalise_input(respelling, pagename)
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
			local merged_qualifiers = term.q
			if additional_qualifier then
				merged_qualifiers = require(table_module).shallowcopy(merged_qualifiers)
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
				table_insert_if_absent(hyph_list, hyph)
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
			process_args[lect] = {},
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

	local pronobj = export.get_lect_pron_info(terms, pagename, ilang)
	local hyph_list, rhyme_list, do_hyph = pronobj.hyph_list, pronobj.rhyme_list, pronobj.do_hyph

	local pl_lect_prons

	if ilang == "pl" then
		for lect, _ in pairs(data.lects) do
			if args[lect] then
				if pl_lect_prons == nil then pl_lect_prons = {} end
				pl_lect_prons[lect] = export.get_lect_pron_info(
					parse_respellings_with_modifiers(args[lect], lect),
					pagename,
					"pl",
					lect,
					args[lect .. "_period"]
				).pron_list
			end
		end
	end

	if args.hyphs then
		if args.hyphs == "-" then
			do_hyph = false
		else
			hyph_list = {}
			for v in args.hyphs:gmatch("[^;]+") do
				table.insert(hyph_list, v)
			end
			do_hyph = true
		end
	end

	if args.rhymes then
		if args.rhymes == "-" then
			rhyme_list = {}
		elseif args.rhymes ~= "+" then
			rhyme_list = {}
			for v in args.rhymes:gmatch("[^;]+") do
				if rfind(v, ".+/.+") then
					table.insert(rhyme_list, {
						rhyme = rsub(v, "/.+", ""),
						num_syl = { tonumber(rsub(v, ".+/", "")) },
					})
				else
					error(("The manual rhyme %s did not specify syllable number as RHYME/NUM_SYL."):format(v))
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
	local ret = ""

	local do_collapse = false

	if pronobj.pron_list then
		if pl_lect_prons then
			do_collapse = true
			ret = '<div class="vsSwitcher" data-toggle-category="pronunciations" style="width: {width}em; max-width:100%;"><span class="vsToggleElement" style="float: right;">&nbsp;</span>\n'
		end
		ret = ret .. "*" .. m_IPA_format { lang = lang, items = pronobj.pron_list }
	end

	if pl_lect_prons then
		if do_collapse then
			ret = ret .. '\n<div class="vsHide">\n'
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
			ret = ret .. "\n" .. formatted
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
							ret = ret .. "\n*" .. m_format_qualifiers(lang, { data.lect_groups[group_index - 1].name }) .. ":"
						end
					end
					-- Lect group header.
					ret = ret .. "\n*" .. additional_indent ..
						m_format_qualifiers(lang, { group.name }) .. ":"
					-- The lects are sorted according to their <index> value.
					table.sort(lects, function (a, b) return data.lects[a.code].index < data.lects[b.code].index end)
					for _, lect in ipairs(lects) do
						display_lect(lect, "**" .. additional_indent)
					end
				end
			end
		end

		if do_collapse then
			ret = ret .. '\n</div></div>\n'
		end

		local em_length = math.floor(maxlen * 0.68)

		ret = m_str_utils.gsub(ret, "{width}", em_length)
	end

	if args.audios then
		local format_audio = require("Module:audio").format_audio
		local audio_index = 1
		for audio in args.audios:gmatch("[^;]+") do
			local caption = "Audio " .. audio_index
			if audio:find("<[^<>]+>$") then
				caption = caption .. ", ''" ..
					(audio:match("<([^<>]+)>$"))
						:gsub("#", pagename)
						:gsub("~", pagename .. " się")
					.. "''"
				audio = (audio:gsub("<[^<>]+>$", ""))
			end
			ret = ("%s\n*%s"):format(ret, format_audio {
				lang = lang,
				file = audio:gsub("#", pagename),
				caption = caption,
			})
			audio_index = audio_index + 1
		end
	end

	if #rhyme_list > 0 then
		ret = ("%s\n*%s"):format(ret, require("Module:rhymes").format_rhymes { lang = lang, rhymes = rhyme_list })
	end

	if do_hyph then
		ret = ret .. "\n*"
		if #hyph_list > 0 then
			local hyphs = {}
			for hyph_i, hyph_v in ipairs(hyph_list) do
				hyphs[hyph_i] = { hyph = {} }
				for syl_v in hyph_v:gmatch("[^.]+") do
					table.insert(hyphs[hyph_i].hyph, syl_v)
				end
			end
			ret = ret .. require("Module:hyphenation").format_hyphenations {
				lang = lang, hyphs = hyphs, caption = "Syllabification"
			}
		else
			ret = ret .. "Syllabification: <small>[please specify syllabification manually]</small>"
			if mw.title.getCurrentTitle().nsText == "" then
				ret = ("%s[[Category:%s-pronunciation_without_hyphenation]]"):format(ret, ilang)
			end
		end
	end

	if args.homophones then
		local homophone_list = {}
		for v in args.homophones:gmatch("[^;]+") do
			if v:find("<.->$") then
				table.insert(homophone_list, {
					term = v:gsub("<.->$", ""),
					qualifiers = { (v:gsub(".+<(.-)>$", "%1")) },
				})
			else
				table.insert(homophone_list, { term = v })
			end
		end
		ret = ("%s\n*%s"):format(ret, require("Module:homophones").format_homophones {
			lang = lang,
			homophones = homophone_list,
		})
	end

	return ret
end

return export
