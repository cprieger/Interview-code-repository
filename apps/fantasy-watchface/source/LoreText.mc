import Toybox.Lang;

// "Lore text" - a little surprise treat under the clock: an obscure/
// interesting World of Warcraft or Lord of the Rings fact, picked by the
// digit-sum of today's step count (e.g. 9,999 steps -> 9+9+9+9 = 36) and
// changed ONLY on the sleep->active wake transition (see
// FantasyWatchFaceView.onExitSleep()), never on every redraw or as steps
// tick up during an already-active session - the whole point is that it's
// a small discovery at each wake, not a live-updating field.
//
// 37 entries (index 0..36) - a 4-digit step count's digit sum ranges
// 0 (0000 steps) to 36 (9999 steps) inclusive, so this covers that range
// exactly. Real step counts can exceed 4 digits later in a very active
// day, in which case the digit-sum math in the view clamps/wraps back
// into this same 0..36 range rather than indexing out of bounds - see
// FantasyWatchFaceView.pickLoreIndex().
//
// Every entry kept comfortably under the 256-char settings.xml/property
// budget (longest here is ~180 chars) - both because that's plenty of
// room for one good fact, and because a shorter string is what actually
// fits legibly under the clock on a 280px round display.
module LoreText {
    const ENTRIES as Array<String> = [
        // 0
        "In LOTR, Sauron's One Ring bears an inscription in Black Speech, the only place that language appears in written form in the entire book.",
        // 1
        "WoW's Thunder Bluff was originally going to be a Horde-only zone reachable solely by elevator - the surrounding ramps were added late in development.",
        // 2
        "Tolkien invented Elvish languages (Quenya and Sindarin) before he wrote The Lord of the Rings - the story grew to give the languages a history.",
        // 3
        "The Elder Scrolls-style 'ding' level-up sound in WoW was inspired by an actual dinner bell recording, chosen because it cut through raid chaos.",
        // 4
        "Gandalf's sword Glamdring and Bilbo's Sting were forged in Gondolin, a hidden Elven city that fell before the events of The Hobbit even begin.",
        // 5
        "The Barrens chat channel became so famous for off-topic jokes that Blizzard referenced it directly in later expansions as an in-lore meme.",
        // 6
        "Treebeard is described as the oldest living being in Middle-earth - older than the Valar's arrival, older even than Sauron himself.",
        // 7
        "Arthas Menethil's story arc took over a decade to complete, spanning Warcraft III through the Wrath of the Lich King raid finale in 2010.",
        // 8
        "Tolkien was a philologist first - The Lord of the Rings began as an excuse to give his invented languages a world and history to live in.",
        // 9
        "The goblin engineering questline in WoW was written partly as a parody of corporate bureaucracy, down to mandatory safety-goggle jokes.",
        // 10
        "Frodo and Sam never actually see an Orc's face up close and unmasked in the entire trilogy - only helmed, hooded, or distant figures.",
        // 11
        "Deathwing's redesign for Cataclysm added asymmetrical, jagged wings specifically so players could recognize battle damage lore at a glance.",
        // 12
        "The Ents' language, Entish, is described by Tolkien as so slow that a simple greeting could take hours to fully pronounce.",
        // 13
        "World of Warcraft's original name during early development was simply 'Warcraft Adventures' before the MMO direction was finalized.",
        // 14
        "Aragorn is over 80 years old during the War of the Ring - Numenorean bloodlines age far slower than ordinary Men.",
        // 15
        "The Lich King's iconic runeblade Frostmourne was designed with a deliberately jagged, asymmetrical silhouette to read instantly at a distance.",
        // 16
        "Tom Bombadil is older than Sauron, older than the Elves waking at Cuivienen - by his own account, 'eldest' of anything in Middle-earth.",
        // 17
        "The Scarlet Monastery instance in WoW was originally one massive dungeon before being split into four wings for pacing reasons.",
        // 18
        "Legolas is stated to have keener eyesight than any other character in the trilogy, able to count riders on the plains miles away.",
        // 19
        "Blizzard's original plan for the Undead Forsaken was scrapped and rewritten twice before Sylvanas Windrunner became their leader.",
        // 20
        "The Balrog that fights Gandalf in Moria is never given a proper name in the published text - only the title 'Durin's Bane'.",
        // 21
        "Ironforge's dwarven architecture was modeled after real-world Scottish and Norse stonework references during WoW's earliest concept art phase.",
        // 22
        "Sauron himself never physically appears on-page as a character in The Lord of the Rings - only as the Eye, a voice, or distant memory.",
        // 23
        "The goblin and gnome starting zones in Cataclysm were the most requested community feature from the game's first five years combined.",
        // 24
        "Gollum's riddle game with Bilbo in The Hobbit uses riddles drawn from real Old English and Norse riddle traditions Tolkien studied.",
        // 25
        "Illidan Stormrage's famous line was reused so often as a meme that Blizzard began referencing it directly inside later expansions.",
        // 26
        "The Shire's calendar in LOTR's appendices runs on a completely different system than our own, with named days unique to Hobbits.",
        // 27
        "Naxxramas was one of the first WoW raids ever designed, but was delayed so long it launched practically obsolete, then was rebuilt for Wrath.",
        // 28
        "Isildur cut the One Ring from Sauron's hand with the broken shard of his father's sword, not a fully intact blade as often depicted.",
        // 29
        "The Draenei's crystalline aesthetic in WoW was chosen partly to visually distinguish them instantly from every existing Horde/Alliance race.",
        // 30
        "Merry and Pippin are the only hobbits in the Fellowship who never actually visit Rivendell before the quest to destroy the Ring begins.",
        // 31
        "World of Warcraft's engine originally ran Warcraft III assets directly during the earliest internal prototype builds circa 2001.",
        // 32
        "The Mouth of Sauron, a minor but memorable film character, has no dialogue at all in Tolkien's original published text.",
        // 33
        "Karazhan's tower design was inspired by classic gothic architecture references gathered specifically for that one raid's concept art.",
        // 34
        "Frodo sails to the Undying Lands at the very end of the story - one of the only mortals ever granted passage there by special grace.",
        // 35
        "The goblin phrase 'Time is money, friend' became so popular with players that it outlived the quest line that originally introduced it.",
        // 36
        "Gandalf the Grey returns as Gandalf the White after his fall in Moria - a resurrection Tolkien deliberately left mostly unexplained.",
    ] as Array<String>;

    function get(index as Number) as String {
        if (index < 0 || index >= ENTRIES.size()) {
            return ENTRIES[0];
        }
        return ENTRIES[index];
    }
}
