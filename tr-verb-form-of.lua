local export = {}

local m_harmony = require("Module:tr-harmony")
local m_form_of = require("Module:form of")

local lang = require("Module:languages").getByCode("tr")

function export.show(frame)
   	local args = require "Module:parameters".process(frame:getParent().args, {
		[1] = { required = true },
		["title"] = { default = nil },
	})

	local lemma = args[1]
	local title = args["title"] or mw.title.getCurrentTitle().text
	if not mw.ustring.match(lemma, "m[ae]k$") then
		error("lemma form must end in -mak or -mek")
	end
	
	local stem = lemma:sub(1, -4)
	local soft_stem = m_harmony.soften(stem)
	local has_soft_stem = stem ~= soft_stem
	
	local stem_last_word = mw.ustring.match(stem, "(%w+)$")
	local one_syllable = not mw.ustring.match(stem_last_word, "[" .. m_harmony.vowels .. "][^" .. m_harmony.vowels .. "]+[" .. m_harmony.vowels .. "]")
	local etmek_style = mw.ustring.match(stem, "et$")
	local could_have_2_way_aorist = one_syllable or etmek_style

	forms = {}
	local lemma_obj = {
		lang = lang,
		term = lemma,
	}
	
	function add_form_to_base(base, suffixes, tags)
		suffixed = m_harmony.attach_suffixes(base, suffixes, nil, could_have_2_way_aorist, true)
		for _, form in ipairs(suffixed) do
			forms[form] = tags
		end
	end
	function add_form(suffixes, tags)
		add_form_to_base(stem, suffixes, tags)
		if has_soft_stem then -- here, more checks could potentially be added based on the suffixes
			add_form_to_base(soft_stem, suffixes, tags)
		end
	end
	
	-- imperative
	add_form("",         { "2", "s", "imp" })
	add_form("sIn",      { "3", "s", "imp" })
	add_form("YIn",      { "2", "p", "imp" })
	add_form("YInIz",    { "polite", "2", "p", "imp" })
	add_form("sInlAr",   { "3", "p", "imp" })
	add_form("mA",       { "2", "s", "neg", "imp" })
	add_form("mAsIn",    { "3", "s", "neg", "imp" })
	add_form("mAyIn",    { "2", "p", "neg", "imp" })
	add_form("mAyInIz",  { "polite", "2", "p", "neg", "imp" })
	add_form("mAsInlAr", { "3", "p", "neg", "imp" })
	
	-- indicative
	--- aorist
	add_form("RIm",    { "1", "s", "ind", "aor" })
	add_form("RsIn",   { "2", "s", "ind", "aor" })
	add_form("R",      { "3", "s", "ind", "aor" })
	add_form("RIz",    { "1", "p", "ind", "aor" })
	add_form("RsInIz", { "2", "p", "ind", "aor" })
	add_form("RlAr",   { "3", "p", "ind", "aor" })
	
	add_form("mAm",      { "1", "s", "ind", "neg", "aor" })
	add_form("mAzsIn",   { "2", "s", "ind", "neg", "aor" })
	add_form("mAz",      { "3", "s", "ind", "neg", "aor" })
	add_form("mAyIz",    { "1", "p", "ind", "neg", "aor" })
	add_form("mAzsInIz", { "2", "p", "ind", "neg", "aor" })
	add_form("mAzlAr",   { "3", "p", "ind", "neg", "aor" })
	
	--- simple past
	add_form("DIm",   { "1", "s", "ind", "simple past" })
	add_form("DIn",   { "2", "s", "ind", "simple past" })
	add_form("DI",    { "3", "s", "ind", "simple past" })
	add_form("DIk",   { "1", "p", "ind", "simple past" })
	add_form("DInIz", { "2", "p", "ind", "simple past" })
	add_form("DIlAr", { "3", "p", "ind", "simple past" })
	
	add_form("mAdIm",   { "1", "s", "ind", "neg", "simple past" })
	add_form("mAdIn",   { "2", "s", "ind", "neg", "simple past" })
	add_form("mAdI",    { "3", "s", "ind", "neg", "simple past" })
	add_form("mAdIk",   { "1", "p", "ind", "neg", "simple past" })
	add_form("mAdInIz", { "2", "p", "ind", "neg", "simple past" })
	add_form("mAdIlAr", { "3", "p", "ind", "neg", "simple past" })
	
	--- future
	add_form("YAcAğIm",    { "1", "s", "ind", "fut" })
	add_form("YAcAksIn",   { "2", "s", "ind", "fut" })
	add_form("YAcAk",      { "3", "s", "ind", "fut" })
	add_form("YAcAğIz",    { "1", "p", "ind", "fut" })
	add_form("YAcAksInIz", { "2", "p", "ind", "fut" })
	add_form("YAcAklAr",   { "3", "p", "ind", "fut" })
	
	add_form("mAyAcAğIm",    { "1", "s", "ind", "neg", "fut" })
	add_form("mAyAcAksIn",   { "2", "s", "ind", "neg", "fut" })
	add_form("mAyAcAk",      { "3", "s", "ind", "neg", "fut" })
	add_form("mAyAcAğIz",    { "1", "p", "ind", "neg", "fut" })
	add_form("mAyAcAksInIz", { "2", "p", "ind", "neg", "fut" })
	add_form("mAyAcAklAr",   { "3", "p", "ind", "neg", "fut" })
    --- participles
    add_form("YAn",           { "present", "participle"})
    --- gerunds
    add_form("YArAk",         { "gerund" })
    add_form("Ip",           { "gerund" })
	
	tags = forms[title]
	if tags then
		local categories = m_form_of.fetch_lang_categories(lang, tags, lemma_obj, "verb")
		return m_form_of.tagged_inflections({ lang = lang, tags = tags, lemmas = {lemma_obj}, lemma_face = "term" }) ..
			require("Module:utilities").format_categories(categories, lang) -- , args["sort"] needed?
	else
		error("unknown verb form")
	end
end

return export
