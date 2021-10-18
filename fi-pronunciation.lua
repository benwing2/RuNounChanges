local export = {}

local m_IPA = require("Module:IPA")
local m_fi_IPA = require("Module:fi-IPA") -- <= the module you want to edit if the IPA transcription is wrong
local m_hyph = require("Module:fi-hyphenation") -- <= the module you want to edit if the automatic hyphenation is wrong
local m_qual = require("Module:qualifier")
local m_utilities = require("Module:utilities")

local lang = require("Module:languages").getByCode("fi")

local vowels = "aeiouyåäö"
local vowel = "[" .. vowels .. "]"
local consonants = "bcdfghjklmnpqrstvwxzšžʔ"
local consonant = "[" .. consonants .. "]"
local apostrophe = "’"	
local tertiary = m_fi_IPA.tertiary
local ipa_symb = "ˣˈˌ"..tertiary.."̯̝̞̠̪" -- include ˣ because final gemination does not affect rhymes

local function clean_for_hyphenation(word)
	return mw.ustring.gsub(mw.ustring.gsub(mw.ustring.gsub(mw.ustring.gsub(mw.ustring.gsub(word, "%([:ː]%)", ""), "(.)ː", "%1%1"), "[" .. ipa_symb .. "ˣ*]", ""), "/", "-"), "^-", "")
end
export.h = clean_for_hyphenation

-- applies gemination mid-word for rhymes
local function apply_gemination(word)
	return mw.ustring.gsub(mw.ustring.gsub(word, "[*ˣ](" .. vowel .. ")", "ʔ%1"), "[*ˣ](" .. consonant .. ")", "%1ː")
end

local function clean_for_rhyme(word)
	return mw.ustring.gsub(mw.ustring.gsub(mw.ustring.gsub(mw.ustring.gsub(apply_gemination(mw.ustring.lower(word)), "%([:ː]%)", ""), "(.)ː", "%1%1"), "[" .. ipa_symb .. "]", ""), "/", "-")
end

