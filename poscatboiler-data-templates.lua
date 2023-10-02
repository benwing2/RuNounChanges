local labels = {}
local raw_categories = {}



-----------------------------------------------------------------------------
--                                                                         --
--                                  LABELS                                 --
--                                                                         --
-----------------------------------------------------------------------------


labels["templates"] = {
	description = "{{{langname}}} [[Wiktionary:Templates|templates]], containing reusable wiki code that help with creating and managing entries.",
	umbrella = {
		parents = {{name = "Templates", sort = " "}},
		breadcrumb = "by language",
	},
	parents = {{name = "{{{langcat}}}", raw = true}},
}

labels["auto-table templates"] = {
	description = "Templates that contain {{{langname}}} tables generated automatically.",
	additional = "They use the <code>table:</code> prefix. For example, see [[Template:table:chess pieces/en]].",
	parents = {"templates"},
}

labels["category boilerplate templates"] = {
	description = "Templates used to generate descriptions and categorization for category pages.",
	parents = {"templates"},
}

labels["definition templates"] = {
	description = "Templates used in the [[Wiktionary:Glossary#definition line|definition line]] of {{{langname}}} entries to help in creating definitions.",
	parents = {"templates"},
}

labels["entry templates"] = {
	description = "Templates used to help in the creation of {{{langname}}} entries.",
	umbrella_parents = {"Templates subcategories by language", "Entry templates"},
	parents = {"templates"},
}

labels["etymology templates"] = {
	description = "Templates used in the etymology section of {{{langname}}} entries.",
	parents = {"templates"},
}

labels["experimental templates"] = {
	description = "Templates used to test possible content for {{{langname}}} entries.",
	parents = {"templates"},
}

labels["form-of templates"] = {
	description = "Templates used on the definition line of entries for inflected forms of words in {{{langname}}}, to link back to the main form.",
	parents = {"templates"},
}

labels["headword-line templates"] = {
	description = "Templates used to show lines that contain headwords in {{{langname}}}.",
	parents = {"templates"},
}

labels["index templates"] = {
	description = "Templates used to organize {{{langname}}} indexes.",
	parents = {"templates"},
}

labels["inflection-table templates"] = {
	description = "Templates used to show inflection tables for {{{langname}}} terms.",
	parents = {"templates"},
}

-- Do particular types of inflection-table templates.
for _, pos in ipairs({
	"adjective",
	"adverb",
	"determiner",
	"nominal",
	"noun",
	"numeral",
	"participle",
	"postposition",
	"preposition",
	"pronoun",
	"verb",
}) do
	labels[pos .. " inflection-table templates"] = {
		description = "Templates used to show declension tables for {{{langname}}} " .. pos .. "s.",
		parents = {"inflection-table templates"},
	}
end

labels["list templates"] = {
	description = "Templates that contain {{{langname}}} lists.",
	additional = "They use the <code>list:</code> prefix. For example, see [[Template:list:Latin script letters/en]].",
	parents = {"templates"},
}

labels["mutation templates"] = {
	description = "Templates used to show mutation of {{{langname}}} words.",
	parents = {"templates"},
}

labels["quotation templates"] = {
	description = "Templates used to generate quotations for {{{langname}}} entries.",
	parents = {"templates"},
}

labels["reference templates"] = {
	topright = function(data)
		if data.lang and data.lang:getCode() == "ine-pro" then
			return "{{shortcut|WT:RTINE}}"
		end
	end,
	description = "Templates used to generate reference footnotes for {{{langname}}} entries.",
	parents = {"templates"},
}

labels["supplementary templates"] = {
	description = "Templates used to keep contents for other {{{langname}}} templates.",
	parents = {"templates"},
}

labels["usage templates"] = {
	description = "Templates used to show usage notes in {{{langname}}} entries.",
	parents = {"templates"},
}


-- Add 'umbrella_parents' key if not already present.
for key, data in pairs(labels) do
	if not data.umbrella_parents then
		data.umbrella_parents = "Templates subcategories by language"
	end
	-- Add breadcrumb by chopping off the parent from the end of the label, if possible.
	if #data.parents == 1 and type(data.parents[1]) == "string" then
		local parent_re = " " .. require("Module:utilities").pattern_escape(data.parents[1]) .. "$"
		if key:find(parent_re) then
			data.breadcrumb = key:gsub(parent_re, "")
		end
	end
