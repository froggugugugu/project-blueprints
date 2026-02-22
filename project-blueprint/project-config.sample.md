# Project Configuration

> **人間が記入するプロジェクトパラメータファイル。**
> 技術選定・品質基準・ポリシーなど「人間が決定すべき事項」をここに集約する。
>
> **AI が管理する領域（このファイルに含めない）:**
> - ルーティング定義 → `docs/project.md` にAIが自動生成・更新
> - ストア一覧 → `docs/project.md` にAIが自動生成・更新
> - データモデル/スキーマ → `docs/data-model.md` にAIが自動生成・更新
>
> **AI によるメンテナンス:**
> 各スキル（`/implementing-features`, `/plan` 等）は設計・実装の進行に伴い、
> このファイルのセクション11（既知の落とし穴）やセクション2（技術スタック）を
> 必要に応じて更新し、`docs/` 配下との整合性を保つ。

> **📝 これはサンプルファイルです。**
> 「タスク管理Webアプリ（TaskFlow）」を題材に全12セクションを記入した例です。
> 実際のプロジェクトでは `project-config.md` をコピーして記入してください。

---

## 1. プロジェクト基本情報 <!-- 必須 -->

| 項目           | 値                                            |
| -------------- | --------------------------------------------- |
| プロジェクト名 | TaskFlow                                      |
| 概要           | チーム向けタスク管理Webアプリ。カンバン・リスト表示、タグ管理、期限管理をサポート |
| 対応言語       | ja                                            |
| Node.js要件    | 20以上                                        |

---

## 2. 技術スタック <!-- 必須 -->

| カテゴリ         | 技術                              |
| ---------------- | --------------------------------- |
| フレームワーク   | React 19, TypeScript 5.x, Vite 6 |
| スタイリング     | Tailwind CSS 4, shadcn/ui        |
| 状態管理         | Zustand 5                         |
| バリデーション   | Zod 3.x                          |
| ルーティング     | React Router 7                    |
| アイコン         | lucide-react                      |
| コード品質       | Biome 2.x                        |
| 依存方向チェック | なし                              |
| Git Hooks        | husky 9, lint-staged 16           |
| テスト           | Vitest 3, Playwright 1.x         |

---

## 3. コマンド <!-- 必須 -->

```bash
npm run dev              # 開発サーバー（Vite）
npm run build            # 本番ビルド
npm run lint             # Biome lint + format check
npm run lint:fix         # Biome lint + format 自動修正
npm run test             # Vitest ウォッチモード
npm run test:run         # Vitest 一回実行
npm run test:coverage    # カバレッジ付きテスト
npm run e2e              # Playwright E2Eテスト
npm run e2e:ui           # Playwright UIモード
```

---

## 4. アーキテクチャ <!-- 推奨 -->

### 4.1 パターン

Feature-Sliced Design（簡易版）

### 4.2 パスエイリアス

`@/` → `src/`

### 4.3 ディレクトリ構成（概要）

```text
src/
├── main.tsx               # エントリーポイント
├── App.tsx                # ルーティング定義
├── features/              # 機能モジュール
│   ├── task/              #   タスクCRUD
│   ├── board/             #   カンバンボード
│   ├── tag/               #   タグ管理
│   └── auth/              #   認証（将来拡張）
├── shared/                # 共有レイヤー
│   ├── ui/                #   共通UIコンポーネント
│   ├── hooks/             #   共通フック
│   └── utils/             #   ユーティリティ関数
├── stores/                # Zustand ストア
├── test/                  # テストセットアップ
└── lib/                   # 外部ライブラリラッパー
```

### 4.4 依存方向ルール

- `features/X` → `features/Y` の直接依存: 禁止（shared経由で連携）
- `shared` → `features`: 禁止
- `stores` → `features`: 禁止
- 循環依存: 禁止
- 検出コマンド: 目視（dependency-cruiser 未導入）

---

## 5. データ永続化 <!-- 任意 -->

| 項目               | 値                                          |
| ------------------ | ------------------------------------------- |
| 戦略               | localStorage（MVP）、将来的にREST API移行   |
| ストレージキー     | `taskflow-tasks`（タスクデータ）、`taskflow-tags`（タグデータ） |
| マイグレーション方針 | optional + デフォルト値で後方互換           |

