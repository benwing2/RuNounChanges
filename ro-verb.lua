local dbg = false

local export = {}
local data = {}
data.forms = {}
		
data.pronouns = {
	["Latn"] = {
		["1"] = {
			["s"] = "eu",
			["p"] = "noi",
		},
		["2"] = {
			["s"] = "tu",
			["p"] = "voi",
		},
		["3"] = {
			["s"] = "el/ea",
			["p"] = "ei/ele",
		},
	},

	["Cyrl"] = {
		["1"] = {
			["s"] = "еу",
			["p"] = "ной",
		},
		["2"] = {
			["s"] = "ту",
			["p"] = "вой",
		},
		["3"] = {
			["s"] = "ел/я",
			["p"] = "ей/еле",
		},
	},
}

local form_names = {
	"inf"         ,
	"ger"         ,
	"pp"          ,
	
	"indc_pres_1s",
	"indc_pres_2s",
	"indc_pres_3s",
	"indc_pres_1p",
	"indc_pres_2p",
	"indc_pres_3p",
	
	"indc_impf_1s",
	"indc_impf_2s",
	"indc_impf_3s",
	"indc_impf_1p",
	"indc_impf_2p",
	"indc_impf_3p",
	
	"indc_perf_1s",
	"indc_perf_2s",
	"indc_perf_3s",
	"indc_perf_1p",
	"indc_perf_2p",
	"indc_perf_3p",
	
	"indc_plup_1s",
	"indc_plup_2s",
	"indc_plup_3s",
	"indc_plup_1p",
	"indc_plup_2p",
	"indc_plup_3p",
	
	"subj_pres_1s",
	"subj_pres_2s",
	"subj_pres_3s",
	"subj_pres_1p",
	"subj_pres_2p",
	"subj_pres_3p",
	
	"impr_aff_2s" ,
	"impr_aff_2p" ,
	"impr_neg_2s" ,
	"impr_neg_2p" ,
}

local consonants = {
	["i_"] = {
		{"[sș][ct]$", "șt"},
		{"^d$", "z"},
		{"^t$", "ț"},
		{"([^șj])d$", "%1z"},
		{"([^șj])t$", "%1ț"},
		{"s$", "ș"},
		{"x$", "cș"},
	},
	
	["i"] = {
		{"[sș]c$", "șt"},
		{"x$", "cș"},
	},

	["e"] = {
		{"[sș]c$", "șt"},
	},
}

local consonants_23 = {
	["i_"] = {
		{"^n$", ""},
	},
	
	["u"] = {
		{"^d$", "z"},
	},

	["â"] = {
		{"d$", "z"},
		-- {"t$", "ț"}, -- inconsistent
	}
}

-- stressed stems for null, ă, e and i endings
-- the given stems should not include the unstressed stem (unless it happens to
-- coincide with one of the other forms)
local vow_changes = {
	-- sort order: aeiouâîă
	
	["a-e"] = {	-- zbiera/așeza, a variant of e-ea below
		["-"] = "e",
		["ă"] = "a",
		["e"] = "e",
		["i"] = "e",
	},

	["a-e-ă"] = {	-- spăla
		["-"] = "ă",
		["ă"] = "a",
		["e"] = "e",
		["i"] = "e",
	},

	["a-ă"] = {	-- arăta
		["-"] = "ă",
		["ă"] = "a",
		["e"] = "a",
		["i"] = "ă",
	},

	["e-ea"] = {	-- încerca
		["-"] = "e",
		["ă"] = "ea",
		["e"] = "e",
		["i"] = "e",
	},

	["e-ea-2"] = {	-- lepăda
		["-"] = {"e", "ea"},
		["ă"] = "ea",
		["e"] = "e",
		["i"] = "e",
	},

	["e-ă"] = {		-- supăra
		["-"] = "ă",
		["ă"] = "ă",
		["e"] = "e",
		["i"] = "e",
	},

	["i-â"] = {		-- vinde (might be the only one)
		["-"] = "â",
		["ă"] = "â",
		["e"] = "i",
		["i"] = "i",
	},

	["o-oa"] = {	-- toca
		["-"] = "o",
		["ă"] = "oa",
		["e"] = "oa",
		["i"] = "o",
	},
}

-- format: conj = {lemma, stems, stem}
local template_defaults = {
	["a"] = {"aduna"},
	["a-ez"] = {"lucra"},
	["i"] = {"dormi", "dorm/doarm"},
	["i-esc"] = {"munci"},
	["î"] = {"coborî", "cobor/coboar"},
	["î-ăsc"] = {"hotărî"},
	["e-s"] = {"ajunge"},
	["e-t"] = {"sparge", "sparg", "spărg"},
	["e-pt"] = {"rupe"},
	["e-ut"] = {"trece", "trec/treac"},
	["ea-ut"] = {"cădea", "cad"},
}

local m_links = require("Module:links")
local lang = require("Module:languages").getByCode("ro")

local PAGENAME = mw.title.getCurrentTitle().text

local vowels = "aeiouăâî"

local function split(word)
	local stem, vow, cons
	
	if mw.ustring.match(word, "[" .. vowels .. "][iu]$") then
		stem, vow, cons = mw.ustring.match(word, "^(.-)([" .. vowels .. "]-)([iu])$")
	else
		stem, vow, cons = mw.ustring.match(word, "^(.-)([" .. vowels .. "]-)([^" .. vowels .. "]-)$")
	end
	
	return stem, vow, cons
end

local function split_vow(vow)
	local pre, post = "", ""
	
	if mw.ustring.len(vow) > 1 then
		pre, vow, post = mw.ustring.match(vow, "^([iu]?)(.-)([iu]?)$")
	end
	
	return pre, vow, post
end

