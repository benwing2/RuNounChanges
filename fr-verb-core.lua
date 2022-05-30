local export = {}

local m_conj = require("Module:fr-conj")
local m_links = require("Module:links")
local lang = require("Module:languages").getByCode("fr")
local IPA = function(str)
	return require("Module:IPA").format_IPA(nil, str)
end

local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub

local pref_sufs = {}
export.pref_sufs = pref_sufs

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function verb_slot_to_accel(slot)
	return rsub(slot, "^([a-z_]+)_([123])([sp])$",
		function(mood_tense, person, number)
			local mood_tense_to_infl = {
				["ind_p"] = "pres|indc",
				["ind_i"] = "impf|indc",
				["ind_ps"] = "phis",
				["ind_f"]  = "futr",
				["cond_p"] = "cond",
				["sub_p"] = "pres|subj",
				["sub_pa"] = "impf|subj",
				["imp_p"] = "impr"
			}
			return person .. "|" .. number .. "|" .. mood_tense_to_infl[mood_tense]
		end
	)
end

local function map(seq, fun)
	if type(seq) == "table" then
		local ret = {}
		for _, s in ipairs(seq) do
			-- Handle stem of the form {"STEM", RESPELLING="RESPELLING"}
			if type(s) == "table" then
				s = s[1]
			end
			-- store in separate var in case fun() has multiple retvals
			local retval = fun(s)
			table.insert(ret, retval)
		end
		return ret
	else
		-- store in separate var in case fun() has multiple retvals
		local retval = fun(seq)
		return retval
	end
end

local function add(source, appendix)
	return map(source, function(s) return s .. appendix end)
end

function export.make_ind_p_e(data, stem, stem2, stem3)
	stem2 = stem2 or stem
	stem3 = stem3 or stem

	data.forms.ind_p_1s = add(stem, "e")
	data.forms.ind_p_2s = add(stem, "es")
	data.forms.ind_p_3s = add(stem, "e")
	data.forms.ind_p_3p = add(stem, "ent")
	data.forms.ind_p_1p = add(stem2, "ons")
	-- stem3 is used in -ger and -cer verbs
	data.forms.ind_p_2p = add(stem3, "ez")

	export.make_ind_i(data, stem2, stem3)
	export.make_ind_ps_a(data, stem2, stem3)
	export.make_sub_p(data, stem, stem3)
	export.make_imp_p_ind(data)
	export.make_ind_f(data, add(stem, "er"))
	data.forms.ppr = add(stem2, "ant")
end

function export.make_ind_p(data, stem, stem2, stem3)
	stem2 = stem2 or stem
	stem3 = stem3 or stem2
	data.forms.ind_p_1s = add(stem, "s")
	data.forms.ind_p_2s = add(stem, "s")
	-- add t unless stem ends in -t (e.g. met), -d (e.g. vend, assied) or
	-- -c (e.g. vainc).
	data.forms.ind_p_3s = map(stem, function(s)
		return add(s, rmatch(s, "[tdc]$") and "" or "t")
	end)
	data.forms.ind_p_1p = add(stem2, "ons")
	data.forms.ind_p_2p = add(stem2, "ez")
	data.forms.ind_p_3p = add(stem3, "ent")

	export.make_ind_i(data, stem2)
	export.make_sub_p(data, stem3, stem2)
	export.make_imp_p_ind(data)
	data.forms.ppr = add(stem2, "ant")
end

function export.make_ind_i(data, stem, stem2)
	stem2 = stem2 or stem
	data.forms.ind_i_1s = add(stem, "ais")
	data.forms.ind_i_2s = add(stem, "ais")
	data.forms.ind_i_3s = add(stem, "ait")
	data.forms.ind_i_1p = add(stem2, "ions")
	data.forms.ind_i_2p = add(stem2, "iez")
	data.forms.ind_i_3p = add(stem, "aient")
end

