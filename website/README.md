# OldLocal website

Public site: https://oldleeo.github.io/OldLocal/

Buildless HTML, CSS and JavaScript, deployed with the GitHub Pages workflow in `.github/workflows/pages.yml`. No framework, dependency install or build step is required. Changes to `website/` on main trigger deployment. `index.html` is the product page; `guide.html` is the illustrated tutorial.

The coordinate interaction is a browser-only preview with public landmark presets. It neither reads nor modifies the user's real location. Inputs are kept in memory, with no storage or geolocation permission. Copy uses the Clipboard API, with manual selection as a fallback.

The site reads the public GitHub latest-release API for version and download links, validating repository and URL prefix. On network or rate-limit failures it retains permanent Releases links. App compatibility is based on the current published release; do not turn its macOS minimum into a claim of real location verification on every OS version.

Assets reuse the approved logo, author portrait and native app UI with isolated public landmark fixtures. Screenshots are optimized WebP exports. World-map land outlines are derived from [Natural Earth 1:110m land](https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_110m_land.geojson), which is [public domain](https://www.naturalearthdata.com/about/terms-of-use/); the coordinate map is an equirectangular overview, not live map tiles.

No analytics, tracking pixels, newsletter forms or account systems are included. Browser HTTPS requests to hosting and GitHub follow those providers' policies.

Local preview:

```bash
python3 -m http.server 8768 --bind 127.0.0.1 --directory website
```

Maintain the project's existing software and resource licenses. Brand and portrait rights are described in the repository's `THIRD_PARTY_NOTICES.md`.
