# vRain（兀雨）—— 中文古籍刻本風格直排電子書製作工具

[![Version](https://img.shields.io/badge/version-v1.5-blue.svg)](https://github.com/shanleiguang/vRain)
[![Language](https://img.shields.io/badge/language-Perl%205-brightgreen.svg)](https://www.perl.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg)]()

vRain（兀雨）是一個 Perl 工具鏈，可將中文文本生成為古籍刻本風格的直排（豎排）PDF 電子書。支援木活字、竹簡、棋譜等多種刻本風格，內建多字體補全策略確保生僻字正常顯示，並支援字體度量微調保持版面視覺一致性。

[English Documentation](README_EN.md)

## 功能特性

- **直排（豎排）排版**：傳統中文自上而下、從右至左的閱讀方式
- **多種刻本風格**：木活字、竹簡、棋譜等古籍背景圖
- **多字體補全**：最多 5 種字體按優先級回退，確保生僻字可正常顯示
- **字體度量微調**：自動測量各字體字形高度差異，微調字號保持視覺大小一致
- **回退字體加粗**：正文中回退到非主字體的字元可自動疊加描邊模擬加粗效果
- **夾批雙排**：支援 `【】` 標記的批注文字以小字雙排形式呈現
- **特殊標記系統**：書名波浪線、圓角方框、圓形框、圈注/點注/線注、字體縮放等
- **自動目錄**：自動提取章回標題生成 PDF 書籤目錄
- **PDF 壓縮**：可選用 Ghostscript 對輸出 PDF 進行壓縮

## 系統需求

- **Perl 5**（含核心模組）
- **PDF::Builder** — PDF 生成
- **Font::FreeType** — 字體字形檢測與度量
- **Image::Magick** — 背景圖生成（`canvas/*.pl` 指令碼使用）
- **Ghostscript** (`gs`) — PDF 壓縮（`-c` 參數，僅 macOS）

### 安裝依賴

```bash
# macOS（Homebrew）
brew install perl imagemagick ghostscript
cpan install PDF::Builder Font::FreeType

# Linux（Debian/Ubuntu）
sudo apt-get install perl imagemagick ghostscript
cpan install PDF::Builder Font::FreeType
```

## 快速開始

```bash
# 基本用法
perl vrain.pl -b <書籍ID> [-f 起始文本序號] [-t 結束文本序號] [-z 測試頁數] [-c] [-v]

# 範例：生成 book ID 為 00 的全部文本 PDF
perl vrain.pl -b 00 -f 1 -t 80

# 測試模式：僅輸出 5 頁用於調參，生成帶 _test 標識的 PDF
perl vrain.pl -b 00 -f 1 -t 80 -z 5

# 生成後自動用 Ghostscript 壓縮 PDF（僅 macOS）
perl vrain.pl -b 00 -f 1 -t 80 -c

# 顯示詳細排版資訊
perl vrain.pl -b 00 -v
```

### 生成背景圖

```bash
# 在 canvas/ 目錄下執行，根據 cfg 設定檔生成刻本背景圖 JPG
cd canvas && perl vintage.pl -c vintage
cd canvas && perl bamboo.pl -c bamboo
```

## 命令列參數

| 參數 | 說明 |
|------|------|
| `-h` | 顯示幫助資訊 |
| `-v` | 顯示詳細排版資訊（含字體選擇、縮放因子等） |
| `-c` | 壓縮 PDF（macOS，需 Ghostscript） |
| `-z <頁數>` | 測試模式，僅輸出指定頁數，生成帶 `_test` 標識的 PDF |
| `-b <書籍ID>` | 書籍 ID，對應 `books/<ID>/` 目錄 |
| `-f <序號>` | 文本起始序號（按檔案名排序後的順序序號，非檔案名數字） |
| `-t <序號>` | 文本結束序號 |

## 專案目錄結構

```
vRain/
├── vrain.pl                     ← 核心 PDF 排版指令碼
├── books/
│   └── <ID>/
│       ├── book.cfg             ← 書籍排版設定（核心入口設定檔）
│       ├── text/                ← 源文本檔案，按數字編號（001.txt, 002.txt ...）
│       │   ├── 000.txt           ← 可選：序言/前言
│       │   └── 999.txt           ← 可選：附錄/後記
│       ├── cover.jpg             ← 可選：封面圖片，不存在則自動生成簡易封面
│       └── *.pdf                 ← 輸出 PDF 儲存於此目錄
├── canvas/
│   ├── *.cfg                    ← 背景圖設定（頁尺寸、邊距、列數、魚尾等）
│   ├── *.jpg                    ← 生成的背景圖
│   └── *.pl                     ← 背景圖生成指令碼（使用 Image::Magick）
├── fonts/                       ← TTF 字體檔案
└── db/
    └── num2zh_jid.txt           ← 阿拉伯數字→中文數字映射（章回、頁碼用）
```

## 兩級設定系統

### 畫布級（`canvas/*.cfg`）—— 定義「紙」的樣式

| 參數 | 說明 |
|------|------|
| `canvas_width` / `canvas_height` | 頁面寬高（px） |
| `margins_top` / `margins_bottom` | 上下留白 |
| `margins_left` / `margins_right` | 左右留白 |
| `leaf_col` | 列數 |
| `leaf_center_width` | 版心寬度（中縫） |
| `outline_width` / `outline_color` | 外邊框線寬/顏色 |
| `inline_width` / `inline_color` | 內邊框線寬/顏色 |
| `outline_hmargin` / `outline_vmargin` | 邊框水平/垂直邊距 |
| `if_multirows` | 是否啟用多欄模式 |
| `multirows_num` | 欄數 |
| `logo_text` | 書房名/Logo 文字 |

### 書籍級（`books/<ID>/book.cfg`）—— 定義「字」的排版

#### 基礎設定

| 參數 | 說明 |
|------|------|
| `title` | 書名 |
| `author` | 作者 |
| `canvas_id` | 關聯的背景圖 ID |
| `row_num` | 每列字數 |
| `row_delta_y` | 列末字元到邊框距離微調 |

#### 字體設定（最多 5 種）

| 參數 | 說明 |
|------|------|
| `font1` ~ `font5` | 字體檔案名（存放於 `fonts/` 目錄） |
| `font1_rotate` ~ `font5_rotate` | 各字體旋轉角度微調 |
| `text_fonts_array` | 正文字體優先級陣列（如 `134` 表示依序嘗試 font1、font3、font4） |
| `text_font1_size` ~ `text_font5_size` | 各字體正文字號 |
| `text_font_color` | 正文顏色 |
| `comment_fonts_array` | 批注字體優先級陣列 |
| `comment_font1_size` ~ `comment_font5_size` | 各字體批注字號 |
| `comment_font_color` | 批注顏色 |
| `if_font_metric_adjust` | 是否啟用字體度量微調（`1` = 啟用） |
| `if_fallback_bold` | 是否對正文回退字體字元模擬加粗（`1` = 啟用） |
| `fallback_bold_stroke_width` | 模擬加粗描邊寬度（pt），建議 0.5 ~ 2.0 |

#### 封面與版心

| 參數 | 說明 |
|------|------|
| `cover_title_font_size` / `cover_title_y` | 封面標題字號/位置 |
| `cover_author_font_size` / `cover_author_y` | 封面作者字號/位置 |
| `cover_font_color` | 封面字體顏色 |
| `title_font_size` / `title_font_color` / `title_y` | 版心標題字號/顏色/位置 |
| `title_ydis` | 標題字元縱向間距係數 |
| `title_postfix` | 標題後綴（`X` 自動替換為章回數字） |
| `title_directory` | 是否生成 PDF 書籤目錄 |
| `pager_font_size` / `pager_font_color` / `pager_y` | 頁碼字號/顏色/位置 |

#### 標點符號處理

| 參數 | 說明 |
|------|------|
| `exp_replace_comma` | 標點符號替換規則（`\|` 分隔） |
| `exp_replace_number` | 數字替換規則 |
| `exp_delete_comma` | 刪除的標點符號 |
| `if_nocomma` / `exp_nocomma` | 無標點模式及過濾規則 |
| `if_onlyperiod` / `exp_onlyperiod` | 標點歸一化為句號模式 |
| `text_comma_nop` | 正文不佔字元位的標點 |
| `text_comma_nop_size` / `_x` / `_y` | 不佔位標點大小/位置微調 |
| `text_comma_90` | 正文旋轉 90 度的標點 |
| `text_comma_90_size` / `_x` / `_y` | 旋轉標點大小/位置微調 |
| `comment_comma_nop` / `comment_comma_90` | 批注標點（同上結構） |

#### 特殊標記

| 參數 | 標記符號 | 說明 |
|------|---------|------|
| `if_tag_bookline` | `《》` | 書名號 → 轉為文字左側波浪線 |
| `if_tag_rectframe` | `〔〕` | 圓角方框 |
| `if_tag_circleframe` | `〈〉` | 圓形框 |
| `if_tag_textzoom` | `（）` | 字體大小縮放 |
| `if_tag_circlenote` | `｛｝` | 正文右側圈注 |
| `if_tag_pointnote` | `＜＞` | 正文右側點注 |
| `if_tag_linenote` | `［］` | 正文右側線注 |

## 文本標記系統

源文本中使用特殊符號控制排版行為：

| 符號 | 作用 |
|------|------|
| `【批注】` | 批注文字（雙排夾批），奇數個字自動補齊 |
| `《》` | 書名號 → 轉為文字左側波浪線 |
| `〔〕` | 為字元添加圓角方框 |
| `〈〉` | 為字元添加圓形框 |
| `（）` | 字體大小縮放 |
| `｛｝` | 正文右側圈注 |
| `＜＞` | 正文右側點注 |
| `［］` | 正文右側線注 |
| `%` | 整頁分頁符 |
| `$` | 半頁分頁符 |
| `&` | 跳至當前頁最後一列 |
| `@` | 空格 |
| `TNO` | 進一字（前移一個字元位） |

## 核心排版機制

- **字位計數器** `$pcnt`：每頁當前寫入位置的標準字位指標，達到 `page_chars_num`（`col_num × row_num`）時觸發換頁
- **座標預計算**：`@pos_l`（左側）和 `@pos_r`（右側，用於雙排夾批）陣列在排版前預先計算
- **字體回退**：`get_font()` 使用 Font::FreeType 逐一檢查字元是否存在於字體中，按優先級回退；字元無可用字體時顯示 `□`
- **字體度量微調**：透過比較各字體與主字體的參考字元（「國」）字形高度，計算縮放因子，在 PDF 渲染時自動微調字號和居中位置
- **批注交叉處理**：遇到 `【` 時提取批注內容，優先以雙排位置列印，處理完後繼續正文

## 字體建議

推薦使用以下字體組合以獲得最佳效果：

- **主字體**：具有 Bold/Heavy 風格的中文字體（如方正金陵HK Bold）
- **輔助字體**：同一字體家族的 Light/Regular 變體（用於批注）
- **生僻字回退**：方正楷體或方宋 Plane00/Plane02（覆蓋 CJK 基本區及擴展區）
- **超生僻字**：全宋體、花園明朝等大字符集字體

## 版本歷史

| 版本 | 日期 | 更新內容 |
|------|------|---------|
| v1.5 | 2025-05 | 新增字體度量微調功能、回退字體模擬加粗功能 |
| v1.4 | 2025-03 | 多欄模式、字體配置優化 |
| v1.3 | 2025-01 | 新增書名波浪線、圓角方框、標記系統 |
| v1.2 | 2024-12 | 夾批雙排、標點符號處理優化 |
| v1.1 | 2024-11 | 多字體回退系統 |
| v1.0 | 2024-10 | 初始版本 |

## 授權

本專案採用 MIT 授權條款。詳見 [LICENSE](LICENSE) 檔案。

## 作者

- **GitHub**：[@shanleiguang](https://github.com/shanleiguang)
- **小紅書**：@兀雨書屋
- **郵箱**：shanleiguang@gmail.com

---

*兀雨——為中文古籍數位化提供專業的刻本風格排版工具。*