function export.make_ind_ps_a(data, stem, stem2)
	stem2 = stem2 or stem
	data.forms.ind_ps_1s = add(stem, "ai")
	data.forms.ind_ps_2s = add(stem, "as")
	data.forms.ind_ps_3s = add(stem, "a")
	data.forms.ind_ps_1p = add(stem, "âmes")
	data.forms.ind_ps_2p = add(stem, "âtes")
	data.forms.ind_ps_3p = add(stem2, "èrent")

	export.make_sub_pa(data, add(stem, "a"))

	data.forms.pp = data.forms.pp or add(stem2, "é")
end

local function fix_circumflex(val)
	return rsub(val, "[aiïu]n?%^", {["a^"]="â", ["i^"]="î", ["ï^"]="ï", ["in^"]="în", ["u^"]="û"})
end

function export.make_ind_ps(data, stem)
	data.forms.ind_ps_1s = add(stem, "s")
	data.forms.ind_ps_2s = add(stem, "s")
	data.forms.ind_ps_3s = add(stem, "t")
	data.forms.ind_ps_1p = map(add(stem, "^mes"), fix_circumflex)
	data.forms.ind_ps_2p = map(add(stem, "^tes"), fix_circumflex)
	data.forms.ind_ps_3p = add(stem, "rent")

	export.make_sub_pa(data, stem)

	data.forms.pp = data.forms.pp or add(stem, "")
end

function export.make_ind_f(data, stem)
	data.forms.ind_f_1s = add(stem, "ai")
	data.forms.ind_f_2s = add(stem, "as")
	data.forms.ind_f_3s = add(stem, "a")
	data.forms.ind_f_1p = add(stem, "ons")
	data.forms.ind_f_2p = add(stem, "ez")
	data.forms.ind_f_3p = add(stem, "ont")

	export.make_cond_p(data, stem)
end

function export.make_cond_p(data, stem)
	data.forms.cond_p_1s = add(stem, "ais")
	data.forms.cond_p_2s = add(stem, "ais")
	data.forms.cond_p_3s = add(stem, "ait")
	data.forms.cond_p_1p = add(stem, "ions")
	data.forms.cond_p_2p = add(stem, "iez")
	data.forms.cond_p_3p = add(stem, "aient")
end

function export.make_sub_p(data, stem, stem2)
	stem2 = stem2 or stem
	data.forms.sub_p_1s = add(stem, "e")
	data.forms.sub_p_2s = add(stem, "es")
	data.forms.sub_p_3s = add(stem, "e")
	data.forms.sub_p_3p = add(stem, "ent")
	data.forms.sub_p_1p = add(stem2, "ions")
	data.forms.sub_p_2p = add(stem2, "iez")
end

function export.make_sub_pa(data, stem)
	data.forms.sub_pa_1s = add(stem, "sse")
	data.forms.sub_pa_2s = add(stem, "sses")
	data.forms.sub_pa_3s = map(add(stem, "^t"), fix_circumflex)
	data.forms.sub_pa_1p = add(stem, "ssions")
	data.forms.sub_pa_2p = add(stem, "ssiez")
	data.forms.sub_pa_3p = add(stem, "ssent")
end

function export.make_imp_p_ind(data)
	data.forms.imp_p_2s = map(data.forms.ind_p_2s, function(form)
		return rsub(form, "([ae])s$", "%1")
	end)
	data.forms.imp_p_1p = data.forms.ind_p_1p
	data.forms.imp_p_2p = data.forms.ind_p_2p
end

function export.clear_imp(data)
	data.forms.imp_p_2s = "—"
	data.forms.imp_p_1p = "—"
	data.forms.imp_p_2p = "—"
end

