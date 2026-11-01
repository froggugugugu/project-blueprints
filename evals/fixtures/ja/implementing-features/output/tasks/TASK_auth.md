# TASK01 — ログインフォーム

## 1. 基本情報

| 項目 | 内容 |
|---|---|
| タスクID | TASK01 |
| 機能名 | ログインフォーム |
| 関連チーム定義 | TEAM_FEATURE.md |
| 対象画面 / URL | /login |
| 優先度 | 高 |

## 2. 機能概要

社員がメールアドレスとパスワードでログインし、備品の貸出操作を自分のアカウントで行えるようにする(`output/prd/PRD_auth.md` FR-001 / FR-002 / NFR-003)。

## 3. 対象ファイル・ディレクトリ

| 種別 | パス | 備考 |
|---|---|---|
| ページ | src/features/auth/pages/LoginPage.tsx | 新規作成 |
| スキーマ | src/features/auth/schema.ts | 新規作成(Zod) |
| ストア | src/features/auth/store.ts | 新規作成(Zustand) |
| ユーティリティ | src/features/auth/validate-credentials.ts | 新規作成 |
| テスト | src/features/auth/__tests__/validate-credentials.test.ts | 新規作成 |
| テスト | src/features/auth/__tests__/schema.test.ts | 新規作成 |

> **重要**: 上記以外のファイルは変更しないこと。

## 4. 機能要件

### 4.1 画面仕様

- メールアドレス、パスワードの 2 フィールドと「ログイン」ボタン
- 送信中はボタンを無効化する
- 失敗時はフォーム上部に「メールアドレスまたはパスワードが違います」を表示する(どちらが誤りかは明かさない)

### 4.2 バリデーション

- メールアドレス: 必須、RFC 5322 形式
- パスワード: 必須、8 文字以上 72 文字以下
- エラーは各フィールドの直下に表示する

### 4.3 状態管理

- `useAuthStore`: `user | null`、`status: "idle" | "submitting" | "error"`、`login(credentials)`、`logout()`

## 5. 受け入れ基準

- [ ] スキーマのユニットテスト(有効 / 無効 / 境界値)が通る
- [ ] `validate-credentials` のユニットテストが通る(正しい組み合わせ・誤り・空入力)
- [ ] `npm run test:run` と `npm run lint` が通る

## 6. 検証コマンド

```bash
npm run lint
npm run test:run
```
