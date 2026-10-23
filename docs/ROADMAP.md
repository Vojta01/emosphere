# EmoSphere — Roadmap a návrhy (pipeline)

> **Stav: pipeline návrhů.** Hotové položky jsou označené v tabulce. Ostatní
> čekají na Vojtovo „jdi“ — pak se mění na commity / karty noční směny.
> Zapsáno: 22. 10. 2026 (R1–R8) · doplněno 23. 10. 2026 (R9–R11) · aplikace **v0.5.0**

## Přehled

| # | Téma | Stav |
|---|------|------|
| R1 | Heat mapa — barva buňky = směs všech check-inů (realtime) | rozhodnuto: **A** |
| R2 | Lokalita — oprava granularity: Vypnuto · Město · Oblast | rozhodnuto |
| R3 | Profily — jméno + ikonka (kind 0) | návrh |
| R4 | Feed → klepnutí na check-in → profil uživatele + přidat do přátel | rozhodnuto: badge v hlavičce |
| R5 | Privátní zprávy (DM) | rozhodnuto: **NIP-04** (v1) |
| R6 | APK — název `emosphere-<verze>.apk` + stabilní podpis + zachování dat | připraveno |
| R7 | Odolnost proti spamu (agregace per npub, limity, verifikace podpisů) | pozdější fáze |
| R8 | Heatmapa místo kruhů — plynulé slévání blobů | hotovo (v0.3.0, oprava polohy v0.3.2) |
| R9 | Stroj času — slider + ▶ play na mapě (vývoj nálady v čase) | hotovo (v0.5.0) |
| R10 | Animace po odeslání („afterglow“) v barvě emoce | hotovo (v0.4.0) |
| R11 | Citáty k emocím (20/emoci, CZ+EN) jako součást animace | hotovo (v0.4.0) |

---

## R1 — Heat mapa: výsledná barva = směs všech check-inů

**Cíl:** barva buňky se počítá ze **všech** check-inů v okně (1 h / 24 h / 7 dní).
Váha = počet × intenzita. Příklad: 1× radost + 1× vztek → **oranžová**.
Barvy mají „vypovídat" (čím zelenější, tím pozitivnější). Přepočet v reálném čase.

**Dnes:** buňka má `dominant` (emoci s nejvyšší váhou) a maluje se její barvou;
glow podle počtu (`lib/core/geo/aggregate.dart`, `heat.dart`).

**Návrh:**
1. Nový modul `lib/core/geo/blend.dart`: barva buňky = **vážený průměr barev
   všech check-inů v buňce, počítaný v OKLab** (perceptuálně rovnoměrný prostor),
   zpět do sRGB.
   - váha `w = intenzita` (1–5); případně `intenzita²` (ostřejší rozdíl) — otestovat,
     default lineární.
   - alfa/glow zůstává podle počtu (log, jako dnes).
   - kontrola: 1 check-in = přesně jeho barva; prázdná buňka = nic.
