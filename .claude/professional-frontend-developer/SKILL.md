---
name: professional-developer
description: 本プロジェクト（リソース配分管理ツール）の開発標準に従い、機能実装・バグ修正・リファクタリングを行う。React 19 + TypeScript + Zustand + AG Grid環境での開発時に自動適用。
---

# Professional Developer スキル

`.claude/developer.md` および `CLAUDE.md` の方針に基づき、以下のルールを厳守して実装する。

## 基本姿勢

- 実務でそのまま使えるコードを書く
- 擬似コードは禁止、TODOで逃げない
- 仕様が曖昧な場合は実装前に質問する
- 設計を勝手に変えない、過剰な抽象化をしない
- 命名は意味を表す英語を使う

## 実装フロー

1. 仕様確認 — 曖昧な点は質問、推測で進めない
2. テスト作成 — 正常系・異常系を分けて書く（Vitest + Testing Library）
3. 本体実装 — テストが通る最小実装
4. 検証 — `npm run test:run && npm run check && npm run build`

## 出力ルール

実装時は以下の順で出力:
1. 実装方針（簡潔に）
2. 本体コード
3. テストコード

## アーキテクチャ準拠

- Feature-Sliced Design: `src/features/{feature}/` 配下に components, pages, utils
- 状態管理: Zustand 5（persist middleware使用時はセレクタで新しいオブジェクト/配列を生成しない）
- バリデーション: Zod スキーマで型安全に
- UI: Tailwind CSS 4 + shadcn/ui、ダークモード必須（`dark:` prefix）
- パスエイリアス: `@/` → `src/`

## データモデル変更時

- Zodスキーマを先に定義（`src/shared/types/`）
- 既存の `DatabaseSchema` との後方互換を維持（optional追加）
- localStorage永続化層（`jsonStorage`）への影響を確認

## テストポリシー

- テストは「仕様を説明するもの」と考える
- 重要なロジックには必ずテストケースを用意
- カバレッジ80%以上を目標
- `describe` / `it` の説明文は振る舞いを明記

## 禁止事項

- Zustandセレクタ内での `.filter()` / `.map()` / `.sort()`（無限ループの原因）
- 仕様書にない機能の追加
- ユーザーデータの暗黙的な削除・上書き
