local m_links = require("Module:links")
local m_utilities = require("Module:utilities")

local m_infl =  require("Module:fur-conj/data")

local lang = require("Module:languages").getByCode("fur")

local export = {}

local function make_table(data)
	local function show_form(form)
		if not form then
			return "–"
		end
		
		local ret = {}
		
		for key, subform in ipairs(form) do
			table.insert(ret, m_links.full_link({lang = lang, term = subform}))
		end
			
		return table.concat(ret, ", ")
	end
	local function repl(param)
		if param == "conj" then
			return data.conj
		else
			return show_form(data.forms[param])
		end
	end
	local wikicode = [=[{{{comment}}}
<div class="NavFrame">
<div class="NavHead" align=left>Conjugation of {{{inf}}} ({{{conj}}})</div>
<div class="NavContent">
{| style="background:#F0F0F0;text-align:center;width:100%;margin:auto;"
|-
! colspan="3" style="background:#e2e4c0" | infinitive
| colspan="5" | {{{inf}}}
|-
! colspan="3" style="background:#e2e4c0" | gerund
| colspan="5" | {{{gerund}}}
|-
! colspan="2" rowspan="3" style="background:#e2e4c0" | past participle
! colspan="2" style="background:#e2e4c0" |
! colspan="2" style="background:#e2e4c0" | singular
! colspan="2" style="background:#e2e4c0" | plural
|-
! colspan="2" style="background:#e2e4c0" | masculine
| colspan="2" | {{{m_past_part}}}
| colspan="2" | {{{m_pl_past_part}}}
|-
! colspan="2" style="background:#e2e4c0" | feminine
| colspan="2" | {{{f_past_part}}}
| colspan="2" | {{{f_pl_past_part}}}
|-
! colspan="2" rowspan="2" style="background:#C0C0C0" | person
! colspan="3" style="background:#C0C0C0" | singular
! colspan="3" style="background:#C0C0C0" | plural
|-
! style="background:#C0C0C0;width:12.5%" | first
! style="background:#C0C0C0;width:12.5%" | second
! style="background:#C0C0C0;width:12.5%" | third
! style="background:#C0C0C0;width:12.5%" | first
! style="background:#C0C0C0;width:12.5%" | second
! style="background:#C0C0C0;width:12.5%" | third
|-
! rowspan="5" style="background:#c0cfe4" | indicative
! style="background:#c0cfe4" colspan="1" |
! style="background:#c0cfe4" | jo
! style="background:#c0cfe4" | tu
! style="background:#c0cfe4" | lui/jê
! style="background:#c0cfe4" | nô
! style="background:#c0cfe4" | vô
! style="background:#c0cfe4" | lôr
|-
! style="height:3em;background:#c0cfe4" | present
| o {{{pres_ind_1sg}}}
| tu {{{pres_ind_2sg}}}
| al/e {{{pres_ind_3sg}}}
| o {{{pres_ind_1pl}}}
| o {{{pres_ind_2pl}}}
| a {{{pres_ind_3pl}}}
|-
! style="height:3em;background:#c0cfe4" | imperfect
| o {{{impf_ind_1sg}}}
| tu {{{impf_ind_2sg}}}
| al/e {{{impf_ind_3sg}}}
| o {{{impf_ind_1pl}}}
| o {{{impf_ind_2pl}}}
| a {{{impf_ind_3pl}}}
|-
! style="height:3em;background:#c0cfe4" | simple past
| o {{{past_ind_1sg}}}
| tu {{{past_ind_2sg}}}
| al/e {{{past_ind_3sg}}}
| o {{{past_ind_1pl}}}
| o {{{past_ind_2pl}}}
| a {{{past_ind_3pl}}}
|-
! style="height:3em;background:#c0cfe4" | future
| o {{{futr_ind_1sg}}}
| tu {{{futr_ind_2sg}}}
| al/e {{{futr_ind_3sg}}}
| o {{{futr_ind_1pl}}}
| o {{{futr_ind_2pl}}}
| a {{{futr_ind_3pl}}}
|-
! rowspan="2" style="background:#c0d8e4" | conditional
! style="background:#c0d8e4" colspan="1" |
! style="background:#c0d8e4" | jo
! style="background:#c0d8e4" | tu
! style="background:#c0d8e4" | lui/jê
! style="background:#c0d8e4" | nô
! style="background:#c0d8e4" | vô
! style="background:#c0d8e4" | lôr
|-
! style="height:3em;background:#c0d8e4" | present
| o {{{pres_con_1sg}}}
| tu {{{pres_con_2sg}}}
| al/e {{{pres_con_3sg}}}
| o {{{pres_con_1pl}}}
| o {{{pres_con_2pl}}}
| a {{{pres_con_3pl}}}
|-
! rowspan="3" style="background:#c0e4c0" | subjunctive
! style="background:#c0e4c0" colspan="1" |
! style="background:#c0e4c0" | jo
! style="background:#c0e4c0" | tu
! style="background:#c0e4c0" | lui/jê
! style="background:#c0e4c0" | nô
! style="background:#c0e4c0" | vô
! style="background:#c0e4c0" | lôr
|-
! style="height:3em;background:#c0e4c0" | present
| o {{{pres_sub_1sg}}}
| tu {{{pres_sub_2sg}}}
| al/e {{{pres_sub_3sg}}}
| o {{{pres_sub_1pl}}}
| o {{{pres_sub_2pl}}}
| a {{{pres_sub_3pl}}}
|-
! style="height:3em;background:#c0e4c0" | imperfect
| o {{{impf_sub_1sg}}}
| tu {{{impf_sub_2sg}}}
| al/e {{{impf_sub_3sg}}}
| o {{{impf_sub_1pl}}}
| o {{{impf_sub_2pl}}}
| a {{{impf_sub_3pl}}}
|-
! rowspan="3" colspan="2" style="background:#e4d4c0" | imperative
! style="background:#e4d4c0" | –
! style="background:#e4d4c0" | tu
! style="background:#e4d4c0" | –
! style="background:#e4d4c0" | nô
! style="background:#e4d4c0" | vô
! style="background:#e4d4c0" | –
|-
| –
| {{{imp_2sg}}}
| –
| {{{imp_1pl}}}
| {{{imp_2pl}}}
| –
|}
</div></div>]=]
	return mw.ustring.gsub(wikicode, "{{{([a-z0-9_]+)}}}", repl)
end

-- Main entry point
function export.show(frame)
	local args = mw.clone(frame:getParent().args)
	
	-- Create the forms
	local data = {forms = {}, categories = {}}
	
	if mw.title.getCurrentTitle().nsText ~= "" then return end
	
	args[1] = mw.title.getCurrentTitle().text
	
	local last2 = mw.ustring.sub(args[1], -2)
	local ending = mw.ustring.sub(args[1], -1)
	if m_infl.irregular[args[1]] then
		m_infl.irregular[args[1]](args, data)
	elseif m_infl[last2] then
		args[1] = mw.ustring.sub(args[1], 1, -3)
		m_infl[last2](args, data)
	elseif m_infl[ending] then
		args[1] = mw.ustring.sub(args[1], 1, -2)
		m_infl[ending](args, data)
	else
		error("Inflection for " .. word .. " not found.")
	end
	
	return make_table(data) .. m_utilities.format_categories(data.categories, lang)
end

return export