function export.generate_rhyme(word)
	-- convert syllable weight to hyphen for next routine
	-- (just in case these are included manually... even if they shouldn't be)
	local fmtword = mw.ustring.gsub(word, "[ˈˌ"..tertiary.."]", "-")
	fmtword = mw.ustring.gsub(word, "’", ".")
	
	-- get final part of a compound word
	local last_hyph = mw.ustring.find(fmtword, "%-[^%-]*$") or 0
	local last_part = mw.ustring.sub(fmtword, last_hyph + 1)
	
	-- split to syllables, keep . in case we have a syllable break
	local hyph = m_hyph.generate_hyphenation(last_part, ".")
	local last_index = #hyph
	local last_stressed = 1
	local prev_stress = false
	
	-- find last stressed syllable
	for index, syllable in ipairs(hyph) do
		local stressed = false
		
		if index == 1 then
			stressed = true
		elseif not prev_stress and index < last_index then
			-- shift stress if current syllable light and a heavy syllable occurs later
			stressed = index == last_index - 1 or not m_fi_IPA.is_light_syllable(syllable) or not m_fi_IPA.has_later_heavy_syllable(hyph, index + 1)
		end
		
		if stressed then
			last_stressed = index
		end
		prev_stress = stressed
	end
	
	local res = {}
	for i = last_stressed, #hyph, 1 do 
		table.insert(res, hyph[i])	
	end
	
	res = table.concat(res)
	
	-- remove initial consonants, convert to IPA, remove IPA symbols
	res = mw.ustring.gsub(res, "^%.", "")
	res = mw.ustring.gsub(res, "^" .. consonant .. "+", "")
	res = m_fi_IPA.IPA_wordparts(res, false)
	res = mw.ustring.gsub(res, "[" .. ipa_symb .. "]", "")
	res = mw.ustring.gsub(res, "^%.", "")
	
	return res
end

local function pron_equal(title, pron)
	if not pron or pron == "" then
		return true
	end
	
	-- handle slashes as hyphens
	pron = mw.ustring.gsub(pron, "/", "-")
	-- remove gemination asterisks and syllable separating dots
	pron = mw.ustring.gsub(pron, "*", "")
	pron = mw.ustring.gsub(pron, "%.", "")
	-- remove optional lengthening/shortening, should not cause any issues
	pron = mw.ustring.gsub(pron, "%([:ː]%)", "")
	-- map existing glottal stops to apostrophes
	pron = mw.ustring.gsub(pron, "%(?ʔ%)?", apostrophe)
	-- /ŋn/ for /gn/ is fine
	pron = mw.ustring.gsub(pron, "ŋn", "gn")
	-- remove hyphens but also apostrophes right after hyphens
	-- (so that glottal stop is allowed after hyphen separating two same vowels)
	pron = mw.ustring.gsub(pron, "-" .. apostrophe .. "?", "")
	title = mw.ustring.gsub(title, "-", "")
	
	return pron == mw.ustring.lower(title)
end

function export.show(frame)
	local title = mw.title.getCurrentTitle().text
	local pronunciation = { "" }
	local ipa = { nil }
	local rhymes = { nil }
	local hyphenation = { nil }
	local audio = { }
	local qualifiers = { }
	local hyphlabels = { }
	local rhymlabels = { }
	local homophones = { }
	local homophonelabels = { }
	local nohyphen = false
	local norhymes = false
	local csuffix = false
	local categories = { }
	
	if type(frame) == "table" then
		local params = {
			[1] = { list = true, default = "" },
			
			["ipa"] = { list = true, default = nil, allow_holes = true },
			["h"] = { list = true, default = nil, allow_holes = true }, ["hyphen"] = {},
			["r"] = { list = true, default = nil, allow_holes = true }, ["rhymes"] = {},
			["a"] = { list = true, default = nil }, ["audio"] = {},
			["ac"] = { list = true, default = nil }, ["caption"] = {},
			["hh"] = { default = "" }, ["homophones"] = {},
			
			["q"] = { list = true, default = nil, allow_holes = true },
			["hp"] = { list = true, default = nil, allow_holes = true },
			["rp"] = { list = true, default = nil, allow_holes = true },
			["hhp"] = { list = true, default = nil, allow_holes = true },
			
			["nohyphen"] = { type = "boolean", default = false },
			["norhymes"] = { type = "boolean", default = false },
			["csuffix"] = { type = "boolean", default = false },
			
			["title"] = {}, -- for debugging or demonstration only
		}
		
		local args, further = require("Module:parameters").process(frame:getParent().args, params, true)
		
		title = args["title"] or title
		pronunciation = args[1]
		ipa = args["ipa"]
		hyphenation = args["h"]
		rhymes = args["r"]
		qualifiers = args["q"]
		hyphlabels = args["hp"]
		rhymlabels = args["rp"]
		nohyphen = args["nohyphen"]
		norhymes = args["norhymes"]
		csuffix = args["csuffix"]
		homophones = mw.text.split(args["hh"], ",")
		homophonelabels = args["hhp"]
		
		if #homophones == 1 and homophones[1] == "" then homophones = {} end
		if args["hyphen"] then hyphenation[1] = args["hyphen"] end
		if args["rhymes"] then rhymes[1] = args["rhymes"] end
		if args["homophones"] then homophones = mw.text.split(args["homophones"], ",") end
		
		-- messy
		if ipa[2] and ipa[1] == nil then ipa[1] = "" end
		
		local audios = args["a"]
		local captions = args["ac"]
		if args["audio"] then audios[1] = args["audio"] end
		if args["captions"] then captions[1] = args["caption"] end
		
		for i, audiofile in ipairs(audios) do
			if audiofile then
				table.insert(audio, {file = audiofile, caption = captions[i] or "Audio"})
			end
		end
	end

	for i, p in ipairs(pronunciation) do
		if p == "" then
			pronunciation[i] = title
		elseif p == "*" then
			pronunciation[i] = title .. p
		end
	end
	
	-- make sure #pronunciation >= #IPA
	for i, p in ipairs(ipa) do
		if not pronunciation[i] then
			pronunciation[i] = ""
		end
	end
	
	local manual_hr = false
	local ripa = {}
	
	local has_spaces = mw.ustring.match(title, " ")
	local is_suffix = mw.ustring.match(title, "^-")
	local is_prefix_or_suffix = not csuffix and (mw.ustring.match(title, "-$") or is_suffix)
	for i, p in ipairs(pronunciation) do
		local qual = qualifiers[i] or ""
		
		if #qual > 0 then
			qual = " " .. m_qual.format_qualifier(qualifiers[i])
		end
		
		if ipa[i] and ipa[i] ~= "" then
			table.insert(ripa, "* " .. m_IPA.format_IPA_full(lang, {{pron = ipa[i]}}, nil, nil, nil, has_spaces) .. qual)
			manual_hr = true
		else
			p = mw.ustring.gsub(p, ":", "ː")
			
			local IPA_narrow = m_fi_IPA.IPA_wordparts(p, true)
			local IPA = m_fi_IPA.IPA_wordparts(p, false)
			
			-- multi-word stress
			if has_spaces then
				IPA_narrow = mw.ustring.gsub(IPA_narrow, " ([^ˈˌ"..tertiary.."])", " ˈ%1")
				IPA = mw.ustring.gsub(IPA, " ([^ˈˌ"..tertiary.."])", " ˈ%1")
			end
			
			-- remove initial stress if suffix
			if is_suffix then
				if csuffix then
					IPA_narrow = mw.ustring.gsub(IPA_narrow, "^ˈ", "ˌ")
					IPA = mw.ustring.gsub(IPA, "^ˈ", "ˌ")
				else
					IPA_narrow = mw.ustring.gsub(IPA_narrow, "^ˈ", "")
					IPA = mw.ustring.gsub(IPA, "^ˈ", "")
				end
			end
			
			table.insert(ripa, "* " .. m_IPA.format_IPA_full(lang, {{pron = "/" .. IPA .. "/"}, {pron = "[" .. IPA_narrow .. "]"}}, nil, nil, nil, has_spaces) .. qual)
		end
	end
	
	local results = mw.clone(ripa)
	manual_hr = manual_hr or has_spaces or is_prefix_or_suffix or not pron_equal(title, mw.ustring.lower(pronunciation[1]))
	
	if not hyphenation[1] and not manual_hr then
		hyphenation[1] = m_hyph.generate_hyphenation(clean_for_hyphenation(pronunciation[1]), false)
	end
	if not rhymes[1] and not manual_hr then
		rhymes[1] = export.generate_rhyme(clean_for_rhyme(pronunciation[1]))
	end
	if not has_spaces and not is_prefix_or_suffix and not (hyphenation[1] and rhymes[1]) then
		table.insert(categories, "fi-pronunciation without hyphenation or rhymes")
	end
	
	if #hyphenation == 1 and hyphenation[1] == "-" then
		hyphenation = {}
	end
	if #rhymes == 1 and rhymes[1] == "-" then
		rhymes = {}
	end
	
	for i, h in ipairs(hyphenation) do
		if type(h) == "string" then
			hyphenation[i] = mw.text.split(h, '[' .. m_hyph.sep_symbols .. ']')
		end
	end
	
	for i, a in ipairs(audio) do
		table.insert(results, "* " .. frame:expandTemplate{title = "audio", args = {"fi", a["file"], a["caption"]}})
	end
	
	if not norhymes then
		if #rhymes > 0 then
			-- merge rhymes if they have identical labels
			local last_label = false
			local new_rhymes = {}
			local new_labels = {}
			local current_list = {}
			
			for i, r in ipairs(rhymes) do
				local label = rhymlabels[i]
				if last_label == label then
					table.insert(current_list, r)
				else
					if #current_list > 0 then
						table.insert(new_rhymes, current_list)
					end
					if last_label ~= false then
						table.insert(new_labels, last_label)
					end
					current_list = { r }
					last_label = label
				end
			end
			
			table.insert(new_rhymes, current_list)
			table.insert(new_labels, last_label)
			rhymes = new_rhymes
			rhymlabels = new_labels
		end
		
		for i, r in ipairs(rhymes) do
			local label = ""
			if rhymlabels[i] then
				label = " " .. m_qual.format_qualifier(rhymlabels[i])
			end
			if #r >= 1 then
				local sylkeys = {}
				local sylcounts = {}
				-- get all possible syllable counts from syllabifications
				for i, h in ipairs(hyphenation) do
					local hl = #h
					if hl > 0 and not sylkeys[hl] then
						table.insert(sylcounts, hl)
						sylkeys[hl] = true
					end
				end
				table.insert(results, "* " .. frame:expandTemplate{title = "rhymes", args = {"fi", s = table.concat(sylcounts, ","), unpack(r)}} .. label)
			end
		end
	end
	if #homophones > 0 then
		local homophone_param = {"fi"}
		for i, h in ipairs(homophones) do
			table.insert(homophone_param, h)
			if homophonelabels[i] then
				homophone_param["q" .. i] = homophonelabels[i]
			end
		end
		table.insert(results, "* " .. frame:expandTemplate{title = "homophones", args = homophone_param})
	end
	if not nohyphen then
		for i, h in ipairs(hyphenation) do
			local label = ""
			if hyphlabels[i] then
				label = " " .. m_qual.format_qualifier(hyphlabels[i])
			end
			table.insert(results, "* Syllabification: " .. require("Module:links").full_link({lang = lang, alt = table.concat(h, "‧"), tr = "-"}) .. label)
		end
	end
	
	return table.concat(results, "\n") .. m_utilities.format_categories(categories, lang)
end

return export
