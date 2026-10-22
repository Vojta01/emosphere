# EmoSphere — Roadmap a návrhy (pipeline)

> **Stav: návrhy k odsouhlasení.** Nic z tohoto není implementované.
> Až Vojta řekne „jdi", položky se mění na commity / karty noční směny.
> Zapsáno: 22. 10. 2026 · verze aplikace v době zápisu: **0.1.2+3**

## Přehled

| # | Téma | Stav |
|---|------|------|
| R1 | Heat mapa — barva buňky = směs všech check-inů (realtime) | rozhodnuto: **A** |
| R2 | Lokalita — oprava granularity: Vypnuto · Město · Oblast | rozhodnuto |
| R3 | Profily — jméno + ikonka (kind 0) | návrh |
| R4 | Feed → klepnutí na check-in → profil uživatele + přidat do přátel | rozhodnuto: badge v hlavičce |
| R5 | Privátní zprávy (DM) | rozhodnuto: **NIP-04** (v1) |
| R6 | APK — název `emosphere-<verze>.apk` + stabilní podpis + zachování dat | připraveno |

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

## Pořadí a odhady (návrh)

1. **R6** (balení) — malé, odstraní trable s instalací
2. **R2** (lokalita) — malé
3. **R3 + R4** (profily + sheet) — střední
4. **R1** (barvy) — střední (+ volba A/B)
5. **R5** (DM) — větší (volba A/B)

## Rozhodnutí Vojty (22. 10. 2026)

- **(a) Barvy: varianta A** — zachovat schválenou paletu + OKLab mix.
  Před nasazením vygenerovat ukázkovou stránku se všemi 36 dvojicemi emocí.
- **(b) Oblast = geohash-6** (okruh ~0,5 km); pořadí Vypnuto · Město · Oblast.
- **(c) DM: NIP-04** pro v1 (NIP-17 ponechat jako budoucí upgrade, stejné UX).
- **(d) Zprávy: badge v hlavičce** feedu.
- **(e) Pořadí implementace** (R6 → R2 → R3/R4 → R1 → R5): vysvětleno 22. 10.;
  čeká se na Vojtovo „jdi".

---

*Zapsal Hermes · 22. 10. 2026 · zdroj: zadání Vojty (chat) · nic neimplementováno*
