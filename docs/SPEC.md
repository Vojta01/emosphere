# EmoSphere — zadání (v0.3 — finální pro noční směnu 21./22. 10. 2026)

> Zdroj: původní koncept Vojty (25. 6. 2026, Obsidian) + rozhodnutí 21. 10. 2026.
> Účel: zadání pro noční směnu (Flutter app na Nostr).

## Pitch
„Podívej se, jak se svět právě teď cítí. A řekni mu, jak se cítíš ty."

## Co to je
Mobilní + webová aplikace pro sdílení emocí přes Nostr protokol.
- Bez registrace: identita = Nostr klíč vygenerovaný v aplikaci.
- Check-in emoce → podepsaný event na veřejné relaye → světová mapa nálad.
- Soukromí: lokalita jen hrubá (oblast/město) nebo vypnutá. Žádné e-maily, žádná jména.

## Platformy (potvrzeno Vojta 21. 10. 2026)
1. **Android** — nativní appka (Flutter, APK ke stažení; později případně Google Play).
2. **Web/PWA** — Flutter web build, instalovatelná na **iPhone** přes Safari
   → „Sdílet" → „Přidat na plochu". Bez App Storu, bez Macu, zdarma.
   Hosting: GitHub Pages → **https://vojta01.github.io/emosphere/**
3. Nativní iOS: **vynecháno** (pokryto PWA). Scaffold odstraněn; případně později.

## Klíčová rozhodnutí (potvrzeno 21. 10.)
- Název: **EmoSphere**
- Emoce (8) + intenzita 1–5 (povinná)
- Barvy: radost #FFD93D · klid #4ADE80 · láska #F472B6 · překvapení #FB923C ·
  smutek #60A5FA · vztek #EF4444 · strach #A78BFA · únava #94A3B8
- Poznámka ke check-inu: volitelná, max 140 znaků, veřejná
- Lokalita: vypnuto / oblast (geohash 3) / město (geohash 5) — nikdy přesná
- Přátelé: součástí této fáze (follow přes npub)
- Jazyky: CZ + EN
- Mapa: **styl A** — heat buňky (barva = převládající emoce, záře = počet check-inů);
  při zbývajícím čase body při zoomu (styl D)
- Ikona: **varianta „nebulová planeta"** (v4) — vybráno Vojtou; detaily v
  `/root/workspace/noc/emosphere-icon-choice.txt` (+ SVG/PNG v `noc/emosphere-icons/`)

## Funkce (MVP)
1. Onboarding: co to je, vygenerování klíče, záloha nsec (text + QR), obnova z nsec
2. Check-in: emoce, intenzita, poznámka, lokalita → publikace
3. Mapa: heat buňky (geohash), okna 1 h / 24 h / 7 dní, klepnutí na buňku = rozpad;
   přátelé zvýrazněni
4. Feed: „Právě teď ve světě" (anonymně: emoce, město, čas) + „Moji blízcí"
5. Přátelé: přidat/odebrat npub, sdílet můj npub (kopírovat + QR), jméno/avatar z kind:0
6. Historie: moje check-iny + jednoduché statistiky (po emocích, po dnech)
7. Nastavení: relaye, přesnost lokace, jazyk, smazat moje data (NIP-09), záloha klíče, o aplikaci
8. Design: tmavý prémiový + logo EmoSphere

## Nostr technický design
- Kind: **1074** (EmoSphere check-in) — regular event
- Tags: ["t","emosphere"], ["e","<emotion-slug>"], ["i","<1-5>"],
  ["g","<geohash>"] (jen pokud je lokalita zapnutá)
- Content: poznámka (může být prázdná)
- Mazání: kind 5 (NIP-09) odkazující na moje 1074 eventy; v UI zmizí
- Klíč: native = flutter_secure_storage; web/PWA = localStorage (bezpečnostní
  kompromis — dokumentovat v UI u zálohy klíče)
- npub zobrazení (NIP-19 bech32)
- Relaye default: wss://relay.damus.io, wss://nos.lol, wss://relay.primal.net,
  wss://relay.nostr.band (uživatel může upravit)
- Knihovna: dart_nostr v10 (fallback: ndk) — čistě Dart, funguje i na webu
- Agregace mapy: klient stahuje 1074 eventy s #t=emosphere za zvolené okno,
  seskupí po geohash buňce (přesnost dle zoomu), převládající emoce (váženo
  intenzitou) + počet check-inů

## Obrazovky
- Splash (logo) → Onboarding (3 kroky) → Domů (mapa + tlačítko „Jak se cítíš?")
- Check-in sheet: 8 velkých barevných tlačítek emocí, intenzita (slider 1–5),
  poznámka, lokalita (toggle + přesnost), Odeslat
- Mapa: heat vrstva, přepínač oken, legenda barev, klepnutí = detail buňky
- Feed: karty check-inů (barva emoce, město, čas); nahoře sekce „Moji blízcí"
- Historie: timeline + mini grafy
- Nastavení + profil (npub, QR pro sdílení)
- Jazyk CZ/EN — přepínatelný

## Design
- Tmavý prémiový základ: pozadí gradient #0B1020 → #0E1430, glass karty
  (blur + border rgba(255,255,255,0.08)), glow akcenty v barvách emocí,
  jemné animace (pulzující heat, plynulé přechody), haptika
- Logo/ikona: „nebulová planeta" (viz výše) — finální SVG → PNG sady
  (adaptive icon Android, PWA ikony 192/512 + apple-touch-icon 180, splash)
- Rasterizace ikon: rsvg-convert (nainstalováno na serveru)

## Technický stack
- Flutter 3.47.7 stable (Dart 3.13.5), Android SDK 36, JDK 21
- Balíčky (orientační): dart_nostr, flutter_map + latlong2, geolocator,
  flutter_secure_storage, shared_preferences, qr_flutter, provider, intl
- Web: flutter build web --base-href /emosphere/ --pwa-strategy offline-first
- Hosting: GitHub Pages (workflow deploy), repo Vojta01/emosphere (public)
- Server má jen 3,8 GB RAM → gradle.properties: Xmx2G, workers.max=2
  (už nastaveno). Těžké buildy sériově: `flock /tmp/emosphere-build.lock`

## Kvalita a výstup noci
- `flutter analyze` bez chyb; všechny unit testy zelené
- APK (release) běží na Androidu 13 (redroid emulátor) — screenshoty klíčových obrazovek
- PWA build funguje; nasazený na GitHub Pages; instalovatelný na iPhone
- Repo: kód + README (EN) + screenshoty + CI (Android build+testy; web deploy)
- APK ke stažení (GitHub Release v0.1.0 + raw link)
- Ranní report na Telegram

## Pravidla pro workery (konvence)
- Commity: conventional commits (feat/fix/chore/docs/test), anglicky
- Před push: `git pull --rebase`; malé commity; nikdy neforce-push
- Každá karta: na konci spustit `flutter analyze` + `flutter test` (musí projít)
- Struktura: lib/core (model, nostr, storage, i18n), lib/screens, lib/widgets, lib/theme
- Interface mezi kartami: přesné názvy tříd/metod viz karty níže

## Priority (kdyby noc nestíhala)
1. Jádro: klíč + check-in + publikace/čtení relayů
2. Mapa + feed
3. Přátelé
4. PWA deploy + APK build + screenshoty
5. Historie/statistiky + polish