-- todo: somehow account for hiatus (deochea)
local function get_vow_changes(words, result)
	local all_dupes = true
	
	for _, val in ipairs(words) do
		if val ~= words[1] then
			all_dupes = false
			break
		end
	end
	
	if all_dupes then
		table.insert(result, words[1])
		
		return
	else
		local split_words = {}
		
		for _, val in ipairs(words) do
			if val == "" then
				error("Cannot match stems, should only have different vowels")
			end
			
			local stem, pre, vow, post, cons
			local res = {}
			
			stem, vow, cons = split(val)
			pre, vow, post = split_vow(vow)
			
			table.insert(res, stem)
			table.insert(res, pre)
			table.insert(res, vow)
			table.insert(res, post)
			table.insert(res, cons)
			
			table.insert(split_words, res)
		end
		
		local vowel_appearances, found_vowels = {}, {}
		
		for i, val in ipairs(split_words) do
			-- compare pre-vowel, post-vowel, cons
			if val[5] ~= split_words[1][5] then
				error("Stems differ in something other than main vowels: " 
					.. words[1] .. ", " .. words[i] .. ", "
					.. (val[5] or "fjdfl") .. ", " .. (split_words[1][5] or " fda"))
			end
			
			if val[4] ~= split_words[1][4] then
				error("Stems differ in something other than main vowels: " 
					.. words[1] .. ", " .. words[i] .. ", "
					.. val[4] .. ", " .. split_words[1][4])
			end
			
			if val[2] ~= split_words[1][2] then
				error("Stems differ in something other than main vowels: " 
					.. words[1] .. ", " .. words[i] .. ", "
					.. val[2] .. ", " .. split_words[1][2])
			end
			
			-- add the vowel
			vowel_appearances[val[3]] = true
		end
		
		for vow, _ in pairs(vowel_appearances) do
			table.insert(found_vowels, vow)
		end
		
		table.sort(found_vowels)
		
		-- replace words with stems
		for key, _ in ipairs(words) do
			words[key] = split_words[key][1]
		end
		
		get_vow_changes(words, result)
		
		-- join pre-vowel to last consonant
		result[#result] = result[#result] .. split_words[1][2]
		
		-- add all the vowel variations
		table.insert(result, table.concat(found_vowels, "-"))
		
		-- add post-vowel + last cons
		table.insert(result, split_words[1][4] .. split_words[1][5])
		
		return
	end
end

local get_stem_a = function()
	local stem
	
	if mw.ustring.match(data.lemma, "[cg]hea$") then
		stem = mw.ustring.match(data.lemma, "^(.*)ea$")
	else
		stem = mw.ustring.match(data.lemma, "^(.*)a$")
	end
	
	return stem
	or error("The given conjugation type does not match the infinitive ending")
end

local get_stem_e = function()
	return mw.ustring.match(data.lemma, "^(.*)e$")
	or error("The given conjugation type does not match the infinitive ending")
end

local get_stem_ea = function()
	return mw.ustring.match(data.lemma, "^(.*)ea$")
	or error("The given conjugation type does not match the infinitive ending")
end

local get_stem_i = function()
	return mw.ustring.match(data.lemma, "^(.*[" .. vowels .. "]i)$")
	or mw.ustring.match(data.lemma, "^(.*)i$")
	or error("The given conjugation type does not match the infinitive ending")
end

local get_stem_ih = function()
	return mw.ustring.match(data.lemma, "^(.*)î$")
	or error("The given conjugation type does not match the infinitive ending")
end

-- todo: don't do this
local get_inf_stem = function()
	if mw.ustring.find(data.type, "^a") then
		return get_stem_a()
	elseif mw.ustring.find(data.type, "^i") then
		return get_stem_i()
	elseif mw.ustring.find(data.type, "^î") then
		return get_stem_ih()
	elseif mw.ustring.find(data.type, "^ea") then
		return get_stem_ea()
	elseif mw.ustring.find(data.type, "^e") then
		return get_stem_e()
	end
end

-- given a comma-separated list of slash-separated lists of stems
-- get a list of stems for each ending
local function get_stems(stems)
	local stem_types = {"-", "ă", "e", "i"}
	
	local res = {}
	
	for _, stype in ipairs(stem_types) do
		res[stype] = {}
	end
	
	if not stems then
		local stem = get_inf_stem()
		
		for _, val in ipairs(stem_types) do
			res[val] = stem
		end
	else
		local stem_lists = mw.text.split(stems, " *, *")
		
		for _, stem_set in ipairs(stem_lists) do
			-- make a new resi table to hold all the stems
			local resi = {}
			local stems2, stem_parts = mw.text.split(stem_set, " */ *"), {}
			
			get_vow_changes(stems2, stem_parts)
			
			for _, stype in ipairs(stem_types) do
				resi[stype] = {""}
				
				for i = 1, #stem_parts, 2 do
					for j, _ in ipairs(resi[stype]) do
	                    resi[stype][j] = resi[stype][j] .. stem_parts[i]
	                end
	                
	                -- which syllable this is, counting from the end
	                local syln = (#stem_parts - i) / 2
					
					if stem_parts[i + 1] then
						local vc = vow_changes[stem_parts[i + 1] .. "-" .. syln] 
	                    or vow_changes[stem_parts[i + 1]]
	                    
						if not vc then
	                    -- no vowel alternation found for these vowels
	                    
							if not mw.ustring.find(stem_parts[i + 1], "\-") then
							-- there's only one vowel, so use it
							
								for k, stem in ipairs(resi[stype]) do
									resi[stype][k] = stem .. stem_parts[i + 1]
								end
							else
							-- multiple vowels not matching a known vowel alternation
								
								error(stem_parts[i + 1] ..
								" is not a valid vowel change")
		                    end
						elseif type(vc[stype]) == "string" then
						-- only one vowel can be used with that ending
						
							for k, stem in ipairs(resi[stype]) do
								resi[stype][k] = stem .. vc[stype]
							end
						elseif type(vc[stype]) == "table" then
						-- multiple vowels for that ending, so make a copy
						-- of the partial stem for each one
							
							local copy = resi[stype]
							resi[stype] = {}
							
							for _, vow in ipairs(vc[stype]) do
								for _, stem in ipairs(copy) do
									table.insert(resi[stype], stem .. vow)
								end
							end
						end
					end
				end
			end
			
			-- add only the stems that are not already in res
			for _, stype in ipairs(stem_types) do
				for _, stemi in ipairs(resi[stype]) do
					local is_new = true
					
					for _, stem in ipairs(res[stype]) do
						if stem == stemi then
							is_new = false
							
							break
						end
					end
					
					if is_new then
						table.insert(res[stype], stemi)
					end
				end
			end
		end
	end
	
	return res
end

local function find_cons(cons, mode, conj_23, vow)
	local n
	
	-- ugly hack
	if conj_23 and mode == "â" and cons == "t" 
	and mw.ustring.find(vow, "[eio]$") then
		cons = "ț"
		
		return cons
	end
	
	if conj_23 and consonants_23[mode] then
		for _, p in ipairs(consonants_23[mode]) do
			cons, n = mw.ustring.gsub(cons, p[1], p[2], 1)
			
			if n >= 1 then
				return cons
			end
		end
	end
	
	if consonants[mode] then
		for _, p in pairs(consonants[mode]) do
			cons, n = mw.ustring.gsub(cons, p[1], p[2], 1)
			
			if n >= 1 then
				return cons
			end
		end
	end

	return cons
end

local tsub = function(t, i, j)
	local res = mw.clone(t)
	
	for k, form in ipairs(res) do
		res[k] = mw.ustring.sub(form, i, j)
	end
	
	return res
end

-- compare two arrays, ignoring order
-- might not work if there are duplicates
local tequals = function(t1, t2)
	if #t1 ~= #t2 then
		return false
	else
		local a = {}
		
		for _, val in ipairs(t1) do
			a[val] = true
		end
		
		for _, val in ipairs(t2) do
			if not a[val] then
				return false
			end
		end
		
		return true
	end
end

-- common for both functions below
local join_ending_common = function(stem, ending)
	ending = ending or ""
	local res = {}
	
	if type(stem) == "string" then
		stem = {stem}
	end
	
	for _, s in ipairs(stem) do
		if ending == "" then
			if mw.ustring.match(s, "[cg]h$") or mw.ustring.match(s, "[^" .. vowels .. "]i$") then
				table.insert(res, s .. "i")
			elseif mw.ustring.match(s, "[^" .. vowels .. "][lr]$") then
				table.insert(res, s .. "u")
			end
		elseif mw.ustring.match(s, "[cg]h$") then
			if mw.ustring.match(ending, "^a") then
				table.insert(res, s .. "e" .. ending)
			elseif mw.ustring.match(ending, "^ă") then
				table.insert(res, s .. mw.ustring.gsub(ending, "^ă", "e"))
			elseif mw.ustring.match(ending, "^[âî]") then
				table.insert(res, s .. mw.ustring.gsub(ending, "^[âî]", "i"))
			end
		elseif mw.ustring.match(s, "i$") then
			if mw.ustring.match(ending, "^ă") then
				table.insert(res, s .. mw.ustring.gsub(ending, "^ă", "e"))
			elseif mw.ustring.match(ending, "^ea") then
				table.insert(res, s .. mw.ustring.gsub(ending, "^e", ""))
			elseif mw.ustring.match(ending, "^[âi]") then
				if mw.ustring.match(s, "[" .. vowels .. "]i$") then
					table.insert(res, s .. mw.ustring.gsub(ending, "^[âi]", ""))
				else
					table.insert(res, s .. mw.ustring.gsub(ending, "^[âi]", "i"))
				end
			end
		end
	end
	
	return res
end

-- no consonant change
local join_ending_2 = function(stem, ending)
	ending = ending or ""
	local res = join_ending_common(stem, ending)
	
	if #res == 0 then
		if type(stem) == "string" then
			stem = {stem}
		end
		
		for _, s in ipairs(stem) do
			if mw.ustring.match(ending, "^[ei]") and mw.ustring.match(s, "[cg]$") then
				table.insert(res, s .. "h" .. ending)
			else
				table.insert(res, s .. ending)
			end
		end
	end
	
	for i, form in ipairs(res) do
		res[i] = mw.ustring.match(form, "^(.-)_?$")
	end
	
	return res
end

-- consonant change
local join_ending = function(stem, ending, conj_23)
	ending = ending or ""
	local res = join_ending_common(stem, ending)
	
	if #res == 0 then
		if type(stem) == "string" then
			stem = {stem}
		end
		
		for _, s in ipairs(stem) do
			if mw.ustring.match(ending, "^[ei]") or 
			(conj_23 and mw.ustring.match(ending, "^[uâ]")) then
				local st, vow, cons = split(s)
				local ending_vow = ending == "i_" and "i_" or mw.ustring.sub(ending, 1, 1)
				
				cons = find_cons(cons, ending_vow, conj_23, vow)
				
				table.insert(res, st .. vow .. cons .. ending)
			else
				table.insert(res, s .. ending)
			end
		end
	end
	
	for i, form in ipairs(res) do
		res[i] = mw.ustring.match(form, "^(.-)_?$")
	end
	
	return res
end

local add_form = function(t, name, new_form)
	if not t[name] then
		t[name] = new_form
	end
end

local add_repeated_forms_new = function(t)
	add_form(t, "inf", {data.lemma})
	
	add_form(t, "indc_impf_1s", join_ending(t.impf_stem, "am"))
	add_form(t, "indc_impf_2s", join_ending(t.impf_stem, "ai"))
	add_form(t, "indc_impf_3s", join_ending(t.impf_stem, "a"))
	add_form(t, "indc_impf_1p", join_ending(t.impf_stem, "am"))
	add_form(t, "indc_impf_2p", join_ending(t.impf_stem, "ați"))
	add_form(t, "indc_impf_3p", join_ending(t.impf_stem, "au"))
	
	add_form(t, "indc_plup_1s", join_ending(t.plup_stem, "sem"))
	add_form(t, "indc_plup_2s", join_ending(t.plup_stem, "seși"))
	add_form(t, "indc_plup_3s", join_ending(t.plup_stem, "se"))
	add_form(t, "indc_plup_1p", join_ending(t.plup_stem, "serăm"))
	add_form(t, "indc_plup_2p", join_ending(t.plup_stem, "serăți"))
	add_form(t, "indc_plup_3p", join_ending(t.plup_stem, "seră"))
	
	add_form(t, "subj_pres_1s", mw.clone(t.indc_pres_1s))
	add_form(t, "subj_pres_2s", mw.clone(t.indc_pres_2s))
	add_form(t, "subj_pres_1p", mw.clone(t.indc_pres_1p))
	add_form(t, "subj_pres_2p", mw.clone(t.indc_pres_2p))
	
	add_form(t, "subj_pres_3p", mw.clone(t.subj_pres_3s))
	
	add_form(t, "impr_aff_2p", mw.clone(t.indc_pres_2p))
	add_form(t, "impr_neg_2s", mw.clone(t.inf))
	add_form(t, "impr_neg_2p", mw.clone(t.indc_pres_2p))
end

local conjugations_new = {}

conjugations_new["a"] = function(t, stem, stems, ez)
	data.conj = 1
	
	stem = stem or get_stem_a() -- unstressed stem
	stem_ = stems["-"] or stem -- stressed stem before zero ending
	stem_ah = stems["ă"] or stem -- stressed stem before ă ending
	stem_e = stems["e"] or stem -- stressed stem before e ending
	stem_i = stems["i"] or stem -- stressed stem before i ending
	
	add_form(t, "ger", join_ending(stem, "ând"))
	add_form(t, "pp", join_ending(stem, "at"))
	
	add_form(t, "indc_pres_1s", join_ending(stem_, ""))
	add_form(t, "indc_pres_2s", join_ending(stem_i, "i_"))
	add_form(t, "indc_pres_3s", join_ending(stem_ah, "ă"))
	add_form(t, "indc_pres_1p", join_ending(stem, "ăm"))
	add_form(t, "indc_pres_2p", join_ending(stem, "ați"))
	add_form(t, "indc_pres_3p", mw.clone(t.indc_pres_3s))
	
	t.impf_stem = stem
	
	add_form(t, "indc_perf_1s", join_ending(stem, "ai"))
	add_form(t, "indc_perf_2s", join_ending(stem, "ași"))
	add_form(t, "indc_perf_3s", join_ending(stem, "ă"))
	add_form(t, "indc_perf_1p", join_ending(stem, "arăm"))
	add_form(t, "indc_perf_2p", join_ending(stem, "arăți"))
	add_form(t, "indc_perf_3p", join_ending(stem, "ară"))
	
	t.plup_stem = join_ending(stem, "a")
	
	add_form(t, "subj_pres_3s", join_ending(stem_e, "e"))
	
	add_form(t, "impr_aff_2s", mw.clone(t.indc_pres_3s))
end

conjugations_new["a-ez"] = function(t, stem)
	stem = stem or get_stem_a()
	local stem_ez = join_ending_2(stem, "ez")
	local stem_eaz = join_ending_2(stem, "eaz")
	
	conjugations_new["a"](t, stem, {["-"] = stem_ez,
								 ["ă"] = stem_eaz,
								 ["e"] = stem_ez,
								 ["i"] = stem_ez}, true)
end

conjugations_new["i"] = function(t, stem, stems, esc)
	data.conj = 4
	
	stem = stem or get_stem_i() -- unstressed stem
	stem_ = stems["-"] or stem -- stressed stem before zero ending
	stem_ah = stems["ă"] or stem -- stressed stem before ă ending
	stem_e = stems["e"] or stem -- stressed stem before e ending
	stem_i = stems["i"] or stem -- stressed stem before i ending
	
	add_form(t, "ger", join_ending(stem, "ind"))
	add_form(t, "pp", join_ending(stem, "it"))
	
	add_form(t, "indc_pres_1s", join_ending(stem_, ""))
	add_form(t, "indc_pres_2s", join_ending(stem_i, "i_"))
	add_form(t, "indc_pres_3s", join_ending(stem_e, "e"))
	add_form(t, "indc_pres_1p", join_ending(stem, "im"))
	add_form(t, "indc_pres_2p", join_ending(stem, "iți"))
	-- todo: this is probably based on stress
	add_form(t, "indc_pres_3p", mw.clone(mw.ustring.match(stem_[1], "[" .. vowels .. "]i$"))
							  and t.indc_pres_3s or t.indc_pres_1s)
	
	t.impf_stem = tsub(join_ending(stem, "ea"), 1, -2)
	
	add_form(t, "indc_perf_1s", join_ending(stem, "ii"))
	add_form(t, "indc_perf_2s", join_ending(stem, "iși"))
	add_form(t, "indc_perf_3s", join_ending(stem, "i"))
	add_form(t, "indc_perf_1p", join_ending(stem, "irăm"))
	add_form(t, "indc_perf_2p", join_ending(stem, "irăți"))
	add_form(t, "indc_perf_3p", join_ending(stem, "iră"))
	
	t.plup_stem = join_ending(stem, "i")
	
	add_form(t, "subj_pres_3s", join_ending(stem_ah, "ă"))
	
	add_form(t, "impr_aff_2s", mw.clone(t.indc_pres_3s))
end

conjugations_new["i-esc"] = function(t, stem)
	stem = stem or get_stem_i()
	local stem_esc = join_ending(stem, "esc")
	local stem_easc = join_ending(stem, "easc")
	
	conjugations_new["i"](t, stem, {["-"] = stem_esc,
								 ["ă"] = stem_easc,
								 ["e"] = stem_esc,
								 ["i"] = stem_esc}, true)
end

conjugations_new["î"] = function(t, stem, stems)
	data.conj = 4
	
	stem = stem or get_stem_ih() -- unstressed stem
	stem_ = stems["-"] or stem -- stressed stem before zero ending
	stem_ah = stems["ă"] or stem -- stressed stem before ă ending
	stem_e = stems["e"] or stem -- stressed stem before e ending
	stem_i = stems["i"] or stem -- stressed stem before i ending
	
	add_form(t, "ger", join_ending(stem, "ând"))
	add_form(t, "pp", join_ending(stem, "ât"))
	
	add_form(t, "indc_pres_1s", join_ending(stem_, ""))
	add_form(t, "indc_pres_2s", join_ending(stem_i, "i_"))
	add_form(t, "indc_pres_3s", join_ending(stem_ah, "ă"))
	add_form(t, "indc_pres_1p", join_ending(stem, "âm"))
	add_form(t, "indc_pres_2p", join_ending(stem, "âți"))
	-- todo: change this
	add_form(t, "indc_pres_3p", mw.clone(t.indc_pres_3s))
	
	t.impf_stem = stem
	
	add_form(t, "indc_perf_1s", join_ending(stem, "âi"))
	add_form(t, "indc_perf_2s", join_ending(stem, "âși"))
	add_form(t, "indc_perf_3s", join_ending(stem, "î"))
	add_form(t, "indc_perf_1p", join_ending(stem, "ârăm"))
	add_form(t, "indc_perf_2p", join_ending(stem, "ârăți"))
	add_form(t, "indc_perf_3p", join_ending(stem, "âră"))
	
	t.plup_stem = join_ending(stem, "â")
	
	add_form(t, "subj_pres_3s", join_ending(stem_e, "e"))
	
	add_form(t, "impr_aff_2s", mw.clone(t.indc_pres_3s))
end

conjugations_new["î-ăsc"] = function(t, stem)
	data.conj = 4
	
	stem = stem or get_stem_ih()
	stem_ = join_ending(stem, "ăsc") -- stressed stem before zero ending
	stem_ah = join_ending(stem, "asc") -- stressed stem before ă ending
	stem_e = stem_ -- stressed stem before e ending
	stem_i = stem_ -- stressed stem before i ending
	
	add_form(t, "ger", join_ending(stem, "ând"))
	add_form(t, "pp", join_ending(stem, "ât"))
	
	add_form(t, "indc_pres_1s", join_ending(stem_, ""))
	add_form(t, "indc_pres_2s", join_ending(stem_i, "i_"))
	add_form(t, "indc_pres_3s", join_ending(stem_e, "e"))
	add_form(t, "indc_pres_1p", join_ending(stem, "âm"))
	add_form(t, "indc_pres_2p", join_ending(stem, "âți"))
	add_form(t, "indc_pres_3p", mw.clone(t.indc_pres_1s))
	
	t.impf_stem = stem
	
	add_form(t, "indc_perf_1s", join_ending(stem, "âi"))
	add_form(t, "indc_perf_2s", join_ending(stem, "âși"))
	add_form(t, "indc_perf_3s", join_ending(stem, "î"))
	add_form(t, "indc_perf_1p", join_ending(stem, "ârăm"))
	add_form(t, "indc_perf_2p", join_ending(stem, "ârăți"))
	add_form(t, "indc_perf_3p", join_ending(stem, "âră"))
	
	t.plup_stem = join_ending(stem, "â")
	
	add_form(t, "subj_pres_3s", join_ending(stem_ah, "ă"))
	
	add_form(t, "impr_aff_2s", mw.clone(t.indc_pres_3s))
end

conjugations_new["e-s"] = function(t, stem, stems)
	data.conj = 3
	
	stem = stem or get_stem_e() -- unstressed stem
	stem_ = stems["-"] or stem -- stressed stem before zero ending
	stem_ah = stems["ă"] or stem -- stressed stem before i ending
	stem_e = stems["e"] or stem -- stressed stem before e ending
	stem_i = stems["i"] or stem -- stressed stem before ă ending
	
	local pp_stem = tsub(stem, 1, -2)
	local pp_stem_ = tsub(stem_, 1, -2)
	local pp_stem_e = tsub(stem_e, 1, -2)
	
	add_form(t, "ger", join_ending(stem, "ând", true))
	add_form(t, "pp", join_ending(pp_stem_, "s"))
	
	add_form(t, "indc_pres_1s", join_ending(stem_, ""))
	add_form(t, "indc_pres_2s", join_ending(stem_i, "i_", true))
	add_form(t, "indc_pres_3s", join_ending(stem_e, "e"))
	add_form(t, "indc_pres_1p", join_ending(stem_e, "em"))
	add_form(t, "indc_pres_2p", join_ending(stem_e, "eți"))
	add_form(t, "indc_pres_3p", mw.clone(t.indc_pres_1s))
	
	t.impf_stem = tsub(join_ending(stem, "ea"), 1, -2)
	
	add_form(t, "indc_perf_1s", join_ending(pp_stem, "sei"))
	add_form(t, "indc_perf_2s", join_ending(pp_stem, "seși"))
	add_form(t, "indc_perf_3s", join_ending(pp_stem_e, "se"))
	add_form(t, "indc_perf_1p", join_ending(pp_stem_e, "serăm"))
	add_form(t, "indc_perf_2p", join_ending(pp_stem_e, "serăți"))
	add_form(t, "indc_perf_3p", join_ending(pp_stem_e, "seră"))
	
	t.plup_stem = join_ending(pp_stem, "se")
	
	add_form(t, "subj_pres_3s", join_ending(stem_ah, "ă"))
	
	add_form(t, "impr_aff_2s", mw.clone(t.indc_pres_3s))
end

-- same as e-s except for the past participle
conjugations_new["e-t"] = function(t, stem, stems)
	data.conj = 3
	
	stem = stem or get_stem_e() -- unstressed stem
	stem_ = stems["-"] or stem -- stressed stem before zero ending
	stem_ah = stems["ă"] or stem -- stressed stem before i ending
	stem_e = stems["e"] or stem -- stressed stem before e ending
	stem_i = stems["i"] or stem -- stressed stem before ă ending
	
	local pp_stem = tsub(stem, 1, -2)
	local pp_stem_ = tsub(stem_, 1, -2)
	local pp_stem_e = tsub(stem_e, 1, -2)
	
	add_form(t, "ger", join_ending(stem, "ând", true))
	add_form(t, "pp", join_ending(pp_stem_, "t"))
	
	add_form(t, "indc_pres_1s", join_ending(stem_, ""))
	add_form(t, "indc_pres_2s", join_ending(stem_i, "i_", true))
	add_form(t, "indc_pres_3s", join_ending(stem_e, "e"))
	add_form(t, "indc_pres_1p", join_ending(stem_e, "em"))
	add_form(t, "indc_pres_2p", join_ending(stem_e, "eți"))
	add_form(t, "indc_pres_3p", mw.clone(t.indc_pres_1s))
	
	t.impf_stem = tsub(join_ending(stem, "ea"), 1, -2)
	
	add_form(t, "indc_perf_1s", join_ending(pp_stem, "sei"))
	add_form(t, "indc_perf_2s", join_ending(pp_stem, "seși"))
	add_form(t, "indc_perf_3s", join_ending(pp_stem_e, "se"))
	add_form(t, "indc_perf_1p", join_ending(pp_stem_e, "serăm"))
	add_form(t, "indc_perf_2p", join_ending(pp_stem_e, "serăți"))
	add_form(t, "indc_perf_3p", join_ending(pp_stem_e, "seră"))
	
	t.plup_stem = join_ending(pp_stem, "se")
	
	add_form(t, "subj_pres_3s", join_ending(stem_ah, "ă"))
	
	add_form(t, "impr_aff_2s", mw.clone(t.indc_pres_3s))
end

conjugations_new["e-pt"] = function(t, stem, stems)
	data.conj = 3
	
	stem = stem or get_stem_e() -- unstressed stem
	stem_ = stems["-"] or stem -- stressed stem before zero ending
	stem_ah = stems["ă"] or stem -- stressed stem before i ending
	stem_e = stems["e"] or stem -- stressed stem before e ending
	stem_i = stems["i"] or stem -- stressed stem before ă ending
	
	local pp_stem = tsub(stem, 1, -2)
	local pp_stem_ = tsub(stem_, 1, -2)
	local pp_stem_e = tsub(stem_e, 1, -2)
	
	add_form(t, "ger", join_ending(stem, "ând", true))
	add_form(t, "pp", join_ending(pp_stem_, "pt"))
	
	add_form(t, "indc_pres_1s", join_ending(stem_, ""))
	add_form(t, "indc_pres_2s", join_ending(stem_i, "i_", true))
	add_form(t, "indc_pres_3s", join_ending(stem_e, "e"))
	add_form(t, "indc_pres_1p", join_ending(stem_e, "em"))
	add_form(t, "indc_pres_2p", join_ending(stem_e, "eți"))
	add_form(t, "indc_pres_3p", mw.clone(t.indc_pres_1s))
	
	t.impf_stem = tsub(join_ending(stem, "ea"), 1, -2)
	
	add_form(t, "indc_perf_1s", join_ending(pp_stem, "psei"))
	add_form(t, "indc_perf_2s", join_ending(pp_stem, "pseși"))
	add_form(t, "indc_perf_3s", join_ending(pp_stem_e, "pse"))
	add_form(t, "indc_perf_1p", join_ending(pp_stem_e, "pserăm"))
	add_form(t, "indc_perf_2p", join_ending(pp_stem_e, "pserăți"))
	add_form(t, "indc_perf_3p", join_ending(pp_stem_e, "pseră"))
	
	t.plup_stem = join_ending(pp_stem, "pse")
	
	add_form(t, "subj_pres_3s", join_ending(stem_ah, "ă"))
	
	add_form(t, "impr_aff_2s", mw.clone(t.indc_pres_3s))
end

conjugations_new["e-ut"] = function(t, stem, stems)
	data.conj = 3
	
	stem = stem or get_stem_e() -- unstressed stem
	stem_ = stems["-"] or stem -- stressed stem before zero ending
	stem_ah = stems["ă"] or stem -- stressed stem before i ending
	stem_e = stems["e"] or stem -- stressed stem before e ending
	stem_i = stems["i"] or stem -- stressed stem before ă ending
	
	add_form(t, "ger", join_ending(stem, "ând", true))
	add_form(t, "pp", join_ending(stem, "ut", true))
	
	add_form(t, "indc_pres_1s", join_ending(stem_, ""))
	add_form(t, "indc_pres_2s", join_ending(stem_i, "i_", true))
	add_form(t, "indc_pres_3s", join_ending(stem_e, "e"))
	add_form(t, "indc_pres_1p", join_ending(stem_e, "em"))
	add_form(t, "indc_pres_2p", join_ending(stem_e, "eți"))
	add_form(t, "indc_pres_3p", mw.clone(t.indc_pres_1s))
	
	t.impf_stem = tsub(join_ending(stem, "ea"), 1, -2)
	
	add_form(t, "indc_perf_1s", join_ending(stem, "ui", true))
	add_form(t, "indc_perf_2s", join_ending(stem, "uși", true))
	add_form(t, "indc_perf_3s", join_ending(stem, "u", true))
	add_form(t, "indc_perf_1p", join_ending(stem, "urăm", true))
	add_form(t, "indc_perf_2p", join_ending(stem, "urăți", true))
	add_form(t, "indc_perf_3p", join_ending(stem, "ură", true))
	
	t.plup_stem = join_ending(stem, "u", true)
	
	add_form(t, "subj_pres_3s", join_ending(stem_ah, "ă"))
	
	add_form(t, "impr_aff_2s", mw.clone(t.indc_pres_3s))
end

conjugations_new["ea-ut"] = function(t, stem, stems)
	data.conj = 2
	
	stem = stem or get_stem_ea() -- unstressed stem
	stem_ = stems["-"] or stem -- stressed stem before zero ending
	stem_ah = stems["ă"] or stem -- stressed stem before i ending
	stem_e = stems["e"] or stem -- stressed stem before e ending
	stem_i = stems["i"] or stem -- stressed stem before ă ending
	
	add_form(t, "ger", join_ending(stem, "ând", true))
	add_form(t, "pp", join_ending(stem, "ut", true))
	
	add_form(t, "indc_pres_1s", join_ending(stem_, ""))
	add_form(t, "indc_pres_2s", join_ending(stem_i, "i_", true))
	add_form(t, "indc_pres_3s", join_ending(stem_e, "e"))
	add_form(t, "indc_pres_1p", join_ending(stem, "em"))
	add_form(t, "indc_pres_2p", join_ending(stem, "eți"))
	add_form(t, "indc_pres_3p", mw.clone(t.indc_pres_1s))
	
	t.impf_stem = tsub(join_ending(stem, "ea"), 1, -2)
	
	add_form(t, "indc_perf_1s", join_ending(stem, "ui", true))
	add_form(t, "indc_perf_2s", join_ending(stem, "uși", true))
	add_form(t, "indc_perf_3s", join_ending(stem, "u", true))
	add_form(t, "indc_perf_1p", join_ending(stem, "urăm", true))
	add_form(t, "indc_perf_2p", join_ending(stem, "urăți", true))
	add_form(t, "indc_perf_3p", join_ending(stem, "ură", true))
	
	t.plup_stem = join_ending(stem, "u", true)
	
	add_form(t, "subj_pres_3s", join_ending(stem_ah, "ă"))
	
	add_form(t, "impr_aff_2s", mw.clone(t.indc_pres_3s))
end

local add_repeated_forms = function()
	add_form(data.forms, "inf", {data.lemma})
	
	local impf_stem = mw.ustring.match(data.forms.indc_impf_1s[1], "^(.*)am$")
	
	add_form(data.forms, "indc_impf_2s", {impf_stem .. "ai"})
	add_form(data.forms, "indc_impf_3s", {impf_stem .. "a"})
	add_form(data.forms, "indc_impf_1p", {impf_stem .. "am"})
	add_form(data.forms, "indc_impf_2p", {impf_stem .. "ați"})
	add_form(data.forms, "indc_impf_3p", {impf_stem .. "au"})
	
	local plup_stem = mw.ustring.match(data.forms.indc_plup_1s[1], "^(.*)sem$")
	
	add_form(data.forms, "indc_perf_1s", {plup_stem .. "i"})
	add_form(data.forms, "indc_perf_2s", {plup_stem .. "și"})
	
	local pl_perf_stem = mw.ustring.match(data.forms.indc_perf_1p[1], "^(.*)răm$")
	
	add_form(data.forms, "indc_perf_2p", {pl_perf_stem .. "răți"})
	add_form(data.forms, "indc_perf_3p", {pl_perf_stem .. "ră"})
	
	add_form(data.forms, "indc_plup_2s", {plup_stem .. "seși"})
	add_form(data.forms, "indc_plup_3s", {plup_stem .. "se"})
	add_form(data.forms, "indc_plup_1p", {plup_stem .. "serăm"})
	add_form(data.forms, "indc_plup_2p", {plup_stem .. "serăți"})
	add_form(data.forms, "indc_plup_3p", {plup_stem .. "seră"})
	
	add_form(data.forms, "subj_pres_1s", mw.clone(data.forms.indc_pres_1s))
	add_form(data.forms, "subj_pres_2s", mw.clone(data.forms.indc_pres_2s))
	add_form(data.forms, "subj_pres_1p", mw.clone(data.forms.indc_pres_1p))
	add_form(data.forms, "subj_pres_2p", mw.clone(data.forms.indc_pres_2p))
	
	add_form(data.forms, "impr_aff_2p", mw.clone(data.forms.indc_pres_2p))
	add_form(data.forms, "impr_neg_2s", mw.clone(data.forms.inf))
	add_form(data.forms, "impr_neg_2p", mw.clone(data.forms.impr_aff_2p))
end

local conjugations = {}

-- First conjugation
conjugations["a-generic"] = function(stem)
	if mw.title.getCurrentTitle().nsText == "Template" then
		data.lemma = "aduna"
	end
	
	local conj
	
	if (mw.ustring.match(data.lemma, "[" .. vowels .. "]ia$")) then
		conj = "Via"
	elseif (mw.ustring.match(data.lemma, "ia$")) then
		conj = "Cia"
	elseif (mw.ustring.match(data.lemma, "hea$")) then
		conj = "chea"
	else
		conj = "a"
	end
	
	data.conj = 1
	data.infix = "no"
	
	conjugations[conj](stem)
end

conjugations["a"] = function(stem)
	stem = stem or data.lemma:match("^(.*)a$")

	add_form(data.forms, "inf", {stem .. "a"})
	add_form(data.forms, "ger", {stem .. "ând"})
	add_form(data.forms, "pp", {stem .. "at"})
	
	add_form(data.forms, "indc_pres_1s", {stem})
	add_form(data.forms, "indc_pres_2s", {stem .. "i"})
	add_form(data.forms, "indc_pres_3s", {stem .. "ă"})
	add_form(data.forms, "indc_pres_1p", {stem .. "ăm"})
	add_form(data.forms, "indc_pres_2p", {stem .. "ați"})
	add_form(data.forms, "indc_pres_3p", mw.clone(data.forms.indc_pres_3s))
	
	add_form(data.forms, "indc_impf_1s", {stem .. "am"})
	
	add_form(data.forms, "indc_perf_3s", {stem .. "ă"})
	add_form(data.forms, "indc_perf_1p", {stem .. "arăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "asem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "e"})
	add_form(data.forms, "subj_pres_3p", {stem .. "e"})
	
	add_form(data.forms, "impr_aff_2s", mw.clone(data.forms.indc_pres_3s))
end

conjugations["chea"] = function(stem)
	stem = stem or data.lemma:match("^(.*)ea$")

	add_form(data.forms, "inf", {stem .. "ea"})
	add_form(data.forms, "ger", {stem .. "ind"})
	add_form(data.forms, "pp", {stem .. "eat"})
	
	add_form(data.forms, "indc_pres_1s", {stem .. "i"})
	add_form(data.forms, "indc_pres_2s", {stem .. "i"})
	add_form(data.forms, "indc_pres_3s", {stem .. "e"})
	add_form(data.forms, "indc_pres_1p", {stem .. "em"})
	add_form(data.forms, "indc_pres_2p", {stem .. "eați"})
	add_form(data.forms, "indc_pres_3p", {stem .. "e"})
	
	add_form(data.forms, "indc_impf_1s", {stem .. "eam"})
	
	add_form(data.forms, "indc_perf_3s", {stem .. "e"})
	add_form(data.forms, "indc_perf_1p", {stem .. "earăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "easem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "e"})
	add_form(data.forms, "subj_pres_3p", {stem .. "e"})
	
	add_form(data.forms, "impr_aff_2s", {stem .. "e"})
end

conjugations["Cia"] = function(stem)
	stem = stem or data.lemma:match("^(.*)a$")

	add_form(data.forms, "inf", {stem .. "a"})
	add_form(data.forms, "ger", {stem .. "ind"})
	add_form(data.forms, "pp", {stem .. "at"})
	
	add_form(data.forms, "indc_pres_1s", {stem .. "i"})
	add_form(data.forms, "indc_pres_2s", {stem .. "i"})
	add_form(data.forms, "indc_pres_3s", {stem .. "e"})
	add_form(data.forms, "indc_pres_1p", {stem .. "em"})
	add_form(data.forms, "indc_pres_2p", {stem .. "ați"})
	add_form(data.forms, "indc_pres_3p", {stem .. "e"})
	
	add_form(data.forms, "indc_impf_1s", {stem .. "am"})
	
	add_form(data.forms, "indc_perf_3s", {stem .. "e"})
	add_form(data.forms, "indc_perf_1p", {stem .. "arăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "asem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "e"})
	add_form(data.forms, "subj_pres_3p", {stem .. "e"})
	
	add_form(data.forms, "impr_aff_2s", {stem .. "e"})
end
	
conjugations["Via"] = function(stem)
	stem = stem or data.lemma:match("^(.*)a$")

	add_form(data.forms, "inf", {stem .. "a"})
	add_form(data.forms, "ger", {stem .. "nd"})
	add_form(data.forms, "pp", {stem .. "at"})
	
	add_form(data.forms, "indc_pres_1s", {stem})
	add_form(data.forms, "indc_pres_2s", {stem})
	add_form(data.forms, "indc_pres_3s", {stem .. "e"})
	add_form(data.forms, "indc_pres_1p", {stem .. "em"})
	add_form(data.forms, "indc_pres_2p", {stem .. "ați"})
	add_form(data.forms, "indc_pres_3p", {stem .. "e"})
	
	add_form(data.forms, "indc_impf_1s", {stem .. "am"})
	
	add_form(data.forms, "indc_perf_3s", {stem .. "e"})
	add_form(data.forms, "indc_perf_1p", {stem .. "arăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "asem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "e"})
	add_form(data.forms, "subj_pres_3p", {stem .. "e"})
	
	add_form(data.forms, "impr_aff_2s", {stem .. "e"})
end

conjugations["a-ez-generic"] = function(stem)
	if mw.title.getCurrentTitle().nsText == "Template" then
		data.lemma = "lucra"
	end
	
	local conj
	
	if (mw.ustring.match(data.lemma, "[" .. vowels .. "]ia$")) then
		conj = "Via-ez"
	elseif (mw.ustring.match(data.lemma, "ia$")) then
		conj = "Cia-ez"
	elseif (mw.ustring.match(data.lemma, "hea$")) then
		conj = "chea-ez"
	elseif (mw.ustring.match(data.lemma, "[cg]a$")) then
		conj = "ca-ez"
	else
		conj = "a-ez"
	end
	
	data.conj = 1
	data.infix = "-ez-"
	
	conjugations[conj](stem)
end

conjugations["a-ez"] = function(stem)
	stem = stem or data.lemma:match("^(.*)a$")

	add_form(data.forms, "inf", {stem .. "a"})
	add_form(data.forms, "ger", {stem .. "ând"})
	add_form(data.forms, "pp", {stem .. "at"})
	
	add_form(data.forms, "indc_pres_1s", {stem .. "ez"})
	add_form(data.forms, "indc_pres_2s", {stem .. "ezi"})
	add_form(data.forms, "indc_pres_3s", {stem .. "ează"})
	add_form(data.forms, "indc_pres_1p", {stem .. "ăm"})
	add_form(data.forms, "indc_pres_2p", {stem .. "ați"})
	add_form(data.forms, "indc_pres_3p", {stem .. "ează"})
	
	add_form(data.forms, "indc_impf_1s", {stem .. "am"})
	
	add_form(data.forms, "indc_perf_3s", {stem .. "ă"})
	add_form(data.forms, "indc_perf_1p", {stem .. "arăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "asem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "eze"})
	add_form(data.forms, "subj_pres_3p", {stem .. "eze"})
	
	add_form(data.forms, "impr_aff_2s", {stem .. "ează"})
end

conjugations["ca-ez"] = function(stem)
	stem = stem or data.lemma:match("^(.*)a$")

	add_form(data.forms, "inf", {stem .. "a"})
	add_form(data.forms, "ger", {stem .. "ând"})
	add_form(data.forms, "pp", {stem .. "at"})
	
	add_form(data.forms, "indc_pres_1s", {stem .. "hez"})
	add_form(data.forms, "indc_pres_2s", {stem .. "hezi"})
	add_form(data.forms, "indc_pres_3s", {stem .. "hează"})
	add_form(data.forms, "indc_pres_1p", {stem .. "ăm"})
	add_form(data.forms, "indc_pres_2p", {stem .. "ați"})
	add_form(data.forms, "indc_pres_3p", {stem .. "hează"})
	
	add_form(data.forms, "indc_impf_1s", {stem .. "am"})
	
	add_form(data.forms, "indc_perf_3s", {stem .. "ă"})
	add_form(data.forms, "indc_perf_1p", {stem .. "arăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "asem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "heze"})
	add_form(data.forms, "subj_pres_3p", {stem .. "heze"})
	
	add_form(data.forms, "impr_aff_2s", {stem .. "hează"})
end

conjugations["chea-ez"] = function(stem)
	stem = stem or data.lemma:match("^(.*)ea$")

	add_form(data.forms, "inf", {stem .. "ea"})
	add_form(data.forms, "ger", {stem .. "ind"})
	add_form(data.forms, "pp", {stem .. "eat"})
	
	add_form(data.forms, "indc_pres_1s", {stem .. "ez"})
	add_form(data.forms, "indc_pres_2s", {stem .. "ezi"})
	add_form(data.forms, "indc_pres_3s", {stem .. "ează"})
	add_form(data.forms, "indc_pres_1p", {stem .. "em"})
	add_form(data.forms, "indc_pres_2p", {stem .. "eați"})
	add_form(data.forms, "indc_pres_3p", {stem .. "ează"})
	
	add_form(data.forms, "indc_impf_1s", {stem .. "eam"})
	
	add_form(data.forms, "indc_perf_3s", {stem .. "e"})
	add_form(data.forms, "indc_perf_1p", {stem .. "earăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "easem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "eze"})
	add_form(data.forms, "subj_pres_3p", {stem .. "eze"})
	
	add_form(data.forms, "impr_aff_2s", {stem .. "ează"})
end

conjugations["Cia-ez"] = function(stem)
	stem = stem or data.lemma:match("^(.*)a$")

	add_form(data.forms, "inf", {stem .. "a"})
	add_form(data.forms, "ger", {stem .. "ind"})
	add_form(data.forms, "pp", {stem .. "at"})
	
	add_form(data.forms, "indc_pres_1s", {stem .. "ez"})
	add_form(data.forms, "indc_pres_2s", {stem .. "ezi"})
	add_form(data.forms, "indc_pres_3s", {stem .. "ază"})
	add_form(data.forms, "indc_pres_1p", {stem .. "em"})
	add_form(data.forms, "indc_pres_2p", {stem .. "ați"})
	add_form(data.forms, "indc_pres_3p", {stem .. "ază"})
	
	add_form(data.forms, "indc_impf_1s", {stem .. "am"})
	
	add_form(data.forms, "indc_perf_3s", {stem .. "e"})
	add_form(data.forms, "indc_perf_1p", {stem .. "arăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "asem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "eze"})
	add_form(data.forms, "subj_pres_3p", {stem .. "eze"})
	
	add_form(data.forms, "impr_aff_2s", {stem .. "ază"})
end
	
conjugations["Via-ez"] = function(stem)
	stem = stem or data.lemma:match("^(.*)a$")

	add_form(data.forms, "inf", {stem .. "a"})
	add_form(data.forms, "ger", {stem .. "nd"})
	add_form(data.forms, "pp", {stem .. "at"})
	
	add_form(data.forms, "indc_pres_1s", {stem .. "ez"})
	add_form(data.forms, "indc_pres_2s", {stem .. "ezi"})
	add_form(data.forms, "indc_pres_3s", {stem .. "ază"})
	add_form(data.forms, "indc_pres_1p", {stem .. "em"})
	add_form(data.forms, "indc_pres_2p", {stem .. "ați"})
	add_form(data.forms, "indc_pres_3p", {stem .. "ază"})
	
	add_form(data.forms, "indc_impf_1s", {stem .. "am"})

	add_form(data.forms, "indc_perf_3s", {stem .. "e"})
	add_form(data.forms, "indc_perf_1p", {stem .. "arăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "asem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "eze"})
	add_form(data.forms, "subj_pres_3p", {stem .. "eze"})
	
	add_form(data.forms, "impr_aff_2s", {stem .. "ază"})
end

-- Second conjugation
conjugations["ea-ut-generic"] = function(stem)
	if mw.title.getCurrentTitle().nsText == "Template" then
		data.lemma = "" -- todo
	end
	
	data.conj = 2
	
	stem = stem or data.lemma:match("^(.*)ea$")

	add_form(data.forms, "inf", {stem .. "ea"})
	add_form(data.forms, "ger", {stem .. "ând"})
	add_form(data.forms, "pp", {stem .. "ut"})
	
	add_form(data.forms, "indc_pres_1s", {stem})
	add_form(data.forms, "indc_pres_2s", {stem .. "i"})
	add_form(data.forms, "indc_pres_3s", {stem .. "e"})
	add_form(data.forms, "indc_pres_1p", {stem .. "em"})
	add_form(data.forms, "indc_pres_2p", {stem .. "eți"})
	add_form(data.forms, "indc_pres_3p", mw.clone(data.forms.indc_pres_1s))
	
	add_form(data.forms, "indc_impf_1s", {stem .. "eam"})

	add_form(data.forms, "indc_perf_3s", {stem .. "u"})
	add_form(data.forms, "indc_perf_1p", {stem .. "urăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "usem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "ă"})
	add_form(data.forms, "subj_pres_3p", {stem .. "ă"})
	
	add_form(data.forms, "impr_aff_2s", mw.clone(data.forms.indc_pres_3s))
end

-- Third conjugation
conjugations["e-s-generic"] = function(stem)
	if mw.title.getCurrentTitle().nsText == "Template" then
		data.lemma = "stinge"
	end
	
	data.conj = 3
	
	-- ste is the stem without the last letter... yeah
	local ste, last = data.lemma:match("^(.*)(.)e$")

	add_form(data.forms, "inf", {ste .. last .. "e"})
	add_form(data.forms, "ger", {ste .. last .. "ând"})
	add_form(data.forms, "pp", {ste .. "s"})
	
	add_form(data.forms, "indc_pres_1s", {ste .. last})
	add_form(data.forms, "indc_pres_2s", {ste .. last .. "i"})
	add_form(data.forms, "indc_pres_3s", {ste .. last .. "e"})
	add_form(data.forms, "indc_pres_1p", {ste .. last .. "em"})
	add_form(data.forms, "indc_pres_2p", {ste .. last .. "eți"})
	add_form(data.forms, "indc_pres_3p", mw.clone(data.forms.indc_pres_1s))
	
	add_form(data.forms, "indc_impf_1s", {ste .. last .. "eam"})

	add_form(data.forms, "indc_perf_3s", {ste .. "se"})
	add_form(data.forms, "indc_perf_1p", {ste .. "serăm"})
	
	add_form(data.forms, "indc_plup_1s", {ste .. "sesem"})

	add_form(data.forms, "subj_pres_3s", {ste .. last .. "ă"})
	add_form(data.forms, "subj_pres_3p", {ste .. last .. "ă"})
	
	add_form(data.forms, "impr_aff_2s", mw.clone(data.forms.indc_pres_3s))
end

conjugations["e-ut-generic"] = function(stem)
	if mw.title.getCurrentTitle().nsText == "Template" then
		data.lemma = "" -- todo
	end
	
	data.conj = 3
	
	stem = stem or data.lemma:match("^(.*)e$")

	add_form(data.forms, "inf", {stem .. "e"})
	add_form(data.forms, "ger", {stem .. "ând"})
	add_form(data.forms, "pp", {stem .. "ut"})
	
	add_form(data.forms, "indc_pres_1s", {stem})
	add_form(data.forms, "indc_pres_2s", {stem .. "i"})
	add_form(data.forms, "indc_pres_3s", {stem .. "e"})
	add_form(data.forms, "indc_pres_1p", {stem .. "em"})
	add_form(data.forms, "indc_pres_2p", {stem .. "eți"})
	add_form(data.forms, "indc_pres_3p", mw.clone(data.forms.indc_pres_1s))
	
	add_form(data.forms, "indc_impf_1s", {stem .. "eam"})

	add_form(data.forms, "indc_perf_3s", {stem .. "u"})
	add_form(data.forms, "indc_perf_1p", {stem .. "urăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "usem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "ă"})
	add_form(data.forms, "subj_pres_3p", {stem .. "ă"})
	
	add_form(data.forms, "impr_aff_2s", mw.clone(data.forms.indc_pres_3s))
end

-- Fourth conjugation
conjugations["i-generic"] = function(stem)
	if mw.title.getCurrentTitle().nsText == "Template" then
		data.lemma = "" --todo
	end
	
	local conj
	
	if (mw.ustring.match(data.lemma, "hi$")) then
		conj = "chi"
	elseif (mw.ustring.match(data.lemma, "[" .. vowels .. "]i$")) then
		conj = "Vi"
	elseif (mw.ustring.match(data.lemma, "i$")) then
		conj = "Ci"
	end
	
	data.conj = 4
	data.infix = "no"
	
	conjugations[conj](stem)
end

conjugations["Ci"] = function(stem)
	stem = stem or data.lemma:match("^(.*)i$")

	add_form(data.forms, "inf", {stem .. "i"})
	add_form(data.forms, "ger", {stem .. "ind"})
	add_form(data.forms, "pp", {stem .. "it"})
	
	add_form(data.forms, "indc_pres_1s", {stem})
	add_form(data.forms, "indc_pres_2s", {stem .. "i"})
	add_form(data.forms, "indc_pres_3s", {stem .. "e"})
	add_form(data.forms, "indc_pres_1p", {stem .. "im"})
	add_form(data.forms, "indc_pres_2p", {stem .. "iți"})
	add_form(data.forms, "indc_pres_3p", {stem})
	
	add_form(data.forms, "indc_impf_1s", {stem .. "eam"})
	
	add_form(data.forms, "indc_perf_3s", {stem .. "i"})
	add_form(data.forms, "indc_perf_1p", {stem .. "irăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "isem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "ă"})
	add_form(data.forms, "subj_pres_3p", {stem .. "ă"})
	
	add_form(data.forms, "impr_aff_2s", {stem .. "e"})
end

conjugations["Vi"] = function(stem)
	stem = stem or data.lemma
	
	-- todo: remove ugly hack
	if stem .. "i" == data.lemma then
		stem = data.lemma
	end

	add_form(data.forms, "inf", {stem})
	add_form(data.forms, "ger", {stem .. "nd"})
	add_form(data.forms, "pp", {stem .. "t"})
	
	add_form(data.forms, "indc_pres_1s", {stem})
	add_form(data.forms, "indc_pres_2s", {stem})
	add_form(data.forms, "indc_pres_3s", {stem .. "e"})
	add_form(data.forms, "indc_pres_1p", {stem .. "m"})
	add_form(data.forms, "indc_pres_2p", {stem .. "ți"})
	add_form(data.forms, "indc_pres_3p", mw.clone(data.forms.indc_pres_3s))
	
	add_form(data.forms, "indc_impf_1s", {stem .. "am"})
	
	add_form(data.forms, "indc_perf_3s", {stem})
	add_form(data.forms, "indc_perf_1p", {stem .. "răm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "sem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "e"})
	add_form(data.forms, "subj_pres_3p", {stem .. "e"})
	
	add_form(data.forms, "impr_aff_2s", mw.clone(data.forms.indc_pres_3s))
end

conjugations["chi"] = function(stem)
	stem = stem or data.lemma:match("^(.*)i$")

	add_form(data.forms, "inf", {stem .. "i"})
	add_form(data.forms, "ger", {stem .. "ind"})
	add_form(data.forms, "pp", {stem .. "it"})
	
	add_form(data.forms, "indc_pres_1s", {stem .. "i"})
	add_form(data.forms, "indc_pres_2s", {stem .. "i"})
	add_form(data.forms, "indc_pres_3s", {stem .. "e"})
	add_form(data.forms, "indc_pres_1p", {stem .. "im"})
	add_form(data.forms, "indc_pres_2p", {stem .. "iți"})
	add_form(data.forms, "indc_pres_3p", {stem .. "i"})
	
	add_form(data.forms, "indc_impf_1s", {stem .. "eam"})
	
	add_form(data.forms, "indc_perf_3s", {stem .. "i"})
	add_form(data.forms, "indc_perf_1p", {stem .. "irăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "isem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "e"})
	add_form(data.forms, "subj_pres_3p", {stem .. "e"})
	
	add_form(data.forms, "impr_aff_2s", {stem .. "e"})
end

conjugations["i-esc-generic"] = function(stem)
	if mw.title.getCurrentTitle().nsText == "Template" then
		data.lemma = "munci"
	end
	
	local conj
	
	if (mw.ustring.match(data.lemma, "[" .. vowels .. "]i$")) then
		conj = "Vi-esc"
	elseif (mw.ustring.match(data.lemma, "i$")) then
		conj = "Ci-esc"
	end
	
	data.conj = 4
	data.infix = "-esc-"
	
	conjugations[conj](stem)
end

conjugations["Ci-esc"] = function(stem)
	stem = stem or data.lemma:match("^(.*)i$")

	add_form(data.forms, "inf", {stem .. "i"})
	add_form(data.forms, "ger", {stem .. "ind"})
	add_form(data.forms, "pp", {stem .. "it"})
	
	add_form(data.forms, "indc_pres_1s", {stem .. "esc"})
	add_form(data.forms, "indc_pres_2s", {stem .. "ești"})
	add_form(data.forms, "indc_pres_3s", {stem .. "ește"})
	add_form(data.forms, "indc_pres_1p", {stem .. "im"})
	add_form(data.forms, "indc_pres_2p", {stem .. "iți"})
	add_form(data.forms, "indc_pres_3p", {stem .. "esc"})
	
	add_form(data.forms, "indc_impf_1s", {stem .. "eam"})
	
	add_form(data.forms, "indc_perf_3s", {stem .. "i"})
	add_form(data.forms, "indc_perf_1p", {stem .. "irăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "isem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "ească"})
	add_form(data.forms, "subj_pres_3p", {stem .. "ească"})
	
	add_form(data.forms, "impr_aff_2s", {stem .. "ește"})
end

conjugations["Vi-esc"] = function(stem)
	stem = stem or data.lemma
	
	-- todo: remove
	if not mw.ustring.find(stem, "i$") then
		stem = stem .. "i"
	end

	add_form(data.forms, "inf", {stem})
	add_form(data.forms, "ger", {stem .. "nd"})
	add_form(data.forms, "pp", {stem .. "t"})
	
	add_form(data.forms, "indc_pres_1s", {stem .. "esc"})
	add_form(data.forms, "indc_pres_2s", {stem .. "ești"})
	add_form(data.forms, "indc_pres_3s", {stem .. "ește"})
	add_form(data.forms, "indc_pres_1p", {stem .. "m"})
	add_form(data.forms, "indc_pres_2p", {stem .. "ți"})
	add_form(data.forms, "indc_pres_3p", {stem .. "esc"})
	
	add_form(data.forms, "indc_impf_1s", {stem .. "am"})
	
	add_form(data.forms, "indc_perf_3s", {stem})
	add_form(data.forms, "indc_perf_1p", {stem .. "răm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "sem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "ască"})
	add_form(data.forms, "subj_pres_3p", {stem .. "ască"})
	
	add_form(data.forms, "impr_aff_2s", {stem .. "ește"})
end

conjugations["î-generic"] = function(stem)
	if mw.title.getCurrentTitle().nsText == "Template" then
		data.lemma = "" --todo
	end
	
	data.conj = 4
	data.infix = "no"
	
	stem = stem or data.lemma:match("^(.*)î$")

	add_form(data.forms, "inf", {stem .. "î"})
	add_form(data.forms, "ger", {stem .. "ând"})
	add_form(data.forms, "pp", {stem .. "ât"})
	
	add_form(data.forms, "indc_pres_1s", {stem})
	add_form(data.forms, "indc_pres_2s", {stem .. "i"})
	add_form(data.forms, "indc_pres_3s", {stem .. "ă"})
	add_form(data.forms, "indc_pres_1p", {stem .. "âm"})
	add_form(data.forms, "indc_pres_2p", {stem .. "âți"})
	add_form(data.forms, "indc_pres_3p", mw.clone(data.forms.indc_pres_3s))
	
	add_form(data.forms, "indc_impf_1s", {stem .. "am"})
	
	add_form(data.forms, "indc_perf_3s", {stem .. "î"})
	add_form(data.forms, "indc_perf_1p", {stem .. "ârăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "âsem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "e"})
	add_form(data.forms, "subj_pres_3p", {stem .. "e"})
	
	add_form(data.forms, "impr_aff_2s", mw.clone(data.forms.indc_pres_3s))
end

conjugations["î-ăsc-generic"] = function(stem)
	if mw.title.getCurrentTitle().nsText == "Template" then
		data.lemma = "hotărî" --todo
	end
	
	data.conj = 4
	data.infix = "-ăsc-"
	
	stem = stem or data.lemma:match("^(.*)î$")

	add_form(data.forms, "inf", {stem .. "î"})
	add_form(data.forms, "ger", {stem .. "ând"})
	add_form(data.forms, "pp", {stem .. "ât"})
	
	add_form(data.forms, "indc_pres_1s", {stem .. "ăsc"})
	add_form(data.forms, "indc_pres_2s", {stem .. "ăști"})
	add_form(data.forms, "indc_pres_3s", {stem .. "ăște"})
	add_form(data.forms, "indc_pres_1p", {stem .. "âm"})
	add_form(data.forms, "indc_pres_2p", {stem .. "âți"})
	add_form(data.forms, "indc_pres_3p", {stem .. "ăsc"})
	
	add_form(data.forms, "indc_impf_1s", {stem .. "am"})
	
	add_form(data.forms, "indc_perf_3s", {stem .. "î"})
	add_form(data.forms, "indc_perf_1p", {stem .. "ârăm"})
	
	add_form(data.forms, "indc_plup_1s", {stem .. "âsem"})

	add_form(data.forms, "subj_pres_3s", {stem .. "ască"})
	add_form(data.forms, "subj_pres_3p", {stem .. "ască"})
	
	add_form(data.forms, "impr_aff_2s", {stem .. "ăște"})
end

local add_given_forms = function(args)
	local add_form = function(form_name, arg_name, appendix)
		appendix = appendix or ""
		
		if args[arg_name] then
			data.forms[form_name] = mw.text.split(args[arg_name], " *, *")
			
			for i, val in ipairs(data.forms[form_name]) do
				data.forms[form_name][i] = val .. appendix
			end
		end
	end
	
	add_form("ger", "ger")
	add_form("pp", "past")
	
	add_form("indc_pres_1s", "1s")
	add_form("indc_pres_2s", "2s")
	add_form("indc_pres_3s", "3s")
	add_form("indc_pres_1p", "1p")
	add_form("indc_pres_2p", "2p")
	add_form("indc_pres_3p", "3p")
	
	add_form("indc_impf_1s", "imp", "am")
	add_form("indc_impf_3s", "3imp")
	
	add_form("indc_perf_3s", "3perf")
	add_form("indc_perf_1p", args["plperf"] and "plperf" or "perf", "răm")
	
	add_form("indc_plup_1s", "perf", "sem")
	
	add_form("subj_pres_3s", "3sub")
	add_form("subj_pres_3p", "3sub")
	
	add_form("impr_aff_2s", "2imp")
end

local function get_conj_type()
	local conj_type
	
	if data.conj == 1 then
		if data.forms.indc_pres_1s[1] == join_ending_2(get_stem_a(), "ez")[1] then
			conj_type = "a-ez"
		else
			conj_type = "a"
		end
	elseif data.conj == 4 then
		if mw.ustring.find(data.lemma, "i$") then
			if data.forms.indc_pres_1s[1] == get_stem_i() .. "esc" or data.forms.indc_pres_1s[1] == mw.ustring.gsub(get_stem_i(), "ii$", "iesc") then
				conj_type = "i-esc"
			else
				conj_type = "i"
			end
		else
			if data.forms.indc_pres_1s[1] == get_stem_ih() .. "ăsc" then
				conj_type = "î-ăsc"
			else
				conj_type = "î"
			end
		end
	elseif data.conj == 3 then
		if mw.ustring.find(data.forms.pp[1], "ut$") then
			conj_type = "e-ut"
		elseif mw.ustring.find(data.forms.pp[1], "pt$") then
			conj_type = "e-pt"
		elseif mw.ustring.find(data.forms.pp[1], "t$") then
			conj_type = "e-t"
		else
			conj_type = "e-s"
		end
	elseif data.conj == 2 then
		if mw.ustring.find(data.forms.pp[1], "ut$") then
			conj_type = "ea-ut"
		elseif mw.ustring.find(data.forms.pp[1], "pt$") then
			conj_type = "ea-pt"
		elseif mw.ustring.find(data.forms.pp[1], "t$") then
			conj_type = "ea-t"
		else
			conj_type = "ea-s"
		end
	else
		error("No conjugation type given")
	end
	
	return conj_type
end

local function get_stem_1s()
	local res
	
	if data.type == "a" then
		if mw.ustring.find(data.lemma, "[" .. vowels .. "]ia$") then
			res = data.forms.indc_pres_1s[1]
		elseif mw.ustring.find(data.lemma, "ia$") then
			res = mw.ustring.match(data.forms.indc_pres_1s[1], "^(.*)i$")
		elseif mw.ustring.find(data.lemma, "[cg]hea$") then
			res = mw.ustring.match(data.forms.indc_pres_1s[1], "^(.*)i$")
		elseif mw.ustring.find(data.lemma, "[^" .. vowels .. "][lr]a$") then
			res = mw.ustring.match(data.forms.indc_pres_1s[1], "^(.*)u$")
		else
			res = data.forms.indc_pres_1s[1]
		end
	else
		res = data.forms.indc_pres_1s[1]
	end
	
	return res
end

local function replace_stem_cons(res, ending, conj_23)
	local stem1, vow1, cons1 = split(data.forms.indc_pres_1s[1])
	local stem2, vow2, cons2 = split(res)
	
	if cons1 ~= cons2 then
		local consf = find_cons(cons1, ending, conj_23)
		
		if consf == cons2 then
			res = stem2 .. vow2 .. cons1
		end
	end
	
	return res
end

local function get_stem_2s(conj_23)
	local res
	
	if data.type == "a" then
		if mw.ustring.find(data.lemma, "[" .. vowels .. "]ia$") then
			res = data.forms.indc_pres_2s[1]
		else
			res = mw.ustring.match(data.forms.indc_pres_2s[1], "^(.*)i$")
		end
	elseif data.type == "i" then
		if mw.ustring.find(data.lemma, "[" .. vowels .. "]i$") then
			res = data.forms.indc_pres_2s[1]
		else
			res = mw.ustring.match(data.forms.indc_pres_2s[1], "^(.*)i$")
		end
	else
		res = mw.ustring.match(data.forms.indc_pres_2s[1], "^(.*)i$")
	end
	
	if not mw.ustring.find(data.forms.indc_pres_1s[1], "[" .. vowels .. "]$") then
		res = replace_stem_cons(res, "i_", conj_23)
	end
	
	return res
end

local function get_stem_3s()
	local res = mw.ustring.match(data.forms.indc_pres_3s[1], "^(.*)[ăe]$")
	
	if not mw.ustring.find(data.forms.indc_pres_1s[1], "[" .. vowels .. "]$") 
	and mw.ustring.find(data.forms.indc_pres_3s[1], "e$") then
		res = replace_stem_cons(res, "e")
	end
	
	return res
end

local function get_stem_3sub()
	local res = mw.ustring.match(data.forms.subj_pres_3s[1], "^(.*)[ăe]$")
	
	if not mw.ustring.find(data.forms.indc_pres_1s[1], "[" .. vowels .. "]$") 
	and mw.ustring.find(data.forms.subj_pres_3s[1], "e$") then
		res = replace_stem_cons(res, "e")
	end
	
	return res
end

local function compare_conj()
	local stem_appearances, stems, inf_stem = {}, {}
	local forms_new = {}
	
	local conj_type = get_conj_type()
	
	if data.type and data.type ~= conj_type then
		require("Module:debug").track("ro-verb/different conj type")
	end
	
	data.type = conj_type
	
	if data.conj == 3 then
		inf_stem = {mw.ustring.match(data.forms.ger[1], "^(.*)ând$")}
		local stemi, vowi, consi = split(inf_stem[1])
		local stem1, vow1, cons1 = split(data.forms.indc_pres_1s[1])
		
		if consi ~= cons1 and find_cons(cons1, "â", true, vowi) == consi then
			inf_stem[1] = stemi .. vowi .. cons1
		end
	else
		inf_stem = {get_inf_stem()}
	end
	
	local ok, errtext = true
	
	if conj_type == "a-ez" or conj_type == "i-esc" or conj_type == "î-ăsc" then
		stems = nil
	else
		local conj_23
		
		if data.conj == 2 or data.conj == 3 then
			conj_23 = true
		end
		
		ok, errtext = pcall(function()
			stem_appearances[get_stem_1s()] = true
			stem_appearances[get_stem_2s(conj_23)] = true
			stem_appearances[get_stem_3s()] = true
			stem_appearances[get_stem_3sub()] = true
		end)
	
		if ok then
			for key, _ in pairs(stem_appearances) do
				table.insert(stems, key)
			end
		
			stems = table.concat(stems, "/")
		
			ok, errtext = pcall(get_stems, stems)
		end
	end
	
	local equal = true
	local equal_except_impr = false
	local wrong_form = ""
	
	if ok then
		stems = errtext
		ok, errtext = pcall(conjugations_new[data.type], forms_new, inf_stem, stems)
	end
	
	if not ok then
		equal = false
		wrong_form = "error: " .. errtext
	else
		equal_except_impr = true
		add_repeated_forms_new(forms_new)
		
		for _, val in ipairs(form_names) do
			if #forms_new[val] >= 2 or #data.forms[val] >= 2 then
				if not tequals(forms_new[val], data.forms[val]) then
					equal = false
					wrong_form = wrong_form .. val .. ":" 
					.. table.concat(forms_new[val], ",") .. "~="	
					.. table.concat(data.forms[val], ",") .. ";"
					
					if val ~= "impr_aff_2s" then
						equal_except_impr = false
					end
				end
			elseif forms_new[val][1] ~= data.forms[val][1] then
				equal = false
				wrong_form = wrong_form .. val .. ":" 
				.. (forms_new[val][1] or "nil") .. "~="
				.. (data.forms[val][1] or "nil") .. ";"
				
				if val ~= "impr_aff_2s" then
					equal_except_impr = false
				end
			end
		end
	end
	
	if equal then
		require("Module:debug").track("ro-verb/matches_new/yes")
		
		if dbg then
			table.insert(data.info, "same")
		end
	else
		require("Module:debug").track("ro-verb/matches_new/no")
		
		if dbg then
			table.insert(data.info, "different: " .. wrong_form)
		end
	
		if equal_except_impr then
			require("Module:debug").track("ro-verb/matches_new/no/impr")
		else
			require("Module:debug").track("ro-verb/matches_new/no/others")
		end
	end
end

local function make_table()
	data.info = table.concat(data.info, ", ")
	if data.info == "" then data.info = nil end
	
	local function show_form(form)
		if not form then
			return "&mdash;"
		elseif type(form) ~= "table" then
			error("a non-table value was given in the list of inflected forms.")
		elseif #form == 0 then
			return "&mdash;"
		end
		
		local ret = {}
		
		for key, subform in ipairs(form) do
			table.insert(ret, m_links.full_link({lang = lang, term = subform}))
		end
		
		return table.concat(ret, "<br/>")
	end
	
	local function repl(param)
		if param == "lemma" then
			return m_links.full_link({lang = lang, alt = data.lemma}, "term")
		elseif param == "info" then
			return #data.info > 0 and " (" .. data.info .. ")" or ""
		elseif param:match("^pronoun") then
			local person, number = param:match("^pronoun_(.)(.)")
			return data.pronouns[data.sc][person][number]
		else
			return show_form(data.forms[param])
		end
	end
	
	local result = [=[
<div class="NavFrame">
<div class="NavHead">&nbsp; &nbsp; conjugation of {{{lemma}}} <small>{{{info}}}</small></div>
<div class="NavContent">

{| class="roa-inflection-table" data-toggle-category="inflection"
|-
! colspan="3" class="roa-nonfinite-header" | <span title="infinitiv">infinitive</span>
| colspan="5" | {{{inf}}}

|-
! colspan="3"  class="roa-nonfinite-header" | <span title="gerunziu">gerund</span>
| colspan="5" | {{{ger}}}

|-
! colspan="3" class="roa-nonfinite-header" | <span title="participiu">past participle</span>
| colspan="5" | {{{pp}}}

|-
! colspan="2" class="roa-person-number-header" | number
! colspan="3" class="roa-person-number-header" | singular
! colspan="3" class="roa-person-number-header" | plural

|-
! colspan="2" class="roa-person-number-header" | person
! class="roa-person-number-header" | 1st person
! class="roa-person-number-header" | 2nd person
! class="roa-person-number-header" | 3rd person
! class="roa-person-number-header" | 1st person
! class="roa-person-number-header" | 2nd person
! class="roa-person-number-header" | 3rd person

|-
! rowspan="5" class="roa-indicative-left-rail" | <span title="indicativ">indicative</span>
! class="roa-indicative-left-rail" | 
! class="roa-indicative-left-rail" | {{{pronoun_1s}}}
! class="roa-indicative-left-rail" | {{{pronoun_2s}}}
! class="roa-indicative-left-rail" | {{{pronoun_3s}}}
! class="roa-indicative-left-rail" | {{{pronoun_1p}}}
! class="roa-indicative-left-rail" | {{{pronoun_2p}}}
! class="roa-indicative-left-rail" | {{{pronoun_3p}}}

|-
! class="roa-indicative-left-rail" | <span title="prezent">present</span>
| {{{indc_pres_1s}}}
| {{{indc_pres_2s}}}
| {{{indc_pres_3s}}}
| {{{indc_pres_1p}}}
| {{{indc_pres_2p}}}
| {{{indc_pres_3p}}}

|-
! class="roa-indicative-left-rail" | <span title="imperfect">imperfect</span>
| {{{indc_impf_1s}}}
| {{{indc_impf_2s}}}
| {{{indc_impf_3s}}}
| {{{indc_impf_1p}}}
| {{{indc_impf_2p}}}
| {{{indc_impf_3p}}}

|-
! class="roa-indicative-left-rail" | <span title="perfect simplu">simple perfect</span>
| {{{indc_perf_1s}}}
| {{{indc_perf_2s}}}
| {{{indc_perf_3s}}}
| {{{indc_perf_1p}}}
| {{{indc_perf_2p}}}
| {{{indc_perf_3p}}}

|-
! class="roa-indicative-left-rail" | <span title="mai mult ca perfect">pluperfect</span>
| {{{indc_plup_1s}}}
| {{{indc_plup_2s}}}
| {{{indc_plup_3s}}}
| {{{indc_plup_1p}}}
| {{{indc_plup_2p}}}
| {{{indc_plup_3p}}}

|-
! rowspan="2" class="roa-subjunctive-left-rail" | <span title="conjunctiv">subjunctive</span>
! class="roa-subjunctive-left-rail" | 
! class="roa-subjunctive-left-rail" | {{{pronoun_1s}}}
! class="roa-subjunctive-left-rail" | {{{pronoun_2s}}}
! class="roa-subjunctive-left-rail" | {{{pronoun_3s}}}
! class="roa-subjunctive-left-rail" | {{{pronoun_1p}}}
! class="roa-subjunctive-left-rail" | {{{pronoun_2p}}}
! class="roa-subjunctive-left-rail" | {{{pronoun_3p}}}

|-
! class="roa-subjunctive-left-rail" | <span title="prezent">present</span>
| {{{subj_pres_1s}}}
| {{{subj_pres_2s}}}
| {{{subj_pres_3s}}}
| {{{subj_pres_1p}}}
| {{{subj_pres_2p}}}
| {{{subj_pres_3p}}}

|-
! rowspan="3" class="roa-imperative-left-rail" | <span title="imperativ">imperative</span>
! class="roa-imperative-left-rail" | 
! class="roa-imperative-left-rail" | —
! class="roa-imperative-left-rail" | {{{pronoun_2s}}}
! class="roa-imperative-left-rail" | —
! class="roa-imperative-left-rail" | —
! class="roa-imperative-left-rail" | {{{pronoun_2p}}}
! class="roa-imperative-left-rail" | —

|-
! class="roa-imperative-left-rail" | affirmative
| 
| {{{impr_aff_2s}}}
| 
| 
| {{{impr_aff_2p}}}
| 

|-
! class="roa-imperative-left-rail" | negative
| 
| {{{impr_neg_2s}}}
| 
| 
| {{{impr_neg_2p}}}
| 
|}</div></div>]=]

	return require("Module:TemplateStyles")("Module:roa-verb/style.css") .. (mw.ustring.gsub(result, "{{{([a-z0-9_]+)}}}", repl))
end

local function add_particle(form_table, particle)
	if form_table then
		for i, form in ipairs(form_table) do
			form_table[i] = particle .. " [[" .. form .. "]]"
		end
	end
end

local function add_particles()
	add_particle(data.forms.inf, data.sc == "Cyrl" and "а" or "a")
	
	local sa = data.sc == "Cyrl" and "сэ" or "să"
	
	for i = 1, 3 do
		add_particle(data.forms["subj_pres_" .. i .. "s"], sa)
		add_particle(data.forms["subj_pres_" .. i .. "p"], sa)
	end
	
	local nu = data.sc == "Cyrl" and "ну" or "nu"
	
	add_particle(data.forms.impr_neg_2s, nu)
	add_particle(data.forms.impr_neg_2p, nu)
end

local function is_new_conj(args)
	if args.new then
		return true
	elseif not args[1] then
		return true
	elseif args[2] then
		if data.type == "e-s" and mw.ustring.len(args[2]) == 1 then
			return false
		else
			return true
		end
	elseif mw.ustring.find(args[1], "[/,]") then
		return true
	elseif not mw.ustring.find(data.lemma, "^" .. args[1]) then
		return true
	else
		return false
	end
end

local function get_type_info()
	if data.type == "e" then
		return "past participle in -s"
	elseif data.type == "ea" then
		return "past participle in -ut"
	elseif mw.ustring.match(data.type, "^[aiî]") then
		local infix = mw.ustring.match(data.type, "^.*\-(.*)$")
		return (infix and "-" .. infix .. "-" or "no") .. " infix"
	else
		local pp = mw.ustring.match(data.type, "^.*\-(.*)$")
		
		if pp then
			return "past participle in -" .. pp
		else
			return "past participle not used"
		end
	end
end

function export.show(frame)
	local args = frame:getParent().args
		
	local params = {
		--["sc"] = {},
		[1] = {},		-- stressed stem(s)
		[2] = {},		-- unstressed stem
		["lemma"] = {},
		["conjtype"] = {}, -- todo: remove this
		["type"] = {},
		["new"] = {type = "boolean"},
		["only"] = {},
	}
	
	local override_params = {
		"ger",
		"past",
		"1s",
		"2s",
		"3s",
		"1p",
		"2p",
		"3p",
		"imp",
		"3imp",
		"perf",
		"3perf",
		"plperf",
		"3sub",
		"2imp",
	}
	
	local no_overrides = true
	
	for _, param in ipairs(override_params) do
		params[param] = {}
		
		if args[param] then
			no_overrides = false
		end
	end
	
	if not no_overrides then
		require("Module:debug").track("ro-verb/overrides")
	end
	
	args = require("Module:parameters").process(args, params)
	
	data.info = {}
	data.only = {}
		
	if args.only then
		if args.only:match("^[1-3]?[sp]?$") then
			for i, val in ipairs(mw.text.split(args.only, "")) do
				data.only[val] = true
			end
		else
			error("Parameter \"only\" has an incorrect value, see documentation for details")
		end
	end
		
	local only_modes = {
		["1"] = "first-person",
		["2"] = "second-person",
		["3"] = "third-person",
		["s"] = "singular",
		["p"] = "plural",
	}
	
	local ordinals = {
		[1] = "first",
		[2] = "second",
		[3] = "third",
		[4] = "fourth",
	}
	
	data.lemma = args.lemma or (mw.title.getCurrentTitle().nsText == "" and PAGENAME)
	data.sc = frame.args.sc or "Latn"
	data.type = args.conjtype or frame.args.type
	
	if data.type == "e" then
		data.type = "e-s"
	elseif data.type == "ea" then
		data.type = "ea-ut"
	end
	
	if data.type == "conj-2" then
		if mw.title.getCurrentTitle().nsText ~= "Template" then
			add_given_forms(args)
			data.conj = tonumber(args.type)
			
			add_repeated_forms()
			
			-- todo: get data.type outside of compare_conj()
			compare_conj()
			
			if dbg then
				table.insert(data.info, "old")
			end
			
			require("Module:debug").track("ro-verb/old")
		end
	else
		if mw.title.getCurrentTitle().nsText == "Template" and
		template_defaults[data.type] and not data.lemma then
			data.lemma = template_defaults[data.type][1]
			args[1] = template_defaults[data.type][2]
			args[2] = template_defaults[data.type][3]
			
			args.new = true
		end
		
		if is_new_conj(args) then	-- new functions
			local inf_stem = args[2] and {args[2]} or {get_inf_stem()}
			local stems = get_stems(args[1] or inf_stem[1])
			
			add_given_forms(args)
			
			conjugations_new[(data.type)](data.forms, inf_stem, stems)
			
			add_repeated_forms_new(data.forms)
			
			if dbg then
				table.insert(data.info, "new")
			end
		
			require("Module:debug").track("ro-verb/new")
		else
			add_given_forms(args)
			
			conjugations[(data.type) .. "-generic"](args[1] and (args[1] .. (args[2] or "")))
			
			add_repeated_forms()
			
			compare_conj()
			
			if dbg then
				table.insert(data.info, "old")
			end
		
			require("Module:debug").track("ro-verb/old")
		end
	end
	
	if mw.title.getCurrentTitle().nsText ~= "Template" and
	data.lemma ~= data.forms.inf[1] then
		require("Module:debug").track("ro-verb/different pagename")
	end
	
	if data.conj then
		table.insert(data.info, "[[Appendix:Romanian " .. ordinals[data.conj] .. " conjugation|" .. ordinals[data.conj] .. " conjugation]]")
	else
		table.insert(data.info, "unknown conjugation")
	end
	
	table.insert(data.info, get_type_info())
	
	add_particles()

	if args.only then
		local only_info = {}
		
		for key, name in pairs(only_modes) do
			if data.only[key] then
				table.insert(only_info, name)
				
				if key:match("^[1-3]$") then	-- person
					for i, form in ipairs(form_names) do
						-- finite form, but different person
						if not form:find(key) and form:find("[1-3]") then
							data.forms[form] = nil
						end
					end
				else							-- number
					for i, form in ipairs(form_names) do
						-- finite form, but different number
						if not form:find(key .. "$") and form:find("[1-3]") then
							data.forms[form] = nil
						end
					end
				end
			end
		end
		
		table.insert(data.info, table.concat(only_info, " ") .. " only")
	end
	
	return make_table()
end

return export
