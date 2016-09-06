local export = {}
local m_links = require("Module:links")

local lang = require("Module:languages").getByCode("fr")

--entry point
function export.frconj(frame)
	--are we directly embedding through Template:fr-conj or calling the module? 
	local args = {}
	if frame.args["direct"] == "yes" then
		args = frame:getParent().args
	else
		args = frame.args
	end
	
	--create the forms
	local data = {forms = {}, categories = {}, refl = false, aux = ""}
	data.aux = args["aux"]
	if not (data.aux == "avoir" or data.aux == "être") then
		data.aux = "avoir ''or'' être"
	end
	
	if (args["inf"] == nil or args["inf"] == "" or args["inf"] == mw.title.getCurrentTitle().text) then
		data.forms.inf_nolink = mw.title.getCurrentTitle().text
	else
		data.forms.inf_nolink = format_links(args["inf"])
	end
	data.forms.pp = format_links(args["pp"])
	data.forms.ppr = format_links(args["ppr"])
	if data.forms.pp == "—" then
		data.forms.pp_nolink = "—"
	else
		data.forms.pp_nolink = args["pp"]
	end
	if data.forms.ppr == "—" then
		data.forms.ppr_nolink = "—"
	else
		data.forms.ppr_nolink = args["ppr"]
	end
	data.forms.ind_p_1s = format_links(args["ind.p.1s"])
	data.forms.ind_p_2s = format_links(args["ind.p.2s"])
	data.forms.ind_p_3s = format_links(args["ind.p.3s"])
	data.forms.ind_p_1p = format_links(args["ind.p.1p"])
	data.forms.ind_p_2p = format_links(args["ind.p.2p"])
	data.forms.ind_p_3p = format_links(args["ind.p.3p"])
	data.forms.ind_i_1s = format_links(args["ind.i.1s"])
	data.forms.ind_i_2s = format_links(args["ind.i.2s"])
	data.forms.ind_i_3s = format_links(args["ind.i.3s"])
	data.forms.ind_i_1p = format_links(args["ind.i.1p"])
	data.forms.ind_i_2p = format_links(args["ind.i.2p"])
	data.forms.ind_i_3p = format_links(args["ind.i.3p"])
	data.forms.ind_ps_1s = format_links(args["ind.ps.1s"])
	data.forms.ind_ps_2s = format_links(args["ind.ps.2s"])
	data.forms.ind_ps_3s = format_links(args["ind.ps.3s"])
	data.forms.ind_ps_1p = format_links(args["ind.ps.1p"])
	data.forms.ind_ps_2p = format_links(args["ind.ps.2p"])
	data.forms.ind_ps_3p = format_links(args["ind.ps.3p"])
	data.forms.ind_f_1s = format_links(args["ind.f.1s"])
	data.forms.ind_f_2s = format_links(args["ind.f.2s"])
	data.forms.ind_f_3s = format_links(args["ind.f.3s"])
	data.forms.ind_f_1p = format_links(args["ind.f.1p"])
	data.forms.ind_f_2p = format_links(args["ind.f.2p"])
	data.forms.ind_f_3p = format_links(args["ind.f.3p"])
	data.forms.cond_p_1s = format_links(args["cond.p.1s"])
	data.forms.cond_p_2s = format_links(args["cond.p.2s"])
	data.forms.cond_p_3s = format_links(args["cond.p.3s"])
	data.forms.cond_p_1p = format_links(args["cond.p.1p"])
	data.forms.cond_p_2p = format_links(args["cond.p.2p"])
	data.forms.cond_p_3p = format_links(args["cond.p.3p"])
	data.forms.sub_p_1s = format_links(args["sub.p.1s"])
	data.forms.sub_p_2s = format_links(args["sub.p.2s"])
	data.forms.sub_p_3s = format_links(args["sub.p.3s"])
	data.forms.sub_p_1p = format_links(args["sub.p.1p"])
	data.forms.sub_p_2p = format_links(args["sub.p.2p"])
	data.forms.sub_p_3p = format_links(args["sub.p.3p"])	
	data.forms.sub_pa_1s = format_links(args["sub.pa.1s"])
	data.forms.sub_pa_2s = format_links(args["sub.pa.2s"])
	data.forms.sub_pa_3s = format_links(args["sub.pa.3s"])
	data.forms.sub_pa_1p = format_links(args["sub.pa.1p"])
	data.forms.sub_pa_2p = format_links(args["sub.pa.2p"])
	data.forms.sub_pa_3p = format_links(args["sub.pa.3p"])
	data.forms.imp_p_2s =  format_links(args["imp.p.2s"])
	data.forms.imp_p_1p = format_links(args["imp.p.1p"])
	data.forms.imp_p_2p = format_links(args["imp.p.2p"])
	
	
	
	-- add alt forms
	
	
	
	if not (args["ind.p.1s.alt"] == nil or args["ind.p.1s.alt"] == "" or args["ind.p.1s.alt"] == "—") then
		data.forms.ind_p_1s = data.forms.ind_p_1s .. " or " .. format_links(args["ind.p.1s.alt"])
	end
	if not (args["ind.p.2s.alt"] == nil or args["ind.p.2s.alt"] == "" or args["ind.p.2s.alt"] == "—") then
		data.forms.ind_p_2s = data.forms.ind_p_2s .. " or " .. format_links(args["ind.p.2s.alt"])
	end
	if not (args["ind.p.3s.alt"] == nil or args["ind.p.3s.alt"] == "" or args["ind.p.3s.alt"] == "—") then
		data.forms.ind_p_3s = data.forms.ind_p_3s .. " or " .. format_links(args["ind.p.3s.alt"])
	end
	if not (args["ind.p.1p.alt"] == nil or args["ind.p.1p.alt"] == "" or args["ind.p.1p.alt"] == "—") then
		data.forms.ind_p_1p = data.forms.ind_p_1p .. " or " .. format_links(args["ind.p.1p.alt"])
	end
	if not (args["ind.p.2p.alt"] == nil or args["ind.p.2p.alt"] == "" or args["ind.p.2p.alt"] == "—") then
		data.forms.ind_p_2p = data.forms.ind_p_2p .. " or " .. format_links(args["ind.p.2p.alt"])
	end
	if not (args["ind.p.3p.alt"] == nil or args["ind.p.3p.alt"] == "" or args["ind.p.3p.alt"] == "—") then
		data.forms.ind_p_3p = data.forms.ind_p_3p .. " or " .. format_links(args["ind.p.3p.alt"])
	end
	if not (args["ind.i.1s.alt"] == nil or args["ind.i.1s.alt"] == "" or args["ind.i.1s.alt"] == "—") then
		data.forms.ind_i_1s = data.forms.ind_i_1s .. " or " .. format_links(args["ind.i.1s.alt"])
	end
	if not (args["ind.i.2s.alt"] == nil or args["ind.i.2s.alt"] == "" or args["ind.i.2s.alt"] == "—") then
		data.forms.ind_i_2s = data.forms.ind_i_2s .. " or " .. format_links(args["ind.i.2s.alt"])
	end
	if not (args["ind.i.3s.alt"] == nil or args["ind.i.3s.alt"] == "" or args["ind.i.3s.alt"] == "—") then
		data.forms.ind_i_3s = data.forms.ind_i_3s .. " or " .. format_links(args["ind.i.3s.alt"])
	end
	if not (args["ind.i.1p.alt"] == nil or args["ind.i.1p.alt"] == "" or args["ind.i.1p.alt"] == "—") then
		data.forms.ind_i_1p = data.forms.ind_i_1p .. " or " .. format_links(args["ind.i.1p.alt"])
	end
	if not (args["ind.i.2p.alt"] == nil or args["ind.i.2p.alt"] == "" or args["ind.i.2p.alt"] == "—") then
		data.forms.ind_i_2p = data.forms.ind_i_2p .. " or " .. format_links(args["ind.i.2p.alt"])
	end
	if not (args["ind.i.3p.alt"] == nil or args["ind.i.3p.alt"] == "" or args["ind.i.3p.alt"] == "—") then
		data.forms.ind_i_3p = data.forms.ind_i_3p .. " or " .. format_links(args["ind.i.3p.alt"])
	end
	if not (args["ind.ps.1s.alt"] == nil or args["ind.ps.1s.alt"] == "" or args["ind.ps.1s.alt"] == "—") then
		data.forms.ind_ps_1s = data.forms.ind_ps_1s .. " or " .. format_links(args["ind.ps.1s.alt"])
	end
	if not (args["ind.ps.2s.alt"] == nil or args["ind.ps.2s.alt"] == "" or args["ind.ps.2s.alt"] == "—") then
		data.forms.ind_ps_2s = data.forms.ind_ps_2s .. " or " .. format_links(args["ind.ps.2s.alt"])
	end
	if not (args["ind.ps.3s.alt"] == nil or args["ind.ps.3s.alt"] == "" or args["ind.ps.3s.alt"] == "—") then
		data.forms.ind_ps_3s = data.forms.ind_ps_3s .. " or " .. format_links(args["ind.ps.3s.alt"])
	end
	if not (args["ind.ps.1p.alt"] == nil or args["ind.ps.1p.alt"] == "" or args["ind.ps.1p.alt"] == "—") then
		data.forms.ind_ps_1p = data.forms.ind_ps_1p .. " or " .. format_links(args["ind.ps.1p.alt"])
	end
	if not (args["ind.ps.2p.alt"] == nil or args["ind.ps.2p.alt"] == "" or args["ind.ps.2p.alt"] == "—") then
		data.forms.ind_ps_2p = data.forms.ind_ps_2p .. " or " .. format_links(args["ind.ps.2p.alt"])
	end
	if not (args["ind.ps.3p.alt"] == nil or args["ind.ps.3p.alt"] == "" or args["ind.ps.3p.alt"] == "—") then
		data.forms.ind_ps_3p = data.forms.ind_ps_3p .. " or " .. format_links(args["ind.ps.3p.alt"])
	end
	if not (args["ind.f.1s.alt"] == nil or args["ind.f.1s.alt"] == "" or args["ind.f.1s.alt"] == "—") then
		data.forms.ind_f_1s = data.forms.ind_f_1s .. " or " .. format_links(args["ind.f.1s.alt"])
	end
	if not (args["ind.f.2s.alt"] == nil or args["ind.f.2s.alt"] == "" or args["ind.f.2s.alt"] == "—") then
		data.forms.ind_f_2s = data.forms.ind_f_2s .. " or " .. format_links(args["ind.f.2s.alt"])
	end
	if not (args["ind.f.3s.alt"] == nil or args["ind.f.3s.alt"] == "" or args["ind.f.3s.alt"] == "—") then
		data.forms.ind_f_3s = data.forms.ind_f_3s .. " or " .. format_links(args["ind.f.3s.alt"])
	end
	if not (args["ind.f.1p.alt"] == nil or args["ind.f.1p.alt"] == "" or args["ind.f.1p.alt"] == "—") then
		data.forms.ind_f_1p = data.forms.ind_f_1p .. " or " .. format_links(args["ind.f.1p.alt"])
	end
	if not (args["ind.f.2p.alt"] == nil or args["ind.f.2p.alt"] == "" or args["ind.f.2p.alt"] == "—") then
		data.forms.ind_f_2p = data.forms.ind_f_2p .. " or " .. format_links(args["ind.f.2p.alt"])
	end
	if not (args["ind.f.3p.alt"] == nil or args["ind.f.3p.alt"] == "" or args["ind.f.3p.alt"] == "—") then
		data.forms.ind_f_3p = data.forms.ind_f_3p .. " or " .. format_links(args["ind.f.3p.alt"])
	end
	if not (args["cond.p.1s.alt"] == nil or args["cond.p.1s.alt"] == "" or args["cond.p.1s.alt"] == "—") then
		data.forms.cond_p_1s = data.forms.cond_p_1s .. " or " .. format_links(args["cond.p.1s.alt"])
	end
	if not (args["cond.p.2s.alt"] == nil or args["cond.p.2s.alt"] == "" or args["cond.p.2s.alt"] == "—") then
		data.forms.cond_p_2s = data.forms.cond_p_2s .. " or " .. format_links(args["cond.p.2s.alt"])
	end
	if not (args["cond.p.3s.alt"] == nil or args["cond.p.3s.alt"] == "" or args["cond.p.3s.alt"] == "—") then
		data.forms.cond_p_3s = data.forms.cond_p_3s .. " or " .. format_links(args["cond.p.3s.alt"])
	end
	if not (args["cond.p.1p.alt"] == nil or args["cond.p.1p.alt"] == "" or args["cond.p.1p.alt"] == "—") then
		data.forms.cond_p_1p = data.forms.cond_p_1p .. " or " .. format_links(args["cond.p.1p.alt"])
	end
	if not (args["cond.p.2p.alt"] == nil or args["cond.p.2p.alt"] == "" or args["cond.p.2p.alt"] == "—") then
		data.forms.cond_p_2p = data.forms.cond_p_2p .. " or " .. format_links(args["cond.p.2p.alt"])
	end
	if not (args["cond.p.3p.alt"] == nil or args["cond.p.3p.alt"] == "" or args["cond.p.3p.alt"] == "—") then
		data.forms.cond_p_3p = data.forms.cond_p_3p .. " or " .. format_links(args["cond.p.3p.alt"])
	end
	if not (args["sub.p.1s.alt"] == nil or args["sub.p.1s.alt"] == "" or args["sub.p.1s.alt"] == "—") then
		data.forms.sub_p_1s = data.forms.sub_p_1s .. " or " .. format_links(args["sub.p.1s.alt"])
	end
	if not (args["sub.p.2s.alt"] == nil or args["sub.p.2s.alt"] == "" or args["sub.p.2s.alt"] == "—") then
		data.forms.sub_p_2s = data.forms.sub_p_2s .. " or " .. format_links(args["sub.p.2s.alt"])
	end
	if not (args["sub.p.3s.alt"] == nil or args["sub.p.3s.alt"] == "" or args["sub.p.3s.alt"] == "—") then
		data.forms.sub_p_3s = data.forms.sub_p_3s .. " or " .. format_links(args["sub.p.3s.alt"])
	end
	if not (args["sub.p.1p.alt"] == nil or args["sub.p.1p.alt"] == "" or args["sub.p.1p.alt"] == "—") then
		data.forms.sub_p_1p = data.forms.sub_p_1p .. " or " .. format_links(args["sub.p.1p.alt"])
	end
	if not (args["sub.p.2p.alt"] == nil or args["sub.p.2p.alt"] == "" or args["sub.p.2p.alt"] == "—") then
		data.forms.sub_p_2p = data.forms.sub_p_2p .. " or " .. format_links(args["sub.p.2p.alt"])
	end
	if not (args["sub.p.3p.alt"] == nil or args["sub.p.3p.alt"] == "" or args["sub.p.3p.alt"] == "—") then
		data.forms.sub_p_3p = data.forms.sub_p_3p .. " or " .. format_links(args["sub.p.3p.alt"])
	end
	if not (args["sub.pa.1s.alt"] == nil or args["sub.pa.1s.alt"] == "" or args["sub.pa.1s.alt"] == "—") then
		data.forms.sub_pa_1s = data.forms.sub_pa_1s .. " or " .. format_links(args["sub.pa.1s.alt"])
	end
	if not (args["sub.pa.2s.alt"] == nil or args["sub.pa.2s.alt"] == "" or args["sub.pa.2s.alt"] == "—") then
		data.forms.sub_pa_2s = data.forms.sub_pa_2s .. " or " .. format_links(args["sub.pa.2s.alt"])
	end
	if not (args["sub.pa.3s.alt"] == nil or args["sub.pa.3s.alt"] == "" or args["sub.pa.3s.alt"] == "—") then
		data.forms.sub_pa_3s = data.forms.sub_pa_3s .. " or " .. format_links(args["sub.pa.3s.alt"])
	end
	if not (args["sub.pa.1p.alt"] == nil or args["sub.pa.1p.alt"] == "" or args["sub.pa.1p.alt"] == "—") then
		data.forms.sub_pa_1p = data.forms.sub_pa_1p .. " or " .. format_links(args["sub.pa.1p.alt"])
	end
	if not (args["sub.pa.2p.alt"] == nil or args["sub.pa.2p.alt"] == "" or args["sub.pa.2p.alt"] == "—") then
		data.forms.sub_pa_2p = data.forms.sub_pa_2p .. " or " .. format_links(args["sub.pa.2p.alt"])
	end
	if not (args["sub.pa.3p.alt"] == nil or args["sub.pa.3p.alt"] == "" or args["sub.pa.3p.alt"] == "—") then
		data.forms.sub_pa_3p = data.forms.sub_pa_3p .. " or " .. format_links(args["sub.pa.3p.alt"])
	end
	if not (args["imp.p.2s.alt"] == nil or args["imp.p.2s.alt"] == "" or args["imp.p.2s.alt"] == "—") then
		data.forms.imp_p_2s = data.forms.imp_p_2s .. " or " .. format_links(args["imp.p.2s.alt"])
	end
	if not (args["imp.p.1p.alt"] == nil or args["imp.p.1p.alt"] == "" or args["imp.p.1p.alt"] == "—") then
		data.forms.imp_p_1p = data.forms.imp_p_1p .. " or " .. format_links(args["imp.p.1p.alt"])
	end
	if not (args["imp.p.2p.alt"] == nil or args["imp.p.2p.alt"] == "" or args["imp.p.2p.alt"] == "—") then
		data.forms.imp_p_2p = data.forms.imp_p_2p .. " or " .. format_links(args["imp.p.2p.alt"])
	end
	
	--a few ugly hacks
	data.forms.ger = args["ger.override"]
	data.forms.inf_comp = args["inf.override"]
	data.forms.ger_comp = args["ger.comp.override"]
	
	
	--finish up
	
	
	
	if mw.title.getCurrentTitle().nsText == "" then
		return export.make_table(data) .. categorize(args,data)
	else
		return export.make_table(data)
	end
