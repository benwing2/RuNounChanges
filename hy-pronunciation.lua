local export = {}

local m_str_utils = require("Module:string utilities")

local rsubn = m_str_utils.gsub
local toNFC = mw.ustring.toNFC
local rlower = m_str_utils.lower
local rfind = m_str_utils.find

-- single characters that map to IPA sounds   
local phonetic_chars_map = {
	-- Eastern Armenian
	east = {
		["ա"]="ɑ", ["բ"]="b", ["գ"]="ɡ", ["դ"]="d", ["ե"]="e", ["զ"]="z",
		["է"]="e", ["ը"]="ə", ["թ"]="tʰ", ["ժ"]="ʒ", ["ի"]="i", ["լ"]="l",
		["խ"]="χ", ["ծ"]="t͡s", ["կ"]="k", ["հ"]="h", ["ձ"]="d͡z", ["ղ"]="ʁ", 
		["ճ"]="t͡ʃ", ["մ"]="m", ["յ"]="j", ["ն"]="n", ["շ"]="ʃ", ["ո"]="o",
		["չ"]="t͡ʃʰ", ["պ"]="p", ["ջ"]="d͡ʒ", ["ռ"]="r", ["ս"]="s", ["վ"]="v", 
		["տ"]="t", ["ր"]="ɾ", ["ց"]="t͡sʰ", ["ւ"]="v", ["փ"]="pʰ", ["ք"]="kʰ",
		["և"]="ev", ["օ"]="o", ["ֆ"]="f", ["-"]=" ", ["’"]="", ["-"]=""
	},
	-- note that the default pronunciation of ostensible /ɾ/ is [ɹ]
	-- Western Armenian
	west = {
		["ա"]="ɑ", ["բ"]="pʰ", ["գ"]="kʰ", ["դ"]="tʰ", ["ե"]="e", ["զ"]="z",
		["է"]="e", ["ը"]="ə", ["թ"]="tʰ", ["ժ"]="ʒ", ["ի"]="i", ["լ"]="l",
		["խ"]="χ", ["ծ"]="d͡z", ["կ"]="ɡ", ["հ"]="h", ["ձ"]="t͡sʰ", ["ղ"]="ʁ", 
		["ճ"]="d͡ʒ", ["մ"]="m", ["յ"]="j", ["ն"]="n", ["շ"]="ʃ", ["ո"]="o",
		["չ"]="t͡ʃʰ", ["պ"]="b", ["ջ"]="t͡ʃʰ", ["ռ"]="r", ["ս"]="s", ["վ"]="v", 
		["տ"]="d", ["ր"]="ɾ", ["ց"]="t͡sʰ", ["ւ"]="v", ["փ"]="pʰ", ["ք"]="kʰ",
		["և"]="ev", ["օ"]="o", ["ֆ"]="f", ["-"]=" ", ["’"]="", ["-"]=""
	},
}

-- character sequences of two that map to IPA sounds
local phonetic_2chars_map = {
	east = {
		{ 'ու', 'u' },
	},
	west = {
		-- if not in the initial position and if not preceded by [ɑeəoiu]
		{ '(.?.?)յու', function(before)
			if not (before == '' or rfind(before, '[%sաեէիոօ]$')
			or before == "ու") then
				return before .. 'ʏ'
			end
		end },
		{ 'ու', 'u' },
		{ 'էօ', 'œ' },
		-- պ, տ, կ are not voiced after ս and շ
		{ 'սպ', 'sp' },
		{ 'ստ', 'st' },
		{ 'սկ', 'sk' },
		{ 'շպ', 'ʃp' },
		{ 'շտ', 'ʃt' },
		{ 'շկ', 'ʃk' },
		-- Western Armenian inserts ə in the causative
		{ 'ցնել', 't͡sʰənel' },

	},
}

