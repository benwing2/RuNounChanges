--[[

	TODO: Decide on whether we want the Northern Borderlands dialect.
		The general consensus is to including it by doing the consonant subsitution and put the transcription in brackets
		Also the SBD should be included

--]]

local export = {};

local c_s = string.format;

local function is_str(v) return type(v) == 'string'; end

--[[
	As can be seen from the last lines of the function, this returns a table of transcriptions,
	and if do_hyph, also a string being the hyphenation. These are based on a single spelling given,
	so the reason why the transcriptions are multiple is only because of the -yka alternating stress
	et sim. This only accepts single-word terms. Multiword terms are handled by multiword().
--]]
local function phonemic(text, do_hyph, lang, is_prep, period)

	local ante = 0;
	local unstressed = is_prep or false;
	local colloquial = true;

	function rsub(s, r)
		text, c = mw.ustring.gsub(text, s, r);
		return c > 0;
	end
	function lg(s) return s[lang] or s[1]; end
	function rfind(s) return mw.ustring.find(text, s); end

	-- Save indices of uppercase characters before setting everything lowercase.
	local uppercase_indices;
	if (do_hyph) then
		uppercase_indices = {};
		local capitals = c_s('[A-Z%s]', lg {
			pl = 'ĄĆĘŁŃÓŚŹŻ',
			mpl = 'ĄÁÅĆĘÉŁḾŃÓṔŚẂŹŻ',
			szl = 'ÃĆŁŃŌŎÔÕŚŹŻ',
		});
		if (rfind(capitals)) then
			local i = 1;
			local str = mw.ustring.gsub(text, "[.']", '');
			while (mw.ustring.find(str, capitals, i)) do
				local r, _ = mw.ustring.find(str, capitals, i);
				table.insert(uppercase_indices, r);
				i = r + 1;
			end
		end
		if (#uppercase_indices == 0) then
			uppercase_indices = nil;
		end
	end

	text = mw.ustring.lower(text);

	-- Prevent palatisation of the special case kwazi-.
	rsub('^kwazi', 'kwaz-i');

	-- falling diphthongs <au> and <eu>, and diacriticised variants
	rsub(lg { '([ae])u', mpl = '([aáåeé])u' }, '%1U');

	-- rising diphthongs with <iV>
	local V = lg { pl = 'aąeęioóuy', mpl = 'aąáåeęéioóuy', szl = 'aãeéioōŏôõuy' };
	rsub(c_s('([^%s])i([%s])', V, V), '%1I%2');

	if (text:find('^*')) then
		-- The symbol <*> before a word indicates it is unstressed.
		unstressed = true;
		text = text:sub(2);
	elseif (text:find('^%^+')) then
		-- The symbol <^> before a word indicates it is stressed on the ante-penult,
		-- <^^> on the ante-ante-penult, etc.
		ante = text:gsub('(%^).*', '%1'):len();
		text = text:sub(ante + 1);
	elseif (text:find('^%+')) then
		-- The symbol <+> indicates the word is stressed regularly on the penult. This is useful
		-- for avoiding the following checks to come into place.
		text = text:sub(2);
	else
		if (rfind('.+[łlb][iy].+')) then
			-- Some words endings trigger stress on the ante-penult or ante-ante-penult regularly.
			if (rfind('liśmy$') or rfind('[bł]yśmy$') or rfind('liście$') or rfind('[bł]yście$')) then
				ante = 2;
			elseif (rfind('by[mś]?$') and not rfind('ła?by[mś]?$')) then
				ante = 1;
				colloquial = false;
			end
		end
		if (rfind('.+[yi][kc].+')) then
			local endings = lg {
				{ 'k[aąęio]', 'ce', 'kach', 'kom' },
				szl = { 'k[aãio]', 'ce', 'kacj', 'kōm' }
			};
			for _, v in ipairs(endings) do
				if (rfind(c_s('[yi]%s$', v))) then
					ante = 1;
				end
			end
		end
		if (lang ~= 'pl') then
			if (rfind('.+[yi]j.+')) then
				local endings = lg {
					mpl = { '[ąåéo]', '[ée]j', '[áo]m', 'ach' },
					szl = { '[ŏeiõo]', 'ōm', 'ach' },
				}
				for _, v in ipairs(endings) do
					if (rfind(c_s('[yi]j%s$', v))) then
						ante = 1;
					end
				end
			end
		end
	end

	-- TODO: mpl and szl
	if (not text:find('%.')) then
		-- Don't recognise affixes whenever there's only one vowel (or dipthong).
		local _, n_vowels = mw.ustring.gsub(text, c_s('[%s]', V), '');
		if (n_vowels > 1) then

			-- syllabify common prefixes as separate
			local prefixes = {
				'do', 'wy', 'za', 'aktyno', 'akusto', 'akwa', 'anarcho', 'andro', 'anemo', 'antropo', 'arachno', 'archeo', 'archi', 'arcy', 'areo', 'arytmo', 'audio', 'awio', 'balneo', 'biblio', 'brachy', 'broncho', 'ceno', 'centro', 'centy', 'chalko', 'chiro', 'chloro', 'chole', 'chondro', 'choreo', 'chromato', 'chrysto', 'cyber', 'cyklo', 'cztero', 'ćwierć', 'daktylo', 'decy', 'deka', 'dendro', 'dermato', 'diafano', 'dwu', 'dynamo', 'egzo', 'ekstra', 'elektro', 'encefalo', 'endo', 'entero', 'entomo', 'ergo', 'erytro', 'etno', 'farmako', 'femto', 'ferro', 'fizjo', 'flebo', 'franko', 'ftyzjo', 'galakto', 'galwano', 'germano', 'geronto', 'giganto', 'giga', 'gineko', 'giro', 'gliko', 'gloso', 'glotto', 'grafo', 'granulo', 'grawi', 'haplo', 'helio', 'hemato', 'hepta', 'hetero', 'hiper', 'histo', 'hydro', 'info', 'inter', 'jedno', 'kardio', 'kortyko', 'kosmo', 'krypto', 'kseno', 'logo', 'magneto', 'między', 'niby', 'nie', 'nowo', 'około', 'oksy', 'onto', 'ornito', 'para', 'pierwo', 'pięcio', 'pneumo', 'poli', 'ponad', 'post', 'poza', 'proto', 'pseudo', 'psycho', 'radio', 'samo', 'sfigmo', 'sklero', 'staro', 'stereo', 'tele', 'tetra', 'wice', 'zoo', 'żyro', 'am[bf]i', 'ang[il]o', 'ant[ey]', 'a?steno', '[be]lasto', 'chro[mn]o', 'cys?to', 'de[rs]mo', 'h?ekto', '[gn]eo', 'hi[ge]ro', 'kontra?', 'me[gt]a', 'mi[nl]i', 'a[efg]ro', '[pt]rzy', 'przed?', 'wielk?o', 'mi?elo', 'eur[oy]', 'ne[ku]ro', 'allo', 'astro', 'atto', 'brio', 'heksa', 'all?o', 'at[mt]o', 'a[rs]tro', 'br?io', 'heksa?', 'pato', 'ba[tr][oy]', 'izo', 'myzo', 'm[ai]kro', 'mi[mzk]o', 'chemo', 'gono', 'kilo', 'lipo', 'nano', 'kilk[ou]', 'hem[io]', 'home?o', 'fi[lt]o', 'ma[łn]o', 'h[ioy]lo', 'hip[ns]?o', '[fm]o[nt]o',
				-- <na-, po-, o-, u-> would hit too many false positives
			};
			for _, v in ipairs(prefixes) do
				if (rfind('^'..v)) then
					local _, other_vowels = mw.ustring.gsub(v, c_s('[%s]', V), '');
					if ((n_vowels - other_vowels) > 0) then
						rsub(c_s('^(%s)', v), '%1.');
						break;
					end
				end
			end

			if (do_hyph) then

				-- syllabify common suffixes as separate
				-- TODO: szl
				local suffixes = lg {
					pl = {
						'nąć',
						'[sc]tw[aou]', '[sc]twie', '[sc]tw[eo]m', '[sc]twami', '[sc]twach',
						'dztw[aou]', 'dztwie', 'dztw[eo]m', 'dztwami', 'dztwach',
						'dł[aou]', 'dł[eo]m', 'dłami', 'dłach',
						'[czs]j[aeięąo]', '[czs]jom', '[czs]jami', '[czs]jach',
					}, szl = {
						'nōńć', 'dło',
					}
				};

				for _, v in ipairs(suffixes) do
					if (rsub(c_s('(%s)$', v), '.%1')) then break; end
				end

				-- syllabify <istka> as /ist.ka/
				if (text:find('[iy]st[kc]')) then
					local endings = lg {
						{ 'k[aąęio]', 'ce', 'kach', 'kom', 'kami' },
						szl = { 'k[aãio]', 'ce', 'kami', 'kacj', 'kacach', 'kōma?' },
					};
					for _, v in ipairs(endings) do
						if (rsub(c_s('([iy])st(%s)$', v), '%1st.%2')) then break; end
					end
				end
			end
		end
	end

	-- syllabification
	for _ = 0, 1 do
		rsub(c_s("([%sU])([^%sU.']*)([%s])", V, V, V), function (a, b, c)
			local function find(x) return mw.ustring.find(b, x); end
			local function is_diagraph(thing)
				local r = find(c_s(thing, '[crsd]z')) or find(c_s(thing, 'ch')) or find(c_s(thing, 'd[żź]'));
				if (lang == 'mpl') then return r or find(c_s(thing, 'b́')); end
				return r;
			end
			if ((mw.ustring.len(b) < 2) or is_diagraph('^%s$')) then
				b = '.'..b;
			else
				local i = 2;
				if (is_diagraph('^%s')) then i = 3; end
				if (mw.ustring.sub(b, i, i):find('^[rlłI-]$')) then
					b = '.'..b;
				else
					b = c_s('%s.%s', mw.ustring.sub(b, 0, i - 1), mw.ustring.sub(b, i));
				end
			end
			return c_s('%s%s%s', a, b, c);
		end);
	end

	local hyph;
	if (do_hyph) then
		hyph = text:gsub("'", '.'):gsub('-', ''):lower();
		-- Restore uppercase characters.
		if (uppercase_indices) then
			-- str_i loops through all the characters of the string
			-- list_i loops as above but doesn't count dots
			-- array_i loops through the indices at which the capital letters are
			local str_i, list_i, array_i = 1, 1, 1;
			function h_sub(x, y) return mw.ustring.sub(hyph, x, y); end
			while (array_i <= #uppercase_indices) do
				if (h_sub(str_i, str_i) ~= '.') then
					if (list_i == uppercase_indices[array_i]) then
						hyph = c_s('%s%s%s', h_sub(1,str_i-1), mw.ustring.upper(h_sub(str_i,str_i)), h_sub(str_i+1));
						array_i = array_i + 1;
					end
					list_i = list_i + 1;
				end
				str_i = str_i + 1;
			end
		end
	end

	rsub("'", 'ˈ');

	-- handle digraphs
	rsub('ch', 'x');
	rsub('[crs]z', { ['cz']='t_ʂ', ['rz']='R', ['sz']='ʂ' });
	rsub('d([zżź])', 'd_%1');
	if (lang == 'mpl') then rsub('b́', 'bʲ'); end

	-- basic orthographical rules
	-- not using lg() here for speed
	if (lang == 'pl') then
		rsub('.', {
			-- vowels
			['e']='ɛ', ['o']='ɔ',
			['ą']='ɔN', ['ę']='ɛN',
			['ó']='u', ['y']='ɨ',
			-- consonants
			['c']='t_s', ['ć']='t_ɕ',
			['ń']='ɲ', ['ś']='ɕ', ['ź']='ʑ',
			['ł']='w', ['w']='v', ['ż']='ʐ',
			['g']='ɡ', ['h']='x',
		});
	elseif (lang == 'mpl') then
		rsub('.', {
			-- vowels
			['á']='ɒ', ['å']='ɒ',
			['ę']='ɛ̃', ['ą']='ɔ̃',
			['e']='ɛ', ['o']='ɔ',
			['é']='e', ['ó']='o',
			['y']='ɨ',
			-- consonants
			['ṕ']='pʲ', -- <b́> has no unicode character and is hence handled above
			['ḿ']='mʲ', ['ẃ']='vʲ',
			['c']='t_s', ['ć']='t_ɕ',
			['ń']='ɲ', ['ś']='ɕ', ['ź']='ʑ',
			['ł']='ɫ', ['w']='v', ['ż']='ʐ',
			['g']='ɡ', ['h']='x',
		});
	elseif (lang == 'szl') then
		rsub('.', {
			-- vowels
			['e']='ɛ', ['o']='ɔ',
			['ō']='o', ['ŏ']='O',
			['ô']='wɔ', ['y']='ɨ',
			['õ'] = 'ɔ̃', ['ã'] = 'ã',
			-- consonants
			['c']='t_s', ['ć']='t_ɕ',
			['ń']='ɲ', ['ś']='ɕ', ['ź']='ʑ',
			['ł']='w', ['w']='v', ['ż']='ʐ',
			['g']='ɡ', ['h']='x',
		});
	end

	-- palatalisation
	local palatise_into = { ['n'] = 'ɲ', ['s'] = 'ɕ', ['z'] = 'ʑ' };
	rsub('([nsz])I', function (c) return palatise_into[c]; end);
	rsub('([nsz])i', function (c) return palatise_into[c] .. 'i'; end);

	-- voicing and devoicing

	local T = 'ptsʂɕkx';
	local D = 'bdzʐʑɡ';

	rsub(c_s('([%s][.ˈ]?)v', T), '%1f');
	rsub(c_s('([%s][.ˈ]?)R', T), '%1S');

	local function arr_list(x) local r = ''; for i in pairs(x) do r = r..i; end return r; end
	local devoice = {
		['b'] = 'p', ['d'] = 't', ['ɡ'] = 'k',
		['z'] = 's', ['v'] = 'f',
		['ʑ'] = 'ɕ', ['ʐ'] = 'ʂ', ['R'] = 'S',
	};
	local mpl_J = lg { '', mpl = 'ʲ?' };

	local arr_list_devoice = arr_list(devoice);

	if (not is_prep) then
		rsub(c_s('([%s])(%s)$', arr_list_devoice, mpl_J), function (a, b)
			return devoice[a] .. (is_str(b) and b or '');
		end);
	end

	if (lang ~= 'mpl') then
		rsub('S', 'ʂ'); rsub('R', 'ʐ');
	end

	local voice = {}; for i, v in pairs(devoice) do voice[v] = i; end

	local new_text;
	local devoice_string = c_s('([%s])(%s[._]?[%s])', arr_list_devoice, mpl_J, T);
	local voice_string = c_s('([%s])(%s[._]?[%s])', arr_list(voice), mpl_J, D);
	local function devoice_func(a, b) return devoice[a] .. b; end
	local function voice_func(a, b) return voice[a] .. b; end
	while text ~= new_text do
		new_text = text;
		rsub(devoice_string, devoice_func);
		rsub(voice_string, voice_func);
	end

	if (lang == 'pl') then
		-- nasal vowels
		rsub('N([.ˈ]?[pb])', 'm%1');
		rsub('N([.ˈ]?[ɕʑ])', 'ɲ%1');
		rsub('N([.ˈ]?[td]_[ɕʑ])', 'ɲ%1');
		rsub('N([.ˈ]?[tdsz])', 'n%1');
		rsub('N([.ˈ]?[wl])', '%1');
		rsub('ɛN$', 'ɛ');
		rsub('N', 'w̃');
	end

	-- Hyphen separator, e.g. to prevent palatisation of <kwazi->.
	rsub('-', '');

	rsub('_', '͡');
	rsub('I', 'j'); rsub('U', 'w');

	-- stress
	local function add_stress(a)
		local s = '';
		for _ = 0, a do
			s = s .. '[^.]+%.';
		end
		local r = mw.ustring.gsub(text, c_s('%%.(%s[^.]+)$', s), 'ˈ%1');
		if (not mw.ustring.find(r, 'ˈ')) then
			r = 'ˈ' .. r;
		end
		return (r:gsub('%.', ''));
	end

	local should_stress = not (unstressed or text:find('ˈ'));
	local prons = should_stress and add_stress(ante) or text;

	if (is_prep) then
		prons = prons .. '$';
	end

	if (lang == 'pl') then
		if (should_stress and ante > 0 and colloquial) then
			local thing = add_stress(0);
			if (thing ~= prons) then
				prons = { prons, thing };
			end
		end
	elseif (lang == 'mpl') then
		if (rfind('[RS]')) then
			local mp_early = prons:gsub('[RS]', 'r̝');
			local mp_late = prons:gsub('R', 'ʐ'):gsub('S', 'ʂ');
			if (period == 'early') then
				prons = mp_early;
			elseif (period == 'late') then
				prons = mp_late;
			elseif (not period) then
				prons = {
					mp_early, mp_late,
				};
			else
				error(c_s("'%s' is not a supported Middle Polish period, try with 'early' or 'late'.", period));
			end
		end
	elseif (lang == 'szl') then
		if (rfind('O')) then
			prons = {
				prons:gsub('O', 'ɔ'),
				prons:gsub('O', 'ɔw'),
			};
		end
	end

	if (do_hyph) then
		return prons, hyph;
	else
		return prons;
	end

end

-- TODO: This might slow things down if used too much?
local function table_insert_if_absent(t, s)
	for _, v in ipairs(t) do
		if (v == s) then return; end
	end
	table.insert(t, s);
end

-- Returns rhyme from a transcription.
local function do_rhyme(pron, lang)
	local V = ({ pl = 'aɛiɔuɨ', szl = 'aɛeiɔouɨ' })[lang];
	local num_syl = select(2, mw.ustring.gsub(pron, c_s('[%s]', V), ''));
	return {
		rhyme = mw.ustring.gsub(mw.ustring.gsub(mw.ustring.gsub(pron, '^.*ˈ', ''), c_s('^[^%s]-([%s])', V, V), '%1'), '%.', ''),
		num_syl = num_syl
	};
end

--[[
	Handles a single input, returning a table of transcriptions. Returns also a string of
	hyphenation and a table of rhymes if it is a single-word term.
--]]
local function multiword(term, lang, period)
	if (term:find('^%[.+%]$')) then
		return { phonetic = term };
	elseif (term:find(' ')) then

		-- TODO: repeated
		function lg(s) return s[lang] or s[1]; end

		local prepositions = lg {
			{
				'beze?', 'na', 'dla', 'do', 'ku',
				'nade?', 'o', 'ode?', 'po', 'pode?', 'przede?',
				'przeze?', 'przy', 'spode?', 'u', 'we?',
				'z[ae]?', 'znade?', 'zza',
			}, szl = {
				'bezy?', 'na', 'dlŏ', 'd[oō]', 'ku',
				'nady?', 'ô', 'ôdy?', 'po', 'pody?', 'przedy?',
				'przezy?', 'przi', 'spody?', 'u', 'w[ey]?',
				'z[aey]?', '[śs]', 'znady?'
			}
		};

		local p;
		local contains_preps = false;

		for word in term:gmatch('[^ ]+') do
			local is_prep = false;
			for _, prep in ipairs(prepositions) do
				if (mw.ustring.find(word, c_s('^%s$', prep))) then
					is_prep = true;
					contains_preps = true;
					break;
				end
			end
			local v = phonemic(word, false, lang, is_prep, period);
			local sep = '%s %s';
			if (p == nil) then
				p = v;
			elseif (is_str(p)) then
				if (is_str(v)) then
					p = c_s(sep, p, v);
				else
					p = { c_s(sep, p, v[1]), c_s(sep, p, v[2]) };
				end
			else
				if (is_str(v)) then
					p = { c_s(sep, p[1], v), c_s(sep, p[2], v) };
				else
					p = { c_s(sep, p[1], v[1]), c_s(sep, p[2], v[2]) };
				end
			end
		end

		local function assimilate_preps(str)
			local function assim(from, to, before)
				str = mw.ustring.gsub(str, c_s('%s(%%$ ˈ?[%s])', from, before), to..'%1');
			end
			local T = 'ptsʂɕkx';
			assim('d', 't', T); assim('v', 'f', T); assim('z', 's', T);
			if (lang == 'szl') then
				local D = 'bdzʐʑɡ';
				assim('s', 'z', D); assim('ɕ', 'ʑ', D);
			end
			return mw.ustring.gsub(str, '%$', '');
		end

		if (contains_preps) then
			if (is_str(p)) then
				p = assimilate_preps(p);
			else
				p[1] = assimilate_preps(p[1]);
				p[2] = assimilate_preps(p[2]);
			end
		end

		return p;

	else
		return phonemic(term, lang ~= 'mpl', lang, false, period);
	end

end

-- This handles all the magic characters <*>, <^>, <+>, <.>, <#>.
local function normalise_input(term, title)

	local function check_af(str, af, reg, repl, err_msg)
		reg = c_s(reg, af);
		if (not mw.ustring.find(str, reg)) then
			error(c_s("the word does not %s with %s!", err_msg, af));
		end
		return str:gsub(reg, repl);
	end

	local function check_pref(str, pref) return check_af(str, pref, '^(%s)', '%1.', "start"); end
	local function check_suf(str, suf) return check_af(str, suf, '(%s)$', '.%1', "end"); end

	if (term == '#') then
		-- The diesis stands simply for {{PAGENAME}}.
		return title;
	elseif ((term == '+') or term:find('^%^+$') or (term == '*')) then
		-- Inputs that are just '+', '*', '^', '^^', etc. are treated as
		-- if they contained the title with those symbols preceding it.
		return term .. title;
	-- Handle syntax like <po.>, <.ka> and <po..ka>. This allows to not respell
	-- the entire word when all is needed is to specify syllabification of a prefix
	-- and/or a suffix.
	elseif (term:find('.+%.$')) then
		return check_pref(title, term:sub(1, -2));
	elseif (term:find('^%..+')) then
		return check_suf(title, term:sub(2));
	elseif (term:find('.+%.%..+')) then
		return check_suf(check_pref(title, term:gsub('%.%..+', '')), term:gsub('.+%.%.', ''));
	end

	return term;

end

local function sort_things(lang, title, args_terms, args_quals, args_refs, args_period)

	local pron_list, hyph_list, rhyme_list, do_hyph = { {}, {}, {} }, { }, { {}, {}, {} }, false;

	for index, term in ipairs(args_terms) do
		term = normalise_input(term, title);
		local pron, hyph = multiword(term, lang, args_period);
		local qualifiers = {};
		if (args_quals[index]) then
			for qual in args_quals[index]:gmatch('[^;]+') do
				table.insert(qualifiers, qual);
			end
		end
		local function new_pron(p, additional, dont_refs)
			local ret = {
				pron = c_s('/%s/', p),
				qualifiers = qualifiers,
				refs = not dont_refs and {args_refs[index]},
			};
			if (additional) then
				local new_qualifiers = {};
				for _, v in ipairs(qualifiers) do
					table.insert(new_qualifiers, v);
				end
				table.insert(new_qualifiers, additional);
				ret.qualifiers = new_qualifiers;
			end
			return ret;
		end
		local should_rhyme = lang ~= 'mpl';
		if (is_str(pron)) then
			table.insert(pron_list[1], new_pron(pron));
			if (should_rhyme) then
				table.insert(rhyme_list[1], do_rhyme(pron, lang));
			end
		elseif (pron.phonetic) then
			table.insert(pron_list[1], {
				pron = pron.phonetic,
				qualifiers = qualifiers,
				refs = {args_refs[index]},
			});
		else
			local double_trancript = ({
				pl = { 'prescribed', 'casual' },
				mpl = { '16<sup>th</sup> c.', '17<sup>th</sup>–18<sup>th</sup> c.' },
				szl = { nil, 'Opolskie' },
			})[lang];
			table.insert(pron_list[2], new_pron(pron[1], double_trancript[1]));
			table.insert(pron_list[3], new_pron(pron[2], double_trancript[2], true));
			if (should_rhyme) then
				table.insert(rhyme_list[2], do_rhyme(pron[1], lang));
				table.insert(rhyme_list[3], do_rhyme(pron[2], lang));
			end
		end
		if (hyph) then
			do_hyph = true;
			if (hyph:gsub('%.', '') == title) then
				table_insert_if_absent(hyph_list, hyph);
			end
		end
	end

	-- TODO: looks rather slow.
	local function merge_subtables(t)
		local r = {};
		if (#t[2] + #t[3] == 0) then return t[1]; end
		for _, subtable in ipairs(t) do
			for _, value in ipairs(subtable) do
				table.insert(r, value);
			end
		end
		return r;
	end

	pron_list = merge_subtables(pron_list);
	rhyme_list = merge_subtables(rhyme_list);

	return pron_list, hyph_list, rhyme_list, do_hyph;
end

function export.mpl_IPA(frame)
	
	local args = require('Module:parameters').process(frame:getParent().args, {

		[1] = { list = true },
		["qual"] = { list = true, allow_holes = true },
		["q"] = { list = true, allow_holes = true, alias_of = "qual" },
		["period"] = {},
		["ref"] = { list = true, allow_holes = true },

		["title"] = {}, -- for debugging or demonstration only

	});

	local terms = args[1];

	if (#terms == 0) then
		terms = { '#' };
	end

	return c_s('* %s %s', require('Module:accent qualifier').format_qualifiers{ 'Middle Polish' },
		require('Module:IPA').format_IPA_full(
			require('Module:languages').getByCode('pl'), (sort_things(
				'mpl',
				args.title or mw.title.getCurrentTitle().text,
				terms,
				args.qual,
				args.ref,
				args.period
			))
		)
	);

end

function export.IPA(frame)

	local arg_lang = frame.args.lang;

	local process_args = {

		[1] = { list = true },

		["qual"] = { list = true, allow_holes = true },
		["q"] = { list = true, allow_holes = true, alias_of = "qual" },
		["hyphs"] = {}, ["h"] = { alias_of = "hyphs" },
		["rhymes"] = {}, ["r"] = { alias_of = "rhymes" },
		["audios"] = {}, ["a"] = { alias_of = "audios" },
		["homophones"] = {}, ["hh"] = { alias_of = "homophones" },
		["ref"] = { list = true, allow_holes = true },

		["title"] = {}, -- for debugging or demonstration only

	};

	if (arg_lang == 'pl') then
		process_args["mp"] = { list = true };
		process_args["mp_qual"] = { list = true, allow_holes = true };
		process_args["mp_q"] = { list = true, allow_holes = true, alias_of = "mp_qual" };
		process_args["mp_period"] = {};
		process_args["mp_ref"] = { list = true, allow_holes = true };
	end

	local args = require('Module:parameters').process(frame:getParent().args, process_args);

	local terms = args[1];
	local title = args.title or mw.title.getCurrentTitle().text;

	if (#terms == 0) then
		terms = { '#' };
	end

	local pron_list, hyph_list, rhyme_list, do_hyph = sort_things(arg_lang, title, terms, args.qual, args.ref);

	local mp_prons;

	if (arg_lang == 'pl') then
		if (#args.mp > 0) then
			mp_prons = (sort_things('mpl', title, args.mp, args.mp_qual, args.mp_ref, args.mp_period));
		end
	end

	if (args.hyphs) then
		if (args.hyphs == '-') then
			do_hyph = false;
		else
			hyph_list = {};
			for v in args.hyphs:gmatch('[^;]+') do
				table.insert(hyph_list, v);
			end
			do_hyph = true;
		end
	end

	if (args.rhymes) then
		if (args.rhymes == '-') then
			rhyme_list = {};
		elseif (args.rhymes ~= '+') then
			rhyme_list = {};
			for v in args.rhymes:gmatch('[^;]+') do
				if (mw.ustring.find(v, '.+/.+')) then
					table.insert(rhyme_list, {
						rhyme = mw.ustring.gsub(v, '/.+', ''),
						num_syl = tonumber((mw.ustring.gsub(v, '.+/', ''))),
					});
				else
					error(c_s("The manual rhyme %s did not specify syllable number as RHYME/NUM_SYL.", v));
				end
			end
		end
	end

	for ooi, oov in ipairs(rhyme_list) do
		oov.num_syl = { oov.num_syl };
		for coi = ooi + 1, #rhyme_list do
			local cov = rhyme_list[coi];
			if (oov.rhyme == cov.rhyme) then
				local add_ns = true;
				for _, onv in ipairs(oov.num_syl) do
					if (cov.num_syl == onv) then
						add_ns = false;
						break;
					end
				end
				if (add_ns) then
					table.insert(oov.num_syl, cov.num_syl);
				end
				table.remove(rhyme_list, coi);
			end
		end
	end

	local lang = require('Module:languages').getByCode(arg_lang);

	local m_IPA_format = require('Module:IPA').format_IPA_full;
	local ret = '*' .. m_IPA_format(lang, pron_list);

	if (mp_prons) then
		ret = c_s('%s\n*%s %s', ret,
			require('Module:accent qualifier').format_qualifiers{ 'Middle Polish' },
			m_IPA_format(lang, mp_prons)
		);
	end

	if (args.audios) then
		for v in args.audios:gmatch('[^;]+') do
			-- TODO: can I expand a template or is it a bad thing to do?
			ret = c_s('%s\n*%s', ret, frame:expandTemplate { title = 'audio', args = {
				arg_lang,
				v:gsub('#', title),
				'Audio',
			} });
		end
	end

	if (#rhyme_list > 0) then
		ret = c_s('%s\n*%s', ret, require('Module:rhymes').format_rhymes({ lang = lang, rhymes = rhyme_list }));
	end

	if (do_hyph) then
		ret = ret .. '\n*';
		if (#hyph_list > 0) then
			local hyphs = {};
			for hyph_i, hyph_v in ipairs(hyph_list) do
				hyphs[hyph_i] = { hyph = {} };
				for syl_v in hyph_v:gmatch('[^.]+') do
					table.insert(hyphs[hyph_i].hyph, syl_v);
				end
			end
			ret = ret..require('Module:hyphenation').format_hyphenations {
				lang = lang, hyphs = hyphs, caption = 'Syllabification'
			};
		else
			ret = ret..'Syllabification: <small>[please specify syllabification manually]</small>'
			-- TODO: categorise.
			-- ..'[[Category:'..arg_lang..'-pronunciation_without_hyphenation]]';
		end
	end

	if (args.homophones) then
		local homophone_list = {};
		for v in args.homophones:gmatch('[^;]+') do
			if (v:find('<.->$')) then
				table.insert(homophone_list, {
					term = v:gsub('<.->$', ''),
					qualifiers = { (v:gsub('.+<(.-)>$', '%1')) },
				});
			else
				table.insert(homophone_list, { term = v });
			end
		end
		ret = c_s('%s\n*%s', ret, require('Module:homophones').format_homophones {
			lang = lang,
			homophones = homophone_list,
		});
	end

	return ret;
end

return export;
