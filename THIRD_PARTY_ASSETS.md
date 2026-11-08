# Third-Party Assets

## Offline bird photographs

Birdfolio bundles 50 compressed bird photographs under `entry/src/main/resources/base/media/bird_*.jpg` for the offline Chinese catalogue.

- Sources: GBIF occurrence media and Wikimedia Commons file pages
- Accepted licenses: CC0 1.0 and CC BY 4.0 only
- Changes: Images are resized to fit within 960 x 720 pixels, converted to JPEG, and metadata is removed to reduce the HAP size.
- Per-image species ID, author, license, original image URL, source page, and occurrence key are stored in `catalog/bird-image-attribution.json`.
- The generated HarmonyOS resource mapping is stored in `entry/src/main/ets/data/BirdImageMap.generated.ets`.

CC BY 4.0 images require attribution to the author recorded in the manifest. Preserve the manifest when redistributing the app or its assets.

## OpenMoji sticker subset

Birdfolio includes a curated subset of 26 OpenMoji color SVG assets under:

`entry/src/main/resources/rawfile/journal_editor/assets/stickers/openmoji/`

- Project: OpenMoji
- Website: https://openmoji.org/
- Copyright: OpenMoji contributors; individual authors are recorded in `stickers.json`
- License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
- License URL: https://creativecommons.org/licenses/by-sa/4.0/
- Changes: Files were renamed to readable asset names and organized into a Birdfolio sticker catalog. The SVG artwork is otherwise unmodified.

Per-asset source URLs, author names, categories, and attribution requirements are stored in:

`entry/src/main/resources/rawfile/journal_editor/assets/stickers/stickers.json`

When redistributing these stickers or modified versions, preserve attribution and the CC BY-SA 4.0 license.

## Fabric.js

- Project: Fabric.js 5.3.0
- Website: https://fabricjs.com/
- License: MIT
- Bundled file: `entry/src/main/resources/rawfile/journal_editor/fabric.min.js`

## Google Fonts for the journal editor

Birdfolio bundles the following font files from the official Google Fonts
repository for offline journal editing and image export:

- ZCOOL XiaoWei Regular
- Ma Shan Zheng Regular
- ZCOOL QingKe HuangYou Regular
- Long Cang Regular
- Liu Jian Mao Cao Regular
- Zhi Mang Xing Regular
- ZCOOL KuaiLe Regular

Each family is licensed under the SIL Open Font License 1.1. Its original
`OFL.txt` is stored beside the corresponding font file under:

`entry/src/main/resources/rawfile/journal_editor/assets/fonts/`

The fonts may be used commercially and embedded in the application. Modified
font versions must follow the OFL requirements, including reserved font names
where applicable. Birdfolio does not modify the original font binaries.