2. `CellAggregate` rozšířit o `Color blended` (getter nad `weights`).
3. `dominant` zůstává — pro tooltip/rozpad („Vztek 40 % · Radost 35 % · …").
4. Realtime: mapa se překresluje při každém novém eventu už dnes — barva se
   přepočítá v build fázi, žádná změna síťové vrstvy.
5. Testy: joy+anger → oranžový odstín; calm+anger → neutrál (šedo-hnědá);
   calm+love → žluto-zelená; determinismus; prázdný vstup.

**Paleta — analýza „vypovídajících barev":**

- **Varianta A (doporučená):** zachovat schválené barvy, spoléhat na OKLab mix:
  | emoce | barva |
  |---|---|
  | radost | 🟡 `#FFD93D` |
  | klid | 🟢 `#4ADE80` |
  | láska | 🩷 `#F472B6` |
  | překvapení | 🟠 `#FB923C` |
  | smutek | 🔵 `#60A5FA` |
  | vztek | 🔴 `#EF4444` |
  | strach | 🟣 `#A78BFA` |
  | únava | ⚪ `#94A3B8` |

  - radost + vztek = **oranžová** ✓ (přesně Vojtův příklad)
  - klid + láska → teplá žluto-zelená (pozitivní mix) ✓
  - smutek + strach → modro-fialová ✓
  - klid + vztek → šedo-hnědá = „rozporuplná" buňka (čitelné jako neutrál)
- **Varianta B (experiment):** přerovnat odstíny do **valence osy**
  (zelená = nejpozitivnější … červená = nejnegativnější) a míchat po hue-wheelech;
  cílem je, aby i míchané barvy „říkaly" pozitivitu. Riziko: mění schválený
  vizuál. Doporučení: nasadit **A**, B zvážit, jen pokud budou mixy působit
  neprůhledně (uděláme ukázkovou stránku se vzorky před rozhodnutím).
- **Co je mezi A a B STEJNÉ:** matematika mixu (OKLab, váhy intenzit) je
  v obou variantách identická — volba A/B mění jen to, **které barvy se do mixu
  používají**. Jde čistě o vizuální identitu aplikace, ne o funkci.
- Legenda: po klepnutí na buňku zobrazit rozpad (emoji + procenta).

---

## R2 — Lokalita: odpověď na dotaz + nová granularita

**„Co znamená Oblast teď?"** → dnes `LocationPrecision.area` = **geohash-3,
tj. ≈ 156 × 156 km** (velký region — např. většina Čech). Je to **větší než
Město** — proto to působí matoucím dojmem.

**Návrh (dle Vojty — Oblast MENŠÍ než Město):**

| Volba | geohash | velikost buňky (≈ 50° s. š.) | poznámka |
|---|---|---|---|
| Vypnuto | – | – | beze změny |
| **Město** | 5 | ≈ 4,9 × 3 km | dnešní „city" |
| **Oblast** | 6 | ≈ 1,2 × 0,4 km (okruh ~0,5 km) | NOVÉ — „tvoje okolí / čtvrť" |

- `Geohash.areaPrecision: 3 → 6`; `LocationPrecision.area` nově mapuje na 6.
- UI: pořadí dle Vojty **Vypnuto · Město · Oblast** (vzrůstající přesnost);
  popisky s velikostí („Oblast (okruh ~0,5 km)", „Město (~5 km)").
- Soukromí: stále nikdy přesná poloha; text v UI doplnit o konkrétní velikost.
- Zpětná kompatibilita: staré geohash-3 eventy se agregují beze změny
  (`Geohash.parent()`), nové už se neposílají.
- Mapa: heat vrstva zvládne i g6; volitelně rozšířit `precisionForZoom`,
  aby max. zoom kreslil jemněji (nice-to-have).
- Migrace: uložená předvolba `area` zůstává, mění se jen její význam.
- SPEC.md doplnit; testy: encode g6, popisky UI, agregace mixu g5/g6.

**K rozhodnutí:** Oblast ≈ 1 km (g6, doporučuji), nebo ≈ 150 m (g7 — přesnější,
ale soukromí menší)?

---

## R3 — Profily: jméno + ikonka (kind 0)

**Cíl:** každý si nastaví jméno/přezdívku a fotku; zobrazí se ve feedu.

**Návrh:**
- Standard Nostr **kind 0 metadata** (`{name, display_name?, picture, about?}`) —
  parser `NostrProfile` už v kódu je.
- **Editor:** Nastavení → „Profil" → dialog: jméno (max 40 znaků), „o mně"
  (volitelné, max 200), fotka. Uložení = podepsaný kind 0 (nahradí starší).
- **Fotka:**
  - Fáze 1: URL obrázku (https). Rychlé, bez serveru.
  - Fáze 2: nahrání na `nostr.build` (zdarma, NIP-96 + NIP-98 podepsaná
    autorizace) — samostatný úkol.
  - Bez fotky: barevný kruh s iniciálou (fallback `_Avatar` už existuje).
- **Načítání:** dnes se kind 0 stahuje jen přátelům; nově (a) dávkově pro autory
  ve feedu, (b) on-demand při otevření sheetu; cache + persist do prefs.
- Vlastní profil viditelný v Nastavení (avatar + jméno + npub).

---

## R4 — Feed: klepnutí na check-in → profil uživatele

**Cíl:** ve „Právě teď ve světě" klepnout na check-in → okno se jménem, npub,
ikonkou, místem check-inu + tlačítko „Přidat do přátel".

**Dnes:** bottom sheet `_openFriend` existuje, ale jen pro přátele (avatar, jméno,
odebrat). World feed = neklikatelný.

**Návrh — sjednotit do `UserSheet`:**
1. **Hlavička:** avatar + jméno + npub (klepnutí = kopírovat).
2. **Check-in:** emoce (emoji + barva), intenzita, čas, poznámka;
   **místo:** má-li geohash → „Oblast/Město (~X km)" + tlačítko
   „Zobrazit na mapě" (zavře sheet, zaměří buňku).
3. **Akce:** „+ Přidat do přátel" / „− Odebrat z přátel" (stav dle
   `isFriendKeyPresent`), později „Napsat zprávu" (R5).
- Profil autora se dotáhne on-demand (kind 0); do té doby zkrácený npub.
- Stejný sheet i pro „Moji blízcí".
- Přidání = stávající `app.addFriend(hex)` + snackbar.

---

## R5 — Privátní zprávy (DM)

**Realita:** `dart_nostr 10.0.1` DM (NIP-04/44) **nemá** — krypto si píšeme sami
(pointycastle už je v závislostech: ECDH secp256k1 + AES).

**Varianta A — NIP-04 (kind 4) — doporučuji pro v1:**
- `obsah = base64(AES-256-CBC(ECDH(sender,recipient), text))?iv=base64(iv)`,
  kind 4 s `p` tagem; příjem = subscription kinds `[4]`, `#p = já`.
- + nejjednodušší, kompatibilní s většinou klientů (Amethyst, Primal…).
- − metadata veřejná (kdokoli vidí, kdo komu píše a kdy); starší šifra.

**Varianta B — NIP-17 (kind 14 + seal 13 + gift wrap 1059):**
- + skrytá metadata, moderní krypto (NIP-44 v2).
- − výrazně více práce; méně klientů podporuje.

**Co je na síti veřejně vidět (obsah je šifrovaný v OBOU variantách —
zprávy NEJSOU veřejně čitelné):**

| Co | NIP-04 | NIP-17 |
|---|---|---|
| obsah zprávy | šifrovaný (AES-CBC) | šifrovaný (ChaCha20-Poly1305, silnější) |
| kdo komu píše | **veřejné** (odesílatel i příjemce) | **skryté** (vidět jen příjemce; odesílatel = náhodný klíč) |
| čas zprávy | přesný a veřejný | posunutý (přibližný) |
| délka zprávy | přibližně viditelná | skrytá (padding) |
| kompatibilita | většina klientů | novější, méně klientů |

Poznámka: v obou případech platí, že kdo získá privátní klíč, přečte zprávy —
šifrování chrání proti relayím a cizím lidem, ne proti úniku klíče.

**Doporučení:** v1 = **A** (rychlé, funkční), design rovnou počítat s přechodem
na B (stejné UX). Pokud Vojta chce pryvacy-first, dá se jít rovnou na B
(delší vývoj).

**UX (společné):**
- „Napsat zprávu" v UserSheetu → obrazovka konverzace (bublinky, input).
- Seznam konverzací: ikonka v hlavičce feedu s badge nepřečtených
  (varianta: 5. záložka „Zprávy") — k rozhodnutí.
- Bez push notifikací (nemáme server) — badge při otevření aplikace.
- Příchozí zprávy = subscription od spuštění aplikace.

**Dodělávky:** crypto util + testovací vektory, publish/fetch, UI, badge.

---

## R6 — APK: název + stabilní podpis + zachování dat

**Cíl:** APK se jmenuje `emosphere-<verze>.apk` (ne `app-release`); aktualizace
lze instalovat přes stávající verzi a **data (npub + klíč) zůstanou**.

**Proč se dnes data ztrácela:** CI podepisuje **debug klíčem**, který se na
runneru generuje náhodně → každý build má jiný podpis → Android aktualizaci
odmítne → nutno odinstalovat (a tím zmizí i klíč).

**Plán (připraveno k provedení):**
1. Vytvořit keystore `emosphere-release.jks` (keytool; alias `emosphere`;
   platnost 10 000 dní) → uložit do `/root/keys/` + **záloha u Vojty**
   (hesla do správce hesel, např. Bitwarden).
2. GitHub Secrets: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
   `KEY_PASSWORD`; CI keystore dekóduje a podepíše release.
3. `android/app/build.gradle.kts`: `signingConfigs.release` (z env;
   fallback debug pro lokální build).
4. Workflow: přejmenovat výstup na `emosphere-<verze>.apk` (+ sha256,
   artifact i release asset).
5. **Migrace:** stávající 0.1.x (debug podpis) → **jednorázově odinstalovat**;
   od další verze už aktualizace běží přes sebe a data zůstávají.
   Před odinstalací: zálohovat nsec (Nastavení → Záloha klíče) — nebo začít
   s novou identitou (dosud šlo jen o testovací).

**Rizika:** ztráta keystore = nelze aktualizovat tutéž instalaci → proto
záloha; GitHub secrets = standardní praxe.

---

## R7 — Odolnost proti spamu a zneužití (pozdější fáze, vědomě odloženo)

**Kontext:** Nostr je otevřená síť — kdokoli si zdarma vygeneruje klíče
a může publikovat check-iny. Podpisy zaručují **pravost** (nikdo nemůže
vystupovat za cizí identitu), ale nechrání před spamem → teoreticky lze
přebarvit heatmapu. V alpha fázi bez ochrany (záměrně).

**Vrstvy obrany (od nejúčinnější):**
1. **Agregace v klientu — hlavní obrana:** do heatmapy počítat **max 1
   check-in od jednoho npub na buňku/okno** (např. 5 min); vážit podle stáří
   klíče a vztahu (přátelé výš). I 10 000 eventů jednoho klíče = 1 bod.
2. **Limit v aplikaci** (nápad Vojty): max 1 check-in za 5 min na npub.
   Je to pravidlo pro *naše* uživatele (slušnost + nižší zátěž relayů);
   externí skript appku obejde — není to obrana proti útočníkovi.
3. **Verifikace podpisů příchozích eventů:** `event.isVerified()` z dart_nostr
   (knihovna ji nabízí, ale sama ji automaticky nevolá) — zahazovat neplatné
   eventy. Levné (pár řádků), lze udělat kdykoli.
4. **Výběr relayů:** preferovat relaye s anti-spam politikou (PoW, rate-limit).
5. **Později možno:** vlastní relay s vlastními pravidly.

**Fáze:** až po R1–R6 (alpha = bez omezení). Výjimka: bod 3 lze vzít brzy.

---

## R8 — Heatmapa místo kruhů (vizuální vylepšení mapy)

**Cíl (Vojta, 22. 10.):** mapa má vypadat jako **plynulá heatmapa** — měkké
bloby, které se v překryvu slévají (jako radar), místo kruhů s ostrými hranami.

**Současný stav:** každá buňka = 3 vrstvy kruhů (`CircleLayer`: glow 1,55×,
výplň s rámečkem, přátelský prstenec) — ostré hrany, kruhy se neslévají.

**Varianta A (doporučená) — vlastní vyhlazovací vrstva `HeatLayer`:**
- Custom flutter_map vrstva + `CustomPainter`: každá buňka = **radiální
  gradient** (střed barvy → průhledná), aditivní blend (`BlendMode.plus`) →
  bloby se přirozeně slévají; jas/velikost = počet a intenzita.
- Zachová R1: barva = OKLab mix; klepnutí na buňku = rozpad (hit-test
  `resolveTap` už existuje — beze změny).
- Výkon: kreslí se jen viditelné buňky — stovky buněk v pohodě.

**Varianta B — balíček `flutter_map_heatmap`:** ❌ nevhodný — vyžaduje
flutter_map 6 (máme 8.3) a umí jen jednu barevnou škálu podle hustoty.

**Varianta C — rastrový overlay (budoucí optimalizace):** vykreslit do
bitmapy s rozostřením; nejhladší výsledek, ale složitější (překreslování
při zoomu). A stačí; C jen pokud by bylo potřeba.

**Ukázka:** porovnání stylů (`noc/emosphere-artifacts/mockups/heatmap-style.png`)
— posláno Vojtovi 22. 10. **Stav:** implementováno (v0.3.0); oprava polohy
blobu ve v0.3.2 — buňka se kreslí na těžiště svých check-inů, ne na střed
hrubé buňky (pražské check-iny dřív zářily nad Skandinávií / Maďarskem).

---

## R9 — Stroj času: časová osa vývoje nálady na mapě

**Cíl (Vojta, 23. 10.):** na mapě slider s časem + tlačítko ▶ — uživatel vidí,
jak se nálada ve světě vyvíjela (animace).

**Dnes:** mapa umí okna 1 h / 24 h / 7 dní; vždy ukazuje „teď“ (celé okno).

**Návrh:**
- Pod přepínač oken přibude **časová osa** (slider) + tlačítko **▶ / ⏸**.
  Osa je svázaná se zvoleným oknem (1 h / 24 h / 7 dní); pravý konec = teď.
- **Živý režim** = dnešní chování (celé okno). Posun slideru překreslí mapu na
  stav v čase T; u pravé hrany tlačítko **„Teď“** (návrat k živému).
- **Play** = přehrání od začátku okna do „teď“ (~8 s), pak návrat do živého
  režimu. Klepnutí kamkoli přehrávání pauzne.
- Popisek času: „pá 12. 10. · 14:30“ (čas dle zařízení).
- Check-iny, které dorazí během přehrávání, se projeví až po návratu do živého
  režimu (čas je zamrzlý — mapa se nepřepočítává pod rukama).

**Dvě varianty vykreslování (k rozhodnutí):**

| Varianta | Co záře v čase T ukazuje | Výhody | Nevýhody |
|---|---|---|---|
| **A — kumulativní (doporučeno)** | všechny check-iny od začátku okna do T | svět „ožívá“ postupně; funguje i při málo datech; dobře čitelné | méně „právě teď“ |
| B — klouzavé okno | jen check-iny za poslední zlomek okna (např. 2 h z 24 h) | ukazuje aktuální dění; bloby se objevují a mizí | při alpha objemu dat často prázdné blikání |

**Technika:** události předtříděné podle času → kumulativní agregace
přírůstkově (O(1) na krok); scrubbing = přepočet z nuly (levné). Kreslí
stávající `HeatLayer` beze změny — mění se jen vstupní agregát. Nová komponenta
`TimelineBar` + stav přehrávání v `app_state`.

**Rozhodnuto (Vojta, 23. 10.):** **B — klouzavé okno** s volitelnou délkou okna
(chipy **1 h / 6 h / 24 h** — žádané „více variant“; výchozí 6 h). Kumulativní
varianta zůstává jako možný budoucí přepínač; délka přehrání ~8 s.

**Implementováno (v0.5.0):** `lib/widgets/timeline_bar.dart` (`TimelineBar` —
▶/⏸, slider, popisek instantu, chipy 1h/6h/24h); stav přehrávání žije v
`_MapScreenState` (je to vlastnost mapy, ne globálního stavu). Osu tvoří
zvolené okno (1 h / 24 h / 7 dní), pravý konec = teď; scrubbing kreslí
klouzavé okno `[T − D, T]` (`filterBySlidingWindow` v `aggregate.dart`,
D = chipy, výchozí 6 h); ▶ = ~8s přehrání celého okna → návrat do živého;
tap kamkoli přehrávání pauzne (průhledná vrstva nad mapou — okamžitá, bez
double-tap prodlevy flutter_mapu); čas se během scrubu mrazí (kotva
`_anchor`); popisek `pá 12. 10. · 14:30`; prázdný stav „nikdo nic nesdílel“
se během scrubu nezobrazuje. **Live režim beze změny** (celé okno, jak dnes).

---

## R10 — Animace po odeslání („afterglow“)

**Cíl (Vojta, 23. 10.):** po odeslání check-inu krátká „satisfying“ animace,
která uživateli pomůže emoci zpracovat (motivace + uzavření).

**Návrh:**
- Po úspěšném odeslání se sheet plynule přelije do tmavého overlay (300 ms)
  s částicovou animací **v barvě zvolené emoce** (~4 s).
- Na konci plynule naskočí **citát** (R11) — jeden zážitek: animace → citát.
- **Skip:** klepnutím přeskočit na citát, dalším klepnutím zavřít.
- **Haptika:** jemný impuls na začátku + doprovodné pulzy (vypnutelné
  v Nastavení). Respektovat systémové „omezit animace“ (pak rovnou citát).
- Selhání odeslání: beze změny (červený snackbar, sheet zůstává).

**Styly per emoce (společný engine; per-emoce jen parametry — barva, směr,
tvar, rychlost):**

| Emoce | Barva | Animace |
|---|---|---|
| Radost | `#FFD93D` | stoupající jiskry, jemné rozprsknutí |
| Klid | `#4ADE80` | dýchající soustředné kruhy (nádech/výdech) |
| Láska | `#F472B6` | srdíčka / částice pomalu odplouvající vzhůru |
| Překvapení | `#FB923C` | rychlý radiální záblesk → jiskření, které se zklidní |
| Smutek | `#60A5FA` | kapky pomalu stékající a rozplývající se |
| Vztek | `#EF4444` | uhlíky stoupají a dohasínají |
| Strach | `#A78BFA` | jemný dým, který se rozptýlí |
| Únava | `#94A3B8` | tlumené pomalé pulzy, které se zpomalí a ztiší |

**Technika:** vlastní `CustomPainter` + `AnimationController` (žádný balíček,
stejně jako `HeatLayer`); desítky částic, 60 fps, nízká zátěž.

**Rozhodnuto (Vojta, 23. 10.):** délka **~4 s** (jemná částicová); haptika
zapnutá (s přepínačem v Nastavení); storyboard netřeba — staví se přímo.

**Implementováno (v0.4.0):** `showAfterglow` — průhledná route nad celou
appkou (~4,4 s); klepnutí během částic přeskočí na citát, další klepnutí
zavře; respektuje systémové „omezit animace“ (rovnou citát); haptika řízená
přepínačem v Nastavení; když citát chybí, zůstává potvrzovací snackbar.

---

## R11 — Citáty k emocím

**Cíl (Vojta, 23. 10.):** po animaci citát vztahující se k emoci — pomáhá
reflektovat a emoci zpracovat. ~20 citátů na emoci (celkem 160).

**Zdroj (návrh):**
- buddhistické/zenové texty (Dhammapada, zen), stoikové (Marcus Aurelius,
  Seneca, Epiktétos), psychologové (Jung, Frankl, Rogers), moderní autoři
  (Thich Nhat Hanh, Rumi, Laozi).
- **Politika ověřování:** preferovat dohledatelné citáty. Oblíbené apokryfy
  (např. „Držet vztek je jako držet žhavé uhlí“, připisováno Buddhovi) vynechat
  nebo označit „připisováno“ — bez falešných atribucí.
- Každý citát **CZ + EN** (aplikace je dvojjazyčná). Uloženo v `assets/quotes.json`
  — plně offline, bez serveru a stahování.
- Seznam ke kontrole Vojtovi před nasazením (návrh).

**Výběr a zobrazení:**
- Výběr **deterministicky podle ID check-inu** (stejný check-in → stejný citát;
  nic se neukládá, přepočet z ID). Varianta: pokaždé náhodný.
- Zobrazení: karta v overlay po animaci — citát + autor, jemný fade-in.
- Bonus: citát i v detailu check-inu v Historii (lze vypnout).

**Rozhodnuto (Vojta, 23. 10.):** jazyk **CZ+EN**; **20 citátů na emoci**
(celkem 160), výběr **náhodný** při každém zobrazení; citát i v Historii;
seznam bez předchozího schválení („věřím ti, jdi rovnou“) — atribuce přesto
ověřené, bez falešných.

**Implementováno (v0.4.0):** `assets/quotes.json` — 160 citátů (8 × 20, CZ+EN);
atribuce ověřené, nejisté označené „připisováno“; výběr náhodný při každém
zobrazení; citát je součástí afterglow a nově i detailu check-inu v Historii
(klepnutí na kartu v časové ose).

---

## Pořadí a odhady (návrh)

1. **R6** (balení) — malé, odstraní trable s instalací
2. **R2** (lokalita) — malé
3. **R3 + R4** (profily + sheet) — střední
4. **R1 + R8** (barvy + heatmapa) — jeden vizuální balík (střední)
5. **R5** (DM) — větší (volba A/B)

**Nové položky R9–R11 (23. 10.):**

6. **R10 + R11** (afterglow + citáty) — jeden zážitek; první balík
   z nových nápadů (Vojta: uživatel má být motivován) — **hotovo (v0.4.0)**
7. **R9** (stroj času) — po R10/R11; plně vynikne, až bude víc dat
   — **hotovo (v0.5.0)**

*(potvrzeno Vojtou 23. 10.: první **R10 + R11**, pak **R9**; R9 doručen 23. 10.)*

## Rozhodnutí Vojty (22. 10. 2026)

- **(a) Barvy: varianta A** — zachovat schválenou paletu + OKLab mix.
  Před nasazením vygenerovat ukázkovou stránku se všemi 36 dvojicemi emocí.
- **(b) Oblast = geohash-6** (okruh ~0,5 km); pořadí Vypnuto · Město · Oblast.
- **(c) DM: NIP-04** pro v1 (NIP-17 ponechat jako budoucí upgrade, stejné UX).
- **(d) Zprávy: badge v hlavičce** feedu.
- **(e) Pořadí implementace** (R6 → R2 → R3/R4 → R1 → R5): **schváleno** 22. 10.;
  čeká se na Vojtovo „jdi".
- **(f) Anti-spam (R7):** zapsáno, vědomě odloženo na pozdější fázi (diskuse
  22. 10.). Limit 1 check-in / npub / 5 min = nápad Vojty.
- **(g) Heatmapa (R8):** návrh + ukázka stylu (Telegram 22. 10.) — čeká na
  Vojtovo rozhodnutí; při „jdi" se dělá spolu s R1 jako jeden vizuální balík.
  → **implementováno** (v0.3.0, oprava polohy blobu v0.3.2).
- **(h) Nové nápady (R9–R11), 23. 10.:** pořadí **R10 + R11 první, pak R9**
  („věřím ti, jdi rovnou“ — seznam citátů bez předchozího schválení).
- **(i) R9 — stroj času:** **klouzavé okno** s volitelnou délkou (1 h / 6 h / 24 h).
- **(j) R10 — afterglow:** **~4 s**, jemná částicová animace; storyboard netřeba.
- **(k) R11 — citáty:** 20/emoci (160), výběr **náhodný**; citát i v Historii.

---

*Zapsal Hermes · 22. 10. 2026 (R1–R8) · doplněno 23. 10. 2026 (R9–R11) · zdroj: zadání Vojty (chat) · R10+R11 hotovo 23. 10. 2026 (v0.4.0) · R9 hotovo 23. 10. 2026 (v0.5.0) · položky bez „hotovo“ čekají na Vojtovo „jdi“*
