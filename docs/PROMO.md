# EmoSphere — plán propagace (návrh k odsouhlasení, 24. 10. 2026)

Cíl: dostat appku k prvním reálným uživatelům.
Princip: mapa musí vypadat živá, odkaz musí fungovat na první klik a nikde nespamovat.

**Hlavní sdílený odkaz:** https://emosphere.digitalni-vedomi.cz
**APK:** https://github.com/Vojta01/emosphere/releases/latest

## Předpoklady (co musí platit před spuštěním)

- [ ] Vojtovo „jdi" na spuštění.
- [ ] Čerstvé check-iny v den D — mapa má výchozí okno 24 h.
      Minimálně 1–2 od Vojty; ideálně pár lidí z okolí (ať si appku zkusí).
- [ ] Reddit účet s běžnou historií (pravidlo 90/10). r/InternetIsBeautiful
      je one-shot — účet nesmí být „jen na propagaci".
- [ ] HN účet (ideálně starší; Show HN = jeden pokus na projekt).
- [ ] V den D mám čas odpovídat na komentáře (Reddit/HN celý den).

## Fáze 0 — příprava (D−2 až D−1)

1. Finální kontrola: PWA (zavřít a otevřít 2× kvůli cache), APK odkaz,
   náhled při sdílení (OG karta), onboarding EN/CZ.
2. Zkouška „jako cizinec": otevřít web v čistém profilu prohlížeče a na mobilu.
3. Připravit screenshoty (EN): mapa s heatmapou, uvítačka, stroj času.
4. Připravit texty (níže) — každá komunita dostane vlastní úvod.

## Fáze 1 — Nostr komunita (den D, kdykoli)

Proč první: nejvíc cílová skupina, nulová frikce, rozumí klíčům a relayím.

- Post z Vojtova účtu (Primal / Damus / Amethyst): text + 2 screenshoty
  + odkaz. Tagy: #grownostr #nostr.
- Zápisy do katalogů: nostrapps.com (formulář), awesome-nostr (PR na GitHubu
  — připravím).
- Vojta odpovídá na reakce (je to jeho účet).

## Fáze 2 — Reddit (den D, 15–17 SELČ = americké dopoledne)

| Subreddit           | Formát                                  |
|---------------------|-----------------------------------------|
| r/SideProject       | hlavní post (text níže)                 |
| r/Nostr             | kratší, komunitní tón                   |
| r/InternetIsBeautiful | ONE-SHOT, jen když účet projde 90/10; titulek „I made …" |
| r/androidapps       | s odkazem na APK                        |

Pravidla každé komunity zkontrolovat 10 minut před postem (mění se).
Stejný text do více komunit neposílat — čte se to jako spam.

## Fáze 3 — Show HN (den D+1, 15–17 SELČ)

- Titulek: `Show HN: EmoSphere – an anonymous global mood map on Nostr`
- Do diskuze napsat úvodní komentář (níže) a odpovídat celý den.
- Nežádat kamarády o upvoty — na HN je to zakázané.

## Fáze 4 — Česko (den D+2 až D+3)

- Tip e-mailem na CzechCrunch a Živě.cz (česky, text níže) — příběh
  „český vývojář postavil mapu nálad světa".
- r/czech — krátký český post.

## Fáze 5 — videa (průběžně)

- 10–15 s klip „8 sekund světa" ze stroje času → X, Instagram, TikTok.

## Fáze 6 — distribuce appky (samostatné „jdi", později)

- IzzyOnDroid: split-per-ABI APK ≤ 30 MB + Fastlane metadata (připravím).
- Play Store ($25, rozhodnout).
- Alternativeto.net (záznam).

## Šablony textů (EN)

### Reddit — r/SideProject (hlavní post)