function export._pronunciation(word, system)
	if not (phonetic_chars_map[system] and phonetic_2chars_map[system]) then
		error("Invalid system " .. tostring(system))
	end
	
	word = rlower(word)

	local phonetic = word

	-- then long consonants that are orthographically geminated.
	phonetic = rsubn(phonetic, "(.)%1", "%1ː")

	for _, replacement in ipairs(phonetic_2chars_map[system]) do
		phonetic = rsubn(phonetic, unpack(replacement))
	end
	
	-- ոու is pronounced ou
	phonetic = rsubn(phonetic, "ոːւ", "օու")

	-- ե and ո are pronounced as je and vo word-initially.
	phonetic = rsubn(phonetic, "^ե", "յէ")
	phonetic = rsubn(phonetic, "^ո", "վօ")
	-- except when followed by another վ.
	phonetic = rsubn(phonetic, "^վօվ", "օվ")
	
	-- ոու is pronounced oov
	phonetic = rsubn(phonetic, "ոու", "օու")

	phonetic = rsubn(phonetic, '.', phonetic_chars_map[system])

	--oov is actually ou
	phonetic = rsubn(phonetic, "oov", "ou")

	-- insertion of the optional glide
	phonetic = rsubn(phonetic, "iɑ", "i(j)ɑ")
	phonetic = rsubn(phonetic, "ie", "i(j)e")
	phonetic = rsubn(phonetic, "io", "i(j)o")
	phonetic = rsubn(phonetic, "iu", "i(j)u")
	phonetic = rsubn(phonetic, "ɑi", "ɑ(j)i")
	phonetic = rsubn(phonetic, "ei", "e(j)i")
	phonetic = rsubn(phonetic, "oi", "o(j)i")
	phonetic = rsubn(phonetic, "ui", "u(j)i")

	-- assimilation: ppʰ = pʰː; ttʰ = tʰː; ; kkʰ = kʰː
	phonetic = rsubn(phonetic, "ppʰ", "pʰː")
	phonetic = rsubn(phonetic, "ttʰ", "tʰː")
	phonetic = rsubn(phonetic, "kkʰ ", "kʰː")

	-- nasal assimilation
	phonetic = rsubn(phonetic, "n([ɡk]+)", "ŋ%1")

	-- pseudo-palatalization under the influence of Russian [COLLOQUIAL, NOT STANDARD]
	--phonetic = rsubn(phonetic, "tj", "t͡sj")
	--phonetic = rsubn(phonetic, "tʰj", "t͡sʰj")
	--phonetic = rsubn(phonetic, "dj", "d͡zj")

	-- palatalization in the Eastern Armenian sequence -ությ-, especially in the suffix -ություն [considered non-standard by strict prescriptivists]
	if system == "east" then
		phonetic = rsubn(phonetic, "utʰj", "ut͡sʰj")
	end

	-- trilling of ɾ in some positions [COLLOQUIAL, NOT STANDARD]
	--phonetic = rsubn(phonetic, "ɾt", "rt")

	-- devoicing of consonants in some positions
	phonetic = rsubn(phonetic, "bpʰ", "pʰː")
	phonetic = rsubn(phonetic, "dpʰ", "tʰpʰ")
	phonetic = rsubn(phonetic, "ɡpʰ", "kʰpʰ")
	phonetic = rsubn(phonetic, "d͡zpʰ", "t͡sʰpʰ")
	phonetic = rsubn(phonetic, "d͡ʒpʰ", "t͡ʃʰpʰ")
	phonetic = rsubn(phonetic, "vpʰ", "fpʰ")
	phonetic = rsubn(phonetic, "ʒpʰ", "ʃpʰ")

	phonetic = rsubn(phonetic, "btʰ", "pʰtʰ")
	phonetic = rsubn(phonetic, "dtʰ", "tʰː")
	phonetic = rsubn(phonetic, "ɡtʰ", "kʰtʰ")
	phonetic = rsubn(phonetic, "d͡ztʰ", "t͡sʰtʰ")
	phonetic = rsubn(phonetic, "d͡ʒtʰ", "t͡ʃʰtʰ")
	phonetic = rsubn(phonetic, "vtʰ", "ftʰ")
	phonetic = rsubn(phonetic, "ʒtʰ", "ʃtʰ")

	phonetic = rsubn(phonetic, "bkʰ", "pʰkʰ")
	phonetic = rsubn(phonetic, "dkʰ", "tkʰ")
	phonetic = rsubn(phonetic, "ɡkʰ", "kʰː")
	phonetic = rsubn(phonetic, "d͡zkʰ", "t͡sʰkʰ")
	phonetic = rsubn(phonetic, "d͡ʒkʰ", "t͡ʃʰkʰ")
	phonetic = rsubn(phonetic, "vkʰ", "fkʰ")
	phonetic = rsubn(phonetic, "ʒkʰ", "ʃkʰ")

	phonetic = rsubn(phonetic, "bt͡ʃʰ", "pʰt͡ʃʰ")
	phonetic = rsubn(phonetic, "dt͡ʃʰ", "tʰt͡ʃʰ")
	phonetic = rsubn(phonetic, "ɡt͡ʃʰ", "kʰt͡ʃʰ")
	phonetic = rsubn(phonetic, "d͡zt͡ʃʰ", "t͡sʰt͡ʃʰ")
	phonetic = rsubn(phonetic, "d͡ʒt͡ʃʰ", "t͡ʃʰː")
	phonetic = rsubn(phonetic, "vt͡ʃʰ", "ft͡ʃʰ")
	phonetic = rsubn(phonetic, "ʒt͡ʃʰ", "ʃt͡ʃʰ")

	phonetic = rsubn(phonetic, "bt͡sʰ", "pʰt͡sʰ")
	phonetic = rsubn(phonetic, "dt͡sʰ", "tʰt͡sʰ")
	phonetic = rsubn(phonetic, "ɡt͡sʰ", "kʰt͡sʰ")
	phonetic = rsubn(phonetic, "d͡zt͡sʰ", "t͡sʰː")
	phonetic = rsubn(phonetic, "d͡ʒt͡sʰ", "t͡ʃʰt͡sʰ")
	phonetic = rsubn(phonetic, "vt͡sʰ", "ft͡sʰ")
	phonetic = rsubn(phonetic, "ʒt͡sʰ", "ʃt͡sʰ")

	phonetic = rsubn(phonetic, "zpʰ", "spʰ")
	phonetic = rsubn(phonetic, "ztʰ", "stʰ")
	phonetic = rsubn(phonetic, "zkʰ", "skʰ")

	phonetic = rsubn(phonetic, "ʁt͡s", "χt͡s")
	phonetic = rsubn(phonetic, "ʁt͡ʃ", "χt͡ʃ")
	phonetic = rsubn(phonetic, "ʁp", "χp")
	phonetic = rsubn(phonetic, "ʁt", "χt")
	phonetic = rsubn(phonetic, "ʁk", "χk")
	phonetic = rsubn(phonetic, "ʁs", "χs")
	phonetic = rsubn(phonetic, "ʁʃ", "χʃ")

	phonetic = rsubn(phonetic, "vt͡s", "ft͡s")
	phonetic = rsubn(phonetic, "vt͡ʃ", "ft͡ʃ")
	phonetic = rsubn(phonetic, "vp", "fp")
	phonetic = rsubn(phonetic, "vt", "ft")
	phonetic = rsubn(phonetic, "vk", "fk")
	phonetic = rsubn(phonetic, "vs", "fs")
	phonetic = rsubn(phonetic, "vʃ", "fʃ")

	if system == "west" then
		phonetic = rsubn(phonetic, "χd͡z", "χt͡s")
		phonetic = rsubn(phonetic, "χd͡ʒ", "χt͡ʃ")
		phonetic = rsubn(phonetic, "χb", "χp")
		phonetic = rsubn(phonetic, "χd", "χt")
		phonetic = rsubn(phonetic, "χɡ", "χk")
	end

	if system == "west" then
		phonetic = rsubn(phonetic, "t͡ʃʰd͡z", "t͡ʃʰt͡s")
		phonetic = rsubn(phonetic, "t͡sʰd͡z", "t͡sʰt͡s")
		phonetic = rsubn(phonetic, "pʰd͡z", "pʰt͡s")
		phonetic = rsubn(phonetic, "tʰd͡z", "tʰt͡s")
		phonetic = rsubn(phonetic, "kʰd͡z", "kʰt͡s")

		phonetic = rsubn(phonetic, "t͡ʃʰd͡ʒ", "t͡ʃʰt͡ʃ")
		phonetic = rsubn(phonetic, "t͡sʰd͡ʒ", "t͡sʰt͡ʃ")
		phonetic = rsubn(phonetic, "pʰd͡ʒ", "pʰt͡ʃ")
		phonetic = rsubn(phonetic, "tʰd͡ʒ", "tʰt͡ʃ")
		phonetic = rsubn(phonetic, "kʰd͡ʒ", "kʰt͡ʃ")

		phonetic = rsubn(phonetic, "t͡ʃʰb", "t͡ʃʰp")
		phonetic = rsubn(phonetic, "t͡sʰb", "t͡sʰp")
		phonetic = rsubn(phonetic, "pʰb", "pʰp")
		phonetic = rsubn(phonetic, "tʰb", "tʰp")
		phonetic = rsubn(phonetic, "kʰb", "kʰp")

		phonetic = rsubn(phonetic, "t͡ʃʰd", "t͡ʃʰt")
		phonetic = rsubn(phonetic, "t͡sʰd", "t͡sʰt")
		phonetic = rsubn(phonetic, "pʰd", "pʰt")
		phonetic = rsubn(phonetic, "tʰd", "tʰt")
		phonetic = rsubn(phonetic, "kʰd", "kʰt")

		phonetic = rsubn(phonetic, "t͡ʃʰɡ", "t͡ʃʰk")
		phonetic = rsubn(phonetic, "t͡sʰɡ", "t͡sʰk")
		phonetic = rsubn(phonetic, "pʰɡ", "pʰk")
		phonetic = rsubn(phonetic, "tʰɡ", "tʰk")
		phonetic = rsubn(phonetic, "kʰɡ", "kʰk")

	end


	-- prothetic ə before {s/ʃ/z}{p/t/k/b/d/g} in Western Armenian; this rule is not the norm in Eastern Armenian anymore
	if system == "west" then
		phonetic = rsubn(phonetic, "^([sʃz][ptkbdɡ]+)", "ə%1")
	end

	-- generating the stress
	phonetic = rsubn(phonetic, "%S+", function(word)
		-- Do not add a stress mark for monosyllabic words. Check to see if the word contains only a single instance of [ɑeəoiuœʏ]+.
		local numberOfVowels = select(2, rsubn(word, "[ɑeəoiuœʏ]", "%0"))
	
		-- If polysyllabic, add an acute using the following rules. The stress is always on the last syllable not 
		-- formed by schwa [ə]. In some rare cases the stress is not on the last syllable. In such cases the stressed vowel
		-- is marked by the Armenian stress character <՛>, e.g. մի՛թե. So:
		--      1) Find the vowel followed by <՛> and put the acute on it․ If none, go to step 2. 
		--      2) Find the last non-schwa vowel, i.e. [ɑeoiuœʏ], and put the acute on it.
		if numberOfVowels > 1 then
			local rcount
			word, rcount = rsubn(word, "([ɑeoiuœʏə])՛", "%1́")
			if rcount == 0 then
				word = rsubn(word, "([ɑeoiuœʏ])([^ɑeoiuœʏə]*)(ə?[^ɑeoiuœʏə]?)$", "%1́%2%3")
			end
			return word
		end
	end)

	-- change phonetically-impossible ɾː to ɹː
	if system == "east" or system == "west" then
        phonetic = rsubn(phonetic, "ɾː", "ɹː")
    end

	if system == "east" or system == "west" then
        phonetic = rsubn(phonetic, "([td])%1͡([sʃzʒ])(ʰ?)", "%1̚%1͡%2%3")
        phonetic = rsubn(phonetic, "([td])͡([sʃzʒ])(ʰ?)ː", "%1̚%1͡%2%3")
    end

	phonetic = toNFC(phonetic)
	return phonetic
end

function export.pronunciation(word, system)
	if type(word) == "table" then
		local frame = word
		local invoke_args, parent_args = frame.args, frame:getParent().args
		word = invoke_args[1] or parent_args[1]
		system = invoke_args.system or parent_args.system or "east"
	end
	if not word or (word == "") then
		error("Please put the word as the first positional parameter!")
	end
	
	return export._pronunciation(word, system)
end
 
return export
