local export = {}

local m_conj = require("Module:fr-conj")
local m_links = require("Module:links")
local lang = require("Module:languages").getByCode("fr")
local IPA = function(str)
	return require("Module:IPA").format_IPA(nil,str)
end

local rmatch = mw.ustring.match
local rsubn = mw.ustring.gsub

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
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

	data.forms.ind_p_1s = add(stem,"e")
	data.forms.ind_p_2s = add(stem,"es")
	data.forms.ind_p_3s = add(stem,"e")
	data.forms.ind_p_3p = add(stem,"ent")
	data.forms.ind_p_1p = add(stem2,"ons")
	-- stem3 is used in -ger and -cer verbs
	data.forms.ind_p_2p = add(stem3,"ez")

	export.make_ind_i(data, stem2, stem3)
	export.make_ind_ps_a(data, stem2, stem3)
	export.make_sub_p(data, stem, stem3)
	export.make_imp_p_ind(data)
	export.make_ind_f(data, add(stem, "er"))
	data.forms.ppr = add(stem2,"ant")
end

function export.make_ind_p(data, stem, stem2, stem3)
	stem2 = stem2 or stem
	stem3 = stem3 or stem2
	data.forms.ind_p_1s = add(stem,"s")
	data.forms.ind_p_2s = add(stem,"s")
	-- add t unless stem ends in -t (e.g. met), -d (e.g. vend, assied) or
	-- -c (e.g. vainc).
	data.forms.ind_p_3s = map(stem, function(s)
		return add(s, rmatch(s, "[tdc]$") and "" or "t")
	end)
	data.forms.ind_p_1p = add(stem2,"ons")
	data.forms.ind_p_2p = add(stem2,"ez")
	data.forms.ind_p_3p = add(stem3,"ent")

	export.make_ind_i(data, stem2)
	export.make_sub_p(data, stem3, stem2)
	export.make_imp_p_ind(data)
	data.forms.ppr = add(stem2,"ant")
end

function export.make_ind_i(data, stem, stem2)
	stem2 = stem2 or stem
	data.forms.ind_i_1s = add(stem,"ais")
	data.forms.ind_i_2s = add(stem,"ais")
	data.forms.ind_i_3s = add(stem,"ait")
	data.forms.ind_i_1p = add(stem2,"ions")
	data.forms.ind_i_2p = add(stem2,"iez")
	data.forms.ind_i_3p = add(stem,"aient")
end

function export.make_ind_ps_a(data, stem, stem2)
	stem2 = stem2 or stem
	data.forms.ind_ps_1s = add(stem,"ai")
	data.forms.ind_ps_2s = add(stem,"as")
	data.forms.ind_ps_3s = add(stem,"a")
	data.forms.ind_ps_1p = add(stem,"âmes")
	data.forms.ind_ps_2p = add(stem,"âtes")
	data.forms.ind_ps_3p = add(stem2,"èrent")

	export.make_sub_pa(data,add(stem,"a"))

	data.forms.pp = data.forms.pp or add(stem2,"é")
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

	export.make_sub_pa(data,stem)

	data.forms.pp = data.forms.pp or stem
end

function export.make_ind_f(data, stem)
	data.forms.ind_f_1s = add(stem,"ai")
	data.forms.ind_f_2s = add(stem,"as")
	data.forms.ind_f_3s = add(stem,"a")
	data.forms.ind_f_1p = add(stem,"ons")
	data.forms.ind_f_2p = add(stem,"ez")
	data.forms.ind_f_3p = add(stem,"ont")

	export.make_cond_p(data, stem)
end

function export.make_cond_p(data, stem)
	data.forms.cond_p_1s = add(stem,"ais")
	data.forms.cond_p_2s = add(stem,"ais")
	data.forms.cond_p_3s = add(stem,"ait")
	data.forms.cond_p_1p = add(stem,"ions")
	data.forms.cond_p_2p = add(stem,"iez")
	data.forms.cond_p_3p = add(stem,"aient")
end

function export.make_sub_p(data, stem, stem2)
	stem2 = stem2 or stem
	data.forms.sub_p_1s = add(stem,"e")
	data.forms.sub_p_2s = add(stem,"es")
	data.forms.sub_p_3s = add(stem,"e")
	data.forms.sub_p_3p = add(stem,"ent")
	data.forms.sub_p_1p = add(stem2,"ions")
	data.forms.sub_p_2p = add(stem2,"iez")
