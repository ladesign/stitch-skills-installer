# stitch-skills-installer


> ⚡ 一鍵為 OpenCode 手動安裝 stitch-skills 全部技能

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)]()

## 簡介

本專案提供一支指令檔，讓你**一鍵安裝全部 stitch-skills** 成目前專案的 OpenCode 技能，
免去逐一手動複製、設定技能的繁瑣流程。

## 特色

- **一鍵安裝** — 單一指令完成全部技能部署
- **完整技能包** — 自動安裝 stitch-skills 全部技能
- **零設定** — 無需手動修改設定檔
- **可重複執行** — 冪等設計，重跑不會出錯

## 需求

- VS Code
- OpenCode
- Git


## 使用指令檔一鍵安裝`stitch-skills`全部技能

使用`update-stitch-skills-opencode.cmd`指令檔一鍵為OpenCode手動安裝`stitch-skills`全部技能。

將 GitHub Repository `google-labs-code/stitch-skills`（Google Stitch 官方 repository）的全部技能同步到目前專案的 `.opencode/skills/`，並自動處理 OpenCode 命名規則。

[google-labs-code/stitch-skills 儲存庫](https://github.com/google-labs-code/stitch-skills)



## 不需要安裝Skills CLI

不需要先 Skills CLI 將 stitch-skills 倉庫中全部技能安裝到全域路徑；執行`update-stitch-skills-opencode.cmd`指令檔是將 GitHub 的 `google-labs-code/stitch-skills`最新版 Stitch Skills 同步到專案。

## 不需要 Node.js

不需要 Node.js，使用 Git + Windows cmd。 

## 使用方式
1. 將 `update-stitch-skills-opencode.cmd` 放在專案根目錄
2. 在 CMD 或檔案總管雙擊執行此指令檔案執行安裝，安裝路徑如下：

```text
your-project/
├─ .opencode/
│  └─ skills/（Stitch Skills 安裝位置）
├─ README.md（本文）
├─ update-stitch-skills-opencode.cmd（指令檔）
└─ ...
```

## 需求與腳本對應實作

| # | 需求 | 腳本對應實作 |
|---|------|-------------|
| 1 | 每次從 GitHub main 抓最新 | `git clone --depth 1 --branch main` 每次重新 clone |
| 2 | 自動同步 stitch-skills 內全部 Skill | 掃描 `plugins/*/skills/*` 下所有含 `SKILL.md` 的目錄 |
| 3 | 自動處理 OpenCode 的 SKILL.md frontmatter | 偵測 YAML frontmatter，新增或更新 `name:` 欄位 |
| 4 | `stitch::generate-design` → `stitch-generate-design` | `Get-SafeSkillName` 把 `::` 替換為 `-` |
| 5 | `stitch::react-components` → `stitch-react-components` | 同上 |
| 6 | 自動讓 `name:` 與資料夾名稱一致 | 寫入 `name: $safeName`，資料夾也是 `$safeName` |
| 7 | 使用 `.stitch-sync-manifest.json` 記錄 | 每次結束時寫入 manifest，包含 `source`、`branch`、`updatedAt`、`skills` 陣列 |
| 8 | 不會刪除你自己建立的其他 Skills | 只根據 manifest 中「上一輪由腳本管理的 skill」來清理 |
| 9 | GitHub 新增 Skill 自動加入 | 每次執行指令檔會全掃描，新 skill 自然會被發現並同步 |
| 10 | GitHub 移除 Skill 自動移除 | 比對 `$oldManagedSkills` 與當前 upstream，不存在就刪除 |
| 11 | 只移除「之前由這個同步腳本管理」的 Skill | 刪除候選名單來自 manifest，不碰 manifest 以外的 skill |
| 12 | 不需要 Node.js，只有 Git + Windows cmd | 只相依 Git + Windows cmd |

## 功能

- 每次從 GitHub `main` 取得最新版本
- 同步 `plugins/*/skills/*` 全部技能
- 將 `stitch::xxx` 自動轉為 OpenCode 相容的 lowercase kebab-case
- 自動修正 `SKILL.md` 的 `name` frontmatter
- 產生 `.stitch-sync-manifest.json` 記錄由腳本管理的技能
- 只清理腳本自己之前管理的技能，不會刪除手動建立的其他技能
- 自動清理上輪残留的 `OpenCode` 空檔案

## 執行流程

```text
[1/6] 檢查依賴（Git）
[2/6] 從 GitHub 下載最新 stitch-skills
[3/6] 掃描並同步全部 Skills
[4/6] 顯示目前專案 OpenCode Skills
[5/6] 清理暫存檔
[6/6] 完成
```

## 輸出結構

```text
.opencode/
└─ skills/
   ├─ code-to-design/
   ├─ design-md/   
   ├─ enhance-prompt/   
   ├─ extract-design-md/
   ├─ extract-static-html/
   ├─ generate-design/
   ├─ manage-design-system/
   ├─ react-components/
   ├─ react-native/
   ├─ react-vite-dashboard/
   ├─ remotion/
   ├─ shadcn-ui/   
   ├─ site-md/
   ├─ stitch-loop/
   ├─ taste-design/
   ├─ upload-to-stitch/
   └─ .stitch-sync-manifest.json（Manifest文件）   
```

## 「Manifest」機制

`update-stitch-skills-opencode.cmd` 每次只刪除 Manifest 裡上一輪由 Stitch 管理的 Skills，再重新同步 GitHub 最新版本。這樣你可以放心把自己的 Skill 也放在 .opencode/skills。

`.opencode/skills/.stitch-sync-manifest.json` 記錄：

```json
{
    "source":  "https://github.com/google-labs-code/stitch-skills",
    "branch":  "main",
    "updatedAt":  "2026-10-08T06:15:21.2511447Z",
    "skills":  [
                   "code-to-design",
                   "design-md",
                   "enhance-prompt",
                   "extract-design-md",
                   "extract-static-html",
                   "generate-design",
                   "manage-design-system",
                   "react-components",
                   "react-native",
                   "react-vite-dashboard",
                   "remotion",
                   "shadcn-ui",
                   "site-md",
                   "stitch-loop",
                   "taste-design",
                   "upload-to-stitch"
               ]
}
```

## 注意事項

- 因為腳本以 `%~dp0` 判定專案根目錄，所以放在哪個資料夾，就會同步到該資料夾下的 `.opencode/skills/`
- 如果你自己還有其他手動建立的 OpenCode Skills，放在 `.opencode/skills/` 裡不會被影響
- 若 GitHub 新增 Skill，下次執行會自動加入；若移除，也只會移除manifest中記錄的舊項目
- .opencode/opencode.json 文件需設置 Stitch MCP 服務才能使用`stitch-skills`全部技能

## License

MIT