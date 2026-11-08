# Journal editor assets

The editor treats every sticker provider as a separate asset collection so that
source attribution and license terms remain traceable.

## Directory layout

```text
assets/
  stickers/
    stickers.json
    openmoji/
    noto-emoji/        # Add only when Noto Emoji artwork is imported.
  fonts/
```

`catalog.js` is the offline runtime catalog loaded directly by ArkWeb. This avoids
using `fetch()` with HarmonyOS rawfile resource URLs. `stickers.json` is the full
licensing catalog. Each sticker must have a stable `id`, a
Chinese `name`, a `category`, a rawfile-relative `file`, its original `source`,
the `author` or project owner, its `license`, and `attributionRequired`.

The editor saves only the stable ID in journal data. A filename may therefore be
changed only together with its catalog entry, while an existing ID should not be
renamed after release.

`sticker-data.js` is generated from the local PNG files and embeds their bytes as
data URLs. ArkWeb can show rawfile SVGs in an `<img>`, but some versions cannot
paint SVG images into Canvas even when they use data URLs. Fabric therefore uses
the official PNG artwork in `stickers/openmoji/png/`. The SVG files remain the
high-quality source archive and licensing reference.

## Adding OpenMoji stickers

1. Download the color SVG from the official OpenMoji repository or website.
2. Put it in `stickers/openmoji/` using a lowercase descriptive filename.
3. Add the runtime entry to `catalog.js` and the full licensing entry to
   `stickers.json`, using an ID prefixed by `openmoji-`.
4. Record the icon page, individual author, and `CC BY-SA 4.0` license.
5. Preserve the attribution in `THIRD_PARTY_ASSETS.md` when distributing the app.

OpenMoji modifications and redistributed derivatives remain subject to the
share-alike requirement of CC BY-SA 4.0.

## Using Noto Emoji

Noto Emoji is suitable as another sticker artwork provider. Prefer its individual
SVG or PNG artwork over loading `NotoColorEmoji.ttf` in ArkWeb: support for color
font tables varies by HarmonyOS and WebView version, while image assets render
consistently and export correctly through Fabric.js.

Official repository: `https://github.com/googlefonts/noto-emoji`

For each selected asset:

1. Take the matching file from the repository's `svg/` or PNG asset set.
2. Put it in `stickers/noto-emoji/`.
3. Add a catalog entry with an ID prefixed by `noto-emoji-`.
4. Set the license to `Apache-2.0` and record Google/Noto Emoji as the author.
5. Add the Apache 2.0 notice to `THIRD_PARTY_ASSETS.md` before shipping those files.

Do not use Noto Emoji as the journal's Chinese text font. For Chinese typography,
use separately licensed text fonts such as Noto Sans SC for body text and Noto
Serif SC for titles. Put webfont subsets in `assets/fonts/`, declare them with
`@font-face`, and add their SIL Open Font License notice.

## Runtime rules

- Keep SVG artwork self-contained; do not reference remote images or fonts.
- Use intrinsic image dimensions and a uniform Fabric scale to avoid cropping.
- Keep preview assets reasonably small; optimize SVGs without removing credits.
- Test add, restore, duplicate, transform, delete, and exported PNG rendering.