end

function export.make_sub_pa(data, stem)
	data.forms.sub_pa_1s = add(stem,"sse")
	data.forms.sub_pa_2s = add(stem,"sses")
	data.forms.sub_pa_3s = map(add(stem,"^t"), fix_circumflex)
	data.forms.sub_pa_1p = add(stem,"ssions")
	data.forms.sub_pa_2p = add(stem,"ssiez")
	data.forms.sub_pa_3p = add(stem,"ssent")
end

function export.make_imp_p_ind(data)
	data.forms.imp_p_2s = map(data.forms.ind_p_2s, function(form)
		return rsub(form, "([ae])s$", "%1")
	end)
	data.forms.imp_p_1p = data.forms.ind_p_1p
	data.forms.imp_p_2p = data.forms.ind_p_2p
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
end

function export.clear_imp(data)
	data.forms.imp_p_2s = "—"
	data.forms.imp_p_1p = "—"
	data.forms.imp_p_2p = "—"
end

function export.y(data)
	data.y = true

	for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "y ", "y ", "i.j‿", "i "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "y ", "y ", "i.j‿", "i "
		elseif mw.ustring.match(key,"2s") then
                        if mw.ustring.match(val,"[s]$") then
			        pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "y ", "y ", "i.j‿", "i ", "-y", ".zi"
                        else
                  		pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "y ", "y ", "i.j‿", "i ", "s-y", ".zi"
                        end
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "y ", "y ", "i.j‿", "i "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "y ", "y ", "i.j‿", "i ", "-y", ".zi"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "y ", "y ", "i.j‿", "i ", "-y", ".zi"
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
					suf, suf_pron = "" .. imp, "" .. pron_imp
				end
			end
			if do_nolink then
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
end

function export.en(data)
	data.en = true

	    for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "en ", "en ", "ã.n‿", "ã "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "en ", "en ", "ã.n‿", "ã "
		elseif mw.ustring.match(key,"2s") then
                        if mw.ustring.match(val,"[s]$") then
			        pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "en ", "en ", "ã.n‿", "ã ", "-en", ".zã"
                        else
                  		pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "en ", "en ", "ã.n‿", "ã ", "s-en", ".zã"
                        end
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "en ", "en ", "ã.n‿", "ã "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "en ", "en ", "ã.n‿", "ã ", "-en", ".zã"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "en ", "en ", "ã.n‿", "ã ", "-en", ".zã"
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
					suf, suf_pron = "" .. imp, "" .. pron_imp
				end
			end
			if do_nolink then
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
end

function export.yen(data)
	data.yen = true

	    for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "y en ", "y en ", "i.j‿ã.n‿", "i.j‿ã "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "y en ", "y en ", "i.j‿ã.n‿", "i.j‿ã "
		elseif mw.ustring.match(key,"2s") then
                        if mw.ustring.match(val,"[s]$") then
			        pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "y en ", "y en ", "i.j‿ã.n‿", "i.j‿ã ", "-y-en", ".zi.jã"
                        else
                  		pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "y en ", "y en ", "i.j‿ã.n‿", "i.j‿ã ", "s-y en", ".zi.jã"
                        end
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "y en ", "y en ", "i.j‿ã.n‿", "i.j‿ã "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "y en ", "y en ", "i.j‿ã.n‿", "i.j‿ã ", "-y-en", ".zi.jã"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "y en ", "y en ", "i.j‿ã.n‿", "i.j‿ã ", "-y-en", ".zi.jã"
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
					suf, suf_pron = "" .. imp, "" .. pron_imp
				end
			end
			if do_nolink then
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
end

function export.le(data)
	data.le = true

	    for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "l'", "le ", "l", "lə "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "l'", "le ", "l", "lə "
		elseif mw.ustring.match(key,"2s") then
                        if mw.ustring.match(val,"[s]$") then
			        pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'", "le ", "l", "lə ", "-le", ".lə"
                        else
                  		pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'", "le ", "l", "lə ", "-le", ".lə"
                        end
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "l'", "le ", "l", "lə "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'", "le ", "l", "lə ", "-le", ".lə"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'", "le ''or'' la ", "l", "lə ", "-le", ".lə"
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
					suf, suf_pron = "" .. imp, "" .. pron_imp
				end
			end
			if do_nolink then
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
end

