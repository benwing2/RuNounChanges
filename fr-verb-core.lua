local export = {}

local m_conj = require("Module:fr-conj")
local m_links = require("Module:links")
local lang = require("Module:languages").getByCode("fr")
local IPA = function(str)
	return require("Module:IPA").format_IPA(nil,str)
end

local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

local function add(source,appendix)
	if type(source) == "table" then
		local ret = {}
		for _, stem in ipairs(source) do
			local stemret = add(stem, appendix)
			if type(stemret) == "table" then
				for _, sr in ipairs(stemret) do
					table.insert(ret, sr)
				end
			else
				table.insert(ret, stemret)
			end
		end
		return ret
	end
	if mw.ustring.match(source,"/") then
		source = mw.text.split(source,"/",plain)
		for i,val in ipairs(source) do
			source[i] = val..appendix
		end
		return source
	else
		return source..appendix
	end
end

local function map(seq, fun)
	if type(seq) == "table" then
		local ret = {}
		for _, s in ipairs(seq) do
			table.insert(ret, fun(s))
		end
		return ret
	else
		return fun(seq)
	end
end

function export.make_ind_p_e(data, stem, stem2, stem3)
	stem2 = stem2 or stem
	stem3 = stem3 or stem

	data.forms.ind_p_1s = add(stem,"e")
	data.forms.ind_p_2s = add(stem,"es")
	data.forms.ind_p_3s = add(stem,"e")
	data.forms.ind_p_3p = add(stem,"ent")
	data.forms.ind_p_1p = add(stem2,"ons")
	-- stem3 is used in -ger and -cer verbs
	data.forms.ind_p_2p = add(stem3,"ez")

	data = export.make_ind_i(data, stem2, stem3)
	data = export.make_ind_ps_a(data, stem2, stem3)
	data = export.make_sub_p(data, stem, stem3)
	data = export.make_imp_p_ind(data)
	data = export.make_ind_f(data, add(stem, "er"))
	data.forms.ppr = add(stem2,"ant")

	return data
end

function export.make_ind_p(data, stem, stem2, stem3)
	stem2 = stem2 or stem
	stem3 = stem3 or stem2
	data.forms.ind_p_1s = add(stem,"s")
	data.forms.ind_p_2s = add(stem,"s")
	data.forms.ind_p_3s = add(stem,"t")
	data.forms.ind_p_1p = add(stem2,"ons")
	data.forms.ind_p_2p = add(stem2,"ez")
	data.forms.ind_p_3p = add(stem3,"ent")

	data = export.make_ind_i(data, stem2)
	data = export.make_sub_p(data, stem3, stem2)
	data = export.make_imp_p_ind(data)
	data.forms.ppr = add(stem2,"ant")

	return data
end

function export.make_ind_i(data, stem, stem2)
	stem2 = stem2 or stem
	data.forms.ind_i_1s = add(stem,"ais")
	data.forms.ind_i_2s = add(stem,"ais")
	data.forms.ind_i_3s = add(stem,"ait")
	data.forms.ind_i_1p = add(stem2,"ions")
	data.forms.ind_i_2p = add(stem2,"iez")
	data.forms.ind_i_3p = add(stem,"aient")

	return data
end

function export.make_ind_ps_a(data, stem, stem2)
	stem2 = stem2 or stem
	data.forms.ind_ps_1s = add(stem,"ai")
	data.forms.ind_ps_2s = add(stem,"as")
	data.forms.ind_ps_3s = add(stem,"a")
	data.forms.ind_ps_1p = add(stem,"âmes")
	data.forms.ind_ps_2p = add(stem,"âtes")
	data.forms.ind_ps_3p = add(stem2,"èrent")

	data = export.make_sub_pa(data,add(stem,"a"))

	data.forms.pp = data.forms.pp or add(stem2,"é")

	return data
end

local function fix_circumflex(val)
	return rsub(val, "[aiïu]n?%^",{["a^"]="â", ["i^"]="î", ["ï^"]="ï", ["in^"]="în", ["u^"]="û"})
end

function export.make_ind_ps(data, stem)
	data.forms.ind_ps_1s = add(stem,"s")
	data.forms.ind_ps_2s = add(stem,"s")
	data.forms.ind_ps_3s = add(stem,"t")
	data.forms.ind_ps_1p = map(add(stem,"^mes"), fix_circumflex)
	data.forms.ind_ps_2p = map(add(stem,"^tes"), fix_circumflex)
	data.forms.ind_ps_3p = add(stem,"rent")

	data = export.make_sub_pa(data,stem)

	data.forms.pp = data.forms.pp or stem

	return data
end

