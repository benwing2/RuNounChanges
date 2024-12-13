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
<div class="NavHead">Conjugation of {{{inf}}} ({{{conj}}})</div>
<div class="NavContent">
{| class="roa-inflection-table" data-toggle-category="inflection"
|-
! colspan="3" class="roa-nonfinite-header" | infinitive
| colspan="5" | {{{inf}}}
|-
! colspan="3" class="roa-nonfinite-header" | gerund
| colspan="5" | {{{gerund}}}
|-
! colspan="2" rowspan="3" class="roa-nonfinite-header" | past participle
! colspan="2" class="roa-nonfinite-header" |
! colspan="2" class="roa-nonfinite-header" | singular
! colspan="2" class="roa-nonfinite-header" | plural
|-
! colspan="2" class="roa-nonfinite-header" | masculine
| colspan="2" | {{{m_past_part}}}
| colspan="2" | {{{m_pl_past_part}}}
|-
! colspan="2" class="roa-nonfinite-header" | feminine
| colspan="2" | {{{f_past_part}}}
| colspan="2" | {{{f_pl_past_part}}}
|-
! colspan="2" rowspan="2" class="roa-person-number-header" | person
! colspan="3" class="roa-person-number-header" | singular
! colspan="3" class="roa-person-number-header" | plural
|-
! class="roa-person-number-header" style="width:12.5%;" | first
! class="roa-person-number-header" style="width:12.5%;" | second
! class="roa-person-number-header" style="width:12.5%;" | third
! class="roa-person-number-header" style="width:12.5%;" | first
! class="roa-person-number-header" style="width:12.5%;" | second
! class="roa-person-number-header" style="width:12.5%;" | third
|-
! rowspan="6" class="roa-indicative-left-rail" | indicative
! class="roa-indicative-left-rail" |
! class="roa-indicative-left-rail" | jo
! class="roa-indicative-left-rail" | tu
! class="roa-indicative-left-rail" | lui/jê
! class="roa-indicative-left-rail" | nô
! class="roa-indicative-left-rail" | vô
! class="roa-indicative-left-rail" | lôr
|-
! class="roa-indicative-left-rail" style="height:3em;" | present
| o {{{pres_ind_1sg}}}
| tu {{{pres_ind_2sg}}}
| al/e {{{pres_ind_3sg}}}
| o {{{pres_ind_1pl}}}
| o {{{pres_ind_2pl}}}
| a {{{pres_ind_3pl}}}
|-
! class="roa-indicative-left-rail" style="height:3em;" | imperfect
| o {{{impf_ind_1sg}}}
| tu {{{impf_ind_2sg}}}
| al/e {{{impf_ind_3sg}}}
| o {{{impf_ind_1pl}}}
| o {{{impf_ind_2pl}}}
| a {{{impf_ind_3pl}}}
|-
! class="roa-indicative-left-rail" style="height:3em;" | simple past
| o {{{past_ind_1sg}}}
| tu {{{past_ind_2sg}}}
| al/e {{{past_ind_3sg}}}
| o {{{past_ind_1pl}}}
| o {{{past_ind_2pl}}}
| a {{{past_ind_3pl}}}
|-
! class="roa-indicative-left-rail" style="height:3em;" | future
| o {{{futr_ind_1sg}}}
| tu {{{futr_ind_2sg}}}
| al/e {{{futr_ind_3sg}}}
| o {{{futr_ind_1pl}}}
| o {{{futr_ind_2pl}}}
| a {{{futr_ind_3pl}}}
|-
! class="roa-indicative-left-rail" style="height:3em;" | conditional
| o {{{pres_con_1sg}}}
| tu {{{pres_con_2sg}}}
| al/e {{{pres_con_3sg}}}
| o {{{pres_con_1pl}}}
| o {{{pres_con_2pl}}}
| a {{{pres_con_3pl}}}
|-
! rowspan="3" class="roa-subjunctive-left-rail" | subjunctive
! class="roa-subjunctive-left-rail" |
! class="roa-subjunctive-left-rail" | jo
! class="roa-subjunctive-left-rail" | tu
! class="roa-subjunctive-left-rail" | lui/jê
! class="roa-subjunctive-left-rail" | nô
! class="roa-subjunctive-left-rail" | vô
! class="roa-subjunctive-left-rail" | lôr
|-
! class="roa-subjunctive-left-rail" style="height:3em;" | present
| o {{{pres_sub_1sg}}}
| tu {{{pres_sub_2sg}}}
| al/e {{{pres_sub_3sg}}}
| o {{{pres_sub_1pl}}}
| o {{{pres_sub_2pl}}}
| a {{{pres_sub_3pl}}}
|-
! class="roa-subjunctive-left-rail" style="height:3em;" | imperfect
| o {{{impf_sub_1sg}}}
| tu {{{impf_sub_2sg}}}
| al/e {{{impf_sub_3sg}}}
| o {{{impf_sub_1pl}}}
| o {{{impf_sub_2pl}}}
| a {{{impf_sub_3pl}}}
|-
! rowspan="3" colspan="2" class="roa-imperative-left-rail" | imperative
! class="roa-imperative-left-rail" | –
! class="roa-imperative-left-rail" | tu
! class="roa-imperative-left-rail" | –
! class="roa-imperative-left-rail" | nô
! class="roa-imperative-left-rail" | vô
! class="roa-imperative-left-rail" | –
|-
| –
| {{{imp_2sg}}}
| –
| {{{imp_1pl}}}
| {{{imp_2pl}}}
| –
|}
</div></div>]=]
	return require("Module:TemplateStyles")("Module:roa-verb/style.css") .. mw.ustring.gsub(wikicode, "{{{([a-z0-9_]+)}}}", repl)
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