end



-----------------------------------------------------------------------------
--                                                                         --
--                              RAW CATEGORIES                             --
--                                                                         --
-----------------------------------------------------------------------------


raw_categories["Templates"] = {
	topright = "{{shortcut|WT:T}}",
	description = "An organizing category intended for all templates in use on Wiktionary.",
	additional = "''See also: [[Wiktionary:Templates]], [[meta:Help:Template]]''",
	parents = {"Wiktionary"},
}

raw_categories["Administration templates"] = {
	description = "Templates used in the administration of Wiktionary.",
	additional = "They are only used outside of mainspace and are distinct from [[:Category:Maintenance templates|maintenance templates]], which are used in maintaining entries.",
	breadcrumb = "Administration",
	parents = {"Templates"},
}

raw_categories["Archive templates"] = {
	description = "Templates used on archived or otherwise inactive pages.",
	breadcrumb = "Archive",
	parents = {"Administration templates"},
}

raw_categories["Checkuser templates"] = {
	description = "Templates related to [[Wiktionary:Requests for checkuser|checkuser requests]].",
	breadcrumb = "Checkuser",
	parents = {"Administration templates"},
}

raw_categories["Editnotices"] = {
	description = "Templates used to display notices in edit mode.",
	parents = {"Administration templates"},
}

raw_categories["Appendix templates"] = {
	description = "Templates used in appendices or to link to appendices.",
	breadcrumb = "Appendix",
	parents = {"Templates", "Category:Appendices"},
}

raw_categories["Swadesh list templates"] = {
	description = "Templates used on pages that contain [[w:Swadesh list]]s.",
	breadcrumb = "Swadesh list",
	parents = {"Appendix templates"},
}

raw_categories["Auto-table templates"] = {
	description = "Templates used to generate word tables (like [[Template:table:seasons]]).",
	additional = "See also [[:Category:Auto-table templates by language]].",
	breadcrumb = "Auto-table",
	parents = {"Templates"},
}

raw_categories["Categorization templates"] = {
	preceding = "{{also|:Category:Category modules}}",
	description = "Templates used to categorize terms or entries.",
	additional = "([[:Category:Category templates]], on the other hand, contains templates used in the category namespace.)",
	breadcrumb = "Categorization",
	parents = {"Templates"},
}

raw_categories["Category templates"] = {
	description = "Templates used in the category namespace.",
	additional = "([[:Category:Categorization templates]], on the other hand, contains templates used to categorize pages.)",
	breadcrumb = "Category",
	parents = {"Templates"},
}

raw_categories["Category boilerplate templates"] = {
	description = "Templates used to generate the text of category pages.",
	breadcrumb = "Category boilerplate",
	parents = {"Category templates"},
}

raw_categories["TOC templates"] = {
	description = "Templates used to generate a list of linked letters to navigate the pages listed in categories.",
	breadcrumb = "TOC",
	parents = {"Category templates"},
}

raw_categories["Character insertion templates"] = {
	description = "Templates that provide easier ways to type characters that are not found in most keyboard layouts.",
	breadcrumb = "Character insertion",
	parents = {"Templates"},
}

-- Skipped: Concordance templates

raw_categories["Control flow templates"] = {
	description = "Templates to aid in control-flow constructs, which the template language is normally limited in.",
	breadcrumb = "Control flow",
	parents = {"Templates"},
}

raw_categories["Dictionary templates"] = {
	description = "Templates that are used primarily to create dictionary entries.",
	additional = "These are the pages to which [[WT:EL]] applies, i.e. the main and Reconstruction namespace.",
	breadcrumb = "Dictionary",
	parents = {"Templates"},
}

raw_categories["Audio templates"] = {
	description = "Templates used to play or request audio files.",
	breadcrumb = "Audio",
	parents = {"Dictionary templates"},
}

raw_categories["Character info templates"] = {
	description = "Templates that utilize {{temp|character info}}.",
	breadcrumb = "Character info",
	parents = {"Dictionary templates"},
}