end
	
function format_links(link)
	if (link == nil or link == "" or link == "—") then
		return "—"
	else
		return m_links.full_link({lang = lang, term = link})
	end
end


function categorize(args, data)
	output = ""
	if args.group == "1" or args.group == "1st" or args.group == "first" then
		output = output .. "[[Category:French first group verbs]]"
	elseif args.group == "2" or args.group == "2st" or args.group == "second" then
		output = output .. "[[Category:French second group verbs]]"
	elseif args.group == "3" or args.group == "3rd" or args.group == "third" then
		output = output .. "[[Category:French third group verbs]]"
	end
	if data.aux == "être" then
		output = output .. "[[Category:French verbs taking être as auxiliary]]"
	elseif data.aux == "avoir or être" then
		output = output .. "[[Category:French verbs taking avoir or être as auxiliary]]"
	end
	return output
end

--split from Module:fr-verb/core
function export.make_table(data)
	local aux_gerund = ""
	if data.aux == "avoir" then
		aux_gerund = "en ayant"
	elseif data.aux == "être" then
		aux_gerund = data.refl and "en s'étant" or "en étant"
	else
		aux_gerund = "en ayant ''or'' en étant"
	end
	
	local result = {}
	if data.notes then table.insert(result, data.notes .. '\n') end
	table.insert(result, '<div class="NavFrame" style="clear:both;margin-top:1em">\n')
	table.insert(result, '<div class="NavHead" align=left>&nbsp;&nbsp;Conjugation of \'\'' .. data.forms.inf_nolink .. '\'\' <span style="font-size:90%;">(see also [[Appendix:French verbs]])</span></div>\n')
	table.insert(result, '<div class="NavContent" align=center>\n')
	table.insert(result, '{| style="background:#F0F0F0;width:100%;border-collapse:separate;border-spacing:2px" class="inflection-table"\n')
	table.insert(result, '|-\n')
	table.insert(result, '! colspan="2" style="background:#e2e4c0" |\n')
	table.insert(result, '! colspan="3" style="background:#e2e4c0" | simple\n')
	table.insert(result, '! colspan="3" style="background:#e2e4c0" | compound\n')
	table.insert(result, '|-\n')
	table.insert(result, '! colspan="2" style="background:#e2e4c0" | infinitive\n')
	table.insert(result, '| colspan="3" | ' .. data.forms.inf_nolink .. '\n')
	if data.forms.pp_nolink == "—" then
		table.insert(result, '| colspan="3" | ' .. data.forms.pp_nolink .. '\n')
	elseif not (data.forms.inf_comp == nil or data.forms.inf_comp == "") then
		table.insert(result, '| colspan="3" | ' .. data.forms.inf_comp .. '\n')
	else
		table.insert(result, '| colspan="3" | ' .. data.aux .. " " .. data.forms.pp_nolink .. '\n')
	end
	table.insert(result, '|-\n')
	table.insert(result, '! colspan="2" style="background:#e2e4c0" | gerund\n')
	if data.forms.ppr_nolink == "—" then
		table.insert(result, '| colspan="3" | ' .. data.forms.ppr_nolink .. '\n')
	elseif not (data.forms.ger == nil or data.forms.ger == "") then
		table.insert(result, '| colspan="3" | ' .. data.forms.ger .. '\n')
	else
		table.insert(result, '| colspan="3" | en ' .. data.forms.ppr_nolink .. '\n')
	end
	if data.forms.pp_nolink == "—" then
		table.insert(result, '| colspan="3" | ' .. data.forms.pp_nolink .. '\n')
	elseif not (data.forms.ger_comp == nil or data.forms.ger_comp == "") then
		table.insert(result, '| colspan="3" | ' .. data.forms.ger_comp .. '\n')
	else
		table.insert(result, '| colspan="3" | ' .. aux_gerund .. " " .. data.forms.pp_nolink .. '\n')
	end
	table.insert(result, '|-\n')
	table.insert(result, '! colspan="2" style="background:#e2e4c0" | present participle\n')
	table.insert(result, '| ' .. data.forms.ppr .. '\n')
	table.insert(result, '|-\n')
	table.insert(result, '! colspan="2" style="background:#e2e4c0" | past participle\n')
	table.insert(result, '| ' .. data.forms.pp .. '\n')
	table.insert(result, '|-\n')
	table.insert(result, '! colspan="2" rowspan="2" style="background:#C0C0C0" | person\n')
	table.insert(result, '! colspan="3" style="background:#C0C0C0" | singular\n')
	table.insert(result, '! colspan="3" style="background:#C0C0C0" | plural\n')
	table.insert(result, '|-\n')
	table.insert(result, '! style="background:#C0C0C0;width:12.5%" | first\n')
	table.insert(result, '! style="background:#C0C0C0;width:12.5%" | second\n')
	table.insert(result, '! style="background:#C0C0C0;width:12.5%" | third\n')
	table.insert(result, '! style="background:#C0C0C0;width:12.5%" | first\n')
	table.insert(result, '! style="background:#C0C0C0;width:12.5%" | second\n')
	table.insert(result, '! style="background:#C0C0C0;width:12.5%" | third\n')
	table.insert(result, '|-\n')
	table.insert(result, '! style="background:#c0cfe4" colspan="2" | indicative\n')
	table.insert(result, '! style="background:#c0cfe4" | je (j’)\n')
	table.insert(result, '! style="background:#c0cfe4" | tu\n')
	table.insert(result, '! style="background:#c0cfe4" | il\n')
	table.insert(result, '! style="background:#c0cfe4" | nous\n')
	table.insert(result, '! style="background:#c0cfe4" | vous\n')
	table.insert(result, '! style="background:#c0cfe4" | ils\n')
	table.insert(result, '|-\n')
	table.insert(result, '! rowspan="5" style="background:#c0cfe4" | simple<br>tenses\n')
	table.insert(result, '! style="height:3em;background:#c0cfe4" | present\n')
	table.insert(result, '| ' .. data.forms.ind_p_1s .. '\n')
	table.insert(result, '| ' .. data.forms.ind_p_2s .. '\n')
	table.insert(result, '| ' .. data.forms.ind_p_3s .. '\n')
	table.insert(result, '| ' .. data.forms.ind_p_1p .. '\n')
	table.insert(result, '| ' .. data.forms.ind_p_2p .. '\n')
	table.insert(result, '| ' .. data.forms.ind_p_3p .. '\n')
	table.insert(result, '|-\n')
	table.insert(result, '! style="height:3em;background:#c0cfe4" | imperfect\n')
	table.insert(result, '| ' .. data.forms.ind_i_1s .. '\n')
	table.insert(result, '| ' .. data.forms.ind_i_2s .. '\n')
	table.insert(result, '| ' .. data.forms.ind_i_3s .. '\n')
	table.insert(result, '| ' .. data.forms.ind_i_1p .. '\n')
	table.insert(result, '| ' .. data.forms.ind_i_2p .. '\n')
	table.insert(result, '| ' .. data.forms.ind_i_3p .. '\n')
	table.insert(result, '|-\n')
	table.insert(result, '! style="height:3em;background:#c0cfe4" | <font color="#7f7f7f">past historic<sup>1</sup></font>\n')
	table.insert(result, '| style="background:#c0cfe4" | ' .. data.forms.ind_ps_1s .. '\n')
	table.insert(result, '| style="background:#c0cfe4" |' .. data.forms.ind_ps_2s .. '\n')
	table.insert(result, '| style="background:#c0cfe4" |' .. data.forms.ind_ps_3s .. '\n')
	table.insert(result, '| style="background:#c0cfe4" |' .. data.forms.ind_ps_1p .. '\n')
	table.insert(result, '| style="background:#c0cfe4" |' .. data.forms.ind_ps_2p .. '\n')
	table.insert(result, '| style="background:#c0cfe4" |' .. data.forms.ind_ps_3p .. '\n')
	table.insert(result, '|-\n')
	table.insert(result, '! style="height:3em;background:#c0cfe4" | future\n')
	table.insert(result, '| ' .. data.forms.ind_f_1s .. '\n')
	table.insert(result, '| ' .. data.forms.ind_f_2s .. '\n')
	table.insert(result, '| ' .. data.forms.ind_f_3s .. '\n')
	table.insert(result, '| ' .. data.forms.ind_f_1p .. '\n')
	table.insert(result, '| ' .. data.forms.ind_f_2p .. '\n')
	table.insert(result, '| ' .. data.forms.ind_f_3p .. '\n')
	table.insert(result, '|-\n')
	table.insert(result, '! style="height:3em;background:#c0cfe4" | conditional\n')
	table.insert(result, '| ' .. data.forms.cond_p_1s .. '\n')
	table.insert(result, '| ' .. data.forms.cond_p_2s .. '\n')
	table.insert(result, '| ' .. data.forms.cond_p_3s .. '\n')
	table.insert(result, '| ' .. data.forms.cond_p_1p .. '\n')
	table.insert(result, '| ' .. data.forms.cond_p_2p .. '\n')
	table.insert(result, '| ' .. data.forms.cond_p_3p .. '\n')
	table.insert(result, '|-\n')
	table.insert(result, '! rowspan="5" style="background:#c0cfe4" | compound<br>tenses\n')
	table.insert(result, '! style="height:3em;background:#c0cfe4" | present perfect\n')
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#C0C0C0" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#C0C0C0" | Use the present tense of ' .. data.aux .. ' followed by the past participle\n')
	end
	table.insert(result, '|-\n')
	table.insert(result, '! style="height:3em;background:#c0cfe4" | pluperfect\n')
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#C0C0C0" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#C0C0C0" | Use the imperfect tense of ' .. data.aux .. ' followed by the past participle\n')
	end
	table.insert(result, '|-\n')
	table.insert(result, '! style="height:3em;background:#c0cfe4" | <font color="#7f7f7f">past anterior<sup>1</sup></font>\n')
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#c0cfe4" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#c0cfe4" | Use the past historic tense of ' .. data.aux .. ' followed by the past participle\n')
	end
	table.insert(result, '|-\n')
	table.insert(result, '! style="height:3em;background:#c0cfe4" | future perfect\n')
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#C0C0C0" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#C0C0C0" | Use the future tense of ' .. data.aux .. ' followed by the past participle\n')
	end
	table.insert(result, '|-\n')
	table.insert(result, '! style="height:3em;background:#c0cfe4" | conditional perfect\n')
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#C0C0C0" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#C0C0C0" | Use the conditional tense of ' .. data.aux .. ' followed by the past participle\n')
	end
	table.insert(result, '|-\n')
	table.insert(result, '! style="background:#c0e4c0" colspan="2" | subjunctive\n')
	table.insert(result, '! style="background:#c0e4c0" | que je (j’)\n')
	table.insert(result, '! style="background:#c0e4c0" | que tu\n')
	table.insert(result, '! style="background:#c0e4c0" | qu’il\n')
	table.insert(result, '! style="background:#c0e4c0" | que nous\n')
	table.insert(result, '! style="background:#c0e4c0" | que vous\n')
	table.insert(result, '! style="background:#c0e4c0" | qu’ils\n')
	table.insert(result, '|-\n')
	table.insert(result, '! rowspan="2" style="background:#c0e4c0" | simple<br>tenses\n')
	table.insert(result, '! style="height:3em;background:#c0e4c0" | present\n')
	table.insert(result, '| ' .. data.forms.sub_p_1s .. '\n')
	table.insert(result, '| ' .. data.forms.sub_p_2s .. '\n')
	table.insert(result, '| ' .. data.forms.sub_p_3s .. '\n')
	table.insert(result, '| ' .. data.forms.sub_p_1p .. '\n')
	table.insert(result, '| ' .. data.forms.sub_p_2p .. '\n')
	table.insert(result, '| ' .. data.forms.sub_p_3p .. '\n')
	table.insert(result, '|-\n')
	table.insert(result, '! style="height:3em;background:#c0e4c0" rowspan="1" | <font color="#7f7f7f">imperfect<sup>1</sup></font>\n')
	table.insert(result, '| style="background:#c0e4c0" |' .. data.forms.sub_pa_1s .. '\n')
	table.insert(result, '| style="background:#c0e4c0" |' .. data.forms.sub_pa_2s .. '\n')
	table.insert(result, '| style="background:#c0e4c0" |' .. data.forms.sub_pa_3s .. '\n')
	table.insert(result, '| style="background:#c0e4c0" |' .. data.forms.sub_pa_1p .. '\n')
	table.insert(result, '| style="background:#c0e4c0" |' .. data.forms.sub_pa_2p .. '\n')
	table.insert(result, '| style="background:#c0e4c0" |' .. data.forms.sub_pa_3p .. '\n')
	table.insert(result, '|-\n')
	table.insert(result, '! rowspan="2" style="background:#c0e4c0" | compound<br>tenses\n')
	table.insert(result, '! style="height:3em;background:#c0e4c0" | past\n')
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#C0C0C0" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#C0C0C0" | Use the present subjunctive tense of ' .. data.aux .. ' followed by the past participle\n')
	end
	table.insert(result, '|-\n')
	table.insert(result, '! rowspan="1" style="height:3em;background:#c0e4c0" | <font color="#7f7f7f">pluperfect<sup>1</sup></font>\n')
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#c0e4c0" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#c0e4c0" | Use the imperfect subjunctive tense of ' .. data.aux .. ' followed by the past participle\n')
	end
	table.insert(result, '|-\n')
	table.insert(result, '! colspan="2" rowspan="2" style="height:3em;background:#e4d4c0" | imperative\n')
	table.insert(result, '! style="background:#e4d4c0" | –\n')
	table.insert(result, '! style="background:#e4d4c0" | tu\n')
	table.insert(result, '! style="background:#e4d4c0" | –\n')
	table.insert(result, '! style="background:#e4d4c0" | nous\n')
	table.insert(result, '! style="background:#e4d4c0" | vous\n')
	table.insert(result, '! style="background:#e4d4c0" | –\n')
	table.insert(result, '|-\n')
	table.insert(result, '| —\n')
	table.insert(result, '| ' .. data.forms.imp_p_2s .. '\n')
	table.insert(result, '| —\n')
	table.insert(result, '| ' .. data.forms.imp_p_1p .. '\n')
	table.insert(result, '| ' .. data.forms.imp_p_2p .. '\n')
	table.insert(result, '| —\n')
	table.insert(result, '|-\n')
	table.insert(result, '| colspan="8" |<sup style="margin-left: 20px;">1</sup>literary tenses\n')
	table.insert(result, '|}\n')
	table.insert(result, '</div>\n')
	table.insert(result, '</div>')
	
	return table.concat(result)
end

return export