function export.make_ind_f(data, stem)
	data.forms.ind_f_1s = add(stem,"ai")
	data.forms.ind_f_2s = add(stem,"as")
	data.forms.ind_f_3s = add(stem,"a")
	data.forms.ind_f_1p = add(stem,"ons")
	data.forms.ind_f_2p = add(stem,"ez")
	data.forms.ind_f_3p = add(stem,"ont")

	data = export.make_cond_p(data, stem)

	return data
end

function export.make_cond_p(data, stem)
	data.forms.cond_p_1s = add(stem,"ais")
	data.forms.cond_p_2s = add(stem,"ais")
	data.forms.cond_p_3s = add(stem,"ait")
	data.forms.cond_p_1p = add(stem,"ions")
	data.forms.cond_p_2p = add(stem,"iez")
	data.forms.cond_p_3p = add(stem,"aient")

	return data
end

function export.make_sub_p(data, stem, stem2)
	stem2 = stem2 or stem
	data.forms.sub_p_1s = add(stem,"e")
	data.forms.sub_p_2s = add(stem,"es")
	data.forms.sub_p_3s = add(stem,"e")
	data.forms.sub_p_3p = add(stem,"ent")
	data.forms.sub_p_1p = add(stem2,"ions")
	data.forms.sub_p_2p = add(stem2,"iez")

	return data
end

function export.make_sub_pa(data, stem)
	data.forms.sub_pa_1s = add(stem,"sse")
	data.forms.sub_pa_2s = add(stem,"sses")
	data.forms.sub_pa_3s = map(add(stem,"^t"), fix_circumflex)
	data.forms.sub_pa_1p = add(stem,"ssions")
	data.forms.sub_pa_2p = add(stem,"ssiez")
	data.forms.sub_pa_3p = add(stem,"ssent")

	return data
end

function export.make_imp_p_ind(data)
	data.forms.imp_p_2s = map(data.forms.ind_p_2s, function(form)
		return rsub(form, "([ae])s$", "%1")
	end)
	data.forms.imp_p_1p = data.forms.ind_p_1p
	data.forms.imp_p_2p = data.forms.ind_p_2p

	return data
end

function export.make_imp_p_ind_sub(data)
	data.forms.imp_p_2s = map(data.forms.ind_p_2s, function(form)
		return rsub(form, "([ae])s$", "%1")
	end)
	data.forms.imp_p_1p = map(data.forms.sub_p_1p, function(form)
		return rsub(form, "ions$", "ons")
	end)
	data.forms.imp_p_2p = map(data.forms.sub_p_2p, function(form)
		return rsub(form, "iez$", "ez")
	end)

	return data
end

function export.make_imp_p_sub(data)
	data.forms.imp_p_2s = map(data.forms.sub_p_2s, function(form)
		return rsub(form, "es$", "e")
	end)
	data.forms.imp_p_1p = map(data.forms.sub_p_1p, function(form)
		return rsub(form, "ions$", "ons")
	end)
	data.forms.imp_p_2p = map(data.forms.sub_p_2p, function(form)
		return rsub(form, "iez$", "ez")
	end)

	return data
end

function export.refl(data)
	data.refl = true
	data.aux = "s'être"

	for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "s'", "se ", "s", "sə."
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "m'", "me ", "m", "mə."
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "t'", "te ", "t", "tə.", "toi", "twa"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "s'", "se ", "s", "sə."
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "nous ", "nous ", "nu.z", "nu.", "nous", "nu"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "vous ", "vous ", "vu.z", "vu.", "vous", "vu"
		end
		if pref_v then
			local pref, suf, pref_pron, suf_pron
			local function get_pref_suf(v)
				pref, suf, pref_pron, suf_pron = "", "", "", ""
				if not mw.ustring.match(key,"imp") then
					if mw.ustring.match(v,"^[aeéêiouhywjɑɛœø]") then
						pref, pref_pron = pref_v, pron_v
					else
						pref, pref_pron = pref_c, pron_c
					end
				else
					suf, suf_pron = "-" .. imp, "." .. pron_imp
				end
			end
			if do_nolink then
				get_pref_suf(data.forms[key])
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
	end

	return data
end

function export.link(data)
	for key,val in pairs(data.forms) do
		if type(val) ~= "table" then
			val = {val}
		end
		-- don't destructively modify data.forms[key][i] because it might
		-- be shared among different keys
		local newval = {}
		for i,form in ipairs(val) do
			local newform = form
			if not mw.ustring.match(key,"nolink") and not mw.ustring.match(form,"—") then
				newform = m_links.full_link({term = form, lang = lang})
			end
			if mw.ustring.match(form, "—") then
				newform = "—"
			end
			table.insert(newval, newform)
		end
		data.forms[key] = table.concat(newval, " or ")
	end
	for key,val in pairs(data.prons) do
		if not mw.ustring.match(key,"nolink") then
			if type(val) ~= "table" then
				val = {val}
			end
			-- don't destructively modify data.forms[key][i] because it might
			-- be shared among different keys
			local newprons = {}
			for i,form in ipairs(val) do
				if not mw.ustring.match(form,"—") then
					table.insert(newprons, IPA('/' .. form .. '/'))
				end
			end
			if #newprons > 0 and data.forms[key] ~= "—" then
				data.forms[key] = data.forms[key] .. '<br /><span style="color:#7F7F7F">' .. table.concat(newprons, " or ") .. '</span>'
			end
		end
	end

	return data
