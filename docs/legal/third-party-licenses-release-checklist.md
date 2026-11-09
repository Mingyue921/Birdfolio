# Birdfolio 第三方许可证说明（商业发布前草案）

> 草案，需在正式发布前由专业人员复核。

版本：`0.1-draft`  
核对日期：2026-11-08

本文件以仓库根目录 `THIRD_PARTY_ASSETS.md` 为第三方素材事实来源，并结合锁文件、逐素材清单和随附许可证整理。它用于发布准备，不替代第三方的完整许可证原文和服务条款。发布包应同时保留仓库中的作者清单、许可原文和必要的应用内归属展示。

## 文档状态

- **当前事实**：已登记 GBIF/Wikimedia 图片、OpenMoji、Fabric.js、七款 Google Fonts 字体和腾讯地图 SDK 依赖。
- **正式发布前必须完成**：应用内归属、Fabric.js MIT 原文、腾讯地图条款核验、Release HAP 软件物料清单和逐素材抽查。
- **需要人工确认**：腾讯地图 SDK 分发条款、测试依赖是否进入发布包、实际在线服务条款版本均为 `[待确认]`。

## 1. 离线鸟类照片

Birdfolio 在 `entry/src/main/resources/base/media/bird_*.jpg` 中打包 50 张压缩鸟类照片。

- 来源：GBIF occurrence media 与 Wikimedia Commons 文件页；
- 接受的许可证：CC0 1.0、CC BY 4.0；
- 修改：缩放至不超过 960 x 720、转换为 JPEG，并移除元数据；
- 逐图作者、许可证、原图 URL、来源页和 occurrence key：`catalog/bird-image-attribution.json`。

发布时必须为 CC BY 4.0 图片保留逐图作者和许可归属，不得将这些照片标为 Birdfolio 原创。CC0 素材仍建议保留来源记录。

## 2. 在线 GBIF 内容

服务端可通过 GBIF API 补充物种、出现记录和媒体。当前仅选择标记为 CC0 1.0 或 CC BY 4.0 的媒体，并在数据模型中保留作者、许可和来源 URL。

GBIF 聚合的具体记录权利归数据发布者或媒体权利人。应用展示、缓存和再分发时仍应遵守逐条记录的许可与 GBIF 使用要求。正式发布前应在应用内为在线图片提供可访问的作者、许可和来源入口，该展示验收属于`待开发/待验收`。

## 3. OpenMoji 贴纸

- 项目：OpenMoji；
- 版权：OpenMoji contributors，逐素材作者记录在 `stickers.json`；
- 许可证：Creative Commons Attribution-ShareAlike 4.0 International（CC BY-SA 4.0）；
- 官网：https://openmoji.org/ ；
- 修改：文件改为可读名称并组织为 Birdfolio 贴纸目录，SVG 图稿未作其他修改；运行时另包含官方 PNG 版本。

再分发或修改时必须保留署名，并对适用的衍生作品遵守相同方式共享要求。逐素材来源和作者位于 `entry/src/main/resources/rawfile/journal_editor/assets/stickers/stickers.json`。

## 4. Fabric.js

- 项目：Fabric.js 5.3.0；
- 官网：https://fabricjs.com/ ；
- 许可证：MIT；
- 文件：`entry/src/main/resources/rawfile/journal_editor/fabric.min.js`。

发布包及源代码分发应保留 MIT 许可证要求的版权和许可声明。仓库当前未发现独立的 Fabric.js MIT 许可证文本，补充完整原文属于`待发布整改`。

## 5. Google Fonts 字体

手账编辑器打包以下字体：

- ZCOOL XiaoWei Regular；
- Ma Shan Zheng Regular；
- ZCOOL QingKe HuangYou Regular；
- Long Cang Regular；
- Liu Jian Mao Cao Regular；
- Zhi Mang Xing Regular；
- ZCOOL KuaiLe Regular。

许可证均为 SIL Open Font License 1.1。每个字体目录旁已保存对应 `OFL.txt`。Birdfolio 当前未修改字体二进制；若未来修改，必须遵守 OFL 及保留字体名称等要求。

## 6. 腾讯地图 HarmonyOS SDK

锁文件记录：

- `@tencentmap/map` 2.7.0；
- `@tencentmap/base` 2.7.0；
- 随包原生地图引擎库 `libmapengine.so`。

仓库中未发现可据以断言再分发条款的独立许可证文件。腾讯地图属于第三方商业/平台服务，使用者必须遵守腾讯地图届时有效的开发者协议、隐私政策、Key 限制和归属展示要求。正式发布前核对 SDK 分发授权、用户条款链接、Logo/版权展示及数据处理说明，属于`待法律与运营核验`。

## 7. OpenHarmony 测试开发依赖

锁文件还记录 `@ohos/hypium` 1.0.25 和 `@ohos/hamock` 1.0.0，主要用于测试开发。仓库未附带其许可证文本，且是否进入最终发布包需由构建产物核验。许可证确认和发布包软件物料清单（SBOM）属于`待发布整改`。

## 8. 第三方在线服务

以下是服务而非仓库内开源资产，仍需在正式条款和隐私政策中披露：

- GBIF API；
- 腾讯地图服务；
- 部署方配置的 OpenAI-compatible 视觉服务；
- 部署方配置的邮件网关。

实际视觉和邮件服务商尚未确定，不得预先写成特定品牌，也不得在未核对合同的情况下承诺不留存或不训练。

## 9. 发布清单

正式发布前应：

1. 保留 `catalog/bird-image-attribution.json` 和 `stickers.json` 的逐素材归属；
2. 在应用内提供用户可访问的第三方许可与来源页面；
3. 补充 Fabric.js MIT 完整许可证文本；
4. 核验腾讯地图 SDK、Hypium、Hamock 及所有构建产物依赖的许可证；
5. 生成并审核发布包 SBOM，确认没有未登记素材或依赖；
6. 对 CC BY-SA、CC BY 和 OFL 的署名、相同方式共享及保留声明要求进行发布验收。

