local tests = require("Module:UnitTests")
local m_pt_pronunc = require("Module:pt-pronunc")
local m_links = require("Module:links")
local m_table = require("Module:table")
local pt = require("Module:languages").getByCode("pt")

local rsplit = mw.text.split

local function tag_IPA(IPA)
	return '<span class="IPA">' .. IPA .. '</span>'
end

local function link(text)
	return m_links.full_link{ term = text, lang = pt }
end

local options = { display = tag_IPA }

local known_basic_style_list = {"rio", "sp", "lisbon", "cpt"}
local known_basic_styles = m_table.listToSet(known_basic_style_list)
local known_style_groups = {all = known_basic_style_list, br = {"rio", "sp"}, pt = {"lisbon", "cpt"}}

--[=[
In the following examples, each line is either a section header beginning with a # or an example.
Examples consist of tab-separated fields. The first field is the actual spelling of the term in question.
Each following field consists of a respelling associated with a particular style and the corresponding expected
IPA pronunciation. A style corresponds approximately to a particular dialect and is one of the following:

(1) A "basic style":
    * "rio" = Rio de Janeiro
    * "sp" = São Paulo
	* "lisbon" = Lisbon
	* "cpt" = Portugal outside of Lisbon
(2) A "combined style":
    * "br" = Brazil = "rio" + "sp"
	* "pt" = Portugal = "lisbon" + "cpt"
	* "all" = all basic styles
(3) A "style group", which is a list of hyphen-separated styles;
    * e.g. "br-cpt" = "br" + "cpt" = "rio" + "sp" + "cpt"

If a combined style or style group is specified, the respelling applies to all individual styles.

The format of a respelling field is RESPELLING:IPA (respelling associated with all styles) or STYLE=RESPELLING:IPA
(respelling associated with the specified style). If RESPELLING is omitted (but the colon kept), the term's original
spelling is used. IPA in turn is either a single expected IPA pronunciation (between /.../ to represent phonemic
pronunciation or between [...] to represent phonetic pronunciation), a style-tagged pronunciation of the form
STYLE=PRONUN, or a semicolon-separated list of style-tagged pronunciations.

Examples:

* Hungria	:[ũˈɡɾi.ɐ]
  This means the word [[Hungria]], respelled the same way (note the omitted respelling before the colon), has the
  expected phonetic pronunciation [ũˈɡɾi.ɐ] in all styles (dialects). The actual pronunciation for all styles will
  be generated, and the phonetic output of each in turn will be compared against [ũˈɡɾi.ɐ]. Phonemic output will
  not be checked.
* jogging	br=djógguing:/ˈd͡ʒɔ.ɡĩ/
  This means the word [[jogging]] has the respelling 'djógguing' and expected phonemic pronunciation /ˈd͡ʒɔ.ɡĩ/
  in all Brazilian styles. Portugal styles are omitted and will not be checked.
* abrangência	abrangêncya:br=/a.bɾɐ̃ˈʒẽ.sjɐ/;pt=[ɐ.βɾɐ̃ˈʒẽ.sjɐ]
  This means the word [[abrangência]] has the respelling 'abrangêncya' for all styles, which in turn has the
  expected phonemic pronunciation /a.bɾɐ̃ˈʒẽ.sjɐ/ in Brazil and expected phonetic pronunciation [ɐ.βɾɐ̃ˈʒẽ.sjɐ] in
  Portugal. The phonemic pronunciation for all Brazilian styles (Rio and São Paulo) will be checked against
  /a.bɾɐ̃ˈʒẽ.sjɐ/, and the phonetic pronunciation for all Portugal styles (Lisbon as well as non-Lisbon Central
  Portugal) will be checked against [ɐ.βɾɐ̃ˈʒẽ.sjɐ].
* ninguém	:br-cpt=/nĩˈɡẽj̃/;lisbon=/nĩˈɡɐ̃j̃/
  This means the word [[ninguém]], respelled the same way for all styles, has the phonemic pronunciation /nĩˈɡẽj̃/
  in all styles other than Lisbon, and /nĩˈɡɐ̃j̃/ in Lisbon.
* long neck	br=lòngh nécke,lòngue nécke:/ˌlõɡ ˈnɛ.ki/,/ˌlõ.ɡi ˈnɛ.ki/
  This means the term [[long neck]] has two possible respellings 'lòngh nécke' and 'lòngue nécke' in Brazil, with
  expected respective phonemic pronunciations /ˌlõɡ ˈnɛ.ki/ and /ˌlõ.ɡi ˈnɛ.ki/. Portugal styles will not be
  checked.
* distinguir	pt=distinguir:[diʃ.tĩˈɡiɾ]	br=distingüir:rio=[d͡ʒiʃ.t͡ʃĩˈɡwi(χ)];sp=[d͡ʒis.t͡ʃĩˈɡwi(ɾ)]
  This means the word [[distinguir]] has respelling 'distinguir' in Portugal with expected phonetic pronunciation
  [diʃ.tĩˈɡiɾ] in Portugal (both Lisbon and elsewhere in Central Portugal), but has the respelling 'distingüir'
  in Brazil. The Brazilian respelling has different phonetic pronunciations [d͡ʒiʃ.t͡ʃĩˈɡwi(χ)] in Rio and
  [d͡ʒis.t͡ʃĩˈɡwi(ɾ)] in São Paulo.
]=]
local examples = [[
# cc
cóccix	:/ˈkɔk.siks/
occitano	br=occitano:/ok.siˈtɐ̃.nu/
# d
adjetivo	:br=/ad.ʒeˈt͡ʃi.vu/
Reguengos de Monsaraz	:pt=[ʁɨˈɣẽ.ɡuʒ ðɨ mõ.sɐˈɾaʃ]
# ng
abrangência	abrangêncya:br=/a.bɾɐ̃ˈʒẽ.sjɐ/;pt=[ɐ.βɾɐ̃ˈʒẽ.sjɐ]
camping	br=câmping:/ˈkɐ̃.pĩ/
doping	br=dóping:/ˈdɔ.pĩ/
jogging	br=djógguing:/ˈd͡ʒɔ.ɡĩ/
Beijing	:br=/bejˈʒĩ/
Wellington	br=Wéllington:/ˈwɛ.lĩ.tõ/
Washington	br=Wóshington:/ˈwɔ.ʃĩ.tõ/
distinguir	pt=distinguir:[diʃ.tĩˈɡiɾ]	br=distingüir:rio=[d͡ʒiʃ.t͡ʃĩˈɡwi(χ)];sp=[d͡ʒis.t͡ʃĩˈɡwi(ɾ)]
Hungria	:[ũˈɡɾi.ɐ]
interrobang	pt=intẹrrobangue:/ĩ.tɛ.ʁuˈbɐ̃.ɡɨ/	br=interrobangue:/ĩ.te.ʁoˈbɐ̃.ɡi/
linguiça	lingu.iça,lingüiça:/lĩ.ɡuˈi.sɐ/,/lĩˈɡwi.sɐ/
long neck	br=lòngh nécke,lòngue nécke:/ˌlõɡ ˈnɛ.ki/,/ˌlõ.ɡi ˈnɛ.ki/
Los Angeles	br=Lộs Ângeles:sp=/loz ˈɐ̃.ʒe.lis/;rio=/loz ˈɐ̃.ʒe.liʃ/
ninguém	:br-cpt=/nĩˈɡẽj̃/;lisbon=/nĩˈɡɐ̃j̃/
single	br=síngol:/ˈsĩ.ɡow/
Stonehenge	sp=Stòwnn.rrendj:[ˌstownˈhẽd͡ʒ]
viking	br=víking,víkingue:/ˈvi.kĩ/,/ˈvi.kĩ.ɡi/
zângão	:/ˈzɐ̃.ɡɐ̃w̃/
# nh
banho	:br=/ˈbɐ̃.ɲu/;pt=/ˈbɐ.ɲu/
Congonhinhas	sp=Còngonhinhas:/ˌkõ.ɡõˈɲĩ.ɲɐs/
Congonhinhas	sp=Còngonhinhas:[ˌkõ.ɡõˈj̃ĩ.j̃ɐs]
nheengatu	br=nhengatu:/ɲẽ.ɡaˈtu/
# q
ablaquear	ablaquyar:pt=/ɐ.blɐˈkjaɾ/
acqua alta	:pt=/ˈa.kwɐ ˈal.tɐ/
freqüentemente	:br=/fɾeˌkwẽ.t͡ʃiˈmẽ.t͡ʃi/
obséquio	obzéquyo:br=/obˈzɛ.kju/
quando	:/ˈkwɐ̃.du/
que	:br=/ki/;pt=/kɨ/
québra-nózes	:pt=[ˈkɛ.βɾɐ ˈnɔ.zɨʃ]
qüiproquó	br=qüìproquó:/ˌkwi.pɾoˈkwɔ/
# s
cansar	:sp=/kɐ̃ˈsa(ɾ)/;rio=/kɐ̃ˈsa(ʁ)/;lisbon=/kɐ̃ˈsaɾ/
intransigente	:br=/ĩ.tɾɐ̃.ziˈʒẽ.t͡ʃi/;pt=/ĩ.tɾɐ̃.ziˈʒẽ.tɨ/
transação	:br=/tɾɐ̃.zaˈsɐ̃w̃/;pt=/tɾɐ̃.zɐˈsɐ̃w̃/
# y
Itamaraty	:br=/i.ta.ma.ɾaˈt͡ʃi/
Sydney	Sýdjney:br=/ˈsid͡ʒ.nej/
# -mente
afortunadamente	:rio=/a.foʁ.tuˌna.daˈmẽ.t͡ʃi/;sp=/a.foɾ.tuˌna.daˈmẽ.t͡ʃi/;pt=[ɐ.fuɾ.tuˌna.ðɐˈmẽ.tɨ]
alertamente	alértamente:rio=/aˌlɛʁ.taˈmẽ.t͡ʃi/;sp=/aˌlɛɾ.taˈmẽ.t͡ʃi/;pt=/ɐˌlɛɾ.tɐˈmẽ.tɨ/
anticristãmente	:rio=/ɐ̃.t͡ʃi.kɾiʃˌtɐ̃ˈmẽ.t͡ʃi/;sp=/ɐ̃.t͡ʃi.kɾisˌtɐ̃ˈmẽ.t͡ʃi/;pt=/ɐ̃.ti.kɾiʃˌtɐ̃ˈmẽ.tɨ/
comummente	comunmente:pt=/kuˌmũˈmẽ.tɨ/
dormente	dormênte:br=/doʁˈmẽ.t͡ʃi/;sp=/doɾˈmẽ.t͡ʃi/;pt=/duɾˈmẽ.tɨ/
posteriormente	posteriôrmente:rio=/poʃ.te.ɾiˌoʁˈmẽ.t͡ʃi/;sp=/pos.te.ɾiˌoɾˈmẽ.t͡ʃi/;pt=/puʃ.tɨˌɾjoɾˈmẽ.tɨ/
# -zinho
balãozinho	:br=/baˌlɐ̃w̃ˈzĩ.ɲu/
bauzinho	baúzinho:br=/baˌuˈzĩ.ɲu/
coraçãozinho	cồraçãozinho:br=/ˌko.ɾaˌsɐ̃w̃ˈzĩ.ɲu/
finalzinho	:br=/fiˌnawˈzĩ.ɲu/;pt=/fiˌnalˈzi.ɲu/
homenzinho	:br=/ˌõ.mẽj̃ˈzĩ.ɲu/
nenenzinho	nenénzinho:br=/neˌnẽj̃ˈzĩ.ɲu/
pobrezinho	póbrezinho:br=[ˌpɔ.bɾiˈzĩ.j̃u];pt=[ˌpɔ.βɾɨˈzi.ɲu]
sozinho	sózinho:br=/ˌsɔˈzĩ.ɲu/;pt=/ˌsɔˈzi.ɲu/
vizinho	br=vizínho:/viˈzĩ.ɲu/	pt=vizínho,vezínho:/viˈzi.ɲu/,/vɨˈzi.ɲu/ -- is /vɨˈzi.ɲu/ really a possibility for Portugal?
# double letters
Accra	:/ˈa.kɾɐ/
Aleppo	Aléppo:br=/aˈlɛ.pu/
buffer	bâfferh:rio=/ˈbɐ.feʁ/;sp=/ˈbɐ.feɾ/
cheddar	chéddarh:rio=/ˈʃɛ.daʁ/;sp=/ˈʃɛ.daɾ/
Hanna	br=Ranna:/ˈʁɐ̃.nɐ/
jazz	djézz:sp=/ˈd͡ʒɛs/;rio=/ˈd͡ʒɛʃ/
Minnesota	Mìnnessôta:br=/ˌmi.neˈso.tɐ/
nutella	nutélla:/nuˈtɛ.lɐ/
shopping	br=shópping,shóppem:/ˈʃɔ.pĩ/,/ˈʃɔ.pẽj̃/
Yunnan	:/juˈnɐ̃/
# multiword expressions
água mole em pedra dura tanto bate até que fura	água móle em pédra dura tanto bate até que fura:br=/ˈa.ɡwɐ ˈmɔ.li ẽj̃ ˈpɛ.dɾɐ ˈdu.ɾɐ ˈtɐ̃.tu ˈba.t͡ʃi aˈtɛ ki ˈfu.ɾɐ/;lisbon=[ˈa.ɣwɐ ˈmɔ.l(ɨ) ɐ̃j̃ ˈpɛ.ðɾɐ ˈðu.ɾɐ ˈtɐ̃.tu ˈβa.t(ɨ) ɐ.ˈtɛ kɨ ˈfu.ɾɐ]
era só o que me faltava	éra só o que me faltava:br=/ˈɛ.ɾɐ ˈsɔ u ki mi fawˈta.vɐ/
# nasal diphthongs
mães	:rio-pt=/ˈmɐ̃j̃ʃ/;sp=/ˈmɐ̃j̃s/
põem	põeem:br-cpt=/ˈpõj̃.ẽj̃/;lisbon=/ˈpõj̃.ɐ̃j̃/
pãozão	:/pɐ̃w̃ˈzɐ̃w̃/
# nasal vowels
ano	:br=/ˈɐ̃.nu/;pt=/ˈɐ.nu/
cama	:br=/ˈkɐ̃.mɐ/;pt=/ˈkɐ.mɐ/
entendo	:br=/ĩˈtẽ.du/;pt=/ẽˈtẽ.du/
falámos	:pt=/fɐˈla.muʃ/
Itapoã	:br=/i.ta.poˈɐ̃/
parabéns	:sp=/pa.ɾaˈbẽj̃s/;rio=/pa.ɾaˈbẽj̃ʃ/;lisbon=/pɐ.ɾɐˈbɐ̃j̃ʃ/;cpt=/pɐ.ɾɐˈbẽj̃ʃ/
também	:br-cpt=/tɐ̃ˈbẽj̃/;lisbon=/tɐ̃ˈbɐ̃j̃/
# syllable division
saiba	:/ˈsaj.bɐ/
peixe	:br=/ˈpej.ʃi/;cpt=/ˈpej.ʃɨ/;lisbon=/ˈpɐj.ʃɨ/
noite	:br=/ˈnoj.t͡ʃi/;pt=/ˈnoj.tɨ/
Paulo	:/ˈpaw.lu/
deusa	:/ˈdew.zɐ/
ouro	:/ˈo(w).ɾu/
Bombaim	:br=/bõ.baˈĩ/;pt=/bõ.bɐˈĩ/
Coimbra	:br=/koˈĩ.bɾɐ/
saindo	:br=/saˈĩ.du/;pt=/sɐˈĩ.du/
rainha	:br=/ʁaˈĩ.ɲɐ/;pt=/ʁɐˈi.ɲɐ/
moinho	br=moinho,muinho:/moˈĩ.ɲu/,/muˈĩ.ɲu/	pt=mwinho,mu.inho:/ˈmwi.ɲu/,/muˈi.ɲu/
sair	:rio=/saˈi(ʁ)/;sp=/saˈi(ɾ)/;pt=/sɐˈiɾ/
Iaundé	:br=/ja.ũˈdɛ/;pt=/jɐ.ũˈdɛ/
Raul	:br=/ʁaˈuw/;pt=/ʁɐˈul/
Jaime	:br=/ˈʒaj.mi/;pt=/ˈʒaj.mɨ/
queimar	:rio=/kejˈma(ʁ)/;sp=/kejˈma(ɾ)/;cpt=/kejˈmaɾ/;lisbon=/kɐjˈmaɾ/
fauna	:/ˈfaw.nɐ/
baile	:br=/ˈbaj.li/;pt=/ˈbaj.lɨ/
beira	:br-cpt=/ˈbej.ɾɐ/;lisbon=/ˈbɐj.ɾɐ/
saiu	:br=/saˈiw/;pt=/sɐˈiw/
saído	:br=/saˈi.du/;pt=/sɐˈi.du/
ia	:/ˈi.ɐ/
]]

