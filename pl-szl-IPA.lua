--[[

	TODO: Decide on whether we want the Northern Borderlands dialect.
		The general consensus is to including it by doing the consonant subsitution and put the transcription in brackets
		Also the SBD should be included

--]]

local export = {}

local u = mw.ustring.char
local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub
local rsplit = mw.text.split
local ulen = mw.ustring.len
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub

local m_table = require("Module:table")
local m_IPA = require("Module:IPA")
local qualifier_module = "Module:qualifier"

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local OVERTIE = u(0x361) -- COMBINING DOUBLE INVERTED BREVE
local TEMP1 = u(0xFFF0)

--[=[
About dialects and dialect groups:

A "dialect" describes, approximately, a single way of pronouncing the words of a language. Different dialects generally represent distinct groups of speakers, separately geographically, ethnically, socially or temporally. Within a single
dialect it is possible to have more than one output for a given input; for example, words with rising diphthongs tend to
have two outputs, a "faster" one with the ''i'' or ''u'' in hiatus pronounced as /j/ or /w/, and a "slower" one with
the ''i'' or ''u'' in hiatus pronounced as /i/ or /u/. Another example concerns initial ''es-'' and ''ex-'' followed
by a consonant, where the initial ''e-'' may be pronounce as either /e/ or /i/. In some cases, as in [[experiência]],
this results in four outputs. Some outputs may have associated qualifiers; e.g. the "faster" version of hiatus ''i'' and
''u'' is marked ''faster pronunciation'', and the "slower" version marked ''slower pronunciation''; but the variants in
initial ''esC-'' and ''exC-'' are currently unmarked. The difference between multiple outputs in a single dialect and
multiple dialects is that the multiple outputs represent different ways the same speaker might pronounce a given input
in different circumstances, or represent idiolectal variation that cannot clearly be assigned to a given sociolinguistic
(e.g. geographic, ethnic, social, temporal, etc.) identity.

A "dialect group" groups related dialects. For example, for Portuguese, the module currently defines two dialect
groups: Brazil and Portugal. Within each are several dialects. This concerns the display of the dialects: each dialect
group by default displays as a single line, showing the "representative" dialect of the group, with the individual
dialects hidden and accessible using a toggle dropdown button labeled "More" on the right side of the line. It is
quite possible to imagine multiple levels of dialect groups (e.g. it might make sense to view the current "Northern
Portugal" dialect as its own group, with subdialects Porto/Minho and Transmontano; when this dialect displays, it
in turn hides the subdialects under a "More" button). However, support for this nesting isn't yet provided.
]=]

-- Dialects and subdialects:
export.all_dialects_by_lang = {}
export.all_dialect_groups_by_lang = {
	pl = {
		pl = {"pl-standard"},
		mpl = {"mpl-early", "mpl-late"},
	},
	szl = {
		szl = {"szl-standard", "opolskie"},
	},
}

local dialect_to_lang = {}
local dialect_to_dialect_group = {}
local dialect_group_to_lang = {}
for lang, dialect_groups in pairs(export.all_dialect_groups_by_lang) do
	export.all_dialects_by_lang[lang] = {}
	for group, dialects in pairs(dialect_groups) do
		dialect_group_to_lang[group] = lang
		for _, dialect in ipairs(dialects) do
			dialect_to_lang[dialect] = lang
			dialect_to_dialect_group[dialect] = group
			table.insert(export.all_dialects_by_lang[lang], dialect)
		end
	end
end

for lang, all_dialects in pairs(export.all_dialects_by_lang) do
	export.all_dialect_groups_by_lang[lang].all = all_dialects
end

export.all_dialect_descs = {
	-- dialect groups
	["pl"] = "Polish",
	["mpl"] = "Middle Polish",
	["szl"] = "Silesian",

	-- dialects
	["pl-standard"] = "Standard Polish",
	["mpl-early"] = "16<sup>th</sup> c. Middle Polish",
	["mpl-late"] = "17<sup>th</sup>–18<sup>th</sup> c. Middle Polish",
	["szl-standard"] = "Standard Silesian",
	["opolskie"] = "Opolskie",
}