---

## 6. 品質基準 <!-- 必須 -->

| 項目                 | 値         |
| -------------------- | ---------- |
| テストカバレッジ目標 | 80%        |
| TDD                  | yes        |
| 品質ゲート           | yes        |
| ツール出力先         | `testreport/` |
| サマリー出力先       | `output/reports/` |

### 6.1 レポート出力構成

レポートは用途に応じて2つのディレクトリに分離する:

- `testreport/` — ツールが生成する生データ（HTML/JSON/LCOV等）。`.gitignore`に追加すること
- `output/reports/` — 人間がレビューするMarkdownサマリー。Gitで管理する

```text
testreport/                    ← ツール直接出力（.gitignore対象）
├── coverage/              # ユニットテストカバレッジ（HTML/LCOV）
├── e2e/                   # Playwright E2Eテストレポート・トレース
└── security/              # セキュリティスキャンレポート（JSON/HTML）

output/reports/                ← 人間向けサマリー（Git管理）
├── review/                # コードレビュー結果
├── test/                  # テスト結果サマリー
├── security/              # セキュリティスキャンサマリー
└── legal/                 # 法務チェック結果
```

---

## 7. デザインシステム <!-- 推奨 -->

| 項目                       | 値                           |
| -------------------------- | ---------------------------- |
| 参照するデザインシステム   | なし（独自）                 |
| UIコンポーネントライブラリ | shadcn/ui（Radix UI）        |
| アイコンライブラリ         | Lucide Icons                 |
| アクセシビリティ基準       | WCAG 2.1 AA                  |
| カラートークン定義ファイル | src/index.css                |

---

## 8. E2E テスト環境 <!-- 任意 -->

| 項目                 | 値                         |
| -------------------- | -------------------------- |
| ブラウザ             | Chromium                   |
| ベースURL            | http://localhost:5173      |
| テストファイル配置   | e2e/                       |
| テストデータ注入方式 | localStorage直接注入       |

---

## 9. Git ポリシー <!-- 任意 -->

| 項目           | 値                                      |
| -------------- | --------------------------------------- |
| pre-commit     | lint-staged（Biome check + format）     |
| pre-push       | lint + 型チェック + テスト              |
| `--no-verify`  | 禁止                                    |
| `--force`      | 原則禁止                                |

---

## 10. セキュリティポリシー <!-- 任意 -->

- ユーザー入力は必ず Zod でバリデーション
- 依存パッケージの脆弱性は `npm audit` で定期確認
- localStorage にはパスワード等の機密情報を保存しない
- XSS対策: React のデフォルトエスケープに依存し、`dangerouslySetInnerHTML` は禁止

---

## 11. プロジェクト固有の注意事項 <!-- 推奨 -->

> このセクションはAIが開発中に発見した問題を追記・更新する。
> 人間が初期値を記入してもよい。

### 既知の落とし穴

| 問題 | 原因 | 対策 |
| ---- | ---- | ---- |
| Zustand v5 で型推論が効かない | `create` のダブル呼び出しパターン未使用 | `create<State>()(impl)` を必ず使う |
| Tailwind CSS 4 のクラス名変更 | v3→v4 で一部ユーティリティが renamed | 公式マイグレーションガイドを参照 |

### フレームワーク固有パターン

- React 19: `use()` フックが利用可能。Suspense との組み合わせを推奨
- Vite 6: Environment API が導入されたが、SPA用途では従来通りの設定で問題ない
- shadcn/ui: コンポーネントは `npx shadcn@latest add <name>` でインストール

---

## 12. Claude Code プラグイン設定 <!-- 任意 -->

| プラグイン        | 有効 | 用途                                       |
| ----------------- | ---- | ------------------------------------------ |
| context7          | yes  | ライブラリドキュメント参照                 |
| playwright        | yes  | E2Eテスト実行・デバッグ                    |
| draw.io           | yes  | アーキテクチャ図・フロー図作成             |
| pr-review-toolkit | yes  | GitHub PR連携                              |
| sentry            | no   | 本番エラー調査（必要に応じて有効化）       |