function tests:check_ipa(spelling, expected, comment)
	local inputs = {}
	for style, expected_obj in pairs(expected) do
		inputs[style] = expected_obj.respellings
	end

	local expressed_styles = m_pt_pronunc.express_styles(inputs)
	for _, style_group in ipairs(expressed_styles) do
		for _, style_obj in ipairs(style_group.styles) do
			options.comment = style_obj.tag and style_obj.tag .. (comment and "; " .. comment or "") or comment or ""

			local function get_actual_ipas(ipa_type)
				local actual_ipas = {}
				for _, phonemic_phonetic in ipairs(style_obj.phonemic_phonetic) do
					local ipa = phonemic_phonetic[ipa_type]
					if ipa_type == "phonemic" then
						ipa = "/" .. ipa .. "/"
					else
						ipa = "[" .. ipa .. "]"
					end
					table.insert(actual_ipas, ipa)
				end
				return table.concat(actual_ipas, ",")
			end

			-- Check if all the styles represented by this particular actual IPA have the same expected IPA.
			-- If so, we can display a single test line (whether or not the actual and expected match).
			-- Otherwise, display each style individually.
			local matches = true
			local matching_respellings = nil
			local matching_expected_ipas = nil
			local matching_ipa_type = nil

			for _, represented_style in ipairs(style_obj.represented_styles) do
				if not expected[represented_style] then
					error("Internal error: Didn't generate IPA for style '" .. represented_style .. "'")
				end
				local this_respellings = table.concat(expected[represented_style].respellings, ",")
				local this_expected_ipas = table.concat(expected[represented_style].ipas, ",")
				local this_ipa_type = expected[represented_style].type
				if not matching_expected_ipas then
					matching_respellings = this_respellings
					matching_expected_ipas = this_expected_ipas
					matching_ipa_type = this_ipa_type
				elseif matching_respellings ~= this_respellings or matching_expected_ipas ~= this_expected_ipas or
					matching_ipa_type ~= this_ipa_type then
					matches = false
					break
				end
			end

			if matches then
				self:equals(
					link(spelling) .. (matching_respellings == spelling and "" or ", respelled " .. matching_respellings),
					get_actual_ipas(matching_ipa_type),
					matching_expected_ipas,
					options
				)
			else
				for _, represented_style in ipairs(style_obj.represented_styles) do
					if not expected[represented_style] then
						error("Internal error: Didn't generate IPA for style '" .. represented_style .. "'")
					end
					local this_respellings = table.concat(expected[represented_style].respellings, ",")
					local this_expected_ipas = table.concat(expected[represented_style].ipas, ",")
					local this_ipa_type = expected[represented_style].type
					options.comment = m_pt_pronunc.all_style_descs[represented_style] .. (comment and "; " .. comment or "")
					self:equals(
						link(spelling) .. (this_respellings == spelling and "" or ", respelled " .. this_respellings),
						get_actual_ipas(this_ipa_type),
						this_expected_ipas,
						options
					)
				end
			end
		end
	end
