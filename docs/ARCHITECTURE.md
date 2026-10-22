# EmoSphere — Architektura (proč Nostr)

> Podklad pro odpovědi typu „proč jsi použil Nostr?" · 22. 10. 2026

## Přehled

- **Klient** (Flutter aplikace / PWA) = celá aplikace: klíče, UI, agregace
  heatmapy, míchání barev.
- **Žádný vlastní backend.** Data = podepsané eventy na veřejných **relayích**
  (relay.damus.io, nos.lol, relay.primal.net, relay.nostr.band — seznam je
  konfigurovatelný).
- **Identita** = kryptografický pár klíčů: `npub` (veřejný) + `nsec` (soukromý).
  Žádná registrace, žádný účet, žádné heslo, žádný e-mail.
- Typy dat: check-in = kind `1074` (tagy `t`/`emotion`/`intensity`/`g`),
  profil = kind `0`, přátelé = kind `3`.

## Proč Nostr (výhody)

1. **Decentralizace** — žádný centrální server ani databáze; žádný jediný bod
   selhání; data replikovaná přes mnoho nezávislých relayů.
2. **Nulové provozní náklady** — neplatíme hosting, databázi ani provoz;
   aplikace je jen tenká vrstva nad hotovou infrastrukturou.
3. **Soukromí v základu** — nemáme databázi uživatelů (žádné osobní údaje
   k úniku). Identita je klíč, ne účet.
4. **Žádný vendor lock-in** — otevřený protokol; klienta i relaye může kdokoli
   nahradit nebo provozovat vlastní.
5. **Odolnost proti cenzuře** — žádná firma nemůže aplikaci centrálně vypnout.
6. **Ekosystém** — stejná identita funguje i v dalších Nostr aplikacích;
   data nejsou zamčená v naší appce.

## Nevýhody (poctivě)

1. **Žádné záruky doručení** — relay může event odmítnout nebo smazat; proto
   klient pracuje s více relayi najednou.
2. **Omezené dotazování** — nelze SQL join ani fulltext; filtruje se podle
   kindu, autora, tagů a času. Agregace (heatmapa) se počítá v klientu.
3. **Metadata jsou veřejná** — kdo, kdy a co publikoval. Soukromý obsah
   potřebuje dodatečné šifrování (DM — NIP-04/17).
4. **Spam a šum** — otevřená síť; filtrování je na straně klienta.
5. **Omezená moderace** — cizí obsah nelze centrálně mazat.
6. **Slabší konzistence** — bez realtime garance; propagace eventů má zpoždění.
7. **Zodpovědnost za klíč** — ztráta `nsec` = ztráta identity (neexistuje
   „reset hesla"); proto máme zálohu klíče v Nastavení.
8. **Náročnější vývoj** — protokolová specifika (např. validace tagů relayi),
   vlastní krypto pro DM.

## Alternativy a proč ne

| Možnost | Plus | Mínus |
|---|---|---|
| Vlastní centrální backend (API + Postgres/Supabase) | plná kontrola, SQL, moderace, notifikace | náklady, údržba, odpovědnost za data (GDPR), jeden bod selhání |
| Firebase / Supabase (BaaS) | rychlý start | centralizace, účty s e-maily, lock-in na poskytovatele |
| ActivityPub (Mastodon) | federace, známé | identita vázaná na instanci, účtový model, nesedí pro app-specific data |
| Matrix | federovaný chat | messenger protokol — pro mapu nálad nevhodný model |
| Vlastní P2P (libp2p…) | maximální kontrola | nesrovnatelně více práce (síť, discovery, NAT) |

## Elevator pitch (krátká odpověď)

> „EmoSphere neukládá data do žádné centrální databáze. Každý uživatel má
> vlastní kryptografickou identitu a jeho příspěvky žijí na desítkách
> nezávislých serverů v otevřené síti Nostr. Nemusíme provozovat backend,
> nemáme databázi osobních údajů a aplikace nemá jediný bod selhání — a nikdo
> ji nemůže centrálně vypnout. Cenou je závislost na veřejné infrastruktuře
> a chybějící garance doručení: proto klient pracuje s více relayi a všechno
> agreguje lokálně."

## Delší odpověď (kdyby se ptali víc)

- **Bez backendu** = žádné měsíční náklady, žádná údržba serveru, žádná
  migrace databáze. MVP v provozu „za nula".
- **Soukromí**: uživatel není účet v cizí databázi; je to klíč. Nemůžeme
  (a ani nechceme) sbírat e-maily, telefony, jména.
- **Decentralizace jako princip**: u aplikace o sdílení emocí je důvěra
  v jednu firmu zbytečná — síť relayů drží data, i kdyby jeden vypadl.
- **Trade-offy vědomě**: místo garance doručení máme redundanci přes relaye;
  místo SQL máme klientskou agregaci; místo centrální moderace máme filtrování
  a politiky relayů.
- **Kdy by centrální backend byl lepší**: kdyby data měla být tajná
  (health data), nebo kdybychom potřebovali složité dotazy, moderaci či push
  notifikace na serveru. Pro veřejnou mapu nálad je Nostr výhodnější.

---

*Zapsal Hermes · 22. 10. 2026 · podklad pro obhajobu architektury*
