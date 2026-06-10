// Minimal line-based diff (LCS) for the Admin Prompt Studio editor
// (docs/31 §5). Dependency-free on purpose — the panel needs "what
// changed between two prompt versions", not a full myers/patience
// implementation.
//
// Output is a flat list of ops in display order:
//   { kind: "same" | "add" | "del", text }
// Renderers map kinds to styling (green add / red strikethrough del).

export type DiffOp = { kind: "same" | "add" | "del"; text: string };

export function diffLines(oldText: string, newText: string): DiffOp[] {
  const a = oldText.split("\n");
  const b = newText.split("\n");
  const n = a.length;
  const m = b.length;

  // LCS table — prompts are ≤20k chars (≈ a few hundred lines), so the
  // O(n·m) table stays tiny (worst case ~500×500 numbers).
  const lcs: number[][] = Array.from({ length: n + 1 }, () =>
    new Array<number>(m + 1).fill(0),
  );
  for (let i = n - 1; i >= 0; i--) {
    for (let j = m - 1; j >= 0; j--) {
      lcs[i][j] =
        a[i] === b[j]
          ? lcs[i + 1][j + 1] + 1
          : Math.max(lcs[i + 1][j], lcs[i][j + 1]);
    }
  }

  const ops: DiffOp[] = [];
  let i = 0;
  let j = 0;
  while (i < n && j < m) {
    if (a[i] === b[j]) {
      ops.push({ kind: "same", text: a[i] });
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      ops.push({ kind: "del", text: a[i] });
      i++;
    } else {
      ops.push({ kind: "add", text: b[j] });
      j++;
    }
  }
  for (; i < n; i++) ops.push({ kind: "del", text: a[i] });
  for (; j < m; j++) ops.push({ kind: "add", text: b[j] });
  return ops;
}