end

local function parse(examples)
	-- The following is a list of parsed examples where each element is a three-element list of
	-- {SPELLING, EXPECTED, COMMENT}. SPELLING is the actual spelling of the term; EXPECTED is a table giving
	-- the respellings and associated expected IPA, and COMMENT is an optional comment (if given starting with a
	-- # sign after a given line) or nil. EXPECTED is a table whose keys are basic styles, e.g. "rio", "lisbon",
	-- and values are a table with keys 'respellings' (one or more respellings), 'ipas' (corresponding IPA values)
	-- and 'type' ("phonemic" or "phonetic").
	local parsed_examples = {}
	-- Throw away comments starting with -- and snarf each line.
	for line in examples:gsub("%s*%-%-[^\n]*", ""):gmatch "[^\n]+" do
		-- Trim whitespace at beginning and end.
		line = line:gsub("^%s*(.-)%s*$", "%1")
		if line ~= "" then -- skip blank lines
			local function err(msg)
				error(msg .. ": " .. line)
			end
			local function rsplit2(term, regex)
				local splitvals = rsplit(term, regex)
				if #splitvals ~= 2 then
					err("Expected two parts in '" .. term .. "' when split by '" .. regex .. "'")
				end
				return splitvals
			end
			if line:find("^#") then
				-- Line beginning with # is a section header.
				line = line:gsub("^#%s*", "")
				table.insert(parsed_examples, line)
			else
				local function expand_styles(styles)
					local expansion = {}
					for _, style in ipairs(rsplit(styles, "%-")) do
						if known_basic_styles[style] then
							table.insert(expansion, style)
						elseif known_style_groups[style] then
							for _, basic in ipairs(known_style_groups[style]) do
								table.insert(expansion, basic)
							end
						else
							err("Unrecognized style '" .. style .. "'")
						end
					end
					return expansion
				end

				local parts = rsplit(line, "\t")
				local spelling = parts[1]
				local expected = {}
				local comment
				for i=2,#parts do
					local part = parts[i]
					if part:find("^#") then
						if i ~= #parts then
							err("Comment .. " .. part .. " should be last element on the line")
						end
						comment = part
						break
					end
					local respelling, styled_ipas = unpack(rsplit2(part, ":"))
					local styles
					if respelling:find("=") then
						styles, respelling = unpack(rsplit2(respelling, "="))
					else
						styles = "all"
					end
					if respelling == "" then
						respelling = spelling
					end
					respelling = rsplit(respelling, ",")
					styles = expand_styles(styles)
					local style_set = m_table.listToSet(styles)
					for _, styled_ipa in ipairs(rsplit(styled_ipas, ";")) do
						local ipa_styles, ipas
						if styled_ipa:find("=") then
							ipa_styles, ipas = unpack(rsplit2(styled_ipa, "="))
							ipa_styles = expand_styles(ipa_styles)
						else
							ipa_styles = styles
							ipas = styled_ipa
						end
						ipas = rsplit(ipas, ",")
						local ipa_type
						for _, ipa in ipairs(ipas) do
							local this_ipa_type
							if ipa:find("^/.*/$") then
								this_ipa_type = "phonemic"
							elseif ipa:find("^%[.*%]$") then
								this_ipa_type = "phonetic"
							else
								err("IPA " .. ipa .. " should be surrounded with /.../ or [...]")
							end
							if not ipa_type then
								ipa_type = this_ipa_type
							elseif ipa_type ~= this_ipa_type then
								err("All IPA values " .. table.concat(ipa, ",") ..
									" specified for this style should agree in being phonemic or phonetic")
							end
						end
						for _, ipa_style in ipairs(ipa_styles) do
							if not style_set[ipa_style] then
								err("Style '" .. ipa_style .. "' not listed among respelling styles " ..
									table.concat(styles, ","))
							end
							expected[ipa_style] = {respellings = respelling, ipas = ipas, type = ipa_type}
						end
					end
				end
				if not next(expected) then
					err("No expected pronunciations given")
				end
				table.insert(parsed_examples, {spelling, expected, comment})
			end
		end
	end
	return parsed_examples
end

function tests:test()
	self:iterate(parse(examples), "check_ipa")
end

return tests
