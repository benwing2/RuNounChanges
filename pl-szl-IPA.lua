--[[

	TODO: Decide on whether we want the Northern Borderlands dialect.
		The general consensus is to including it by doing the consonant subsitution and put the transcription in brackets
		Also the SBD should be included

--]]

local export = {}

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub
local ulen = mw.ustring.len
local ulower = mw.ustring.lower
local uupper = mw.ustring.upper
local usub = mw.ustring.sub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local OVERTIE = u(0x361) -- COMBINING DOUBLE INVERTED BREVE

--[[
	As can be seen from the last lines of the function, this returns a table of transcriptions,
	and if do_hyph, also a string being the hyphenation. These are based on a single spelling given,
	so the reason why the transcriptions are multiple is only because of the -yka alternating stress
	et sim. This only accepts single-word terms. Multiword terms are handled by multiword().
--]]
local function phonemic(txt, do_hyph, lang, is_prep, period)
	local ante = 0
	local unstressed = is_prep or false
	local colloquial = true

	function tsub(s, r)
		txt, c = rsubn(txt, s, r)
		return c > 0
	end
	function lg(s) return s[lang] or s[1] end
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

	-- Prevent palatisation of the special case kwazi-.
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
		if lang ~= "pl" then
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
				"do", "wy", "za", "aktyno", "akusto", "akwa", "anarcho", "andro", "anemo", "antropo", "arachno", "archeo", "archi", "arcy", "areo", "arytmo", "audio", "awio", "balneo", "biblio", "brachy", "broncho", "ceno", "centro", "centy", "chalko", "chiro", "chloro", "chole", "chondro", "choreo", "chromato", "chrysto", "cyber", "cyklo", "cztero", "ćwierć", "daktylo", "decy", "deka", "dendro", "dermato", "diafano", "dwu", "dynamo", "egzo", "ekstra", "elektro", "encefalo", "endo", "entero", "entomo", "ergo", "erytro", "etno", "farmako", "femto", "ferro", "fizjo", "flebo", "franko", "ftyzjo", "galakto", "galwano", "germano", "geronto", "giganto", "giga", "gineko", "giro", "gliko", "gloso", "glotto", "grafo", "granulo", "grawi", "haplo", "helio", "hemato", "hepta", "hetero", "hiper", "histo", "hydro", "info", "inter", "jedno", "kardio", "kortyko", "kosmo", "krypto", "kseno", "logo", "magneto", "między", "niby", "nie", "nowo", "około", "oksy", "onto", "ornito", "para", "pierwo", "pięcio", "pneumo", "poli", "ponad", "post", "poza", "proto", "pseudo", "psycho", "radio", "samo", "sfigmo", "sklero", "staro", "stereo", "tele", "tetra", "wice", "zoo", "żyro", "am[bf]i", "ang[il]o", "ant[ey]", "a?steno", "[be]lasto", "chro[mn]o", "cys?to", "de[rs]mo", "h?ekto", "[gn]eo", "hi[ge]ro", "kontra?", "me[gt]a", "mi[nl]i", "a[efg]ro", "[pt]rzy", "przed?", "wielk?o", "mi?elo", "eur[oy]", "ne[ku]ro", "allo", "astro", "atto", "brio", "heksa", "all?o", "at[mt]o", "a[rs]tro", "br?io", "heksa?", "pato", "ba[tr][oy]", "izo", "myzo", "m[ai]kro", "mi[mzk]o", "chemo", "gono", "kilo", "lipo", "nano", "kilk[ou]", "hem[io]", "home?o", "fi[lt]o", "ma[łn]o", "h[ioy]lo", "hip[ns]?o", "[fm]o[nt]o",
				-- <na-, po-, o-, u-> would hit too many false positives
			}
			for _, v in ipairs(prefixes) do
				if tfind("^"..v) then
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

	-- syllabification
	for _ = 0, 1 do
		tsub(("([%sU])([^%sU.']*)([%s])"):format(V, V, V), function (a, b, c)
			local function find(x) return rfind(b, x) end
			local function is_diagraph(thing)
				local r = find(thing:format("[crsd]z")) or find(thing:format("ch")) or find(thing:format("d[żź]"))
				if lang == "mpl" then return r or find(thing:format("b́")) end
				return r
			end
			if ((ulen(b) < 2) or is_diagraph("^%s$")) then
				b = "."..b
			else
				local i = 2
				if is_diagraph("^%s") then i = 3 end
				if usub(b, i, i):find("^[rlłI-]$") then
					b = "."..b
				else
					b = ("%s.%s"):format(usub(b, 0, i - 1), usub(b, i))
				end
			end
			return ("%s%s%s"):format(a, b, c)
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
	tsub("[crs]z", { ["cz"]="t_ʂ", ["rz"]="R", ["sz"]="ʂ" })
	tsub("d([zżź])", "d_%1")
	if lang == "mpl" then tsub("b́", "bʲ") end

	-- basic orthographical rules
	-- not using lg() here for speed
	if lang == "pl" then
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
	elseif lang == "mpl" then
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
	elseif lang == "szl" then
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

	-- palatalisation
	local palatise_into = { ["n"] = "ɲ", ["s"] = "ɕ", ["z"] = "ʑ" }
	tsub("([nsz])I", function (c) return palatise_into[c] end)
	tsub("([nsz])i", function (c) return palatise_into[c] .. "i" end)

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

	if lang ~= "mpl" then
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

	if lang == "pl" then
		-- nasal vowels
		tsub("N([.ˈ]?[pb])", "m%1")
		tsub("N([.ˈ]?[ɕʑ])", "ɲ%1")
		tsub("N([.ˈ]?[td]_[ɕʑ])", "ɲ%1")
		tsub("N([.ˈ]?[tdsz])", "n%1")
		tsub("N([.ˈ]?[wl])", "%1")
		tsub("ɛN$", "ɛ")
		tsub("N", "w̃")
	end

	-- Hyphen separator, e.g. to prevent palatisation of <kwazi->.
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
	local prons = should_stress and add_stress(ante) or txt

	if is_prep then
		prons = prons .. "$"
	end

	if lang == "pl" then
		if should_stress and ante > 0 and colloquial then
			local thing = add_stress(0)
			if thing ~= prons then
				prons = { prons, thing }
			end
		end
	elseif lang == "mpl" then
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
	elseif lang == "szl" then
		if tfind("O") then
			prons = {
				prons:gsub("O", "ɔ"),
				prons:gsub("O", "ɔw"),
			}
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
local function multiword(term, lang, period)
	if term:find("^%[.+%]$") then
		return { phonetic = term }
	elseif term:find(" ") then

		-- TODO: repeated
		function lg(s)
			return s[lang] or s[1]
		end

		local prepositions = lg {
			{
				"beze?", "na", "dla", "do", "ku",
				"nade?", "o", "ode?", "po", "pode?", "przede?",
				"przeze?", "przy", "spode?", "u", "we?",
				"z[ae]?", "znade?", "zza",
			}, szl = {
				"bezy?", "na", "dlŏ", "d[oō]", "ku",
				"nady?", "ô", "ôdy?", "po", "pody?", "przedy?",
				"przezy?", "przi", "spody?", "u", "w[ey]?",
				"z[aey]?", "[śs]", "znady?"
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
			local v = phonemic(word, false, lang, is_prep, period)
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
				str = rsub(str, ("%s(%%$ ˈ?[%s])"):format(from, before), to.."%1")
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
		return phonemic(term, lang ~= "mpl", lang, false, period)
	end

end

-- This handles all the magic characters <*>, <^>, <+>, <.>, <#>.
local function normalise_input(term, title)

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
		return title
	elseif (term == "+") or term:find("^%^+$") or (term == "*") then
		-- Inputs that are just '+', '*', '^', '^^', etc. are treated as
		-- if they contained the title with those symbols preceding it.
		return term .. title
	-- Handle syntax like <po.>, <.ka> and <po..ka>. This allows to not respell
	-- the entire word when all is needed is to specify syllabification of a prefix
	-- and/or a suffix.
	elseif term:find(".+%.$") then
		return check_pref(title, term:sub(1, -2))
	elseif term:find("^%..+") then
		return check_suf(title, term:sub(2))
	elseif term:find(".+%.%..+") then
		return check_suf(check_pref(title, term:gsub("%.%..+", "")), term:gsub(".+%.%.", ""))
	end

	return term

end

local function sort_things(lang, title, args_terms, args_quals, args_refs, args_period)

	local pron_list, hyph_list, rhyme_list, do_hyph = { {}, {}, {} }, { }, { {}, {}, {} }, false

	for index, term in ipairs(args_terms) do
		term = normalise_input(term, title)
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
				table_insert_if_absent(hyph_list, hyph)
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

	local process_args = {

		[1] = { list = true },

		["qual"] = { list = true, allow_holes = true },
		["q"] = { list = true, allow_holes = true, alias_of = "qual" },
		["hyphs"] = {}, ["h"] = { alias_of = "hyphs" },
		["rhymes"] = {}, ["r"] = { alias_of = "rhymes" },
		["audios"] = {}, ["a"] = { alias_of = "audios" },
		["homophones"] = {}, ["hh"] = { alias_of = "homophones" },
		["ref"] = { list = true, allow_holes = true },

		["title"] = {}, -- for debugging or demonstration only

	}

	if arg_lang == "pl" then
		process_args["mp"] = { list = true }
		process_args["mp_qual"] = { list = true, allow_holes = true }
		process_args["mp_q"] = { list = true, allow_holes = true, alias_of = "mp_qual" }
		process_args["mp_period"] = {}
		process_args["mp_ref"] = { list = true, allow_holes = true }
	end

	local args = require("Module:parameters").process(frame:getParent().args, process_args)

	local terms = args[1]
	local title = args.title or mw.title.getCurrentTitle().text

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
			ret = ret..require("Module:hyphenation").format_hyphenations {
				lang = lang, hyphs = hyphs, caption = "Syllabification"
			}
		else
			ret = ret.."Syllabification: <small>[please specify syllabification manually]</small>"
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

return export
