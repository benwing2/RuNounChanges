local export = {}
local m_links = require("Module:links")

local lang = require("Module:languages").getByCode("fr")

-- defined below
local format_links, categorize

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
	local data = {forms = {}, categories = {}, en = false, y = false, yen = false, l = false, le = false, la = false, les = false, l_en = false, l_y = false, l_yen = false, lesen = false, lesy = false, lesyen = false, refl = false, reflen = false, refll = false, reflle = false, reflla = false, reflles = false, reflly = false, refllesy = false, refly = false, reflyen = false, aux = ""}
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
	if (args["pp"] == "—") then
		data.forms.pp_nolink = "—"
	elseif (args["pp"] == nil or mw.title.getCurrentTitle().text) then
		data.forms.pp_nolink = mw.title.getCurrentTitle().text
	else
		data.forms.pp_nolink = format_links(args["pp"])
	end
	if (args["ppr"] == "—") then
		data.forms.ppr_nolink = "—"
	elseif (args["ppr"] == nil or mw.title.getCurrentTitle().text) then
		data.forms.ppr_nolink = mw.title.getCurrentTitle().text
	else
		data.forms.ppr_nolink = format_links(args["ppr"])
	end
	
	local form_params = {
		"ind.p.1s", "ind.p.2s", "ind.p.3s", "ind.p.1p", "ind.p.2p", "ind.p.3p",
		"ind.i.1s", "ind.i.2s", "ind.i.3s", "ind.i.1p", "ind.i.2p", "ind.i.3p",
		"ind.ps.1s", "ind.ps.2s", "ind.ps.3s", "ind.ps.1p", "ind.ps.2p", "ind.ps.3p",
		"ind.f.1s", "ind.f.2s", "ind.f.3s", "ind.f.1p", "ind.f.2p", "ind.f.3p",
		"cond.p.1s", "cond.p.2s", "cond.p.3s", "cond.p.1p", "cond.p.2p", "cond.p.3p",
		"sub.p.1s", "sub.p.2s", "sub.p.3s", "sub.p.1p", "sub.p.2p", "sub.p.3p",
		"sub.pa.1s", "sub.pa.2s", "sub.pa.3s", "sub.pa.1p", "sub.pa.2p", "sub.pa.3p",
		"imp.p.2s", "imp.p.1p", "imp.p.2p",
	}
	
	for _, form in ipairs(form_params) do
		local key = form:gsub("%.", "_")
		data.forms[key] = format_links(args[form])
		local alt = form .. ".alt"
		local alt_arg = args[alt]
		if not (alt_arg == nil or alt_arg == "" or alt_arg == "—") then
			data.forms[key] = data.forms[key] .. " <i>or</i> " .. format_links(alt_arg)
		end
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
	local colors = {
		top = "#F0F0F0", gray = "#C0C0C0", straw = "#e2e4c0", blue = "#c0cfe4",
		gray_text = "#7f7f7f", green = "#c0e4c0",  tan = "#e4d4c0",
	}
	
	local aux_gerund = ""
	if data.aux == "avoir" then
		aux_gerund = "[[ayant]]"
	elseif data.aux == "[[s']][[être]]" then
		aux_gerund = "[[s']][[étant]]"
    elseif data.aux == "s'en être" then
		aux_gerund = "[[s']][[en]] [[étant]]"
    elseif data.aux == "s'y être" then
		aux_gerund = "[[s']][[y]] [[étant]]"
	elseif data.aux == "s'y en être" then
		aux_gerund = "[[s']][[y]] [[en]] [[étant]]"
	elseif data.aux == "se l'être" then
		aux_gerund = "[[se]] [[l']][[étant]]"
	elseif data.aux == "se les être" then
		aux_gerund = "[[se]] [[les]] [[étant]]"
	elseif data.aux == "l'en avoir" then
		aux_gerund = "[[l']][[en]] [[ayant]]"
	elseif data.aux == "l'y en avoir" then
		aux_gerund = "[[l']][[y]] [[en]] [[ayant]]"
	elseif data.aux == "les en avoir" then
		aux_gerund = "[[les]] [[en]] [[ayant]]"
	elseif data.aux == "les y en avoir" then
		aux_gerund = "[[les]] [[y]] [[en]] [[ayant]]"
	elseif data.aux == "se les y être" then
		aux_gerund = "[[se]] [[les]] [[y]] [[étant]]"
	elseif data.aux == "se l'y être" then
		aux_gerund = "[[se]] [[l']][[y]] [[étant]]"
	elseif data.aux == "l'avoir" then
		aux_gerund = "[[l]]'[[ayant]]"
	elseif data.aux == "l'être" then
		aux_gerund = "[[l]]'[[étant]]"
	elseif data.aux == "l'avoir ''or'' être" then
		aux_gerund = "[[l]]'[[ayant]] ''or'' [[étant]]"
	elseif data.aux == "l'y avoir" then
		aux_gerund = "[[l]]'[[y]] [[ayant]]"
	elseif data.aux == "l'y être" then
		aux_gerund = "[[l]]'[[y]] [[étant]]"
	elseif data.aux == "l'y avoir ''or'' être" then
		aux_gerund = "[[l]]'[[y]] [[ayant]] ''or'' [[étant]]"
	elseif data.aux == "les avoir" then
		aux_gerund = "[[les]] [[ayant]]"
	elseif data.aux == "les être" then
		aux_gerund = "[[les]] [[étant]]"
	elseif data.aux == "les avoir ''or'' être" then
		aux_gerund = "[[les]] [[ayant]] ''or'' [[étant]]"
	elseif data.aux == "les y avoir" then
		aux_gerund = "[[les]] [[y]] [[ayant]]"
	elseif data.aux == "les y être" then
		aux_gerund = "[[les]] [[y]] [[étant]]"
	elseif data.aux == "les y avoir ''or'' être" then
		aux_gerund = "[[les]] [[y]] [[ayant]] ''or'' [[étant]]"
    elseif data.aux == "y avoir" then
		aux_gerund = "[[y]] [[ayant]]"
    elseif data.aux == "y être" then
		aux_gerund = "[[y]] [[étant]]"
    elseif data.aux == "y avoir ''or'' être" then
		aux_gerund = "[[y]] [[ayant]] ''or'' [[étant]]"
    elseif data.aux == "y en avoir" then
		aux_gerund = "[[y]] [[en]] [[ayant]]"
    elseif data.aux == "y en être" then
		aux_gerund = "[[y]] [[en]] [[étant]]"
    elseif data.aux == "y en avoir ''or'' être" then
		aux_gerund = "[[y]] [[en]] [[ayant]] ''or'' [[étant]]"
    elseif data.aux == "en avoir" then
		aux_gerund = "[[en]] [[ayant]]"
    elseif data.aux == "en être" then
		aux_gerund = "[[en]] [[étant]]"
    elseif data.aux == "en avoir ''or'' être" then
		aux_gerund = "[[en] [[ayant]] ''or'' [[étant]]"
	elseif data.aux == "être" then
		aux_gerund = "[[étant]]"
	else
		aux_gerund = "[[ayant]] <i>or</i> [[étant]]"
	end
	
	local result = {}
	
	local inv = data.forms.pp_nolink
	local inv_sub = data.forms.pp_nolink
	local inversion_note = ""
	local inversion_sub_note = ""
	local replacement_note = "<sup>2</sup>"
	
	--Until someone implements a better solution
	
	if inv == "aimé" or inv == "chanté" or inv == "dansé" or inv == "dussé" or inv == "-é" or inv == "estimé" or inv == "eussé" or inv == "fussé" or inv == "mangé" or inv == "opiné" or inv == "parlé" or inv == "pensé" or inv == "pu" or inv == "trouvé" then
		inversion_note = "<sup>2</sup>"
		inversion_sub_note = "<sup>2</sup>"
		replacement_note = "<sup>3</sup>"
		if inv == "pu" then
			inv = "puis"
			inv_sub = "puissé"
			inversion_sub_note = "<sup>3</sup>"
			replacement_note = "<sup>4</sup>"
		end
	end
	
	-- Template parameter syntax refers to the corresponding item in the
	-- data.forms or colors table:
	-- {{{inf_nolink}}} -> data.forms.inf_nolink
	-- {{{green}}}		-> colors.green
	if data.notes then table.insert(result, data.notes .. '\n') end
	table.insert(result,
[=[
<div class="NavFrame" style="clear:both">
<div class="NavHead" align=left>Conjugation of ''{{{inf_nolink}}}'' <span style="font-size:90%;">(see also [[Appendix:French verbs]])</span></div>
<div class="NavContent" align=center>
{| style="background:{{{top}}};width:100%;border-collapse:separate;border-spacing:2px" class="inflection-table"
|-
! colspan="1" rowspan="2" style="background:{{{straw}}}" | <span title="infinitif">infinitive</span>
! colspan="1" style="height:3em;background:{{{straw}}}" | <small>simple</small>
| {{{inf_nolink}}}
|-
! colspan="1" style="height:3em;background:{{{straw}}}" | <small>compound</small>
]=])
	if data.forms.inf_comp == "" then
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | ' ..data.forms.inf_comp.. ' \n')
	elseif data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | <i>[[' .. data.aux .. ']]</i> + past participle\n')
	end
	table.insert(result,
[=[
|-
! colspan="1" rowspan="2" style="background:{{{straw}}}" | <span title="participe présent">present participle</span> or <span title="">gerund</span><sup>1</sup>
! colspan="1" style="height:3em;background:{{{straw}}}" | <small>simple</small>
| {{{ppr}}}
|-
! colspan="1" style="height:3em;background:{{{straw}}}" | <small>compound</small>
]=])
	if data.forms.ger_comp == "" then
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | ' ..data.forms.ger_comp.. '\n')
	elseif data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | <i>' .. aux_gerund .. '</i> + past participle \n')
	end
	table.insert(result,
[=[
|-
! colspan="2" style="background:{{{straw}}}" | <span title="participe passé">past participle</span>
| {{{pp}}}
|-
! colspan="2" rowspan="2" |
! colspan="3" style="background:{{{gray}}}" | singular
! colspan="3" style="background:{{{gray}}}" | plural
|-
! style="background:{{{gray}}};width:12.5%" | first
! style="background:{{{gray}}};width:12.5%" | second
! style="background:{{{gray}}};width:12.5%" | third
! style="background:{{{gray}}};width:12.5%" | first
! style="background:{{{gray}}};width:12.5%" | second
! style="background:{{{gray}}};width:12.5%" | third
|-
! style="background:{{{blue}}}" colspan="2" | <span title="indicatif">indicative</span>
! style="background:{{{blue}}}" | je (j’)
! style="background:{{{blue}}}" | tu
! style="background:{{{blue}}}" | il, elle, on
! style="background:{{{blue}}}" | nous
! style="background:{{{blue}}}" | vous
! style="background:{{{blue}}}" | ils, elles
|-
! rowspan="5" style="background:{{{blue}}}" | <small>(simple<br>tenses)</small>
! style="height:3em;background:{{{blue}}}" | <span title="présent">present</span>
| {{{ind_p_1s}}}]=] .. inversion_note .. [=[

| {{{ind_p_2s}}}
| {{{ind_p_3s}}}
| {{{ind_p_1p}}}
| {{{ind_p_2p}}}
| {{{ind_p_3p}}}
|-
! style="height:3em;background:{{{blue}}}" | <span title="imparfait">imperfect</span>
| {{{ind_i_1s}}}
| {{{ind_i_2s}}}
| {{{ind_i_3s}}}
| {{{ind_i_1p}}}
| {{{ind_i_2p}}}
| {{{ind_i_3p}}}
|-
! style="height:3em;background:{{{blue}}}" | <span title="passé simple">past historic</span>]=] .. replacement_note .. [=[

| {{{ind_ps_1s}}}
| {{{ind_ps_2s}}}
| {{{ind_ps_3s}}}
| {{{ind_ps_1p}}}
| {{{ind_ps_2p}}}
| {{{ind_ps_3p}}}
|-
! style="height:3em;background:{{{blue}}}" | <span title="futur simple">future</span>
| {{{ind_f_1s}}}
| {{{ind_f_2s}}}
| {{{ind_f_3s}}}
| {{{ind_f_1p}}}
| {{{ind_f_2p}}}
| {{{ind_f_3p}}}
|-
! style="height:3em;background:{{{blue}}}" | <span title="conditionnel présent">conditional</span>
| {{{cond_p_1s}}}
| {{{cond_p_2s}}}
| {{{cond_p_3s}}}
| {{{cond_p_1p}}}
| {{{cond_p_2p}}}
| {{{cond_p_3p}}}
|-
! rowspan="5" style="background:{{{blue}}}" | <small>(compound<br>tenses)</small>
! style="height:3em;background:{{{blue}}}" | <span title="passé composé">present perfect</span>
]=])
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | present indicative of <i>[[' .. data.aux .. ']]</i> + past participle\n')
	end
	table.insert(result, '|-\n! style="height:3em;background:{{{blue}}}" | <span title="plus-que-parfait">pluperfect</span>\n')
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | imperfect indicative of <i>[[' .. data.aux .. ']]</i> + past participle\n')
	end
	table.insert(result, '|-\n! style="height:3em;background:{{{blue}}}" | <span title="passé antérieur">past anterior</span>' .. replacement_note .. '\n')
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | past historic of <i>[[' .. data.aux .. ']]</i> + past participle\n')
	end
	table.insert(result, '|-\n! style="height:3em;background:{{{blue}}}" | <span title="futur antérieur">future perfect</span>\n')
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | future of <i>[[' .. data.aux .. ']]</i> + past participle\n')
	end
	table.insert(result, '|-\n! style="height:3em;background:{{{blue}}}" | <span title="conditionnel passé">conditional perfect</span>\n')
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | conditional of <i>[[' .. data.aux .. ']]</i> + past participle\n')
	end
	table.insert(result,
[=[
|-
! style="background:{{{green}}}" colspan="2" | <span title="subjonctif">subjunctive</span>
! style="background:{{{green}}}" | que je (j’)
! style="background:{{{green}}}" | que tu
! style="background:{{{green}}}" | qu’il, qu’elle
! style="background:{{{green}}}" | que nous
! style="background:{{{green}}}" | que vous
! style="background:{{{green}}}" | qu’ils, qu’elles
|-
! rowspan="2" style="background:{{{green}}}" | <small>(simple<br>tenses)</small>
! style="height:3em;background:{{{green}}}" | <span title="subjonctif présent">present</span>
| {{{sub_p_1s}}}]=] .. inversion_sub_note .. [=[

| {{{sub_p_2s}}}
| {{{sub_p_3s}}}
| {{{sub_p_1p}}}
| {{{sub_p_2p}}}
| {{{sub_p_3p}}}
|-
! style="height:3em;background:{{{green}}}" rowspan="1" | <span title="subjonctif imparfait">imperfect</span>]=] .. replacement_note .. [=[

| {{{sub_pa_1s}}}
| {{{sub_pa_2s}}}
| {{{sub_pa_3s}}}
| {{{sub_pa_1p}}}
| {{{sub_pa_2p}}}
| {{{sub_pa_3p}}}
|-
! rowspan="2" style="background:{{{green}}}" | <small>(compound<br>tenses)</small>
! style="height:3em;background:{{{green}}}" | <span title="subjonctif passé">past</span>
]=])
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | present subjunctive of <i>[[' .. data.aux .. ']]</i> + past participle\n')
	end
	table.insert(result, '|-\n! style="height:3em;background:{{{green}}}" | <span title="subjonctif plus-que-parfait">pluperfect</span>' .. replacement_note .. '\n')
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | — \n')
	else
		table.insert(result, '! colspan="6" style="background:#DEDEDE" | imperfect subjunctive of <i>[[' .. data.aux .. ']]</i> + past participle\n')
	end
	table.insert(result,
[=[
|-
! colspan="2" style="background:{{{tan}}}" | <span title="impératif">imperative</span>
! style="background:{{{tan}}}" | –
! style="background:{{{tan}}}" | <s>tu</s>
! style="background:{{{tan}}}" | –
! style="background:{{{tan}}}" | <s>nous</s>
! style="background:{{{tan}}}" | <s>vous</s>
! style="background:{{{tan}}}" | –
|-
! style="height:3em;background:{{{tan}}}" colspan="2" | <span title="">simple</span>
| —
| {{{imp_p_2s}}}
| —
| {{{imp_p_1p}}}
| {{{imp_p_2p}}}
| —
|-
! style="height:3em;background:{{{tan}}}" colspan="2" | <span title="">compound</span>
| —
]=])
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! style="background:#DEDEDE" | — \n')
	else
		table.insert(result, '! style="background:#DEDEDE" | simple imperative of <i>[[' .. data.aux .. ']]</i> + past participle\n')
	end
	table.insert(result,
[=[
| —
]=])
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! style="background:#DEDEDE" | — \n')
	else
		table.insert(result, '! style="background:#DEDEDE" | simple imperative of <i>[[' .. data.aux .. ']]</i> + past participle\n')
	end
	table.insert(result,
[=[
]=])
	if data.forms.pp_nolink == "—" then
		table.insert(result, '! style="background:#DEDEDE" | — \n')
	else
		table.insert(result, '! style="background:#DEDEDE" | simple imperative of <i>[[' .. data.aux .. ']]</i> + past participle\n')
	end
	table.insert(result,
[=[
| —
|-
| colspan="8" |<sup>1</sup> The French gerund is usable only with the preposition <i>[[en]]</i>.
|-
]=])
if inversion_note ~= "" then
	table.insert(result,
[=[
| colspan="8" |<sup>2</sup> <i>[[]=] .. inv .. [=[]]</i> when inverted.
|-
]=])
end
if inv ~= inv_sub then
	table.insert(result,
[=[
| colspan="8" |<sup>3</sup> <i>[[]=] .. inv_sub .. [=[]]</i> when inverted.
|-
]=])
end
table.insert(result,
[=[
| colspan="8" |]=] .. replacement_note .. [=[ In less formal writing or speech, these tenses may be found to have been replaced in the following way:
* past historic → present perfect
* past anterior → pluperfect
* imperfect subjunctive → present subjunctive
* pluperfect subjunctive → past subjunctive
(Christopher Kendris [1995], <i>Master the Basics: French</i>, pp. [https://books.google.fr/books?id=g4G4jg5GWMwC&pg=PA77 77], [https://books.google.fr/books?id=g4G4jg5GWMwC&pg=PA78 78], [https://books.google.fr/books?id=g4G4jg5GWMwC&pg=PA79 79], [https://books.google.fr/books?id=g4G4jg5GWMwC&pg=PA81 81]).
|}
</div>
</div>
]=])
	
	--[[
	setmetatable(data.forms, { __index =
		function(t, k)
			mw.log('No key for ' .. k)
		end
	})
	--]]
	
	return string.gsub(table.concat(result), "{{{([^}]+)}}}",
		function(code)
			return data.forms[code] or colors[code]
		end)
end

return export