function export.la(data)
	data.la = true

	    for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "l'", "la ", "l", "la "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "l'", "la ", "l", "la "
		elseif mw.ustring.match(key,"2s") then
                        if mw.ustring.match(val,"[s]$") then
			        pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'", "la ", "l", "la ", "-la", ".la"
                        else
                  		pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'", "la ", "l", "la ", "-la", ".la"
                        end
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "l'", "la ", "l", "la "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'", "la ", "l", "la ", "-la", ".la"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'", "la ", "l", "la ", "-la", ".la"
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
					suf, suf_pron = "" .. imp, "" .. pron_imp
				end
			end
			if do_nolink then
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
end

function export.l(data)
	data.l = true

	    for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "l'", "l'", "l", "l"
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "l'", "l'", "l", "l"
		elseif mw.ustring.match(key,"2s") then
                        if mw.ustring.match(val,"[s]$") then
			        pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'", "l'", "l", "l", "-le ''or'' -la", ".lə ''or'' .la"
                        else
                  		pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'", "l'", "l", "l", "-le ''or'' -la", ".lə ''or'' .la"
                        end
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "l'", "l'", "l", "l"
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'", "l'", "l", "l", "-le ''or'' -la", ".lə ''or'' .la"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'", "l'", "l", "l", "-le ''or'' -la", ".lə ''or'' .la"
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
					suf, suf_pron = "" .. imp, "" .. pron_imp
				end
			end
			if do_nolink then
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
end

function export.les(data)
	data.les = true

	    for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "les ", "les ", "le.z‿", "le"
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "les ", "les ", "le.z‿", "le"
		elseif mw.ustring.match(key,"2s") then
                        if mw.ustring.match(val,"[s]$") then
			        pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les ", "les ", "le.z‿", "le", "-les", ".le"
                        else
                  		pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les ", "les ", "le.z‿", "le", "-les", ".le"
                        end
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "les ", "les ", "le.z‿", "le"
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les ", "les ", "le.z‿", "le", "-les", ".le"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les ", "les ", "le.z‿", "le", "-les", ".le"
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
					suf, suf_pron = "" .. imp, "" .. pron_imp
				end
			end
			if do_nolink then
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
end

function export.l_y(data)
	data.l_y = true

	    for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "l'y ", "l'y ", "li.j‿", "li "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "l'y ", "l'y ", "li.j‿", "li "
		elseif mw.ustring.match(key,"2s") then
                        if mw.ustring.match(val,"[s]$") then
			        pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'y ", "l'y ", "li.j‿", "li ", "-l'y", ".li"
                        else
                  		pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'y ", "l'y ", "li.j‿", "li ", "-l'y", ".li"
                        end
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "l'y ", "l'y ", "li.j‿", "li "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'y ", "l'y ", "li.j‿", "li ", "-l'y", ".li"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'y ", "l'y ", "li.j‿", "li ", "-l'y", ".li"
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
					suf, suf_pron = "" .. imp, "" .. pron_imp
				end
			end
			if do_nolink then
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
end

function export.l_en(data)
	data.l_en = true
		data.aux = "l'en avoir"

	    for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "l'en ", "l'en ", "lã.n‿", "lã "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "l'en ", "l'en ", "lã.n‿", "lã "
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'en ", "l'en ", "lã.n‿", "lã ", "l'en", "lã"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "l'en ", "l'en ", "lã.n‿", "lã "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'en ", "l'en ", "lã.n‿", "lã ", "l'en", "lã"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'en ", "l'en ", "lã.n‿", "lã ", "l'en", "lã"
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
end

function export.lesen(data)
	data.lesen = true
		data.aux = "les en avoir"

	    for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "les en ", "les en ", "le.z‿ã.n‿", "le.z‿ã "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "les en ", "les en ", "le.z‿ã.n‿", "le.z‿ã "
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les en ", "les en ", "le.z‿ã.n‿", "le.z‿ã ", "-les-en", "le.zã"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "les en ", "les en ", "le.z‿ã.n‿", "le.z‿ã "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les en ", "les en ", "le.z‿ã.n‿", "le.z‿ã ", "-les-en", "le.zã"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les en ", "les en ", "le.z‿ã.n‿", "le.z‿ã ", "-les-en", "le.zã"
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
end