--[[
	As can be seen from the last lines of the function, this returns a table of transcriptions,
	and if do_hyph, also a string being the hyphenation. These are based on a single spelling given,
	so the reason why the transcriptions are multiple is only because of the -yka alternating stress
	et sim. This only accepts single-word terms. Multiword terms are handled by multiword().
--]]
local function phonemic(txt, dialect, do_hyph, is_prep)
	local ante = 0
	local unstressed = is_prep or false
	local colloquial = true
	local group = dialect_to_dialect_group[dialect]

	function tsub(s, r)
		txt, c = rsubn(txt, s, r)
		return c > 0
	end
	function lg(s) return s[group] or s[1] end
	function tfind(s) return rfind(txt, s) end

	-- Save indices of uppercase characters before setting everything lowercase.
	local uppercase_indices
	if do_hyph then
		uppercase_indices = {}
		local capitals = ("[A-Z%s]"):format(lg {
			pl = "ĄĆĘŁŃÓŚŹŻ",
			mpl = "ĄÁÅĆĘÉŁḾŃÓṔŚẂŹŻ",
			szl = "ÃĆŁŃŌŎÔÕŚŹŻ",
		})
		if tfind(capitals) then
			local i = 1
			local str = rsub(txt, "[.']", "")
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

	-- Prevent palatalization of the special case kwazi-.
	tsub("^kwazi", "kwaz-i")

	-- falling diphthongs <au> and <eu>, and diacriticised variants
	tsub(lg { "([ae])u", mpl = "([aáåeé])u" }, "%1U")

	-- rising diphthongs with <iV>
	local V = lg { pl = "aąeęioóuy", mpl = "aąáåeęéioóuy", szl = "aãeéioōŏôõuy" }
	tsub(("([^%s])i([%s])"):format(V, V), "%1I%2")

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
		if tfind(".+[yi][kc].+") then
			local endings = lg {
				{ "k[aąęio]", "ce", "kach", "kom" },
				szl = { "k[aãio]", "ce", "kacj", "kōm" }
			}
			for _, v in ipairs(endings) do
				if tfind(("[yi]%s$"):format(v)) then
					ante = 1
				end
			end
		end
		if group ~= "pl" then
			if tfind(".+[yi]j.+") then
				local endings = lg {
					mpl = { "[ąåéo]", "[ée]j", "[áo]m", "ach" },
					szl = { "[ŏeiõo]", "ōm", "ach" },
				}
				for _, v in ipairs(endings) do
					if tfind(("[yi]j%s$"):format(v)) then
						ante = 1
					end
				end
			end
		end
	end

	-- TODO: mpl and szl
	if not txt:find("%.") then
		-- Don't recognise affixes whenever there's only one vowel (or dipthong).
		local _, n_vowels = rsubn(txt, ("[%s]"):format(V), "")
		if n_vowels > 1 then

			-- syllabify common prefixes as separate
			local prefixes = {
				"[be]lasto", "[fm]o[nt]o", "[gn]eo", "[pt]rzy",
				"a?steno", "a[efg]ro", "a[rs]tro", "aktyno", "akusto", "akwa", "all?o", "allo", "am[bf]i", "anarcho",
				"andro", "anemo", "ang[il]o", "ant[ey]", "antropo", "arachno", "archeo", "archi", "arcy", "areo",
				"arytmo", "astro", "at[mt]o", "atto", "audio", "awio",
				"ba[tr][oy]", "balneo", "biblio", "br?io", "brachy", "brio", "broncho",
				"ceno", "centro", "centy", "chalko", "chemo", "chiro", "chloro", "chole", "chondro", "choreo",
				"chro[mn]o", "chromato", "chrysto", "cyber", "cyklo", "cys?to", "cztero",
				"daktylo", "de[rs]mo", "decy", "deka", "dendro", "dermato", "diafano", "do", "dwu", "dynamo",
				"egzo", "ekstra", "elektro", "encefalo", "endo", "entero", "entomo", "ergo", "erytro", "etno",
				"eur[oy]",
				"farmako", "femto", "ferro", "fi[lt]o", "fizjo", "flebo", "franko", "ftyzjo",
				"galakto", "galwano", "germano", "geronto", "giga", "giganto", "gineko", "giro", "gliko", "gloso",
				"glotto", "gono", "grafo", "granulo", "grawi",
				"h?ekto", "h[ioy]lo", "haplo", "heksa", "heksa?", "helio", "hem[io]", "hemato", "hepta", "hetero",
				"hi[ge]ro", "hip[ns]?o", "hiper", "histo", "home?o", "hydro",
				"info", "inter", "izo",
				"jedno",
				"kardio", "kilk[ou]", "kilo", "kontra?", "kortyko", "kosmo", "krypto", "kseno",
				"lipo", "logo",
				"m[ai]kro", "ma[łn]o", "magneto", "me[gt]a", "mi?elo", "mi[mzk]o", "mi[nl]i", "między", "myzo",
				"nano", "ne[ku]ro", "niby", "nie", "nowo",
				"około", "oksy", "onto", "ornito",
				"para", "pato", "pierwo", "pięcio", "pneumo", "poli", "ponad", "post", "poza", "proto", "przed?",
				"pseudo", "psycho",
				"radio",
				"samo", "sfigmo", "sklero", "staro", "stereo",
				"tele", "tetra",
				"wice", "wielk?o", "wy",
				"za", "zoo",
				"ćwierć",
				"żyro",
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
				-- TODO: szl
				local suffixes = lg {
					pl = {
						"nąć",
						"[sc]tw[aou]", "[sc]twie", "[sc]tw[eo]m", "[sc]twami", "[sc]twach",
						"dztw[aou]", "dztwie", "dztw[eo]m", "dztwami", "dztwach",
						"dł[aou]", "dł[eo]m", "dłami", "dłach",
						"[czs]j[aeięąo]", "[czs]jom", "[czs]jami", "[czs]jach",
					}, szl = {
						"nōńć", "dło",
					}
				}

				for _, v in ipairs(suffixes) do
					if tsub(("(%s)$"):format(v), ".%1") then break end
				end

				-- syllabify <istka> as /ist.ka/
				if txt:find("[iy]st[kc]") then
					local endings = lg {
						{ "k[aąęio]", "ce", "kach", "kom", "kami" },
						szl = { "k[aãio]", "ce", "kami", "kacj", "kacach", "kōma?" },
					}
					for _, v in ipairs(endings) do
						if tsub(("([iy])st(%s)$"):format(v), "%1st.%2") then break end
					end
				end
			end
		end
	end

	-- Syllabify by adding a period (.) between syllables. There may already be user-supplied syllable divisions
	-- (period, single quote or hyphen), which we need to respect. This works by replacing each sequence of VC*V with
	-- V.V, V.CV, V.CRV (where R is a liquid) or otherwise VC.C+V, i.e. if there is more than one consonant, put the
	-- syllable boundary after the frist consonant unless the cluster consists of consonant + liquid. The main
	-- trickiness is due to digraphs (cz, rz, sz, dz, ch, dż, dź, and also b́ in Middle Polish, since there's no
	-- single Unicode character for this). We need to do the whole process twice since each VC*V sequence overlaps
	-- the next one.
	for _ = 0, 1 do
		tsub(("([%sU])([^%sU.']*)([%s])"):format(V, V, V), function(before_v, cons, after_v)
			if ulen(cons) < 2 then
				cons = "." .. cons
			else
				local first_two = usub(cons, 1, 2)
				local first, rest
				if rfind(first_two, "^[crsd]z$") or first_two == "ch" or rfind(first_two, "^d[żź]$") or
					group == "mpl" and cluster == "b́" then
					first, rest = rmatch(cons, "^(..)(.*)$")
				else
					first, rest = rmatch(cons, "^(.)(.*)$")
				end
				if rfind(rest, "^[rlłI-]$") then
					cons = "." .. cons
				else
					cons = first .. "." .. rest
				end
			end
			return before_v .. cons .. after_v
		end)
	end

	local hyph
	if do_hyph then
		hyph = txt:gsub("'", "."):gsub("-", ""):lower()
		-- Restore uppercase characters.
		if uppercase_indices then
			-- str_i loops through all the characters of the string
			-- list_i loops as above but doesn't count dots
			-- array_i loops through the indices at which the capital letters are
			local str_i, list_i, array_i = 1, 1, 1
			local function h_sub(x, y) return usub(hyph, x, y) end
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
	tsub("[crs]z", { ["cz"]="t_ʂ", ["rz"]="R", ["sz"]="ʂ" })
	tsub("d([zżź])", "d_%1")
	if group == "mpl" then tsub("b́", "bʲ") end

	-- basic orthographical rules
	-- not using lg() here for speed
	if group == "pl" then
		tsub(".", {
			-- vowels
			["e"]="ɛ", ["o"]="ɔ",
			["ą"]="ɔN", ["ę"]="ɛN",
			["ó"]="u", ["y"]="ɨ",
			-- consonants
			["c"]="t_s", ["ć"]="t_ɕ",
			["ń"]="ɲ", ["ś"]="ɕ", ["ź"]="ʑ",
			["ł"]="w", ["w"]="v", ["ż"]="ʐ",
			["g"]="ɡ", ["h"]="x",
		})
	elseif group == "mpl" then
		tsub(".", {
			-- vowels
			["á"]="ɒ", ["å"]="ɒ",
			["ę"]="ɛ̃", ["ą"]="ɔ̃",
			["e"]="ɛ", ["o"]="ɔ",
			["é"]="e", ["ó"]="o",
			["y"]="ɨ",
			-- consonants
			["ṕ"]="pʲ", -- <b́> has no unicode character and is hence handled above
			["ḿ"]="mʲ", ["ẃ"]="vʲ",
			["c"]="t_s", ["ć"]="t_ɕ",
			["ń"]="ɲ", ["ś"]="ɕ", ["ź"]="ʑ",
			["ł"]="ɫ", ["w"]="v", ["ż"]="ʐ",
			["g"]="ɡ", ["h"]="x",
		})
	elseif group == "szl" then
		tsub(".", {
			-- vowels
			["e"]="ɛ", ["o"]="ɔ",
			["ō"]="o", ["ŏ"]="O",
			["ô"]="wɔ", ["y"]="ɨ",
			["õ"] = "ɔ̃", ["ã"] = "ã",
			-- consonants
			["c"]="t_s", ["ć"]="t_ɕ",
			["ń"]="ɲ", ["ś"]="ɕ", ["ź"]="ʑ",
			["ł"]="w", ["w"]="v", ["ż"]="ʐ",
			["g"]="ɡ", ["h"]="x",
		})
	end

	-- palatalization
	local palatalize_into = { ["n"] = "ɲ", ["s"] = "ɕ", ["z"] = "ʑ" }
	tsub("([nsz])I", function (c) return palatalize_into[c] end)
	tsub("([nsz])i", function (c) return palatalize_into[c] .. "i" end)

	-- voicing and devoicing

	local T = "ptsʂɕkx"
	local D = "bdzʐʑɡ"

	tsub(("([%s][.ˈ]?)v"):format(T), "%1f")
	tsub(("([%s][.ˈ]?)R"):format(T), "%1S")

	local function arr_list(x)
		local r = ""
		for i in pairs(x) do
			r = r .. i
		end
		return r
	end

	local devoice = {
		["b"] = "p", ["d"] = "t", ["ɡ"] = "k",
		["z"] = "s", ["v"] = "f",
		["ʑ"] = "ɕ", ["ʐ"] = "ʂ", ["R"] = "S",
	}
	local mpl_J = lg { "", mpl = "ʲ?" }

	local arr_list_devoice = arr_list(devoice)

	if not is_prep then
		tsub(("([%s])(%s)$"):format(arr_list_devoice, mpl_J), function (a, b)
			return devoice[a] .. (type(b) == "string" and b or "")
		end)
	end

	if group ~= "mpl" then
		tsub("S", "ʂ")
		tsub("R", "ʐ")
	end

	local voice = {}
	for i, v in pairs(devoice) do
		voice[v] = i
	end

	local new_text
	local devoice_string = ("([%s])(%s[._]?[%s])"):format(arr_list_devoice, mpl_J, T)
	local voice_string = ("([%s])(%s[._]?[%s])"):format(arr_list(voice), mpl_J, D)
	local function devoice_func(a, b) return devoice[a] .. b end
	local function voice_func(a, b) return voice[a] .. b end
	while txt ~= new_txt do
		new_txt = txt
		tsub(devoice_string, devoice_func)
		tsub(voice_string, voice_func)
	end

	if group == "pl" then
		-- nasal vowels
		tsub("N([.ˈ]?[pb])", "m%1")
		tsub("N([.ˈ]?[ɕʑ])", "ɲ%1")
		tsub("N([.ˈ]?[td]_[ɕʑ])", "ɲ%1")
		tsub("N([.ˈ]?[tdsz])", "n%1")
		tsub("N([.ˈ]?[wl])", "%1")
		tsub("ɛN$", "ɛ")
		tsub("N", "w̃")
	end

	-- Hyphen separator, e.g. to prevent palatalization of <kwazi->.
	tsub("-", "")

	tsub("_", OVERTIE)
	tsub("I", "j")
	tsub("U", "w")

	-- stress
	local function add_stress(a)
		local s = ""
		for _ = 0, a do
			s = s .. "[^.]+%."
		end
		local r = rsub(txt, ("%%.(%s[^.]+)$"):format(s), "ˈ%1")
		if not rfind(r, "ˈ") then
			r = "ˈ" .. r
		end
		return (r:gsub("%.", ""))
	end

	local should_stress = not (unstressed or txt:find("ˈ"))
	local nosyl_txt = should_stress and add_stress(ante) or txt

	if is_prep then
		nosyl_txt = nosyl_txt .. "$"
	end

	local prons

	if group == "pl" then
		if should_stress and ante > 0 and colloquial then
			local colloquial_pron = add_stress(0)
			if colloquial_pron == nosyl_txt then
				prons = {{ phonemic = nosyl_txt }}
			else
				prons = {
					{ phonemic = nosyl_txt, q = "prescribed" },
					{ phonemic = colloquial_pron, q = "casual" },
				}
			end
		else
			prons = {{ phonemic = nosyl_txt }}
		end
	elseif group == "mpl" then
		if tfind("[RS]") then
			if dialect == "mpl-early" then
				prons = {{ phonemic = nosyl_txt:gsub("[RS]", "r̝") }}
			else
				prons = {{ phonemic = nosyl_txt:gsub("R", "ʐ"):gsub("S", "ʂ") }}
			end
		else
			prons = {{ phonemic = nosyl_txt }}
		end
	elseif group == "szl" then
		if tfind("O") then
			if dialect == "szl-standard" then
				prons = {{ phonemic = nosyl_txt:gsub("O", "ɔ") }}
			else
				prons = {{ phonemic = nosyl_txt:gsub("O", "ɔw") }}
			end
		else
			prons = {{ phonemic = nosyl_txt }}
		end
	else
		error(("Internal error: Unrecognized dialect group '%s'"):format(group))
	end

	if do_hyph then
		return prons, hyph
	else
		return prons
	end
end

-- Returns rhyme from a transcription.
local function do_rhyme(pron, lang)
	local V = ({ pl = "aɛiɔuɨ", szl = "aɛeiɔouɨ" })[lang]
	local num_syl = select(2, rsubn(pron, ("[%s]"):format(V), ""))
	return {
		rhyme = rsub(rsub(rsub(pron, "^.*ˈ", ""), ("^[^%s]-([%s])"):format(V, V), "%1"), "%.", ""),
		num_syl = num_syl
	}
end

--[[
	Handles a single input, returning a table of transcriptions. Returns also a string of
	hyphenation and a table of rhymes if it is a single-word term.
--]]
local function multiword(term, dialect)
	local group = dialect_to_dialect_group[dialect]

	if term:find("^%[.+%]$") then
		return {{ phonetic = term }}
	elseif term:find(" ") then
		local prepositions =
			group == "szl" and {
				"bezy?", "na", "dlŏ", "d[oō]", "ku",
				"nady?", "ô", "ôdy?", "po", "pody?", "przedy?",
				"przezy?", "przi", "spody?", "u", "w[ey]?",
				"z[aey]?", "[śs]", "znady?"
			} or {
				"beze?", "na", "dla", "do", "ku",
				"nade?", "o", "ode?", "po", "pode?", "przede?",
				"przeze?", "przy", "spode?", "u", "we?",
				"z[ae]?", "znade?", "zza",
			}

		local pronuns
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
			local word_pronuns = phonemic(word, dialect, false, is_prep)
			if not pronuns then
				pronuns = word_pronuns
			else
				local matches_up = #pronuns == #word_pronuns
				if matches_up then
					for i = 1, #pronuns do
						if pronuns[i].q ~= word_pronuns[i].q then
							matches_up = false
							break
						end
					end
				end
				if matches_up then
					-- We can just concatenate horizontally, in O(n) time.
					for i = 1, #pronuns do
						pronuns[i].phonemic = pronuns[i].phonemic .. " " .. word_pronuns[i].phonemic
					end
				else
					-- We have to check each combination for compatibility, in O(n^2) time. It's possible to
					-- optimize this but the number of pronunciations will never be more than a few, so it's not
					-- important.
					local result = {}
					for i = 1, #pronuns do
						for j = 1, #word_pronuns do
							if not pronuns[i].q or not word_pronuns[j].q or pronuns[i].q == word_pronuns[j].q then
								table.insert(result, {
									phonemic = pronuns[i].phonemic .. " " .. word_pronuns[j].phonemic,
									q = pronuns[i].q or word_pronuns[j].q
								})
							end
						end
					end
				end
			end
		end

		if contains_preps then
			local function assimilate_preps(str)
				local T = "ptsʂɕkx"
				local devoice_obstruent = {
					["d"] = "t",
					["v"] = "f",
					["z"] = "s",
				}
				str = rsub(str, ("([dvz])(%$ ˈ?[" .. T .. "])"),
					function(voiced, after) return devoice_obstruent[voiced] .. after end)
				if group == "szl" then
					local D = "bdzʐʑɡ"
					local voice_fricative = {
						["s"] = "z",
						["ɕ"] = "ʑ",
					}
					str = rsub(str, ("([sɕ])(%$ ˈ?[" .. D .. "])"),
						function(unvoiced, after) return voice_fricative[unvoiced] .. after end)
				end
				return rsub(str, "%$", "")
			end

			for _, pronun in ipairs(pronuns) do
				pronun.phonemic = assimilate_preps(pronun.phonemic)
			end
		end

		return pronuns
	else
		return phonemic(term, dialect, group ~= "mpl", false)
	end
end

-- This handles all the magic characters <*>, <^>, <+>, <.>, <#>.
local function canonicalize_respelling(respelling, pagename)

	local function check_af(str, af, reg, repl, err_msg)
		reg = reg:format(af)
		if not rfind(str, reg) then
			error(("the word does not %s with %s!"):format(err_msg, af))
		end
		return str:gsub(reg, repl)
	end

	local function check_pref(str, pref) return check_af(str, pref, "^(%s)", "%1.", "start") end
	local function check_suf(str, suf) return check_af(str, suf, "(%s)$", ".%1", "end") end

	if respelling == "#" then
		-- The diaeresis stands simply for {{PAGENAME}}.
		return pagename
	elseif (respelling == "+") or respelling:find("^%^+$") or (respelling == "*") then
		-- Inputs that are just '+', '*', '^', '^^', etc. are treated as
		-- if they contained the pagename with those symbols preceding it.
		return respelling .. pagename
	-- Handle syntax like <po.>, <.ka> and <po..ka>. This allows to not respell
	-- the entire word when all is needed is to specify syllabification of a prefix
	-- and/or a suffix.
	elseif respelling:find(".+%.$") then
		return check_pref(pagename, respelling:sub(1, -2))
	elseif respelling:find("^%..+") then
		return check_suf(pagename, respelling:sub(2))
	elseif respelling:find(".+%.%..+") then
		return check_suf(check_pref(pagename, respelling:gsub("%.%..+", "")), respelling:gsub(".+%.%.", ""))
	end

	return respelling

end

local function sort_things(lang, title, args_terms, args_quals, args_refs, args_period)

	local pron_list, hyph_list, rhyme_list, do_hyph = { {}, {}, {} }, { }, { {}, {}, {} }, false

	for index, term in ipairs(args_terms) do
		term = canonicalize_respelling(term, title)
		local pron, hyph = multiword(term, lang, args_period)
		local qualifiers = {}
		if args_quals[index] then
			for qual in args_quals[index]:gmatch("[^;]+") do
				table.insert(qualifiers, qual)
			end
		end
		local function new_pron(p, additional, dont_refs)
			local ret = {
				pron = ("/%s/"):format(p),
				qualifiers = qualifiers,
				refs = not dont_refs and {args_refs[index]},
			}
			if additional then
				local new_qualifiers = {}
				for _, v in ipairs(qualifiers) do
					table.insert(new_qualifiers, v)
				end
				table.insert(new_qualifiers, additional)
				ret.qualifiers = new_qualifiers
			end
			return ret
		end
		local should_rhyme = lang ~= "mpl"
		if type(pron) == "string" then
			table.insert(pron_list[1], new_pron(pron))
			if should_rhyme then
				table.insert(rhyme_list[1], do_rhyme(pron, lang))
			end
		elseif pron.phonetic then
			table.insert(pron_list[1], {
				pron = pron.phonetic,
				qualifiers = qualifiers,
				refs = {args_refs[index]},
			})
		else
			local double_trancript = ({
				pl = { "prescribed", "casual" },
				mpl = { "16<sup>th</sup> c.", "17<sup>th</sup>–18<sup>th</sup> c." },
				szl = { nil, "Opolskie" },
			})[lang]
			table.insert(pron_list[2], new_pron(pron[1], double_trancript[1]))
			table.insert(pron_list[3], new_pron(pron[2], double_trancript[2], true))
			if should_rhyme then
				table.insert(rhyme_list[2], do_rhyme(pron[1], lang))
				table.insert(rhyme_list[3], do_rhyme(pron[2], lang))
			end
		end
		if hyph then
			do_hyph = true
			if hyph:gsub("%.", "") == title then
				require("Module:table").insertIfNot(hyph_list, hyph)
			end
		end
	end

	-- TODO: looks rather slow.
	local function merge_subtables(t)
		local r = {}
		if #t[2] + #t[3] == 0 then
			return t[1]
		end
		for _, subtable in ipairs(t) do
			for _, value in ipairs(subtable) do
				table.insert(r, value)
			end
		end
		return r
	end

	pron_list = merge_subtables(pron_list)
	rhyme_list = merge_subtables(rhyme_list)

	return pron_list, hyph_list, rhyme_list, do_hyph
end

function export.mpl_IPA(frame)
	
	local args = require("Module:parameters").process(frame:getParent().args, {

		[1] = { list = true },
		["qual"] = { list = true, allow_holes = true },
		["q"] = { list = true, allow_holes = true, alias_of = "qual" },
		["period"] = {},
		["ref"] = { list = true, allow_holes = true },

		["title"] = {}, -- for debugging or demonstration only

	})

	local terms = args[1]

	if #terms == 0 then
		terms = { "#" }
	end

	return ("* %s %s"):format(require("Module:accent qualifier").format_qualifiers{ "Middle Polish" },
		require("Module:IPA").format_IPA_full(
			require("Module:languages").getByCode("pl"), (sort_things(
				"mpl",
				args.title or mw.title.getCurrentTitle().text,
				terms,
				args.qual,
				args.ref,
				args.period
			))
		)
	)

end

function export.IPA(frame)

	local arg_lang = frame.args.lang

	local params = {
		[1] = { list = true },
		["qual"] = { list = true, allow_holes = true },
		["q"] = { list = true, allow_holes = true, alias_of = "qual" },
		["hyphs"] = {}, ["h"] = { alias_of = "hyphs" },
		["rhymes"] = {}, ["r"] = { alias_of = "rhymes" },
		["audios"] = {}, ["a"] = { alias_of = "audios" },
		["homophones"] = {}, ["hh"] = { alias_of = "homophones" },
		["ref"] = { list = true, allow_holes = true },
		["pagename"] = {}, -- for debugging or demonstration only

	}

	if arg_lang == "pl" then
		params["mp"] = { list = true }
		params["mp_qual"] = { list = true, allow_holes = true }
		params["mp_q"] = { list = true, allow_holes = true, alias_of = "mp_qual" }
		params["mp_period"] = {}
		params["mp_ref"] = { list = true, allow_holes = true }
	end

	local args = require("Module:parameters").process(frame:getParent().args, process_args)

	local terms = args[1]
	local title = args.pagename or mw.title.getCurrentTitle().text

	if #terms == 0 then
		terms = { "#" }
	end

	local pron_list, hyph_list, rhyme_list, do_hyph = sort_things(arg_lang, title, terms, args.qual, args.ref)

	local mp_prons

	if arg_lang == "pl" then
		if #args.mp > 0 then
			mp_prons = (sort_things("mpl", title, args.mp, args.mp_qual, args.mp_ref, args.mp_period))
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
						num_syl = tonumber(rsub(v, ".+/", "")),
					})
				else
					error(("The manual rhyme %s did not specify syllable number as RHYME/NUM_SYL."):format(v))
				end
			end
		end
	end

	for ooi, oov in ipairs(rhyme_list) do
		oov.num_syl = { oov.num_syl }
		for coi = ooi + 1, #rhyme_list do
			local cov = rhyme_list[coi]
			if oov.rhyme == cov.rhyme then
				local add_ns = true
				for _, onv in ipairs(oov.num_syl) do
					if cov.num_syl == onv then
						add_ns = false
						break
					end
				end
				if add_ns then
					table.insert(oov.num_syl, cov.num_syl)
				end
				table.remove(rhyme_list, coi)
			end
		end
	end

	local lang = require("Module:languages").getByCode(arg_lang)

	local m_IPA_format = require("Module:IPA").format_IPA_full
	local ret = "*" .. m_IPA_format(lang, pron_list)

	if mp_prons then
		ret = ("%s\n*%s %s"):format(ret,
			require("Module:accent qualifier").format_qualifiers{ "Middle Polish" },
			m_IPA_format(lang, mp_prons)
		)
	end

	if args.audios then
		for v in args.audios:gmatch("[^;]+") do
			-- TODO: can I expand a template or is it a bad thing to do?
			ret = ("%s\n*%s"):format(ret, frame:expandTemplate { title = "audio", args = {
				arg_lang,
				v:gsub("#", title),
				"Audio",
			} })
		end
	end

	if #rhyme_list > 0 then
		ret = ("%s\n*%s"):format(ret, require("Module:rhymes").format_rhymes({ lang = lang, rhymes = rhyme_list }))
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
				ret = ("%s[[Category:%s-pronunciation_without_hyphenation]]"):format(ret, arg_lang)
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