end

-- not sure if it's still used by something so I'm leaving a stub function instead of removing it entirely
function export.make_table(data)
	return m_conj.make_table(data)
end

function export.extract(data, args)
	if args.inf then
		data.forms.inf = args.inf
		data = export.make_ind_f(data, rsub(args.inf,"e$",""))
		data = export.make_cond_p(data, rsub(args.inf,"e$",""))
	end
	if args.pp then
		data.forms.pp = args.pp
		if mw.ustring.match(args.pp, "[iu]$") then
			data = export.make_ind_ps(data, args.pp)
			data = export.make_sub_pa(data, args.pp)
		end
	end
	for _,form in ipairs({"ind_p","ind_i","ind_ps","ind_f","cond_p","sub_p","sub_pa","imp_p"}) do
		local dot_form = rsub(form,"_",".")
		if args[dot_form] then
			if form == "ind_p" then
				local stem = args[dot_form]
				local stem2 = stem
				local stem3 = stem
				if mw.ustring.match(stem, "^[^/]+/[^/]+/[^/]+$") then
					stem = rsub(stem, "^([^/]+)/([^/]+)/([^/]+)$", "%1")
					stem2 = rsub(stem2, "^([^/]+)/([^/]+)/([^/]+)$", "%2")
					stem3 = rsub(stem3, "^([^/]+)/([^/]+)/([^/]+)$", "%3")
				elseif mw.ustring.match(stem, "^[^/]+/[^/]+$") then
					stem = rsub(stem, "^([^/]+)/([^/]+)$", "%1")
					stem2 = rsub(stem2, "^([^/]+)/([^/]+)$", "%2")
					stem3 = stem2
				end
				if args["ind.p_e"] then
					data = export.make_ind_p_e(data, stem, stem2, stem3)
				else
					data = export.make_ind_p(data, stem, stem2, stem3)
				end
				for _,person in ipairs({"1s","2s","3s","1p","2p","3p"}) do
					data.forms[form .. "_" .. person] = args[dot_form .. "." .. person] or data.forms[form .. "_" .. person]
				end
				data = export.make_imp_p_ind(data)
			elseif form == "ind_i" then
				data = export.make_ind_i(data, args[dot_form])
			elseif form == "ind_ps" then
				if mw.ustring.match(args["ind.ps"], "a$") then
					local stem = rsub(args[dot_form],"a$","")
					data = export.make_ind_ps_a(data, stem)
				else
					data = export.make_ind_ps(data, args[dot_form])
				end
				data = export.make_sub_pa(data, args[dot_form])
			elseif form == "ind_f" then
				data = export.make_ind_f(data, args[dot_form])
			elseif form == "cond_p" then
				data = export.make_cond_p(data, args[dot_form])
			elseif form == "sub_p" then
				local stem = args[dot_form]
				local stem2 = stem
				if mw.ustring.match(stem, "^[^/]+/[^/]+$") then
					stem = rsub(stem, "^([^/]+)/([^/]+)$", "%1")
					stem2 = rsub(stem2, "^([^/]+)/([^/]+)$", "%2")
				end
				data = export.make_sub_p(data, stem, stem2)
			elseif form == "sub_pa" then
				data = export.make_sub_pa(data, args[dot_form])
			elseif form == "imp_p" then
				if args[dot_form] == "sub" then
					data = export.make_imp_p_sub(data)
				elseif args[dot_form] == "ind_sub" then
					data = export.make_imp_p_ind_sub(data)
				else
					data = export.make_imp_p_ind(data)
				end
			end
		end
		for _,person in ipairs({"1s","2s","3s","1p","2p","3p"}) do
			data.forms[form .. "_" .. person] = args[dot_form .. "." .. person] or data.forms[form .. "_" .. person]
		end
	end

	data.forms.ppr = args.ppr or data.forms.ppr
	if not data.forms.ppr then
		if data.forms.ind_p_1p then
			data.forms.ppr = map(data.forms.ind_p_1p, function(val)
				return rsub(val, "ons$", "ant")
			end)
		else
			data.forms.ppr = ""
		end
	end
	data.forms.pp = args.pp or data.forms.pp

	return data
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