function export.lesy(data)
	data.lesy = true

	    for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "les y ", "les y ", "le.z‿i.j‿", "le.z‿i "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "les y ", "les y ", "le.z‿i.j‿", "le.z‿i "
		elseif mw.ustring.match(key,"2s") then
                        if mw.ustring.match(val,"[s]$") then
			        pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les y ", "les y ", "le.z‿i.j‿", "le.z‿i ", "-les-y", ".le.zi"
                        else
                  		pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les y ", "les y ", "le.z‿i.j‿", "le.z‿i ", "-les-y", ".le.zi"
                        end
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "les y ", "les y ", "le.z‿i.j‿", "le.z‿i "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les y ", "les y ", "le.z‿i.j‿", "le.z‿i ", "-les-y", ".le.zi"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les y ", "les y ", "le.z‿i.j‿", "le.z‿i ", "-les-y", ".le.zi"
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
					suf, suf_pron = "" .. imp, "" .. pron_imp
				end
			end
			if do_nolink then
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
end

function export.l_yen(data)
	data.l_yen = true
		data.aux = "l'y en avoir"

	    for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "l'y en ", "l'y en ", "li.j‿ã.n‿", "li.j‿ã "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "l'y en ", "l'y en ", "li.j‿ã.n‿", "li.j‿ã "
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'y en ", "l'y en ", "li.j‿ã.n‿", "li.j‿ã ", "l'y-en", "li.jã"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "l'y en ", "l'y en ", "li.j‿ã.n‿", "li.j‿ã "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'y en ", "l'y en ", "li.j‿ã.n‿", "li.j‿ã ", "l'y-en", "li.jã"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "l'y en ", "l'y en ", "li.j‿ã.n‿", "li.j‿ã ", "l'y-en", "li.jã"
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
end

function export.lesyen(data)
	data.lesyen = true
		data.aux = "les y en avoir"

	    for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "les y en ", "les y en ", "le.z‿i.j‿ã.n‿", "le.z‿i.j‿ã "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "les y en ", "les y en ", "le.z‿i.j‿ã.n‿", "le.z‿i.j‿ã "
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les y en ", "les y en ", "le.z‿i.j‿ã.n‿", "le.z‿i.j‿ã ", "-les-y-en", "le.zi.jã"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "les y en ", "les y en ", "le.z‿i.j‿ã.n‿", "le.z‿i.j‿ã "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les y en ", "les y en ", "le.z‿i.j‿ã.n‿", "le.z‿i.j‿ã ", "-les-y-en", "le.zi.jã"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "les y en ", "les y en ", "le.z‿i.j‿ã.n‿", "le.z‿i.j‿ã ", "-les-y-en", "le.zi.jã"
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
end

function export.refl(data)
	data.refl = true
        data.aux = "s'être"

	    for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "s'", "se ", "s", "sə "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "m'", "me ", "m", "mə "
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "t'", "te ", "t", "tə ", "toi", "twa"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "s'", "se ", "s", "sə "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "nous ", "nous ", "nu.z‿", "nu ", "nous", "nu"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "vous ", "vous ", "vu.z‿", "vu ", "vous", "vu"
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
end

function export.reflen(data)
	data.reflen = true
        data.aux = "s'en être"

        for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "s'en ", "s'en ", "sã.n‿", "sã "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "m'en ", "m'en ", "mã.n‿", "mã "
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "t'en ", "t'en ", "tã.n‿", "tã ", "t'en", "tã"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "s'en ", "s'en ", "sã.n‿", "sã "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "nous en ", "nous en ", "nu.z‿ã.n‿", "nu.z‿ã ", "nous-en", "nu.zã"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "vous en ", "vous en ", "vu.z‿ã.n‿", "vu.z‿ã ", "vous-en", "vu.zã"
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
end

