# agape-farmstead-seo-proposal

Proposal decks for **Agape Farmstead** (agapefarmstead.com) — vertical 9:16 HTML presentations built from a shared template and YAML content files.

## Decks (GitHub Pages)

| Deck | Link | Source YAML |
|------|------|-------------|
| **SEO & Content Proposal** | [sharpninja.github.io/agape-farmstead-seo-proposal](https://sharpninja.github.io/agape-farmstead-seo-proposal/) | `source/seo.yml` |
| **Thanksgiving Delivery Expansion** | […/thanksgiving.html](https://sharpninja.github.io/agape-farmstead-seo-proposal/thanksgiving.html) | `source/thanksgiving.yml` |
| **Brand Sustainability & Growth** | […/brand-growth.html](https://sharpninja.github.io/agape-farmstead-seo-proposal/brand-growth.html) | `source/brand-growth.html` |

## Regenerate a deck

```powershell
cd source
./generate.ps1 -InputFile seo.yml -Output ../docs/index.html
./generate.ps1 -InputFile thanksgiving.yml -Output ../docs/thanksgiving.html
./generate.ps1 -InputFile brand-growth.yml -Output ../docs/brand-growth.html
```

## Structure

- `source/template.html` — shared 9:16 slide template with forest/money-green theming
- `source/generate.ps1` — PowerShell generator that merges YAML into the template
- `source/*.yml` — per-deck content (meta, slides, cards, lists, asks)
- `docs/` — generated HTML published via GitHub Pages (docs folder workflow)

## Contact

Agape Farmstead · Clarksville / Adams, TN · (931) 272-1269 · agapefarmstead@outlook.com