local function add_prefix_suffix(data, key, val, pref_v, pref_c, pron_v, pron_c, imp, pron_imp, join_imp_dash)
	if key == "pp" or rmatch(key, "_nolink") then
		return
	end
	local imp_joiner, imp_pron_joiner
	if join_imp_dash then
		imp_joiner = "-"
		imp_pron_joiner = "."
	else
		imp_joiner = ""
		imp_pron_joiner = ""
	end
	local pref, suf, pref_pron, suf_pron
	local function get_pref_suf(v)
		pref, suf, pref_pron, suf_pron = "", "", "", ""
		if not rmatch(key, "imp") then
			if rmatch(v, "^[aeéêiouhywjɑɛœø]") then
				pref, pref_pron = pref_v, pron_v
			else
				pref, pref_pron = pref_c, pron_c
			end
		else
			suf, suf_pron = imp_joiner .. imp, imp_pron_joiner .. pron_imp
		end
	end
	if key == "inf" or key == "ppr" then
		data.forms[key .. '_nolink'] =
			map(data.forms[key], function(val)
				get_pref_suf(val)
				return pref .. val .. suf
			end)
	end
	data.forms[key] = map(val, function(v)
		get_pref_suf(v)
		return rsub(pref .. "[[" .. v .. "]]" .. suf, "%.h", "h")
	end)
	if data.prons[key] then
		data.prons[key] = map(data.prons[key], function(v)
			get_pref_suf(v)
			return pref_pron .. v .. suf_pron
		end)
	end
end

pref_sufs["y"] = function(data, key, val)
	local imp = rmatch(key, "2s") and not rmatch(val, "s$") and "s-y" or "-y"
	add_prefix_suffix(data, key, val, "y ", "y ", "i.j‿", "i ", imp, ".zi", false)
end

pref_sufs["en"] = function(data, key, val)
	local imp = rmatch(key, "2s") and not rmatch(val, "s$") and "s-en" or "-en"
	add_prefix_suffix(data, key, val, "en ", "en ", "ɑ̃.n‿", "ɑ̃ ", imp, ".zɑ̃", false)
end

pref_sufs["yen"] = function(data, key, val)
	local imp = rmatch(key, "2s") and not rmatch(val, "s$") and "s-y en" or "-y-en"
	add_prefix_suffix(data, key, val, "y en ", "y en ", "i.j‿ɑ̃.n‿", "i.j‿ɑ̃ ", imp, ".zi.jɑ̃", false)
end

pref_sufs["le"] = function(data, key, val)
	add_prefix_suffix(data, key, val, "l'", rmatch(key, "2p") and "le ''or'' la " or "le ", "l", "lə ", "-le", ".lə", false)
end

pref_sufs["la"] = function(data, key, val)
	add_prefix_suffix(data, key, val, "l'", "la ", "l", "la ", "-la", ".la", false)
end

pref_sufs["l"] = function(data, key, val)
	add_prefix_suffix(data, key, val, "l'", "l'", "l", "l", "-le ''or'' -la", ".lə ''or'' .la", false)
end

pref_sufs["les"] = function(data, key, val)
	add_prefix_suffix(data, key, val, "les ", "les ", "le.z‿", "le", "-les", ".le", false)
end

pref_sufs["l_y"] = function(data, key, val)
	add_prefix_suffix(data, key, val, "l'y ", "l'y ", "li.j‿", "li ", "-l'y", ".li", false)
end

pref_sufs["l_en"] = function(data, key, val)
	data.aux = "l'en avoir"
	add_prefix_suffix(data, key, val, "l'en ", "l'en ", "lɑ̃.n‿", "lɑ̃ ", "l'en", "lɑ̃", true)
end

pref_sufs["lesen"] = function(data, key, val)
	data.aux = "les en avoir"
	add_prefix_suffix(data, key, val, "les en ", "les en ", "le.z‿ɑ̃.n‿", "le.z‿ɑ̃ ", "-les-en", "le.zɑ̃", true)
end

pref_sufs["lesy"] = function(data, key, val)
	add_prefix_suffix(data, key, val, "les y ", "les y ", "le.z‿i.j‿", "le.z‿i ", "-les-y", ".le.zi", false)
end

pref_sufs["l_yen"] = function(data, key, val)
	data.aux = "l'y en avoir"
	add_prefix_suffix(data, key, val, "l'y en ", "l'y en ", "li.j‿ɑ̃.n‿", "li.j‿ɑ̃ ", "l'y-en", "li.jɑ̃", true)
end

pref_sufs["lesyen"] = function(data, key, val)
	data.aux = "les y en avoir"
	add_prefix_suffix(data, key, val, "les y en ", "les y en ", "le.z‿i.j‿ɑ̃.n‿", "le.z‿i.j‿ɑ̃ ", "-les-y-en", "le.zi.jɑ̃", true)
end