raw_categories["Chess templates"] = {
	description = "Templates that display chess diagrams.",
	breadcrumb = "Chess",
	parents = {"Dictionary templates"},
}

raw_categories["Citation templates"] = {
	preceding = "{{ombox|type=speedy|text=Some templates may be marked '''FOR TESTING ONLY'''. Do not use these in entries, if requested on the template page itself. Take a look at the template page before using it.}}",
	description = "Templates used to generate citations and quotations.",
	additional = [=[
{{citation templates}}

==See also==
* [[Wiktionary:Quotations]]
* [[:Category:Reference templates]] for specific templates to well-known and widely used sources.]=],
	breadcrumb = "Citation",
	parents = {"Dictionary templates"},
}

raw_categories["Dating templates"] = {
	description = "Templates for displaying dates.",
	breadcrumb = "Dating",
	parents = {"Dictionary templates"},
}

raw_categories["Definition templates"] = {
	description = "Templates used in the [[Wiktionary:Glossary#definition line|definition line]] to help in creating definitions.",
	breadcrumb = "Definition",
	parents = {"Dictionary templates"},
}

raw_categories["Form-of templates"] = {
	description = "Templates used in defining inflections or variants of a given lemma.",
	breadcrumb = "Form-of",
	parents = {"Dictionary templates"},
}

raw_categories["Grammar form-of templates"] = {
	description = "Templates used in defining terms that stand in a particular grammatical relation to a given lemma.",
	breadcrumb = "Grammar",
	parents = {"Form-of templates"},
}

raw_categories["Conjugation form-of templates"] = {
	description = "Templates used in defining terms that represent particular verb forms (e.g. past participle) of given lemma.",
	breadcrumb = "Conjugation",
	parents = {"Grammar form-of templates"},
}

raw_categories["Declension form-of templates"] = {
	description = "Templates used in defining terms that represent particular noun or adjective forms (e.g. masculine plural) of given lemma.",
	breadcrumb = "Declension",
	parents = {"Grammar form-of templates"},
}

raw_categories["Name templates"] = {
	description = "Templates used in the [[Wiktionary:Glossary#definition line|definition line]] to help in creating definitions for names.",
	breadcrumb = "Name",
	parents = {"Definition templates"},
}

raw_categories["Object usage templates"] = {
	description = "Templates used in the [[Wiktionary:Glossary#definition line|definition line]] to show case and adposition usage for verb objects and similar constructs.",
	breadcrumb = "Object usage",
	parents = {"Definition templates"},
}

raw_categories["Entry templates"] = {
	description = "Templates used to help the creation of new entries.",
	breadcrumb = "Entry",
	parents = {"Dictionary templates"},
}

raw_categories["Etymology templates"] = {
	description = "Templates used in etymology sections to define the etymology of a term.",
	breadcrumb = "Etymology",
	parents = {"Dictionary templates"},
}

raw_categories["Foreign derivation templates"] = {
	description = "Templates used in etymology sections to indicate derivation from a different language than the language of the current entry.",
	breadcrumb = "Foreign derivation",
	parents = {"Etymology templates"},
}

raw_categories["Morphology templates"] = {
	description = "Templates used in etymology sections to specify the morphology of a term.",
	breadcrumb = "Morphology",
	parents = {"Etymology templates"},
}

raw_categories["Language-specific morphology templates"] = {
	description = "Specialized morphology templates used in the etymology sections of terms in particular languages.",
	breadcrumb = "Language-specific",
	parents = {"Morphology templates"},
}

raw_categories["Non-production templates and modules"] = {
	description = "Templates and modules not currently used in production.",
	additional = "{{also|Special:UnusedTemplates|Category:Unused templates}}",
	parents = {"Templates", "Modules", "Category:Wiktionary maintenance"},
}

raw_categories["Templates subcategories by language"] = {
	description = "Umbrella categories covering topics related to templates.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"Umbrella metacategories",
		{name = "templates", is_label = true, sort = " "},
	},
}


return {LABELS = labels, RAW_CATEGORIES = raw_categories}
