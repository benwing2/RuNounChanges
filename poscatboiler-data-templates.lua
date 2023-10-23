local labels = {}
local raw_categories = {}



-----------------------------------------------------------------------------
--                                                                         --
--                                  LABELS                                 --
--                                                                         --
-----------------------------------------------------------------------------


labels["templates"] = {
	description = "{{{langname}}} [[Wiktionary:Templates|templates]], which contain reusable wiki code that helps with creating and managing entries.",
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

labels["pronunciation templates"] = {
	description = "Templates used to generate IPA pronunciation, rhymes, hyphenation, etc. for {{{langname}}} entries.",
	umbrella_parents = {"Templates subcategories by language", "Category:Pronunciation templates"},
	parents = {"templates"},
}

labels["quotation templates"] = {
	description = "Templates used to generate quotations for {{{langname}}} entries.",
	umbrella_parents = {"Templates subcategories by language", "Category:Citation templates"},
	parents = {"templates"},
}

labels["reference templates"] = {
	topright = function(data)
		if data.lang and data.lang:getCode() == "ine-pro" then
			return "{{shortcut|WT:RTINE}}"
		end
	end,
	umbrella = {
		preceding = "{{also|Wiktionary:Reference templates}}\n{{also|Template:refcat}}",
		parents = {"Templates subcategories by language", "Category:Reference templates"},
		breadcrumb = "by language",
	},
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
	if not data.umbrella and not data.umbrella_parents then
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
	parents = {"Templates"},
}

raw_categories["Archive templates"] = {
	description = "Templates used on archived or otherwise inactive pages.",
	parents = {"Administration templates"},
}

raw_categories["Checkuser templates"] = {
	description = "Templates related to [[Wiktionary:Requests for checkuser|checkuser requests]].",
	parents = {"Administration templates"},
}

raw_categories["Editnotices"] = {
	description = "Templates used to display notices in edit mode.",
	parents = {"Administration templates"},
}

raw_categories["Appendix templates"] = {
	description = "Templates used in appendices or to link to appendices.",
	parents = {"Templates", "Category:Appendices"},
}

raw_categories["Swadesh list templates"] = {
	description = "Templates used on pages that contain [[w:Swadesh list]]s.",
	parents = {"Appendix templates"},
}

raw_categories["Auto-table templates"] = {
	description = "Templates used to generate word tables (like [[Template:table:seasons]]).",
	additional = "See also [[:Category:Auto-table templates by language]].",
	parents = {"Templates"},
}

raw_categories["Categorization templates"] = {
	preceding = "{{also|:Category:Category modules}}",
	description = "Templates used to categorize terms or entries.",
	additional = "([[:Category:Category templates]], on the other hand, contains templates used in the category namespace.)",
	parents = {"Templates"},
}

raw_categories["Category templates"] = {
	description = "Templates used in the category namespace.",
	additional = "([[:Category:Categorization templates]], on the other hand, contains templates used to categorize pages.)",
	parents = {"Templates"},
}

raw_categories["Category boilerplate templates"] = {
	description = "Templates used to generate the text of category pages.",
	parents = {"Category templates"},
}

raw_categories["TOC templates"] = {
	description = "Templates used to generate a list of linked letters to navigate the pages listed in categories.",
	parents = {"Category templates"},
}

raw_categories["Character insertion templates"] = {
	description = "Templates that provide easier ways to type characters that are not found in most keyboard layouts.",
	parents = {"Templates"},
}

-- Skipped: Concordance templates

raw_categories["Control flow templates"] = {
	description = "Templates to aid in control-flow constructs, which the template language is normally limited in.",
	parents = {"Templates"},
}

raw_categories["Dictionary templates"] = {
	description = "Templates that are used primarily to create dictionary entries.",
	additional = "These are the pages to which [[WT:EL]] applies, i.e. the main and Reconstruction namespace.",
	parents = {"Templates"},
}

raw_categories["Audio templates"] = {
	description = "Templates used to play or request audio files.",
	parents = {"Dictionary templates"},
}

raw_categories["Character info templates"] = {
	description = "Templates that utilize {{temp|character info}}.",
	parents = {"Dictionary templates"},
}

raw_categories["Chess templates"] = {
	description = "Templates that display chess diagrams.",
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
	parents = {"Dictionary templates"},
}

raw_categories["Dating templates"] = {
	description = "Templates for displaying dates.",
	parents = {"Dictionary templates"},
}

raw_categories["Definition templates"] = {
	description = "Templates used in the [[Wiktionary:Glossary#definition line|definition line]] to help in creating definitions.",
	parents = {"Dictionary templates"},
}

raw_categories["Form-of templates"] = {
	description = "Templates used in defining inflections or variants of a given lemma.",
	parents = {"Definition templates"},
}

raw_categories["Grammar form-of templates"] = {
	description = "Templates used in defining terms that stand in a particular grammatical relation to a given lemma.",
	parents = {"Form-of templates"},
}

raw_categories["Conjugation form-of templates"] = {
	description = "Templates used in defining terms that represent particular verb forms (e.g. past participle) of given lemma.",
	parents = {"Grammar form-of templates"},
}

raw_categories["Declension form-of templates"] = {
	description = "Templates used in defining terms that represent particular noun or adjective forms (e.g. masculine plural) of given lemma.",
	parents = {"Grammar form-of templates"},
}

raw_categories["Name templates"] = {
	description = "Templates used in the [[Wiktionary:Glossary#definition line|definition line]] to help in creating definitions for names.",
	parents = {"Definition templates"},
}

raw_categories["Object usage templates"] = {
	description = "Templates used in the [[Wiktionary:Glossary#definition line|definition line]] to show case and adposition usage for verb objects and similar constructs.",
	parents = {"Definition templates"},
}

raw_categories["Place name templates"] = {
	description = "Templates used in defining place names or demonyms that refer to place names.",
	parents = {"Definition templates"},
}

raw_categories["Entry templates"] = {
	description = "Templates used to help create new entries.",
	parents = {"Dictionary templates"},
}

raw_categories["Etymology templates"] = {
	description = "Templates used in etymology sections to define the etymology of a term.",
	parents = {"Dictionary templates"},
}

raw_categories["Foreign derivation templates"] = {
	description = "Templates used in etymology sections to indicate derivation from a different language than the language of the current entry.",
	parents = {"Etymology templates"},
}

raw_categories["Morphology templates"] = {
	description = "Templates used in etymology sections to specify the morphology of a term.",
	parents = {"Etymology templates"},
}

raw_categories["Language-specific morphology templates"] = {
	description = "Specialized morphology templates used in the etymology sections of terms in particular languages.",
	parents = {"Morphology templates"},
}

raw_categories["Headword-line templates"] = {
	preceding = "{{also|Wiktionary:Headword-line templates}}",
	description = "Templates used to define the [[Wiktionary:Glossary#headword line|headword line]] of a term.",
	parents = {"Dictionary templates"},
}

raw_categories["Language attestation warning templates"] = {
	description = "Templates that warn users about the attestation status of entries or senses from a language.",
	parents = {"Dictionary templates"},
}

raw_categories["Pronunciation templates"] = {
	description = "Templates used to format pronunciation sections and the characters they use.",
	additional = "See also [[:Category:Script templates]] and [[Wiktionary:Pronunciation]].",
	parents = {"Dictionary templates"},
}

raw_categories["Rhyme templates"] = {
	description = "Templates used to format [[Wiktionary:Rhymes|rhyme pages]], links to them from pronunciation sections, etc.",
	parents = {"Pronunciation templates"},
}

raw_categories["Redirect templates"] = {
	description = "Templates used to format redirect pages.",
	parents = {"Dictionary templates"},
}

raw_categories["Reference templates"] = {
	preceding = "{{also|Wiktionary:Reference templates|:Category:Reference templates by language}}",
	description = "Templates used to format references.",
	parents = {"Dictionary templates"},
}

raw_categories["Reference templates"] = {
	description = "Templates that are placed below the [[Wiktionary:Glossary#definition line|definition line]], to indicate other terms semantically related to a particular sense.",
	parents = {"Dictionary templates"},
}

raw_categories["Sign-language templates"] = {
	description = "Templates used to format sign-language pronunciation charts.",
	parents = {"Dictionary templates"},
}

raw_categories["Taxonomy templates"] = {
	description = "Templates used in Translingual taxonomy entries and in reference to those entries.",
	parents = {"Dictionary templates"},
}

raw_categories["Taxonomic hypernym templates"] = {
	description = "Templates containing text to appear under the Hypernyms header for taxonomic name entries.",
	additional = "Each template has the name of the taxon from which it begins. The taxonomy ends at a taxon with a name close to one a normal human could understand, e.g. [[Insecta]], [[Vertebrata]], [[Plantae]], [[Fungi]], etc.",
	breadcrumb = "Hypernym",
	parents = {"Taxonomy templates"},
}

raw_categories["Taxonomic name templates"] = {
	description = "Templates used for the presentation of taxonomic names on a definition line.",
	breadcrumb = "Name",
	parents = {"Taxonomy templates", "Definition templates"},
}

raw_categories["Taxonomic reference templates"] = {
	description = "Templates used to format references for taxonomic names.",
	breadcrumb = "Reference",
	parents = {"Taxonomy templates", "Reference templates"},
}

raw_categories["Templates with acceleration"] = {
	description = "Templates can be added to this category by adding {{tl|isAccelerated}} to their documentation pages.",
	additional = "Presence in this category indicates that at least some of the \"form-of\" entries for the word can be generated semi-automatically by users with [[Wiktionary:ACCEL|accelerated]] editing enabled.",
	parents = {"Dictionary templates"},
}

raw_categories["Translation templates"] = {
	description = "Templates used to format entries in and parts of translation tables.",
	parents = {"Dictionary templates"},
}

raw_categories["Discussion templates"] = {
	description = "Templates intended for use only in discussions and documentation of templates and modules.",
	parents = {"Templates"},
}

raw_categories["Monthly-subpages discussion room infrastructure"] = {
	description = "Templates used in generating and maintaining monthly discussion forums such as the [[Wiktionary:Grease pit|Grease pit]] and [[Wiktionary:Beer parlour|Beer parlour]].",
	parents = {"Discussion templates"},
}

raw_categories["Documentation templates"] = {
	description = "Templates used on template and module documentation pages.",
	parents = {"Templates"},
}

raw_categories["File templates"] = {
	description = "Templates used in the File namespace, primarily to indicate licensing restrictions.",
	parents = {"Templates"},
}

raw_categories["Layout templates"] = {
	description = "Templates used in laying out tables and columns.",
	parents = {"Templates"},
}

raw_categories["Column templates"] = {
	preceding = "{{also|Wiktionary:Templates#Columns}}",
	description = "Templates used in laying out lists in columns.",
	parents = {"Layout templates"},
}

raw_categories["Table templates"] = {
	description = "Templates used in formatting tables.",
	parents = {"Layout templates"},
}

raw_categories["Link templates"] = {
	description = "Templates used to link to other terms, to other MediaWiki projects or to external websites.",
	parents = {"Templates"},
}

raw_categories["Disambiguation templates"] = {
	description = "Templates used to disambiguate multiple similar terms.",
	parents = {"Link templates"},
}

raw_categories["External link templates"] = {
	description = "Templates that link to websites outside of the MediaWiki Foundation purview.",
	additional = "See also [[:Category:Citation templates]] for others.",
	parents = {"Link templates"},
}

-- FIXME! This doesn't belong and the templates in it should be deleted (they are in [[WT:RFDO]] currently).
raw_categories["Greek link templates"] = {
	description = "Templates which link between Greek entries.",
	parents = {
		{name = "templates", is_label = true, lang = require("Module:languages").getByCode("el", true), sort = "link"},
		"Link templates",
	},
}

raw_categories["Internal link templates"] = {
	description = "Templates that link between Wiktionary entries.",
	parents = {"Link templates"},
}

raw_categories["Interwiki templates"] = {
	description = "Templates that link to other MediaWiki projects.",
	parents = {"Link templates"},
}

raw_categories["List templates"] = {
	description = "Templates used to generate lists.",
	additional = "See also [[:Category:List templates by language]].",
	parents = {"Templates"},
}

raw_categories["Character list templates"] = {
	description = "Templates used to generate lists of characters.",
	parents = {"List templates"},
}

raw_categories["Lua-free templates"] = {
	description = "Lua-free (i.e. \"lite\") versions of templates that use Lua.",
	additional = "Lua-free templates are used on long pages to avoid [[Wiktionary:Lua memory errors|Lua memory errors]].",
	parents = {"Templates"},
}

raw_categories["Maintenance templates"] = {
	preceding = "{{also|Wiktionary:Maintenance templates}}",
	description = "Templates used in the maintenance of Wiktionary entries and other pages.",
	additional = "They are distinct from [[:Category:Administration templates|administration templates]], which are only used outside of mainspace.",
	parents = {"Templates"},
}

raw_categories["Navigation templates"] = {
	description = "Templates used to create navigation boxes for easily linking to other similar pages.",
	parents = {"Templates"},
}

raw_categories["Number templates"] = {
	description = "Templates used to convert numbers or generate boxes describing numbers in a given language.",
	parents = {"Templates"},
}

raw_categories["Cleanup templates"] = {
	description = "Templates used to request cleanup of entries.",
	additional = "Some of these templates are used when entries are batch-imported from another source.",
	parents = {"Maintenance templates"},
}

raw_categories["Deletion templates"] = {
	description = "Templates used to request deletion of entries.",
	parents = {"Maintenance templates"},
}

raw_categories["Verification templates"] = {
	description = "Templates used to request verification of entries that may be incorrect.",
	parents = {"Maintenance templates"},
}

raw_categories["Wiktionary templates"] = {
	description = "Templates used in the internal operation of Wiktionary.",
	parents = {"Templates", "Wiktionary"},
}

raw_categories["Metatemplates"] = {
	description = "Templates used in other templates or to create other templates.",
	parents = {"Templates"},
}

raw_categories["String manipulation templates"] = {
	description = "Templates used to manipulate strings.",
	additional = "See also [[Module:string]], which can be invoked from templates to do string manipulation.",
	parents = {"Metatemplates"},
}

raw_categories["WOTD templates"] = {
	description = "Templates used to support the Word of the Day.",
	parents = {"Wiktionary templates"},
}

raw_categories["FWOTD templates"] = {
	description = "Templates used to support the Foreign Word of the Day.",
	parents = {"WOTD templates"},
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

-- Add breadcrumb by chopping off the parent (or the parent's parent, etc.) from the end of the label, if possible.
for key, data in pairs(raw_categories) do
	local parent = data.parents[1]
	while true do
		if type(parent) == "string" then
			local parent_re = " " .. require("Module:utilities").pattern_escape(mw.getContentLanguage():lcfirst(parent)) .. "$"
			if key:find(parent_re) then
				data.breadcrumb = key:gsub(parent_re, "")
				break
			end
			if raw_categories[parent] then
				parent = raw_categories[parent].parents[1]
			else
				break
			end
		else
			break
		end
	end
end


return {LABELS = labels, RAW_CATEGORIES = raw_categories}