-- Add reflexive prefixes and suffixes to verb forms. KEY is the form to add to, and VAL is the value
-- without prefixes and suffixes. PREF_V is the prefix to add to non-imperative forms that begin with a
-- vowel, and PREF_C is the corresponding prefix for non-imperative forms beginning with a consonant.
-- PRON_V is the prefix to add to the pronunciation of non-imperative forms that begin with a vowel, and
-- PRON_C is the corresponding prefix for pronunciations beginning with a consonant. IMP is the suffix to
-- add to imperative forms, and PRON_IMP is the corresponding suffix to add to the pronunciation of
-- imperative forms. All prefixes and suffixes are added directly, without an intervening space.
--
-- Since the prefixes and suffixes vary depending on the person and number, the specified prefixes and
-- suffixes should contain "%c" and/or "%v" specs in them. "%c" represents the appropriate pronominal
-- form to add before a consonant (or when nothing follows, in the case of suffixes), and "%v" represents
-- the corresponding form to add before a vowel. The actual forms substituted depend on both the person
-- and number of KEY and the type of prefix (i.e. whether it's a spelled prefix, pronunciation prefix,
-- spelled imperative suffix or pronunciation imperative suffix). For example, if key contains "2s"
-- (i.e. it represents a second person singular form), a "%v" in a spelled prefix will be replaced with
-- "t'" and a "%c" in a pronounced prefix will be replaced with "tə ". Note that it's not always the
-- case that %c should occur in a pre-consonant prefix/suffix and correspondingly for %v. For example,
-- if the prefix occurs before "en" or "y" you should use %v in both the pre-vowel and pre-consonant
-- prefixes.
local function add_refl_prefix_suffix(data, key, val, pref_v, pref_c, pron_v, pron_c, imp, pron_imp)
	local sub_pref_v, sub_pref_c, sub_pron_v, sub_pron_c
	local sub_imp_v, sub_imp_c, sub_pron_imp_v, sub_pron_imp_c = "", "", "", ""
	if rmatch(key, "1s") then
		sub_pref_v, sub_pref_c, sub_pron_v, sub_pron_c = "m'", "me ", "m", "mə "
	elseif rmatch(key, "2s") then
		sub_pref_v, sub_pref_c, sub_pron_v, sub_pron_c = "t'", "te ", "t", "tə "
		sub_imp_v, sub_imp_c, sub_pron_imp_v, sub_pron_imp_c = "t'", "toi", "t", "twa"
	elseif rmatch(key, "1p") then
		sub_pref_v, sub_pref_c, sub_pron_v, sub_pron_c = "nous ", "nous ", "nu.z‿", "nu "
		sub_imp_v, sub_imp_c, sub_pron_imp_v, sub_pron_imp_c = "nous-", "nous", "nu.z", "nu"
	elseif rmatch(key, "2p") then
		sub_pref_v, sub_pref_c, sub_pron_v, sub_pron_c = "vous ", "vous ", "vu.z‿", "vu "
		sub_imp_v, sub_imp_c, sub_pron_imp_v, sub_pron_imp_c = "vous-", "vous", "vu.z", "vu"
	else
		sub_pref_v, sub_pref_c, sub_pron_v, sub_pron_c = "s'", "se ", "s", "sə "
	end
	local function dosub(spec, dotype)
		if type(spec) == "table" then
			local sing, plur = spec[1], spec[2]
			if rmatch(key, "[12]p") then
				spec = plur
			else
				spec = sing
			end
		end
		spec = rsub(spec, "%%v",
			dotype == "pron" and sub_pron_v or
			dotype == "imp" and sub_imp_v or
			dotype == "pron-imp" and sub_pron_imp_v or
			sub_pref_v
		)
		spec = rsub(spec, "%%c",
			dotype == "pron" and sub_pron_c or
			dotype == "imp" and sub_imp_c or
			dotype == "pron-imp" and sub_pron_imp_c or
			sub_pref_c
		)
		return spec
	end
	add_prefix_suffix(data, key, val, dosub(pref_v), dosub(pref_c), dosub(pron_v, "pron"), dosub(pron_c, "pron"),
		dosub(imp, "imp"), dosub(pron_imp, "pron-imp"), true)