--[==[
Compute the pronunciation for each given respelling of each dialect. `inputs` is an object listing the respellings and
associated properties for each dialect. `args_dialect` is the value of the {{para|dialect}} parameter, which can be
used to restrict the output to particular dialects. `pagename` is the page title (either the actual one or a value
specified for debugging or demonstration purposes).

The value of `inputs` is a table whose keys are dialect codes and whose values are objects with the following fields:
* `pre`: Text to display before the output pronunciations, from the <pre:...> inline modifier.
* `post`: Text to display after the output pronunciations, from the <post:...> inline modifier.
* `bullets`: Number of "bullets" (asterisks) to insert into the wikitext of the output pronunciations at the outermost
  level, to control the indentation, from the <bullets:...> inline modifier; defaults to 1.
* `terms`: List of objects describing the respellings. Each object has the following fields:
** `term`: The respelling. The value {+} is allowed for specifying a respelling that is the same as the pagename,
   and substitution specs of the form {[vol:vôl;ei:éi]} are allowed.
** `q`: List of left qualifiers to display before the pronunciation. The pronunciation itself may include one or more
   qualifiers, which are appended to any user-specified qualifiers.
** `ref`: List of references to display after the pronunciation. Each reference is as specified by the user, i.e. a
   string of the format parsed by {parse_references()} in [[Module:references]].

The output of this function is a list of "expressed dialects", i.e. per-dialect pronunciations. Specifically, it is a
list of objects, one per dialect group, with the following fields:
* `tag`: The tag text to show for the dialect group when displaying the default (hidden) tab for the dialect as a whole,
  where the representative pronunciation(s) of that dialect group (corresponding to the first object in `dialects`) is
  shown. The value can be `false` to show no tag text (if all dialect pronunciations are the same).
* `dialects`: A list of objects, each representing the pronunciation(s) of a specific dialect in the dialect group. Each
  object has the following fields:
** `tag`: The tag text to show for the dialect, or `false` to show no tag text (if all dialect pronunciations are the
   same).
** `represented_dialects`: A string representing the dialect code of the dialect represented by this object, or a list of
   such codes.
** `indent`: The level of indentation to display this dialect at. Generally 1 if there's only a single set of
   pronunciations for all dialects, otherwise 2. This controls the number of "bullets" (asterisks) to insert into the
   wikitext; see `bullets` just below.
** `bullets`: The value of `bullets` from the corresponding structure in `inputs`. The actual number of "bullets"
   (asterisks) inserted into the wikitext is `bullets` + `indent` - 1.
** `pre`: Text to display before the output pronunciation(s), from the `pre` value of the corresponding structure in
   `inputs`.
** `post`: Text to display before the output pronunciation(s), from the `post` value of the corresponding structure in
   `inputs`.
** `pronuns`: A list specifying the actual pronunciation(s) to display. Each object has the following fields:
*** `phonemic`: The phonemic IPA of the pronunciation (without surrounding slashes).
*** `phonetic`: The phonetic IPA of the pronunciation (without surrounding brackets).
*** `qualifiers`: The left qualifiers describing this particular pronunciation; a combination of any qualifiers
    generated by the code itself (e.g. ''faster pronunciation'', ''slower pronunciation'') followed by any qualifiers
	specified by the user for the corresponding input respelling. If there are no qualifiers, this field will be nil.
*** `refs`: A list of reference objects describing the references for this pronunciation. This comes from the
    corresponding user-specified references (if any) for the input respelling, passed through {parse_references()} in
	[[Module:references]], and is passed directly to {format_IPA_full()} in [[Module:IPA]]. If there are no references,
	this field will be nil.
]==]
function export.express_dialects(inputs, lang, args_dialect, pagename)
	local pronuns_by_dialect = {}
	local expressed_dialects = {}

	local function dodialect(dialect)
		pronuns_by_dialect[dialect] = {}
		for _, val in ipairs(inputs[dialect].terms) do
			local respelling = val.term
			respelling = canonicalize_respelling(respelling, pagename)

			local refs
			if #val.ref == 0 then
				refs = nil
			else
				refs = {}
				for _, refspec in ipairs(val.ref) do
					local this_refs = require("Module:references").parse_references(refspec)
					for _, this_ref in ipairs(this_refs) do
						table.insert(refs, this_ref)
					end
				end
			end

			local pronuns = multiword(respelling, dialect)
			for _, pronun in ipairs(pronuns) do
				local qualifiers = m_table.deepcopy(val.q)
				if pronun.q then
					m_table.insertIfNot(qualifiers, pronun.q)
				end
				pronun.qualifiers = #qualifiers > 0 and qualifiers or nil
				pronun.q = nil
				pronun.refs = refs
				m_table.insertIfNot(pronuns_by_dialect[dialect], pronun)
			end
		end
	end

	local function all_available(dialects)
		local available_dialects = {}
		for _, dialect in ipairs(dialects) do
			if pronuns_by_dialect[dialect] then
				table.insert(available_dialects, dialect)
			end
		end
		return available_dialects
	end

	local function express_dialect(dialects, indent)
		local hidden_tag, tag
		indent = indent or 1
		if type(dialects) == "string" then
			dialects = {dialects}
			tag = export.all_dialect_descs[dialects[1]]
			hidden_tag = export.all_dialect_descs[dialect_to_dialect_group[dialects[1]]]
		else
			tag = false
			hidden_tag = false
		end
		dialects = all_available(dialects)
		if #dialects == 0 then
			return
		end
		local dialect = dialects[1]

		-- If dialect specified, make sure it matches the requested dialect.
		local dialect_matches
		if not args_dialect then
			dialect_matches = true
		else
			local or_dialects = rsplit(args_dialect, "%s*,%s*")
			for _, or_dialect in ipairs(or_dialects) do
				local and_dialects = rsplit(or_dialect, "%s*%+%s*")
				local and_matches = true
				for _, and_dialect in ipairs(and_dialects) do
					local negate
					if and_dialect:find("^%-") then
						and_dialect = and_dialect:gsub("^%-", "")
						negate = true
					end
					local this_dialect_matches = false
					for _, part in ipairs(dialects) do
						if part == and_dialect then
							this_dialect_matches = true
							break
						end
					end
					if negate then
						this_dialect_matches = not this_dialect_matches
					end
					if not this_dialect_matches then
						and_matches = false
					end
				end
				if and_matches then
					dialect_matches = true
					break
				end
			end
		end
		if not dialect_matches then
			return
		end

		local new_dialect = {
			tag = tag,
			represented_dialects = dialects,
			pronuns = pronuns_by_dialect[dialect],
			indent = indent,
			bullets = inputs[dialect].bullets,
			pre = inputs[dialect].pre,
			post = inputs[dialect].post,
		}
		for _, hidden_tag_dialect in ipairs(expressed_dialects) do
			if hidden_tag_dialect.tag == hidden_tag then
				table.insert(hidden_tag_dialect.dialects, new_dialect)
				return
			end
		end
		table.insert(expressed_dialects, {
			tag = hidden_tag,
			dialects = {new_dialect},
		})
	end

	for dialect, _ in pairs(inputs) do
		dodialect(dialect)
	end

	local function diff(dialect1, dialect2)
		if not pronuns_by_dialect[dialect1] or not pronuns_by_dialect[dialect2] then
			return true
		end
		return not m_table.deepEquals(pronuns_by_dialect[dialect1], pronuns_by_dialect[dialect2])
	end
	if lang == "pl" then
		local mpl_early_late_different = diff("mpl-early", "mpl-late")
		local pl_mpl_different = diff("pl-standard", "mpl-early")

		if not mpl_early_late_different and not pl_mpl_different then
			-- All the same
			express_dialect(export.all_dialects_by_lang.pl)
		else
			-- Polish
			express_dialect("pl-standard")
			
			-- Middle Polish
			express_dialect("mpl-early")
			if mpl_early_late_different then
				express_dialect("mpl-late", 2)
			end
		end
	else
		local szl_standard_opolskie_different = diff("szl-standard", "opolskie")
		if not szl_standard_opolskie_different then
			-- All the same
			express_dialect(export.all_dialects_by_lang.szl)
		else
			express_dialect("szl-standard")
			express_dialect("opolskie", 2)
		end
	end
	return expressed_dialects