> **I made an anonymous global mood map — tap how you feel and watch the world light up**
>
> I've spent the last few weeks building EmoSphere: you drop how you feel
> (one of 8 emotions + intensity), and it becomes a glow on a shared world map.
>
> - No account, no email — your identity is a key generated in your browser.
> - Location is optional and never precise (city or ~500 m).
> - It runs on Nostr (decentralised relays), open source (MIT).
> - Web: https://emosphere.digitalni-vedomi.cz (PWA — works on phones)
> - Android: https://github.com/Vojta01/emosphere/releases/latest
>
> There's also a time machine that replays the last 24 h of world mood.
> I'd love feedback — especially on the map (emotion colours, heat layer)
> and what would make you come back.

### r/InternetIsBeautiful

> **I made a world map where anyone can drop how they feel and the world lights up**
>
> Tap an emotion, optionally your city, and your feeling becomes a glow on a
> shared world map. No account, no tracking — check-ins travel over the
> decentralised Nostr network. A time machine replays the last 24 hours, too.
>
> https://emosphere.digitalni-vedomi.cz

### Show HN (úvodní komentář autora)

> Author here. EmoSphere is a small experiment: can you feel how the world is
> doing without a feed, likes or profiles?
>
> You drop one of 8 emotions with intensity 1–5 (optionally a city-level
> location) and it becomes a glow on a shared map. There is no account — a key
> is generated in your browser and check-ins are signed events on Nostr relays,
> so there is no server of mine storing anything. Location is coarse on purpose.
>
> Tech: Flutter (one codebase → web + Android), custom OKLab colour blending
> (the cell colour is an intensity-weighted mix, so a strong emotion outvotes
> a weak one), and a time machine replaying up to 24 h.
>
> Happy to hear thoughts on moderation of a fully anonymous map — that's the
> part I'm least sure about.

### Nostr note

> I built EmoSphere — an anonymous global mood map on Nostr 🌍
>
> Pick one of 8 emotions, drop it on the map (location optional, always
> coarse), watch the world light up. No accounts, no tracking, no server —
> just signed events relayed over Nostr.
>
> - Web: https://emosphere.digitalni-vedomi.cz
> - Android: https://github.com/Vojta01/emosphere/releases/latest
> - Code (MIT): https://github.com/Vojta01/emosphere
>
> Feedback welcome — especially from fellow nostriches. #grownostr #nostr

### Tip pro CzechCrunch / Živě.cz (CZ)

> Dobrý den,
>
> píšu s tipem na český projekt: EmoSphere — anonymní globální mapa nálad.
> Lidé na ni jedním klepnutím vloží, jak se cítí, a svět se rozsvítí barvami
> osmi emocí. Běží na decentralizované síti Nostr, bez účtů a bez sledování;
> data nejsou na žádném centrálním serveru.
>
> Zajímavosti pro čtenáře:
> - „Stroj času" přehraje posledních 24 hodin nálad světa.
> - Barvy se míchají v OKLab prostoru — silnější emoce přebije slabší.
> - Vše open source (MIT), web i Android.
>
> Web: https://emosphere.digitalni-vedomi.cz
>
> Díky za zvážení!

## Připravené odpovědi na časté námitky

- **Proč Nostr, a ne ActivityPub?** Relay model sedí efemérním veřejným
  signálům: žádná instance k údržbě, globální od začátku.
- **Jak je to anonymní?** Náhodný klíč, žádný e-mail/telefon, lokalita jen
  hrubá. (Relaye vidí IP — stejně jako u každé webové appky.)
- **Moderace?** Otevřená otázka; zatím jen 140znakové poznámky a hrubá
  lokalita. Nápady vítám.

## Jak měřit úspěch (bez analytiky)

- Počítám unikátní klíče a check-iny na relayích (skript mám).
- Metriky: D+1 nové check-iny; D+7 unikátní autoři; kolik lidí se vrátí
  (2+ check-iny od stejného klíče).

## Checklist dne D

- 08:00 SELČ — čerstvé check-iny (Vojta + okolí)
- 09:00 — kontrola: PWA, APK, odkazy, OG náhled
- 15:00–17:00 — Reddit posty (fáze 2)
- 18:00–22:00 — odpovídat na komentáře
- D+1 15:00 — Show HN (fáze 3)