end

pref_sufs["refl"] = function(data, key, val)
	data.aux = "s'être"
	add_refl_prefix_suffix(data, key, val, "%v", "%c", "%v", "%c", "%c", "%c")
end

pref_sufs["reflen"] = function(data, key, val)
	data.aux = "s'en être"
	add_refl_prefix_suffix(data, key, val, "%ven ", "%ven ", "%vɑ̃.n‿", "%vɑ̃ ", "%ven", "%vɑ̃")
end

pref_sufs["refly"] = function(data, key, val)
	data.aux = "s'y être"
	add_refl_prefix_suffix(data, key, val, "%vy ", "%vy ", "%vi.j‿", "%vi ", "%vy", "%vi")
end

pref_sufs["reflyen"] = function(data, key, val)
	data.aux = "s'y en être"
	add_refl_prefix_suffix(data, key, val, "%vy en ", "%vy en ", "%vi.j‿ɑ̃.n‿", "%vi.j‿ɑ̃ ", "%v'y-en", "%vi.jɑ̃")
end

pref_sufs["reflle"] = function(data, key, val)
	data.aux = "se l'être"
	add_refl_prefix_suffix(data, key, val, "%cl'", "%cle ", "%cl", "%clə ", "le-%c", "lə.%c")
end

pref_sufs["refll"] = function(data, key, val)
	data.aux = "se l'être"
	add_refl_prefix_suffix(data, key, val, "%cl'", "%cl'", "%cl", "%cl", "le-%c ''or'' -la-%c", "lə.%c ''or'' .la.%c")
end

pref_sufs["reflla"] = function(data, key, val)
	data.aux = "se l'être"
	add_refl_prefix_suffix(data, key, val, "%cl'", "%cla ", "%cl", "%cla ", "la-%c", "la.%c")
end

pref_sufs["reflles"] = function(data, key, val)
	data.aux = "se les être"
	add_refl_prefix_suffix(data, key, val, "%cles ", "%cles ", "%cle.z‿", "%cle ", "les-%c", "le.%c")
end

pref_sufs["reflly"] = function(data, key, val)
	data.aux = "se l'y être"
	add_refl_prefix_suffix(data, key, val, "%cl'y ", "%cl'y ", "%cli.j‿", "%cli ", "le-%cy <i>or</i> -la-%cy", "lə.%ci <i>or</i> .la.%ci")
end

pref_sufs["refllesy"] = function(data, key, val)
	data.aux = "se les y être"
	add_refl_prefix_suffix(data, key, val, "%cles y ", "%cles y ", "%cle.z‿i.j‿", "%cle.z‿i ", "les-%cy", "le.%ci")
end

function export.link(data)
	for key, val in pairs(data.forms) do
		if type(val) ~= "table" then
			val = {val}
		end
		-- don't destructively modify data.forms[key][i] because it might
		-- be shared among different keys
		local newval = {}
		for i, form in ipairs(val) do
			local newform = form
			if not rmatch(key, "nolink") and not rmatch(form, "—") then
				newform = m_links.full_link({term = form, lang = lang,
					accel = { form = verb_slot_to_accel(key) }
				})
			end
			if rmatch(form, "—") then
				newform = "—"
			end
			table.insert(newval, newform)
		end
		data.forms[key] = table.concat(newval, " or ")
	end
	for key, val in pairs(data.prons) do
		if not rmatch(key, "nolink") then
			if type(val) ~= "table" then
				val = {val}
			end
			-- don't destructively modify data.forms[key][i] because it might
			-- be shared among different keys
			local newprons = {}
			for i, form in ipairs(val) do
				if not rmatch(form, "—") then
					table.insert(newprons, IPA('/' .. form .. '/'))
				end
			end
			if #newprons > 0 and data.forms[key] ~= "—" then
				data.forms[key] = data.forms[key] .. '<br /><span style="color:#7F7F7F">' .. table.concat(newprons, " or ") .. '</span>'
			end
		end
	end
end

-- not sure if it's still used by something so I'm leaving a stub function instead of removing it entirely
function export.make_table(data)
	return m_conj.make_table(data)
end

return export