function export.refly(data)
	data.refly = true
        data.aux = "s'y être"

        for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "s'y ", "s'y ", "si.j‿", "si "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "m'y ", "m'y ", "mi.j‿", "mi "
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "t'y ", "t'y ", "ti.j‿", "ti ", "t'y", "ti"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "s'y ", "s'y ", "si.j‿", "si "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "nous y ", "nous y ", "nu.z‿i.j‿", "nu.z‿i ", "nous-y", "nu.zi"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "vous y ", "vous y ", "vu.z‿i.j‿", "vu.z‿i ", "vous-y", "vu.zi"
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
end

function export.reflyen(data)
	data.reflyen = true
        data.aux = "s'y en être"

        for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "s'y en ", "s'y en ", "si.j‿ã.n‿", "si.j‿ã "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "m'y en ", "m'y en ", "mi.j‿ã.n‿", "mi.j‿ã "
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "t'y en ", "t'y en ", "ti.j‿ã.n‿", "ti.j‿ã ", "t'y-en", "ti.jã"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "s'y en ", "s'y en ", "si.j‿ã.n‿", "si.j‿ã "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "nous y en ", "nous y en ", "nu.z‿i.j‿ã.n‿", "nu.z‿i.j‿ã ", "nous-y-en", "nu.zi.jã"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "vous y en ", "vous y en ", "vu.z‿i.j‿ã.n‿", "vu.z‿i.j‿ã ", "vous-y-en", "vu.zi.jã"
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
end

function export.reflle(data)
	data.reflle = true
        data.aux = "se l'être"

        for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "se l'", "se le ", "sə l", "sə lə "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "me l'", "me le ", "mə l", "mə lə "
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "te l'", "te le ", "tə l", "tə lə ", "le-toi", "lə.twa"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "se l'", "se le ", "sə l", "sə lə "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "nous l'", "nous le ", "nu l", "nu lə ", "le-nous", "lə.nu"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "vous l'", "vous le ", "vu l", "vu lə ", "le-vous", "lə.vu"
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
end

function export.refll(data)
	data.refll = true
        data.aux = "se l'être"

        for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "se l'", "se l'", "sə l", "sə l"
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "me l'", "me l'", "mə l", "mə l"
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "te l'", "te l'", "tə l", "tə l", "le-toi ''or'' -la-toi", "lə.twa ''or'' .la.twa"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "se l'", "se l'", "sə l", "sə l"
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "nous l'", "nous l'", "nu l", "nu l", "le-nous ''or'' -la-nous", "lə.nu ''or'' .la.nu"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "vous l'", "vous l'", "vu l", "vu l", "le-vous ''or'' -la-vous", "lə.vu ''or'' .la.vu"
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
end

function export.reflla(data)
	data.reflla = true
        data.aux = "se l'être"

        for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "se l'", "se la ", "sə l", "sə la "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "me l'", "me la ", "mə l", "mə la "
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "te l'", "te la ", "tə l", "tə la ", "la-toi", "la.twa"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "se l'", "se la ", "sə l", "sə la "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "nous l'", "nous la ", "nu l", "nu la ", "la-nous", "la.nu"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "vous l'", "vous la ", "vu l", "vu la ", "la-vous", "la.vu"
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
end

function export.reflles(data)
	data.reflles = true
        data.aux = "se les être"

        for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "se les ", "se les ", "sə le.z‿", "sə le "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "me les ", "me les ", "mə le.z‿", "mə le "
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "te les ", "te les ", "tə le.z‿", "tə le ", "les-toi", "le.twa"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "se les ", "se les ", "sə le.z‿", "sə le "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "nous les ", "nous les ", "nu le.z‿", "nu le ", "les-nous", "le.nu"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "vous les ", "vous les ", "vu le.z‿", "vu le ", "les-vous", "le.vu"
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
end

function export.reflly(data)
	data.reflly = true
        data.aux = "se l'y être"

        for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "se l'y ", "se l'y ", "sə li.j‿", "sə li "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "me l'y ", "me l'y ", "mə li.j‿", "mə li "
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "te l'y ", "te l'y ", "tə li.j‿", "tə li ", "le-t'y <i>or</i> -la-t'y", "lə.ti <i>or</i> .la.ti"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "se l'y ", "se l'y ", "sə li.j‿", "sə li "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "nous l'y ", "nous l'y ", "nu li.j‿", "nu li ", "le-nous-y <i>or</i> -la-nous-y", "lə.nu.zi <i>or</i> .la.nu.zi"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "vous l'y ", "vous l'y ", "vu li.j‿", "vu li ", "le-vous-y <i>or</i> -la-vous-y", "lə.vu.zi <i>or</i> .la.vu.zi"
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
end