end


function export.show_IPA(frame)
	local frame_args = frame.args
	local iparams = {
		["lang"] = {required = true},
	}
	local iargs = require("Module:parameters").process(frame_args, iparams)
	local lang = iargs.lang
	if not export.all_dialect_groups_by_lang[lang] then
		local valid_values = {}
		for valid_lang, _ in pairs(export.all_dialect_groups_by_lang) do
			table.insert(valid_values, ("'%s'"):format(valid_lang))
		end
		table.sort(valid_values)
		error(("Unrecognized value '%s': for invocation argument lang=: Should be one of %s"):format(lang,
			table.concat(valid_values, ", ")))
	end
	local langobj = require("Module:languages").getByCode(lang, true)

	-- Create parameter specs
	local params = {
		[1] = {}, -- this replaces dialect group 'all'
		["dialect"] = {},
		["pagename"] = {},
	}
	for group, _ in pairs(export.all_dialect_groups_by_lang[lang]) do
		if group ~= "all" then
			params[group] = {}
		end
	end
	for _, dialect in ipairs(export.all_dialects_by_lang[lang]) do
		params[dialect] = {}
	end

	-- Parse arguments
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	-- Set inputs
	local inputs = {}
	-- If 1= specified, do all dialects (not including Middle Polish).
	if args[1] then
		for _, dialect in ipairs(export.all_dialects_by_lang[lang]) do
			if not dialect:find("^mpl") then
				inputs[dialect] = args[1]
			end
		end
	end
	-- Then do remaining dialect groups other than 'all', overriding 1= if given.
	for group, dialects in pairs(export.all_dialect_groups_by_lang[lang]) do
		if group ~= "all" and args[group] then
			for _, dialect in ipairs(dialects) do
				inputs[dialect] = args[group]
			end
		end
	end
	-- Then do individual dialect settings.
	for _, dialect in ipairs(export.all_dialects_by_lang[lang]) do
		if args[dialect] then
			inputs[dialect] = args[dialect]
		end
	end
	-- If no inputs given, set all dialects based on current pagename.
	if not next(inputs) then
		for _, dialect in ipairs(export.all_dialects_by_lang[lang]) do
			-- FIXME: Use + for consistency with Portuguese, Italian, Spanish, etc.
			inputs[dialect] = "#"
		end
	end

	-- Parse the arguments.
	local put
	for dialect, input in pairs(inputs) do
		if input:find("[<%[]") then
			local function parse_err(msg)
				error(msg .. ": " .. dialect .. "= " .. input)
			end
			if not put then
				put = require("Module:parse utilities")
			end
			-- We don't want to split off a comma followed by a space, as in [[rei morto, rei posto]], so replace
			-- comma+space with a special character that we later undo.
			input = rsub(input, ", ", TEMP1)
			-- Parse balanced segment runs involving either [...] (substitution notation) or <...> (inline modifiers).
			-- We do this because we don't want commas inside of square or angle brackets to count as respelling
			-- delimiters. However, we need to rejoin square-bracketed segments with nearby ones after splitting
			-- alternating runs on comma. For example, if we are given
			-- "a[x]a<q:learned>,[vol:vôl;ei:éi,ei]<q:nonstandard>", after calling
			-- parse_multi_delimiter_balanced_segment_run() we get the following output:
			--
			-- {"a", "[x]", "a", "<q:learned>", ",", "[vol:vôl;ei:éi,ei]", "", "<q:nonstandard>", ""}
			--
			-- After calling split_alternating_runs(), we get the following:
			--
			-- {{"a", "[x]", "a", "<q:learned>", ""}, {"", "[vol:vôl;ei:éi,ei]", "", "<q:nonstandard>", ""}}
			--
			-- We need to rejoin stuff on either side of the square-bracketed portions.
			local segments = put.parse_multi_delimiter_balanced_segment_run(input, {{"<", ">"}, {"[", "]"}})
			-- Not with spaces around the comma; see above for why we don't want to split off comma followed by space.
			local comma_separated_groups = put.split_alternating_runs(segments, ",")

			local parsed = {terms = {}}
			for i, group in ipairs(comma_separated_groups) do
				-- Rejoin bracketed segments with nearby ones, as described above.
				local j = 2
				while j <= #group do
					if group[j]:find("^%[") then
						group[j - 1] = group[j - 1] .. group[j] .. group[j + 1]
						table.remove(group, j)
						table.remove(group, j)
					else
						j = j + 2
					end
				end
				for j, segment in ipairs(group) do
					group[j] = rsub(segment, TEMP1, ", ")
				end

				local term = {term = group[1], ref = {}, q = {}}
				for j = 2, #group - 1, 2 do
					if group[j + 1] ~= "" then
						parse_err("Extraneous text '" .. group[j + 1] .. "' after modifier")
					end
					local modtext = group[j]:match("^<(.*)>$")
					if not modtext then
						parse_err("Internal error: Modifier '" .. group[j] .. "' isn't surrounded by angle brackets")
					end
					local prefix, arg = modtext:match("^([a-z]+):(.*)$")
					if not prefix then
						parse_err("Modifier " .. group[j] .. " lacks a prefix, should begin with one of " ..
							"'pre:', 'post:', 'ref:', 'bullets:' or 'q:'")
					end
					if prefix == "ref" or prefix == "q" then
						table.insert(term[prefix], arg)
					elseif prefix == "pre" or prefix == "post" or prefix == "bullets" then
						if i < #comma_separated_groups then
							parse_err("Modifier '" .. prefix .. "' should occur after the last comma-separated term")
						end
						if parsed[prefix] then
							parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. group[j])
						end
						if prefix == "bullets" then
							if not arg:find("^[0-9]+$") then
								parse_err("Modifier 'bullets' should have a number as argument")
							end
							parsed.bullets = tonumber(arg)
						else
							parsed[prefix] = arg
						end
					else
						parse_err("Unrecognized prefix '" .. prefix .. "' in modifier " .. group[j]
							.. ", should be one of 'pre', 'post', 'ref', 'bullets' or 'q'")
					end
				end
				table.insert(parsed.terms, term)
			end
			if not parsed.bullets then
				parsed.bullets = 1
			end
			inputs[dialect] = parsed
		else
			local terms = {}
			-- We don't want to split on comma+space, which should become a foot boundary as in
			-- [[rei morto, rei posto]].
			local subbed_input = rsub(input, ", ", TEMP1)
			for _, term in ipairs(rsplit(subbed_input, ",")) do
				term = rsub(term, TEMP1, ", ")
				table.insert(terms, {term = term, ref = {}, q = {}})
			end
			inputs[dialect] = {
				terms = terms,
				bullets = 1,
			}
		end
	end

	local expressed_dialects = export.express_dialects(inputs, lang, args.dialect, pagename)

	local lines = {}

	local function format_dialect(tag, expressed_dialect, is_first)
		local pronunciations = {}
		local formatted_pronuns = {}

		-- Loop through each pronunciation. For each one, add the phonemic and (if different) phonetic versions to
		-- `pronunciations`, for formatting by [[Module:IPA]], and also create an approximation of the formatted
		-- version so that we can compute the appropriate width of the HTML switcher div box that holds the different
		-- per-dialect variants.
		for i, pronun in ipairs(expressed_dialect.pronuns) do
			if pronun.phonemic then
				local separator = i > 1 and ", " or nil
				table.insert(pronunciations, {
					pron = "/" .. pronun.phonemic .. "/",
					qualifiers = pronun.qualifiers,
					separator = separator,
				})
				local formatted_phonemic = "/" .. pronun.phonemic .. "/"
				if pronun.qualifiers then
					formatted_phonemic = "(" .. table.concat(pronun.qualifiers, ", ") .. ") " .. formatted_phonemic
				end
				if separator then
					formatted_phonemic = separator .. formatted_phonemic
				end
				table.insert(formatted_pronuns, formatted_phonemic)
			end

			-- Check if phonetic and phonemic are the same. If so, we skip displaying the phonetic version; but in this
			-- case, we need to attach any references to the phonemic version.
			if pronun.phonemic and (not pronun.phonetic or pronun.phonetic == pronun.phonemic) then
				pronunciations[#pronunciations].refs = pronun.refs
			else
				local separator = pronun.phonemic and " " or i > 1 and ", " or nil
				table.insert(pronunciations, {
					pron = "[" .. pronun.phonetic .. "]",
					refs = pronun.refs,
					separator = separator,
				})
				local reftext = ""
				if pronun.refs then
					reftext = string.rep("[1]", #pronun.refs)
				end
				table.insert(formatted_pronuns, (separator or "") .. "[" .. pronun.phonetic .. "]" .. reftext)
			end
		end

		-- Number of bullets: When indent = 1, we want the number of bullets given by `expressed_dialect.bullets`,
		-- and when indent = 2, we want `expressed_dialect.bullets + 1`, hence we subtract 1.
		local bullet = string.rep("*", expressed_dialect.bullets + expressed_dialect.indent - 1) .. " "
		-- Here we construct the formatted line in `formatted`, and also try to construct the equivalent without HTML
		-- and wiki markup in `formatted_for_len`, so we can compute the approximate textual length for use in sizing
		-- the toggle box with the "more" button on the right.
		local pre = is_first and expressed_dialect.pre and expressed_dialect.pre .. " " or ""
		local pre_for_len = pre .. (tag and "(" .. tag .. ") " or "")
		pre = pre .. (tag and require(qualifier_module).format_qualifier(tag) .. " " or "")
		local post = is_first and (expressed_dialect.post and " " .. expressed_dialect.post or "") or ""
		local formatted = bullet .. pre .. m_IPA.format_IPA_full(langobj, pronunciations, nil, "") .. post
		local formatted_for_len = bullet .. pre .. "IPA(key): " .. table.concat(formatted_pronuns) .. post
		return formatted, formatted_for_len
	end

	for i, dialect_group in ipairs(expressed_dialects) do
		if #dialect_group.dialects == 1 then
			dialect_group.formatted, dialect_group.formatted_for_len =
				format_dialect(dialect_group.dialects[1].tag, dialect_group.dialects[1], i == 1)
		else
			dialect_group.formatted, dialect_group.formatted_for_len =
				format_dialect(dialect_group.tag, dialect_group.dialects[1], i == 1)
			for j, dialect in ipairs(dialect_group.dialects) do
				dialect.formatted, dialect.formatted_for_len =
					format_dialect(dialect.tag, dialect, i == 1 and j == 1)
			end
		end
	end

	-- Remove any HTML from the formatted text, since it doesn't contribute to the textual length, and return the
	-- resulting length in characters.
	local function textual_len(text)
		text = rsub(text, "<.->", "")
		return ulen(text)
	end

	local maxlen = 0
	for i, dialect_group in ipairs(expressed_dialects) do
		local this_len = textual_len(dialect_group.formatted_for_len)
		if #dialect_group.dialects > 1 then
			for _, dialect in ipairs(dialect_group.dialects) do
				this_len = math.max(this_len, textual_len(dialect.formatted_for_len))
			end
		end
		maxlen = math.max(maxlen, this_len)
	end

	for i, dialect_group in ipairs(expressed_dialects) do
		if #dialect_group.dialects == 1 then
			table.insert(lines, "<div>\n" .. dialect_group.formatted .. "</div>")
		else
			local inline = '\n<div class="vsShow" style="display:none">\n' .. dialect_group.formatted .. "</div>"
			local full_prons = {}
			for _, dialect in ipairs(dialect_group.dialects) do
				table.insert(full_prons, dialect.formatted)
			end
			local full = '\n<div class="vsHide">\n' .. table.concat(full_prons, "\n") .. "</div>"
			local em_length = math.floor(maxlen * 0.68) -- from [[Module:grc-pronunciation]]
			table.insert(lines, '<div class="vsSwitcher" data-toggle-category="pronunciations" style="width: ' .. em_length .. 'em; max-width:100%;"><span class="vsToggleElement" style="float: right;">&nbsp;</span>' .. inline .. full .. "</div>")
		end
	end

	-- major hack to get bullets working on the next line
	return table.concat(lines, "\n") .. "\n<span></span>"
end


return export






















--[=============[


















-- Generate all relevant dialect pronunciations and group into dialects. See the comment above about dialects and dialects.
-- A "pronunciation" here could be for example the IPA phonemic/phonetic representation of the term or the IPA form of
-- the rhyme that the term belongs to. If `dialect_spec` is nil, this generates all dialects for all dialects, but
-- `dialect_spec` can also be a dialect spec such as "seseo" or "distincion+yeismo" (see comment above) to restrict the
-- output. `dodialect` is a function of two arguments, `ret` and `dialect`, where `ret` is the return-value table (see
-- below), and `dialect` is a string naming a particular dialect, such as "distincion-lleismo" or "rioplatense-sheismo".
-- `dodialect` should side-effect the `ret` table by adding an entry to `ret.pronun` for the dialect in question.
--
-- The return value is a table of the form
--
-- {
--   pronun = {DIALECT = {PRONUN, PRONUN, ...}, DIALECT = {PRONUN, PRONUN, ...}, ...},
--   expressed_dialects = {STYLE_GROUP, STYLE_GROUP, ...},
-- }
--
-- where:
-- 1. DIALECT is a string such as "distincion-lleismo" naming a specific dialect.
-- 2. PRONUN is a table describing a particular pronunciation. If the dialect is "distincion-lleismo", there should be
--    a field in this table named `differences`, but where other fields may vary depending on the type of pronunciation
--    (e.g. phonemic/phonetic or rhyme). See below for the form of the PRONUN table for phonemic/phonetic pronunciation
--    vs. rhyme and the form of the `differences` field.
-- 3. STYLE_GROUP is a table of the form {tag = "HIDDEN_TAG", dialects = {INNER_STYLE, INNER_STYLE, ...}}. This describes
--    a group of related dialects (such as those for Latin America) that by default (the "hidden" form) are displayed as
--    a single line, with an icon on the right to "open" the dialect group into the "shown" form, with multiple lines
--    for each dialect in the group. The tag of the dialect group is the text displayed before the pronunciation in the
--    default "hidden" form, such as "Spain" or "Latin America". It can have the special value of `false` to indicate
--    that no tag text is to be displayed. Note that the pronunciation shown in the default "hidden" form is taken
--    from the first dialect in the dialect group.
-- 4. INNER_STYLE is a table of the form {tag = "SHOWN_TAG", pronun = {PRONUN, PRONUN, ...}}. This describes a single
--    dialect (such as for the Andes Mountains in the case where the seseo+lleismo accent differs from all others), to
--    be shown on a single line. `tag` is the text preceding the displayed pronunciation, or `false` if no tag text
--    is to be displayed. PRONUN is a table as described above and describes a particular pronunciation.
--
-- The PRONUN table has the following form for the full phonemic/phonetic pronunciation:
--
-- {
--   phonemic = "PHONEMIC",
--   phonetic = "PHONETIC",
--   differences = {FLAG = BOOLEAN, FLAG = BOOLEAN, ...},
-- }
--
-- Here, `phonemic` is the phonemic pronunciation (displayed as /.../) and `phonetic` is the phonetic pronunciation
-- (displayed as [...]).
--
-- The PRONUN table has the following form for the rhyme pronunciation:
--
-- {
--   rhyme = "RHYME_PRONUN",
--   num_syl = {NUM, NUM, ...},
--   qualifiers = nil or {QUALIFIER, QUALIFIER, ...},
--   differences = {FLAG = BOOLEAN, FLAG = BOOLEAN, ...},
-- }
--
-- Here, `rhyme` is a phonemic pronunciation such as "ado" for [[abogado]] or "iʝa"/"iʎa" for [[tortilla]] (depending
-- on the dialect), and `num_syl` is a list of the possible numbers of syllables for the term(s) that have this rhyme
-- (e.g. {4} for [[abogado]], {3} for [[tortilla]] and {4, 5} for [[biología]], which may be syllabified as
-- bio.lo.gí.a or bi.o.lo.gí.a). `num_syl` is used to generate syllable-count categories such as
-- [[Category:Rhymes:Spanish/ia/4 syllables]] in addition to [[Category:Rhymes:Spanish/ia]]. `num_syl` may be nil to
-- suppress the generation of syllable-count categories; this is typically the case with multiword terms.
-- `qualifiers`, if non-nil, comes from the user using the syntax e.g. <rhyme:iʃa<q:Buenos Aires>>.
--
-- The value of the `differences` field in the PRONUN table (which, as noted above, only needs to be present for the
-- "distincion-lleismo" dialect, and otherwise should be nil) is a table containing flags indicating whether and how
-- the per-dialect pronunciations differ. This is an optimization to avoid having to generate all six dialectal
-- pronunciations and compare them. It has the following form:
--
-- {
--   distincion_different = BOOLEAN,
--   lleismo_different = BOOLEAN,
--   need_rioplat = BOOLEAN,
--   sheismo_different = BOOLEAN,
-- }
--
-- where:
-- 1. `distincion_different` should be `true` if the "distincion" and "seseo" pronunciations differ;
-- 2. `lleismo_different` should be `true` if the "lleismo" and "yeismo" pronunciations differ;
-- 3. `need_rioplat` should be `true` if the Rioplatense pronunciations differ from the seseo+yeismo pronunciation;
-- 4. `sheismo_different` should be `true` if the "sheismo" and "zheismo" pronunciations differ.
local function express_all_dialects(dialect_spec, dodialect)
	local ret = {
		pronun = {},
		expressed_dialects = {},
	}

	local need_rioplat

	-- Add a dialect object (see INNER_STYLE above) that represents a particular dialect to `ret.expressed_dialects`.
	-- `hidden_tag` is the tag text to be used when the dialect group containing the dialect is in the default "hidden"
	-- state (e.g. "Spain", "Latin America" or false if there is only one dialect group and no tag text should be
	-- shown), while `tag` is the tag text to be used when the individual dialect is shown (e.g. a description such as
	-- "most of Spain and Latin America", "Andes Mountains" or "everywhere but Argentina and Uruguay").
	-- `representative_dialect` is one of the dialects that this dialect represents, and whose pronunciation is stored in
	-- the dialect object. `matching_dialects` is a hyphen separated string listing the isoglosses described by this dialect.
	-- For example, if the term has an ''ll'' but no ''c/z'', the `tag` text for the yeismo pronunciation will be
	-- "most of Spain and Latin America" and `matching_dialects` will be "distincion-seseo-yeismo", indicating that
	-- it corresponds to both the "distincion" and "seseo" isoglosses as well as the "yeismo" isogloss. This is used
	-- when a particular dialect spec is given. If `matching_dialects` is omitted, it takes its value from
	-- `representative_dialect`; this is used when the dialect contains only a single dialect.
	local function express_dialect(hidden_tag, tag, representative_dialect, matching_dialects)
		matching_dialects = matching_dialects or representative_dialect
		-- If the Rioplatense pronunciation isn't distinctive, add all Rioplatense isoglosses.
		if not need_rioplat then
			matching_dialects = matching_dialects .. "-rioplatense-sheismo-zheismo"
		end
		-- If dialect specified, make sure it matches the requested dialect.
		local dialect_matches
		if not dialect_spec then
			dialect_matches = true
		else
			local dialect_parts = rsplit(matching_dialects, "%-")
			local or_dialects = rsplit(dialect_spec, "%s*,%s*")
			for _, or_dialect in ipairs(or_dialects) do
				local and_dialects = rsplit(or_dialect, "%s*%+%s*")
				local and_matches = true
				for _, and_dialect in ipairs(and_dialects) do
					local negate
					if and_dialect:find("^%-") then
						and_dialect = and_dialect:gsub("^%-", "")
						negate = true
					end
					local this_dialect_matches = false
					for _, part in ipairs(dialect_parts) do
						if part == and_dialect then
							this_dialect_matches = true
							break
						end
					end
					if negate then
						this_dialect_matches = not this_dialect_matches
					end
					if not this_dialect_matches then
						and_matches = false
					end
				end
				if and_matches then
					dialect_matches = true
					break
				end
			end
		end
		if not dialect_matches then
			return
		end

		-- Fetch the representative dialect's pronunciation if not already present.
		if not ret.pronun[representative_dialect] then
			dodialect(ret, representative_dialect)
		end
		-- Insert the new dialect into the dialect group, creating the group if necessary.
		local new_dialect = {
			tag = tag,
			pronun = ret.pronun[representative_dialect],
		}
		for _, hidden_tag_dialect in ipairs(ret.expressed_dialects) do
			if hidden_tag_dialect.tag == hidden_tag then
				table.insert(hidden_tag_dialect.dialects, new_dialect)
				return
			end
		end
		table.insert(ret.expressed_dialects, {
			tag = hidden_tag,
			dialects = {new_dialect},
		})
	end

	-- For each type of difference, figure out if the difference exists in any of the given respellings. We do this by
	-- generating the pronunciation for the dialect "distincion-lleismo", for each respelling. In the process of
	-- generating the pronunciation for a given respelling, it computes how the other dialects for that respelling
	-- differ. Then we take the union of these differences across the respellings.
	dodialect(ret, "distincion-lleismo")
	local differences = {}
	for _, difftype in ipairs { "distincion_different", "lleismo_different", "need_rioplat", "sheismo_different" } do
		for _, pronun in ipairs(ret.pronun["distincion-lleismo"]) do
			if pronun.differences[difftype] then
				differences[difftype] = true
			end
		end
	end
	local distincion_different = differences.distincion_different
	local lleismo_different = differences.lleismo_different
	need_rioplat = differences.need_rioplat
	local sheismo_different = differences.sheismo_different

	-- Now, based on the observed differences, figure out how to combine the individual dialects into dialects and
	-- dialect groups.
	if not distincion_different and not lleismo_different then
		if not need_rioplat then
			express_dialect(false, false, "distincion-lleismo", "distincion-seseo-lleismo-yeismo")
		else
			express_dialect(false, "everywhere but Argentina and Uruguay", "distincion-lleismo",
			"distincion-seseo-lleismo-yeismo")
		end
	elseif distincion_different and not lleismo_different then
		express_dialect("Spain", "Spain", "distincion-lleismo", "distincion-lleismo-yeismo")
		express_dialect("Latin America", "Latin America", "seseo-lleismo", "seseo-lleismo-yeismo")
	elseif not distincion_different and lleismo_different then
		express_dialect(false, "most of Spain and Latin America", "distincion-yeismo", "distincion-seseo-yeismo")
		express_dialect(false, "rural northern Spain, Andes Mountains", "distincion-lleismo", "distincion-seseo-lleismo")
	else
		express_dialect("Spain", "most of Spain", "distincion-yeismo")
		express_dialect("Latin America", "most of Latin America", "seseo-yeismo")
		express_dialect("Spain", "rural northern Spain", "distincion-lleismo")
		express_dialect("Latin America", "Andes Mountains", "seseo-lleismo")
	end
	if need_rioplat then
		local hidden_tag = distincion_different and "Latin America" or false
		if sheismo_different then
			express_dialect(hidden_tag, "Buenos Aires and environs", "rioplatense-sheismo", "seseo-rioplatense-sheismo")
			express_dialect(hidden_tag, "elsewhere in Argentina and Uruguay", "rioplatense-zheismo", "seseo-rioplatense-zheismo")
		else
			express_dialect(hidden_tag, "Argentina and Uruguay", "rioplatense-sheismo", "seseo-rioplatense-sheismo-zheismo")
		end
	end

	-- If only one dialect group, don't indicate the dialect.
	-- Not clear we want this in reality.
	--if #ret.expressed_dialects == 1 then
	--	ret.expressed_dialects[1].tag = false
	--	if #ret.expressed_dialects[1].dialects == 1 then
	--		ret.expressed_dialects[1].dialects[1].tag = false
	--	end
	--end

	return ret
end


local function format_all_dialects(expressed_dialects, format_dialect)
	for i, dialect_group in ipairs(expressed_dialects) do
		if #dialect_group.dialects == 1 then
			dialect_group.formatted, dialect_group.formatted_len =
				format_dialect(dialect_group.dialects[1].tag, dialect_group.dialects[1], i == 1)
		else
			dialect_group.formatted, dialect_group.formatted_len =
				format_dialect(dialect_group.tag, dialect_group.dialects[1], i == 1)
			for j, dialect in ipairs(dialect_group.dialects) do
				dialect.formatted, dialect.formatted_len =
					format_dialect(dialect.tag, dialect, i == 1 and j == 1)
			end
		end
	end

	local maxlen = 0
	for i, dialect_group in ipairs(expressed_dialects) do
		local this_len = dialect_group.formatted_len
		if #dialect_group.dialects > 1 then
			for _, dialect in ipairs(dialect_group.dialects) do
				this_len = math.max(this_len, dialect.formatted_len)
			end
		end
		maxlen = math.max(maxlen, this_len)
	end

	local lines = {}

	local need_major_hack = false
	for i, dialect_group in ipairs(expressed_dialects) do
		if #dialect_group.dialects == 1 then
			table.insert(lines, dialect_group.formatted)
			need_major_hack = false
		else
			local inline = '\n<div class="vsShow" style="display:none">\n' .. dialect_group.formatted .. "</div>"
			local full_prons = {}
			for _, dialect in ipairs(dialect_group.dialects) do
				table.insert(full_prons, dialect.formatted)
			end
			local full = '\n<div class="vsHide">\n' .. table.concat(full_prons, "\n") .. "</div>"
			local em_length = math.floor(maxlen * 0.68) -- from [[Module:grc-pronunciation]]
			table.insert(lines, '<div class="vsSwitcher" data-toggle-category="pronunciations" style="width: ' .. em_length .. 'em; max-width:100%;"><span class="vsToggleElement" style="float: right;">&nbsp;</span>' .. inline .. full .. "</div>")
			need_major_hack = true
		end
	end

	-- major hack to get bullets working on the next line after a div box
	return table.concat(lines, "\n") .. (need_major_hack and "\n<span></span>" or "")
end


local function dodialect_pronun(args, ret, dialect)
	ret.pronun[dialect] = {}
	for i, term in ipairs(args.terms) do
		local phonemic, phonetic, differences
		if term.raw then
			phonemic = term.raw_phonemic
			phonetic = term.raw_phonetic
			differences = construct_default_differences(dialect)
		else
			phonemic = export.IPA(term.term, dialect, false)
			phonetic = export.IPA(term.term, dialect, true)
			differences = phonemic.differences
			phonemic = phonemic.text
			phonetic = phonetic.text
		end
		local refs
		if not term.ref then
			refs = nil
		else
			refs = {}
			for _, refspec in ipairs(term.ref) do
				local this_refs = require("Module:references").parse_references(refspec)
				for _, this_ref in ipairs(this_refs) do
					table.insert(refs, this_ref)
				end
			end
		end

		ret.pronun[dialect][i] = {
			raw = term.raw,
			phonemic = phonemic,
			phonetic = phonetic,
			refs = refs,
			q = term.q,
			qq = term.qq,
			a = term.a,
			aa = term.aa,
			differences = differences,
		}
	end
end

local function generate_pronun(args)
	local function this_dodialect_pronun(ret, dialect)
		dodialect_pronun(args, ret, dialect)
	end

	local ret = express_all_dialects(args.dialect, this_dodialect_pronun)

	local function format_dialect(tag, expressed_dialect, is_first)
		local pronunciations = {}
		local formatted_pronuns = {}

		local function ins(formatted_part)
			table.insert(formatted_pronuns, formatted_part)
		end

		-- Loop through each pronunciation. For each one, add the phonemic and phonetic versions to `pronunciations`,
		-- for formatting by [[Module:IPA]], and also create an approximation of the formatted version so that we can
		-- compute the appropriate width of the HTML switcher div box that holds the different per-dialect variants.
		-- NOTE: The code below constructs the formatted approximation out-of-order in some cases but that doesn't
		-- currently matter because we assume all characters have the same width. If we change the width computation
		-- in a way that requires the correct order, we need changes to the code below.
		for j, pronun in ipairs(expressed_dialect.pronun) do
			-- Add tag to left qualifiers if first one
			-- FIXME: Consider using accent qualifier for the tag instead.
			local qs = pronun.q
			if j == 1 and tag then
				if qs then
					qs = m_table.deepcopy(qs)
					table.insert(qs, tag)
				else
					qs = {tag}
				end
			end

			local first_pronun = #pronunciations + 1

			if not pronun.phonemic and not pronun.phonetic then
				error("Internal error: Saw neither phonemic nor phonetic pronunciation")
			end

			if pronun.phonemic then -- missing if 'raw:[...]' given
				-- don't display syllable division markers in phonemic
				local slash_pron = "/" .. pronun.phonemic:gsub("%.", "") .. "/"
				table.insert(pronunciations, {
					pron = slash_pron,
				})
				ins(slash_pron)
			end

			if pronun.phonetic then -- missing if 'raw:/.../' given
				local bracket_pron = "[" .. pronun.phonetic .. "]"
				table.insert(pronunciations, {
					pron = bracket_pron,
				})
				ins(bracket_pron)
			end

			local last_pronun = #pronunciations

			if qs then
				pronunciations[first_pronun].q = qs
			end
			if pronun.a then
				pronunciations[first_pronun].a = pronun.a
			end
			if j > 1 then
				pronunciations[first_pronun].separator = ", "
				ins(", ")
			end
			if pronun.qq then
				pronunciations[last_pronun].qq = pronun.qq
			end
			if pronun.aa then
				pronunciations[last_pronun].aa = pronun.aa
			end
			if qs or pronun.a or pronun.qq or pronun.aa then
				local data = {
					q = qs,
					a = pronun.a,
					qq = pronun.qq,
					aa = pronun.aa
				}
				-- Note: This inserts the actual formatted qualifier text, including HTML and such, but the later call
				-- to textual_len() removes all HTML and reduces links.
				ins(require("Module:pron qualifier").format_qualifiers(data, ""))
			end

			if pronun.refs then
				pronunciations[last_pronun].refs = pronun.refs
				-- Approximate the reference using a footnote notation. This will be slightly inaccurate if there are
				-- more than nine references but that is rare.
				ins(string.rep("[1]", #pronun.refs))
			end
			if first_pronun ~= last_pronun then
				pronunciations[last_pronun].separator = " "
				ins(" ")
			end
		end

		local bullet = string.rep("*", args.bullets) .. " "
		-- Here we construct the formatted line in `formatted`, and also try to construct the equivalent without HTML
		-- and wiki markup in `formatted_for_len`, so we can compute the approximate textual length for use in sizing
		-- the toggle box with the "more" button on the right.
		local pre = is_first and args.pre and args.pre .. " " or ""
		local post = is_first and args.post and " " .. args.post or ""
		local formatted = bullet .. pre .. m_IPA.format_IPA_full(lang, pronunciations, nil, "") .. post
		local formatted_for_len = bullet .. pre .. "IPA(key): " .. table.concat(formatted_pronuns) .. post
		return formatted, textual_len(formatted_for_len)
	end

	ret.text = format_all_dialects(ret.expressed_dialects, format_dialect)

	return ret
end


local function parse_respelling(respelling, pagename, parse_err)
	local raw_respelling = respelling:match("^raw:(.*)$")
	if raw_respelling then
		local raw_phonemic, raw_phonetic = raw_respelling:match("^/(.*)/ %[(.*)%]$")
		if not raw_phonemic then
			raw_phonemic = raw_respelling:match("^/(.*)/$")
		end
		if not raw_phonemic then
			raw_phonetic = raw_respelling:match("^%[(.*)%]$")
		end
		if not raw_phonemic and not raw_phonetic then
			parse_err(("Unable to parse raw respelling '%s', should be one of /.../, [...] or /.../ [...]")
				:format(raw_respelling))
		end
		return {
			raw = true,
			raw_phonemic = raw_phonemic,
			raw_phonetic = raw_phonetic,
		}
	end
	if respelling == "+" then
		respelling = pagename
	end
	return {term = respelling}
end


-- External entry point for {{es-IPA}}.
function export.show(frame)
	local params = {
		[1] = {},
		["pre"] = {},
		["post"] = {},
		["ref"] = {},
		["dialect"] = {},
		["bullets"] = {type = "number", default = 1},
	}
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local text = args[1] or mw.title.getCurrentTitle().text
	args.terms = {{term = text}}
	local ret = generate_pronun(args)
	return ret.text
end


-- Return the number of syllables of a phonemic representation, which should have syllable dividers in it but no
-- hyphens.
local function get_num_syl_from_phonemic(phonemic)
	-- Maybe we should just count vowels instead of the below code.
	phonemic = rsub(phonemic, "|", " ") -- remove IPA foot boundaries
	local words = rsplit(phonemic, " +")
	for i, word in ipairs(words) do
		-- IPA stress marks are syllable divisions if between characters; otherwise just remove.
		word = rsub(word, "(.)[ˌˈ](.)", "%1.%2")
		word = rsub(word, "[ˌˈ]", "")
		words[i] = word
	end
	-- There should be a syllable boundary between words.
	phonemic = table.concat(words, ".")
	return ulen(rsub(phonemic, "[^.]", "")) + 1
end


-- Get the rhyme by truncating everything up through the last stress mark + any following consonants, and remove
-- syllable boundary markers.
local function convert_phonemic_to_rhyme(phonemic)
	-- NOTE: This works because the phonemic vowels are just [aeiou] possibly with diacritics that are separate
	-- Unicode chars. If we want to handle things like ɛ or ɔ we need to add them to `vowel`.
	return rsub(rsub(phonemic, ".*[ˌˈ]", ""), "^[^" .. vowel .. "]*", ""):gsub("%.", ""):gsub("t͡ʃ", "tʃ")
end


local function split_syllabified_spelling(spelling)
	return rsplit(spelling, "%.")
end


-- "Align" syllabification to original spelling by matching character-by-character, allowing for extra syllable and
-- accent markers in the syllabification. If we encounter an extra syllable marker (.), we allow and keep it. If we
-- encounter an extra accent marker in the syllabification, we drop it. In any other case, we return nil indicating
-- the alignment failed.
local function align_syllabification_to_spelling(syllab, spelling)
	local result = {}
	local syll_chars = rsplit(decompose(syllab), "")
	local spelling_chars = rsplit(decompose(spelling), "")
	local i = 1
	local j = 1
	while i <= #syll_chars or j <= #spelling_chars do
		local ci = syll_chars[i]
		local cj = spelling_chars[j]
		if ci == cj then
			table.insert(result, ci)
			i = i + 1
			j = j + 1
		elseif ci == "." then
			table.insert(result, ci)
			i = i + 1
		elseif ci == AC or ci == GR or ci == CFLEX then
			-- skip character
			i = i + 1
		else
			-- non-matching character
			return nil
		end
	end
	if i <= #syll_chars or j <= #spelling_chars then
		-- left-over characters on one side or the other
		return nil
	end
	return unfc(table.concat(result))
end


local function generate_hyph_obj(term)
	return {syllabification = term, hyph = split_syllabified_spelling(term)}
end


-- Word should already be decomposed.
local function word_has_vowels(word)
	return rfind(word, V)
end


local function all_words_have_vowels(term)
	local words = rsplit(decompose(term), "[ %-]")
	for i, word in ipairs(words) do
		-- Allow empty word; this occurs with prefixes and suffixes.
		if word ~= "" and not word_has_vowels(word) then
			return false
		end
	end
	return true
end


local function should_generate_rhyme_from_respelling(term)
	local words = rsplit(decompose(term), " +")
	return #words == 1 and -- no if multiple words
		not words[1]:find(".%-.") and -- no if word is composed of hyphenated parts (e.g. [[Austria-Hungría]])
		not words[1]:find("%-$") and -- no if word is a prefix
		not (words[1]:find("^%-") and words[1]:find(CFLEX)) and -- no if word is an unstressed suffix
		word_has_vowels(words[1]) -- no if word has no vowels (e.g. a single letter)
end


local function should_generate_rhyme_from_ipa(ipa)
	return not ipa:find("%s") and word_has_vowels(decompose(ipa))
end


local function dodialect_specified_rhymes(rhymes, hyphs, parsed_respellings, rhyme_ret, dialect)
	rhyme_ret.pronun[dialect] = {}
	for _, rhyme in ipairs(rhymes) do
		local num_syl = rhyme.num_syl
		local no_num_syl = false

		-- If user explicitly gave the rhyme but didn't explicitly specify the number of syllables, try to take it from
		-- the hyphenation.
		if not num_syl then
			num_syl = {}
			for _, hyph in ipairs(hyphs) do
				if should_generate_rhyme_from_respelling(hyph.syllabification) then
					local this_num_syl = 1 + ulen(rsub(hyph.syllabification, "[^.]", ""))
					m_table.insertIfNot(num_syl, this_num_syl)
				else
					no_num_syl = true
					break
				end
			end
			if no_num_syl or #num_syl == 0 then
				num_syl = nil
			end
		end

		-- If that fails and term is single-word, try to take it from the phonemic.
		if not no_num_syl and not num_syl then
			for _, parsed in ipairs(parsed_respellings) do
				for dialect, pronun in pairs(parsed.pronun.pronun[dialect]) do
					-- Check that pronun.phonemic exists (it may not if raw phonetic-only pronun is given).
					if pronun.phonemic then
						if not should_generate_rhyme_from_ipa(pronun.phonemic) then
							no_num_syl = true
							break
						end
						-- Count number of syllables by looking at syllable boundaries (including stress marks).
						local this_num_syl = get_num_syl_from_phonemic(pronun.phonemic)
						m_table.insertIfNot(num_syl, this_num_syl)
					end
				end
				if no_num_syl then
					break
				end
			end
			if no_num_syl or #num_syl == 0 then
				num_syl = nil
			end
		end

		table.insert(rhyme_ret.pronun[dialect], {
			rhyme = rhyme.rhyme,
			num_syl = num_syl,
			qualifiers = rhyme.qualifiers,
			differences = construct_default_differences(dialect),
		})
	end
end


local function parse_pron_modifier(arg, parse_err, generate_obj, param_mods, splitchar)
	local retval = {}

	if arg:find("<") then
		local insert = { store = "insert" }
		param_mods.q = insert
		param_mods.qq = insert
		param_mods.a = insert
		param_mods.aa = insert
		return require(put_module).parse_inline_modifiers(arg, {
			param_mods = param_mods,
			generate_obj = generate_obj,
			parse_err = parse_err,
			splitchar = splitchar or ",",
		})
	else
		local split_args
		if not splitchar then
			split_args = split_on_comma(arg)
		else
			split_args = rsplit(arg, splitchar)
		end
		for _, term in ipairs(split_args) do
			table.insert(retval, generate_obj(term))
		end
	end

	return retval
end


local function parse_rhyme(arg, parse_err)
	local function generate_obj(term)
		return {rhyme = term}
	end
	local param_mods = {
		s = {
			item_dest = "num_syl",
			convert = function(arg, parse_err),
				local nsyls = rsplit(arg, ",")
				for i, nsyl in ipairs(nsyls) do
					if not nsyl:find("^[0-9]+$") then
						parse_err("Number of syllables '" .. nsyl .. "' should be numeric")
					end
					nsyls[i] = tonumber(nsyl)
				end
				return nsyls
			end,
		},
	}

	return parse_pron_modifier(arg, parse_err, generate_obj, param_mods)
end


local function parse_hyph(arg, parse_err)
	-- None other than qualifiers
	local param_mods = {}

	return parse_pron_modifier(arg, parse_err, generate_hyph_obj, param_mods)
end


local function parse_homophone(arg, parse_err)
	local function generate_obj(term)
		return {term = term}
	end
	local param_mods = {
		t = {
			-- We need to store the <t:...> inline modifier into the "gloss" key of the parsed term,
			-- because that is what [[Module:links]] (called from [[Module:homophones]]) expects.
			item_dest = "gloss",
		},
		gloss = {},
		pos = {},
		alt = {},
		lit = {},
		id = {},
		g = {
			-- We need to store the <g:...> inline modifier into the "genders" key of the parsed term,
			-- because that is what [[Module:links]] (called from [[Module:homophones]]) expects.
			item_dest = "genders",
			convert = function(arg)
				return rsplit(arg, ",")
			end,
		},
	}

	return parse_pron_modifier(arg, parse_err, generate_obj, param_mods)
end


local function generate_audio_obj(arg)
	local file, gloss
	file, gloss = arg:match("^(.-)%s*#%s*(.*)$")
	if not file then
		file = arg
		gloss = "Audio"
	end
	return {file = file, gloss = gloss}
end


local function parse_audio(arg, parse_err)
	-- None other than qualifiers
	local param_mods = {}

	-- Don't split on comma because some filenames have embedded commas not followed by a space
	-- (typically followed by an underscore).
	return parse_pron_modifier(arg, parse_err, generate_audio_obj, param_mods, ";")
end


-- External entry point for {{pl-pr}}, {{szl-pr}}.
function export.show_pr(frame)
	local params = {
		[1] = {list = true},
		["rhyme"] = {},
		["hyph"] = {},
		["hmp"] = {},
		["audio"] = {},
		["pagename"] = {},
	}
	local parargs = frame:getParent().args
	local args = require("Module:parameters").process(parargs, params)
	local pagename = args.pagename or mw.title.getCurrentTitle().subpageText

	-- Parse the arguments.
	local respellings = #args[1] > 0 and args[1] or {"+"}
	local parsed_respellings = {}
	local function overall_parse_err(msg, arg, val)
		error(msg .. ": " .. arg .. "= " .. val)
	end
	local overall_rhyme = args.rhyme and
		parse_rhyme(args.rhyme, function(msg) overall_parse_err(msg, "rhyme", args.rhyme) end) or nil
	local overall_hyph = args.hyph and
		parse_hyph(args.hyph, function(msg) overall_parse_err(msg, "hyph", args.hyph) end) or nil
	local overall_hmp = args.hmp and
		parse_homophone(args.hmp, function(msg) overall_parse_err(msg, "hmp", args.hmp) end) or nil
	local overall_audio = args.audio and
		parse_audio(args.audio, function(msg) overall_parse_err(msg, "audio", args.audio) end) or nil
	for i, respelling in ipairs(respellings) do
		if respelling:find("<") then
			local param_mods = {
				pre = { overall = true },
				post = { overall = true },
				dialect = { overall = true },
				bullets = {
					overall = true,
					convert = function(arg, parse_err)
						if not arg:find("^[0-9]+$") then
							parse_err("Modifier 'bullets' should have a number as argument, but saw '" .. arg .. "'")
						end
						return tonumber(arg)
					end,
				},
				rhyme = {
					overall = true,
					store = "insert-flattened",
					convert = parse_rhyme,
				},
				hyph = {
					overall = true,
					store = "insert-flattened",
					convert = parse_hyph,
				},
				hmp = {
					overall = true,
					store = "insert-flattened",
					convert = parse_homophone,
				},
				audio = {
					overall = true,
					store = "insert-flattened",
					convert = parse_audio,
				},
				ref = { store = "insert" },
				q = { store = "insert" },
				qq = { store = "insert" },
				a = { store = "insert" },
				aa = { store = "insert" },
			}

			local parsed = require(put_module).parse_inline_modifiers(respelling, {
				paramname = i,
				param_mods = param_mods,
				generate_obj = function(term, parse_err)
					return parse_respelling(term, pagename, parse_err)
				end,
				splitchar = ",",
				outer_container = {
					audio = {}, rhyme = {}, hyph = {}, hmp = {}
				}
			})
			if not parsed.bullets then
				parsed.bullets = 1
			end
			table.insert(parsed_respellings, parsed)
		else
			local termobjs = {}
			local function parse_err(msg)
				error(msg .. ": " .. i .. "= " .. respelling)
			end
			for _, term in ipairs(split_on_comma(respelling)) do
				table.insert(termobjs, parse_respelling(term, pagename, parse_err))
			end
			table.insert(parsed_respellings, {
				terms = termobjs,
				audio = {},
				rhyme = {},
				hyph = {},
				hmp = {},
				bullets = 1,
			})
		end
	end

	if overall_hyph then
		local hyphs = {}
		for _, hyph in ipairs(overall_hyph) do
			if hyph.syllabification == "+" then
				hyph.syllabification = syllabify_from_spelling(pagename)
				hyph.hyph = split_syllabified_spelling(hyph.syllabification)
			elseif hyph.syllabification == "-" then
				overall_hyph = {}
				break
			end
		end
	end

	-- Loop over individual respellings, processing each.
	for _, parsed in ipairs(parsed_respellings) do
		parsed.pronun = generate_pronun(parsed)
		local no_auto_rhyme = false
		for _, term in ipairs(parsed.terms) do
			if term.raw then
				if not should_generate_rhyme_from_ipa(term.raw_phonemic or term.raw_phonetic) then
					no_auto_rhyme = true
					break
				end
			elseif not should_generate_rhyme_from_respelling(term.term) then
				no_auto_rhyme = true
				break
			end
		end

		if #parsed.hyph == 0 then
			if not overall_hyph and all_words_have_vowels(pagename) then
				for _, term in ipairs(parsed.terms) do
					if not term.raw then
						local syllabification = syllabify_from_spelling(term.term)
						local aligned_syll = align_syllabification_to_spelling(syllabification, pagename)
						if aligned_syll then
							m_table.insertIfNot(parsed.hyph, generate_hyph_obj(aligned_syll))
						end
					end
				end
			end
		else
			for _, hyph in ipairs(parsed.hyph) do
				if hyph.syllabification == "+" then
					hyph.syllabification = syllabify_from_spelling(pagename)
					hyph.hyph = split_syllabified_spelling(hyph.syllabification)
				elseif hyph.syllabification == "-" then
					parsed.hyph = {}
					break
				end
			end
		end

		-- Generate the rhymes.
		local function dodialect_rhymes_from_pronun(rhyme_ret, dialect)
			rhyme_ret.pronun[dialect] = {}
			-- It's possible the pronunciation for a passed-in dialect was never generated. This happens e.g. with
			-- {{es-pr|cebolla<dialect:seseo>}}. The initial call to generate_pronun() fails to generate a pronunciation
			-- for the dialect 'distinction-yeismo' because the pronunciation of 'cebolla' differs between distincion
			-- and seseo and so the seseo dialect restriction rules out generation of pronunciation for distincion
			-- dialects (other than 'distincion-lleismo', which always gets generated so as to determine on which axes
			-- the dialects differ). However, when generating the rhyme, it is based only on -olla, whose pronunciation
			-- does not differ between distincion and seseo, but does differ between lleismo and yeismo, so it needs to
			-- generate a yeismo-specific rhyme, and 'distincion-yeismo' is the representative dialect for yeismo in the
			-- situation where distincion and seseo do not have distinct results (based on the following line in
			-- express_all_dialects()):
			--   express_dialect(false, "most of Spain and Latin America", "distincion-yeismo", "distincion-seseo-yeismo")
			-- In this case we need to generate the missing overall pronunciation ourselves since we need it to generate
			-- the dialect-specific rhyme pronunciation.
			if not parsed.pronun.pronun[dialect] then
				dodialect_pronun(parsed, parsed.pronun, dialect)
			end
			for _, pronun in ipairs(parsed.pronun.pronun[dialect]) do
				-- We should have already excluded multiword terms and terms without vowels from rhyme generation (see
				-- `no_auto_rhyme` below). But make sure to check that pronun.phonemic exists (it may not if raw
				-- phonetic-only pronun is given).
				if pronun.phonemic then
					-- Count number of syllables by looking at syllable boundaries (including stress marks).
					local num_syl = get_num_syl_from_phonemic(pronun.phonemic)
					-- Get the rhyme by truncating everything up through the last stress mark + any following
					-- consonants, and remove syllable boundary markers.
					local rhyme = convert_phonemic_to_rhyme(pronun.phonemic)
					local saw_already = false
					for _, existing in ipairs(rhyme_ret.pronun[dialect]) do
						if existing.rhyme == rhyme then
							saw_already = true
							-- We already saw this rhyme but possibly with a different number of syllables,
							-- e.g. if the user specified two pronunciations 'biología' (4 syllables) and
							-- 'bi.ología' (5 syllables), both of which have the same rhyme /ia/.
							m_table.insertIfNot(existing.num_syl, num_syl)
							break
						end
					end
					if not saw_already then
						local rhyme_diffs = nil
						if dialect == "distincion-lleismo" then
							rhyme_diffs = {}
							if rhyme:find("θ") then
								rhyme_diffs.distincion_different = true
							end
							if rhyme:find("ʎ") then
								rhyme_diffs.lleismo_different = true
							end
							if rfind(rhyme, "[ʎɟ]") then
								rhyme_diffs.sheismo_different = true
								rhyme_diffs.need_rioplat = true
							end
						end
						table.insert(rhyme_ret.pronun[dialect], {
							rhyme = rhyme,
							num_syl = {num_syl},
							differences = rhyme_diffs,
						})
					end
				end
			end
		end

		if #parsed.rhyme == 0 then
			if overall_rhyme or no_auto_rhyme then
				parsed.rhyme = nil
			else
				parsed.rhyme = express_all_dialects(parsed.dialect, dodialect_rhymes_from_pronun)
			end
		else
			local no_rhyme = false
			for _, rhyme in ipairs(parsed.rhyme) do
				if rhyme.rhyme == "-" then
					no_rhyme = true
					break
				end
			end
			if no_rhyme then
				parsed.rhyme = nil
			else
				local function this_dodialect(rhyme_ret, dialect)
					return dodialect_specified_rhymes(parsed.rhyme, parsed.hyph, {parsed}, rhyme_ret, dialect)
				end
				parsed.rhyme = express_all_dialects(parsed.dialect, this_dodialect)
			end
		end
	end

	if overall_rhyme then
		local no_overall_rhyme = false
		for _, orhyme in ipairs(overall_rhyme) do
			if orhyme.rhyme == "-" then
				no_overall_rhyme = true
				break
			end
		end
		if no_overall_rhyme then
			overall_rhyme = nil
		else
			local all_hyphs
			if overall_hyph then
				all_hyphs = overall_hyph
			else
				all_hyphs = {}
				for _, parsed in ipairs(parsed_respellings) do
					for _, hyph in ipairs(parsed.hyph) do
						m_table.insertIfNot(all_hyphs, hyph)
					end
				end
			end
			local function dodialect_overall_rhyme(rhyme_ret, dialect)
				return dodialect_specified_rhymes(overall_rhyme, all_hyphs, parsed_respellings, rhyme_ret, dialect)
			end
			overall_rhyme = express_all_dialects(parsed.dialect, dodialect_overall_rhyme)
		end
	end

	-- If all sets of pronunciations have the same rhymes, display them only once at the bottom.
	-- Otherwise, display rhymes beneath each set, indented.
	local first_rhyme_ret
	local all_rhyme_sets_eq = true
	for j, parsed in ipairs(parsed_respellings) do
		if j == 1 then
			first_rhyme_ret = parsed.rhyme
		elseif not m_table.deepEquals(first_rhyme_ret, parsed.rhyme) then
			all_rhyme_sets_eq = false
			break
		end
	end

	local function format_rhyme(rhyme_ret, num_bullets)
		local function format_rhyme_dialect(tag, expressed_dialect, is_first)
			local pronunciations = {}
			local rhymes = {}
			for _, pronun in ipairs(expressed_dialect.pronun) do
				table.insert(rhymes, pronun)
			end
			local data = {
				lang = lang,
				rhymes = rhymes,
				qualifiers = tag and {tag} or nil,
				force_cat = force_cat,
			}
			local bullet = string.rep("*", num_bullets) .. " "
			local formatted = bullet .. require("Module:rhymes").format_rhymes(data)
			local formatted_for_len_parts = {}
			table.insert(formatted_for_len_parts, bullet .. "Rhymes: " .. (tag and "(" .. tag .. ") " or ""))
			for j, pronun in ipairs(expressed_dialect.pronun) do
				if j > 1 then
					table.insert(formatted_for_len_parts, ", ")
				end
				if pronun.qualifiers then
					table.insert(formatted_for_len_parts, "(" .. table.concat(pronun.qualifiers, ", ") .. ") ")
				end
				table.insert(formatted_for_len_parts, "-" .. pronun.rhyme)
			end
			return formatted, textual_len(table.concat(formatted_for_len_parts))
		end

		return format_all_dialects(rhyme_ret.expressed_dialects, format_rhyme_dialect)
	end

	-- If all sets of pronunciations have the same hyphenations, display them only once at the bottom.
	-- Otherwise, display hyphenations beneath each set, indented.
	local first_hyphs
	local all_hyph_sets_eq = true
	for j, parsed in ipairs(parsed_respellings) do
		if j == 1 then
			first_hyphs = parsed.hyph
		elseif not m_table.deepEquals(first_hyphs, parsed.hyph) then
			all_hyph_sets_eq = false
			break
		end
	end

	local function format_hyphenations(hyphs, num_bullets)
		local hyphtext = require("Module:hyphenation").format_hyphenations { lang = lang, hyphs = hyphs, caption = "Syllabification" }
		return string.rep("*", num_bullets) .. " " .. hyphtext
	end

	-- If all sets of pronunciations have the same homophones, display them only once at the bottom.
	-- Otherwise, display homophones beneath each set, indented.
	local first_hmps
	local all_hmp_sets_eq = true
	for j, parsed in ipairs(parsed_respellings) do
		if j == 1 then
			first_hmps = parsed.hmp
		elseif not m_table.deepEquals(first_hmps, parsed.hmp) then
			all_hmp_sets_eq = false
			break
		end
	end

	local function format_homophones(hmps, num_bullets)
		local hmptext = require("Module:homophones").format_homophones { lang = lang, homophones = hmps }
		return string.rep("*", num_bullets) .. " " .. hmptext
	end

	local function format_audio(audios, num_bullets)
		local ret = {}
		for i, audio in ipairs(audios) do
			local text = require("Module:audio").format_audios (
				{
				  lang = lang,
				  audios = {{file = audio.file, qualifiers = nil }, },
				  caption = audio.gloss
				}
			)
			
			if audio.q and audio.q[1] or audio.qq and audio.qq[1]
				or audio.a and audio.a[1] or audio.aa and audio.aa[1] then
				text = require("Module:pron qualifier").format_qualifiers(audio, text)
			end
			table.insert(ret, string.rep("*", num_bullets) .. " " .. text)
		end
		return table.concat(ret, "\n")
	end

	local textparts = {}
	local min_num_bullets = 9999
	for j, parsed in ipairs(parsed_respellings) do
		if parsed.bullets < min_num_bullets then
			min_num_bullets = parsed.bullets
		end
		if j > 1 then
			table.insert(textparts, "\n")
		end
		table.insert(textparts, parsed.pronun.text)
		if #parsed.audio > 0 then
			table.insert(textparts, "\n")
			-- If only one pronunciation set, add the audio with the same number of bullets, otherwise
			-- indent audio by one more bullet.
			table.insert(textparts, format_audio(parsed.audio,
				#parsed_respellings == 1 and parsed.bullets or parsed.bullets + 1))
		end
		if not all_rhyme_sets_eq and parsed.rhyme then
			table.insert(textparts, "\n")
			table.insert(textparts, format_rhyme(parsed.rhyme, parsed.bullets + 1))
		end
		if not all_hyph_sets_eq and #parsed.hyph > 0 then
			table.insert(textparts, "\n")
			table.insert(textparts, format_hyphenations(parsed.hyph, parsed.bullets + 1))
		end
		if not all_hmp_sets_eq and #parsed.hmp > 0 then
			table.insert(textparts, "\n")
			table.insert(textparts, format_homophones(parsed.hmp, parsed.bullets + 1))
		end
	end
	if overall_audio and #overall_audio > 0 then
		table.insert(textparts, "\n")
		table.insert(textparts, format_audio(overall_audio, min_num_bullets))
	end
	if all_rhyme_sets_eq and first_rhyme_ret then
		table.insert(textparts, "\n")
		table.insert(textparts, format_rhyme(first_rhyme_ret, min_num_bullets))
	end
	if overall_rhyme then
		table.insert(textparts, "\n")
		table.insert(textparts, format_rhyme(overall_rhyme, min_num_bullets))
	end
	if all_hyph_sets_eq and #first_hyphs > 0 then
		table.insert(textparts, "\n")
		table.insert(textparts, format_hyphenations(first_hyphs, min_num_bullets))
	end
	if overall_hyph and #overall_hyph > 0 then
		table.insert(textparts, "\n")
		table.insert(textparts, format_hyphenations(overall_hyph, min_num_bullets))
	end
	if all_hmp_sets_eq and #first_hmps > 0 then
		table.insert(textparts, "\n")
		table.insert(textparts, format_homophones(first_hmps, min_num_bullets))
	end
	if overall_hmp and #overall_hmp > 0 then
		table.insert(textparts, "\n")
		table.insert(textparts, format_homophones(overall_hmp, min_num_bullets))
	end

	return table.concat(textparts)
end

return export

]=============]
