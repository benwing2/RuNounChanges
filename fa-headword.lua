local lang = require("Module:languages").getByCode("fa")

local export = {}

local u = mw.ustring.char
local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub

local A = u(0x064E) -- fatḥa
local AN = u(0x064B) -- fatḥatān (fatḥa tanwīn)
local U = u(0x064F) -- ḍamma
local I = u(0x0650) -- kasra
local SK = u(0x0652) -- sukūn = no vowel
local SH = u(0x0651) -- šadda = gemination of consonants
local ZWNJ = u(0x200C) -- ZERO WIDTH NON-JOINER

-----------------------
-- Utility functions --
-----------------------

-- version of mw.ustring.gsub() that discards all but the first return value
function rsub(term, foo, bar)
    local retval = rsubn(term, foo, bar)
    return retval
end


function export.ZWNJ(word)
    if rfind(word, "[بپتثجچحخسشصضطظعغفقکگلمنهی]", -1) then
        return ZWNJ
    end
    return "" -- empty string
end

-- Adjectives and adverbs share an inflection spec.
local function get_adj_adv_inflection_spec()
	return {
		{
			prefix = "c", label = "comparative",
			-- We need translits generated if not explicitly given.
			expand_tr_in_generate = true,
			generate_default_from_head = function(data)
				return {
					term = data.term .. export.ZWNJ(data.term) .. "ت" .. A .. "ر",
					translit = data.tr and data.tr .. "-tar" or nil,
					accel = {form = "compararative"},
				}
			end,
		},
		{
			prefix = "s", label = "superlative",
			default = function(data)
				-- There's a default superlative if any comparatives were given.
				-- The default spec is normally "+" so we don't have to specify it explicitly.
				if #data.args.c > 0 then
					return "+"
				end
			end,
			-- We need translits generated if not explicitly given.
			expand_tr_in_generate = true,
			generate_default_from_head = function(data)
				return {
					term = data.term .. export.ZWNJ(data.term) .. "ت" .. A .. "رین",
					translit = data.tr and data.tr .. "-tarin" or nil,
					accel = {form = "superlative"},
				}
			end,
		},
	}
end

-- Nouns and proper nouns share an inflection spec.
local function get_noun_proper_noun_inflection_spec()
	return {
		{
			prefix = "pl", label = "plural",
			make_inflections = function(data)
				for _, infl in ipairs(data.user_inflections) do
					-- If translit not specified, try to generate it automatically from the head and its translit by
					-- looking for common patterns (this is also what the old {{fa-noun}} template did). It gets a bit
					-- tricky because there may be more than one head translit. We try to generate entries corresponding
					-- to all matching heads; if none match we insert a single entry without translit.
					local any_inserted = false
					if not infl.tr then
						for _, headobj in ipairs(data.headdata.heads) do
							local tr
							local pl = infl.term
							local headtr = head.tr
							local headfa = head.term
							if pl == headfa .. "ها" then
								tr = headtr .. "-hâ"
							elseif pl == headfa .. "ات" then
								tr = headtr .. "ât"
							elseif pl == headfa .. "ان" then
								tr = headtr .. "ân"
							elseif pl == headfa .. "یان" then
								tr = headtr .. "yân"
							end
							if tr then
								local clone = data.clone_infl(infl)
								clone.tr = tr
								table.insert(data.inflections, clone)
								any_inserted = true
							end
						end
					end
					if not any_inserted then
						-- Either the user-specified inflection already has a translit or we couldn't generate a
						-- translit from the head translit. In both cases, just copy the user-specified inflection.
						table.insert(data.inflections, infl)
					end
				end
			end,
		},
	}
end

-- The main entry point.
function export.show(frame)
	require("Module:headword utilities").show_headword {
		lang = "fa",
		tr = true,
		enable_inflection_auto_translit = true,
		head_param = {
			param = "head",
			aliases = {
				{1}
			},
		},
		pos = {
			["verbs"] = {
				inflections = {
					{prefix = "prstem", label = "present stem"},
				},
			},
			["nouns"] = {
				inflections = get_noun_proper_noun_inflection_spec(),
			},
			["proper nouns"] = {
				inflections = get_noun_proper_noun_inflection_spec(),
			},
			["adjectives"] = {
				inflections = get_adj_adv_inflection_spec(),
			},
			["adverbs"] = {
				inflections = get_adj_adv_inflection_spec(),
			},
		},
	}
end

return export