function export.refllesy(data)
	data.refllesy = true
        data.aux = "se les y être"

        for key,val in pairs(data.forms) do
		local pref_v, pref_c, pron_v, pron_c, imp, pron_imp, do_nolink
		if key == "inf" or key == "ppr" then
			pref_v, pref_c, pron_v, pron_c = "se les y ", "se les y ", "sə le.z‿i.j‿", "sə le.z‿i "
			do_nolink = true
		elseif mw.ustring.match(key,"1s") then
			pref_v, pref_c, pron_v, pron_c = "me les y ", "me les y ", "mə le.z‿i.j‿", "mə le.z‿i "
		elseif mw.ustring.match(key,"2s") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "te les y ", "te les y ", "tə le.z‿i.j‿", "tə le.z‿i ", "les-t'y", "le.ti"
		elseif mw.ustring.match(key,"3[sp]") then
			pref_v, pref_c, pron_v, pron_c = "se les y ", "se les y ", "sə le.z‿i.j‿", "sə le.z‿i "
		elseif mw.ustring.match(key,"1p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "nous les y ", "nous les y ", "nu le.z‿i.j‿", "nu le.z‿i ", "les-nous-y", "le.nu.zi"
		elseif mw.ustring.match(key,"2p") then
			pref_v, pref_c, pron_v, pron_c, imp, pron_imp = "vous les y ", "vous les y ", "vu le.z‿i.j‿", "vu le.z‿i ", "les-vous-y", "le.vu.zi"
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
end

-- not sure if it's still used by something so I'm leaving a stub function instead of removing it entirely
function export.make_table(data)
	return m_conj.make_table(data)
end

function export.extract(data, args)
	if args.inf then
		data.forms.inf = args.inf
		export.make_ind_f(data, rsub(args.inf,"e$",""))
		export.make_cond_p(data, rsub(args.inf,"e$",""))
	end
	if args.pp then
		data.forms.pp = args.pp
		if mw.ustring.match(args.pp, "[iu]$") then
			export.make_ind_ps(data, args.pp)
			export.make_sub_pa(data, args.pp)
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
					export.make_ind_p_e(data, stem, stem2, stem3)
				else
					export.make_ind_p(data, stem, stem2, stem3)
				end
				for _,person in ipairs({"1s","2s","3s","1p","2p","3p"}) do
					data.forms[form .. "_" .. person] = args[dot_form .. "." .. person] or data.forms[form .. "_" .. person]
				end
				export.make_imp_p_ind(data)
			elseif form == "ind_i" then
				export.make_ind_i(data, args[dot_form])
			elseif form == "ind_ps" then
				if mw.ustring.match(args["ind.ps"], "a$") then
					local stem = rsub(args[dot_form],"a$","")
					export.make_ind_ps_a(data, stem)
				else
					export.make_ind_ps(data, args[dot_form])
				end
				export.make_sub_pa(data, args[dot_form])
			elseif form == "ind_f" then
				export.make_ind_f(data, args[dot_form])
			elseif form == "cond_p" then
				export.make_cond_p(data, args[dot_form])
			elseif form == "sub_p" then
				local stem = args[dot_form]
				local stem2 = stem
				if mw.ustring.match(stem, "^[^/]+/[^/]+$") then
					stem = rsub(stem, "^([^/]+)/([^/]+)$", "%1")
					stem2 = rsub(stem2, "^([^/]+)/([^/]+)$", "%2")
				end
				export.make_sub_p(data, stem, stem2)
			elseif form == "sub_pa" then
				export.make_sub_pa(data, args[dot_form])
			elseif form == "imp_p" then
				if args[dot_form] == "sub" then
					export.make_imp_p_sub(data)
				elseif args[dot_form] == "ind_sub" then
					export.make_imp_p_ind_sub(data)
				else
					export.make_imp_p_ind(data)
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
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
