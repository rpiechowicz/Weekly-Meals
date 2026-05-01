# Weekly Meals Logo

Aktualny kierunek (v2 "Cozy Kitchen"): **Steaming Bowl** — terakotowa miska
z trzema strugami pary układającymi się w abstrakcyjne `W`. Cieplejszy,
bardziej "food-first" niż wcześniejszy monogram, dalej czytelny w skali
tiny (28pt) i hero (140pt+).

## Pliki

- `weekly-meals-logo-bowl.svg` — wariant dark (gradient ciepły brąz),
  źródło 1024×1024 (viewBox 100×100). To jest aktualny logo source.
- `weekly-meals-logo-bowl-light.svg` — wariant light (kremowo-pastelowy
  gradient na cream-bg).
- `weekly-meals-logo-bowl-mark.svg` — monochromatyczny znak (`currentColor`)
  do użycia jako pojedynczy kolor (np. tinted icon, share-sheet glyph).

### Legacy (zostają dla referencji, nie są aktualnym kierunkiem)

- `weekly-meals-logo-icon.svg`, `weekly-meals-logo-mark.svg` — pierwszy
  monogram `W`.
- `weekly-meals-app-icon-v2.svg` (+ `-dark-v2`, `-tinted-v2`) — App Store
  icon z monogramem `W`. Do wymiany podczas najbliższego release-cycle'u
  (eksport bowl logo do PNG 1024×1024 i podmiana w
  `Assets.xcassets/AppIcon.appiconset/`).

## SwiftUI

Logo jest renderowane natywnie przez `WMSteamingBowlLogo`
(`weekly meals/Components/WMSteamingBowlLogo.swift`) — Canvas-based,
wektorowo, bez aliasingu i bez bundlowania PNG-ów. Parametry:

- `size` — bok kwadratu (px)
- `mono` — true → bez gradientów, kolor tła = `bgCard` z palety
- `palette` — `.auto` (śledzi `ColorScheme`), `.dark`, `.light`

## Design intent

- Misa = kuchnia, prostota, codzienność.
- Para w kształt `W` = Weekly / cykl tygodnia (subtelne nawiązanie do
  starego monogramu, bez literackości).
- Terakota + butter + cream = "cozy kitchen" paleta (vide
  `WMPalette` w `Components/WMDesignSystem.swift`); spójne z
  całym v2 redesignem (kalendarz, przepisy, settings, onboarding).
