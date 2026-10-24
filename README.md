# Agape Farmstead SEO Proposal

Proposal decks for Agape Farmstead (agapefarmstead.com), a regenerative, faith-driven farm in Clarksville/Adams, TN.

## Live Decks (GitHub Pages)

| Deck | Link |
|------|------|
| SEO & Content Proposal | https://sharpninja.github.io/agape-farmstead-seo-proposal/seo.html |
| Thanksgiving Delivery Expansion | https://sharpninja.github.io/agape-farmstead-seo-proposal/thanksgiving.html |
| Brand Sustainability & Growth | https://sharpninja.github.io/agape-farmstead-seo-proposal/brand-growth.html |

## Regenerate a Deck

```powershell
cd source
./generate.ps1 -InputFile seo.yml
./generate.ps1 -InputFile thanksgiving.yml
./generate.ps1 -InputFile brand-growth.yml
```

All decks default to the **agape-farm** theme (warm cream, olive green, earthy brown, Georgia serif headlines). Swap themes with `-Theme <name>` — theme files live in `source/themes/`.

## Source Structure

- `source/template.html` — slide shell; colors/fonts/spacing are `__TOKEN__` placeholders filled from the theme
- `source/themes/agape-farm.json` — theme tokens (colors, fonts, radii, padding)
- `source/themes/agape-farm.css` — compiled `:root` custom properties for static serving
- `source/generate.ps1` — YAML-to-HTML generator
- `source/*.yml` — deck content (meta + slides)

## Edit Content

Edit any YAML file — titles, subtitles, lists, cards, phases, stats, and the ask slide — then rerun the generator. No HTML editing required.
