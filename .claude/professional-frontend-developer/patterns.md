# 本プロジェクト固有のパターン集

## Zustand ストアパターン

### 安全なセレクタの書き方

```typescript
// NG: セレクタ内で新しい配列を生成 → 無限ループ
const items = useStore((s) => s.list.filter((x) => x.active))

// OK: 生データを取得し、useMemoで派生
const list = useStore((s) => s.list)
const items = useMemo(() => list.filter((x) => x.active), [list])
```

### persist middleware 使用時

```typescript
export const useMyStore = create<MyState>()(
  persist(
    (set) => ({ /* state + actions */ }),
    { name: 'storage-key' },
  ),
)
```

## AG Grid パターン

### カスタムCellRenderer

```typescript
function MyCellRenderer(props: ICellRendererParams<FlatRowData>) {
  const data = props.data
  if (!data) return null
  return <div className="flex h-full items-center">{data.field}</div>
}
```

### 動的列定義

```typescript
const columnDefs = useMemo<ColDef<FlatRowData>[]>(() => {
  const dynamicCols = items.map((item) => ({
    headerName: item.name,
    field: `dynamic_${item.id}`,
    editable: (params) => params.data?.isEditable ?? false,
  }))
  return [...staticCols, ...dynamicCols, actionCol]
}, [items])
```

### 行スタイル（getRowStyle）

```typescript
<AgGridReact
  getRowStyle={(params) => {
    if (params.data?.level === 0) return { backgroundColor: '#f0f0f0' }
    return undefined
  }}
/>
```

## データモデルパターン

### Zodスキーマ定義 → 型エクスポート

```typescript
export const MySchema = z.object({
  id: z.string().uuid(),
  name: z.string().min(1).max(200),
})
export type MyType = z.infer<typeof MySchema>

// Create/Update バリアント
export const CreateMySchema = MySchema.omit({ id: true })
export const UpdateMySchema = MySchema.partial().required({ id: true })
```

### DatabaseSchemaへの追加（後方互換）

```typescript
// 既存データが壊れないよう optional で追加
export const DatabaseSchema = z.object({
  // ...existing fields
  newField: z.array(NewSchema).optional(),
})
```

## コンポーネントパターン

### shadcn/ui コンポーネント追加

```bash
npx shadcn@latest add tooltip
```

### ダークモード対応

```typescript
// Tailwind のダークモード prefix を必ず併記
<div className="bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-gray-100">
```

## ツリー構造のロールアップ

```typescript
// post-order traversal: 子を先に計算してから親を集計
function postOrder(nodes: TreeNode[]): void {
  for (const node of nodes) {
    postOrder(node.children)
    processNode(node) // 子の結果を使って親を計算
  }
}
```
