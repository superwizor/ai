import re

with open("marketing-site/src/components/admin/CRMDashboard.tsx", "r") as f:
    code = f.read()

# 1. Light theme colors
code = code.replace('"--crm-text": "#1F2937",', '"--crm-text": "#000000",')
code = code.replace('"--crm-heading": "#1F1F1F",', '"--crm-heading": "#000000",')
code = code.replace('"--crm-muted": "#57606a",', '"--crm-muted": "#374151",')
code = code.replace('"--crm-faint": "#6b7280",', '"--crm-faint": "#4B5563",')

# 2. Add tags to CRMSubscriber
code = code.replace('  org_name: string;\n  past_subscriptions?: PastSubscription[];\n};', '  org_name: string;\n  past_subscriptions?: PastSubscription[];\n  tags: CRMTag[];\n};')

# 3. Add available_tags to CRMGlobalStats (if it exists... wait, it's not a type, we just add it to state)
# We need to add availableTags state
code = code.replace('const [totalAll, setTotalAll] = useState(0);', 'const [totalAll, setTotalAll] = useState(0);\n  const [availableTags, setAvailableTags] = useState<string[]>([]);')

# 4. FilterState
code = code.replace('  app_delay: string;\n  show_test: boolean;\n};', '  app_delay: string;\n  tag: string;\n  show_test: boolean;\n};')

code = code.replace('search: "", app_delay: "", show_test: false };', 'search: "", app_delay: "", tag: "", show_test: false };')
code = code.replace('app_delay: p.get("app_delay") || "",\n      show_test:', 'app_delay: p.get("app_delay") || "",\n      tag: p.get("tag") || "",\n      show_test:')
code = code.replace('if (filters.app_delay) p.set("app_delay", filters.app_delay);', 'if (filters.app_delay) p.set("app_delay", filters.app_delay);\n    if (filters.tag) p.set("tag", filters.tag);')
code = code.replace('if (filters.app_delay) params.set("app_delay", filters.app_delay);', 'if (filters.app_delay) params.set("app_delay", filters.app_delay);\n      if (filters.tag) params.set("tag", filters.tag);')
code = code.replace('setTotalAll(data.total_all || 0);', 'setTotalAll(data.total_all || 0);\n      setAvailableTags(data.available_tags || []);')
code = code.replace('filters.app_delay, filters.show_test,', 'filters.app_delay, filters.tag, filters.show_test,')

# 5. Drawer states and functions
code = code.replace('const [drawerOpen, setDrawerOpen] = useState(false);', 'const [drawerOpen, setDrawerOpen] = useState(false);\n  const [drawerFullScreen, setDrawerFullScreen] = useState(false);')
code = code.replace('const [noteSaving, setNoteSaving] = useState(false);', 'const [noteSaving, setNoteSaving] = useState(false);\n  const [editingNoteId, setEditingNoteId] = useState<string | null>(null);\n  const [editingNoteBody, setEditingNoteBody] = useState("");')

code = code.replace('setDrawerOpen(false);\n    setTimeout(()', 'setDrawerOpen(false);\n    setDrawerFullScreen(false);\n    setTimeout(()')

add_note_end = code.find('const addTag = async () => {')
update_note_func = """
  const updateNote = async (id: string, body: string) => {
    if (!selectedUser || !body.trim()) return;
    try {
      const resp = await crmFetch(`/admin/crm/notes/${id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body }),
      });
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      setEditingNoteId(null);
      await openUserDetail(selectedUser.user_id);
      showToast("📝 Notatka zaktualizowana");
    } catch (err: any) {
      showToast(`❌ Błąd: ${err.message}`);
    }
  };

  const deleteNote = async (id: string) => {
    if (!selectedUser || !confirm("Na pewno usunąć tę notatkę?")) return;
    try {
      const resp = await crmFetch(`/admin/crm/notes/${id}`, { method: "DELETE" });
      if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
      await openUserDetail(selectedUser.user_id);
      showToast("🗑️ Notatka usunięta");
    } catch (err: any) {
      showToast(`❌ Błąd: ${err.message}`);
    }
  };

  """
code = code[:add_note_end] + update_note_func + code[add_note_end:]

# 6. activeFilterCount
code = code.replace('[filters.tier, filters.status, filters.alert, filters.search, filters.app_delay].filter(Boolean).length', '[filters.tier, filters.status, filters.alert, filters.search, filters.app_delay, filters.tag].filter(Boolean).length')

# 7. Full screen mode for main layout
code = code.replace('<div className="min-h-screen bg-[var(--crm-bg)] transition-colors duration-300" style={themeVars}>', '<div className={fullScreen ? "fixed inset-0 z-[100] bg-[var(--crm-bg)] overflow-auto p-4" : "min-h-screen bg-[var(--crm-bg)] transition-colors duration-300"} style={themeVars}>')
code = code.replace('const [error, setError] = useState<string | null>(null);', 'const [error, setError] = useState<string | null>(null);\n  const [fullScreen, setFullScreen] = useState(false);')
code = code.replace('↻ Odśwież\n          </button>', '↻ Odśwież\n          </button>\n          <button onClick={() => setFullScreen(!fullScreen)} className="rounded-lg bg-[var(--crm-elevated)] border border-[var(--crm-border)] text-[var(--crm-text)] px-3.5 py-2.5 text-xs font-semibold hover:bg-[var(--crm-border)] transition">{fullScreen ? "Opuść pełny ekran" : "Pełny ekran CRM"}</button>')
code = code.replace('alert: "", search: "", app_delay: "", show_test: false });', 'alert: "", search: "", app_delay: "", tag: "", show_test: false });')

# Update activeFilter clear button and KPI chips
code = code.replace('alert: "", status: "", tier: "", app_delay: "" }', 'alert: "", status: "", tier: "", app_delay: "", tag: "" }')
code = code.replace('alert: "critical", status: "", tier: "", app_delay: "" }', 'alert: "critical", status: "", tier: "", app_delay: "", tag: "" }')
code = code.replace('alert: "warning", status: "", tier: "", app_delay: "" }', 'alert: "warning", status: "", tier: "", app_delay: "", tag: "" }')
code = code.replace('alert: "expiring", status: "", tier: "", app_delay: "" }', 'alert: "expiring", status: "", tier: "", app_delay: "", tag: "" }')
code = code.replace('alert: "", status: "CANCELED", tier: "", app_delay: "" }', 'alert: "", status: "CANCELED", tier: "", app_delay: "", tag: "" }')

tag_select = """
        <select value={filters.tag} onChange={(e) => setFilters(f => ({ ...f, tag: e.target.value }))} className="rounded-lg bg-[var(--crm-surface)] border border-[var(--crm-border)] text-[var(--crm-text)] px-3.5 py-2.5 text-sm focus:outline-none focus:border-[var(--crm-focus)] transition cursor-pointer">
          <option value="">🏷️ Wszystkie tagi</option>
          {availableTags.map(tag => <option key={tag} value={tag}>{tag}</option>)}
        </select>
"""
code = code.replace('<FilterSelect value={filters.app_delay} onChange={(v) => updateFilter("app_delay", v)} options={APP_DELAY_OPTIONS} />', '<FilterSelect value={filters.app_delay} onChange={(v) => updateFilter("app_delay", v)} options={APP_DELAY_OPTIONS} />\n' + tag_select)

# 8. Table columns
code = code.replace('<th className="px-4 py-3.5 text-center text-[11px] font-semibold uppercase tracking-wider text-[var(--crm-muted)] cursor-pointer hover:text-[var(--crm-text)] transition select-none" onClick={() => toggleSort("sessions")}>Sesje{sortIndicator("sessions")}</th>', '<th className="px-4 py-3.5 text-left text-[11px] font-semibold uppercase tracking-wider text-[var(--crm-muted)] w-24">Tagi</th>\n<th className="px-4 py-3.5 text-center text-[11px] font-semibold uppercase tracking-wider text-[var(--crm-muted)] cursor-pointer hover:text-[var(--crm-text)] transition select-none" onClick={() => toggleSort("sessions")}>Sesje{sortIndicator("sessions")}</th>')

tags_td = """
                      <td className="px-4 py-3.5 text-left">
                        <div className="flex flex-wrap gap-1">
                          {s.tags?.slice(0, 2).map((tag, idx) => (
                            <span key={idx} className="px-1.5 py-0.5 rounded text-[9px] font-bold uppercase whitespace-nowrap text-white" style={{ backgroundColor: tag.color }}>
                              {tag.tag}
                            </span>
                          ))}
                        </div>
                      </td>
"""
code = code.replace('<td className="px-4 py-3.5 text-center font-mono text-[var(--crm-text)]">{s.total_sessions}</td>', tags_td + '<td className="px-4 py-3.5 text-center font-mono text-[var(--crm-text)]">{s.total_sessions}</td>')

# 9. Drawer size and logic
code = code.replace('<div className="fixed inset-0 z-50 flex justify-end">', '<div className="fixed inset-0 z-[200] flex justify-end" style={themeVars}>')
code = code.replace('<div className="absolute inset-0" style={{ backgroundColor: isDark ? "rgba(0,0,0,0.5)" : "rgba(0,0,0,0.2)" }} onClick={closeDrawer} />', '<div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={closeDrawer} />')
code = code.replace('className={`relative w-full max-w-lg', 'className={`relative ${drawerFullScreen ? "w-[90vw] max-w-[1200px]" : "w-full max-w-lg"}')
code = code.replace('<button onClick={closeDrawer} className="absolute top-4 right-4', '<button onClick={() => setDrawerFullScreen(!drawerFullScreen)} className="absolute top-4 right-16 text-[var(--crm-muted)] hover:text-[var(--crm-heading)] transition w-8 h-8 rounded-lg hover:bg-[var(--crm-elevated)] flex items-center justify-center">{drawerFullScreen ? "➖" : "🔲"}</button>\n<button onClick={closeDrawer} className="absolute top-4 right-4')

# 10. Drawer notes UI
notes_old = """                  <div className="space-y-2 max-h-64 overflow-y-auto">
                    {selectedUser.notes.map((note) => (
                      <div key={note.id} className="rounded-lg bg-[var(--crm-card)] border border-[var(--crm-border)] px-3.5 py-3">
                        <p className="text-[var(--crm-text)] text-xs leading-relaxed whitespace-pre-wrap">{note.body}</p>
                        <p className="text-[var(--crm-faint)] text-[10px] mt-1.5">{new Date(note.created_at).toLocaleDateString("pl-PL", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}</p>
                      </div>
                    ))}
                    {selectedUser.notes.length === 0 && <p className="text-[var(--crm-faint)] text-xs">Brak notatek</p>}
                  </div>"""

notes_new = """                  <div className={`space-y-2 overflow-y-auto ${drawerFullScreen ? "max-h-[60vh]" : "max-h-[350px]"}`}>
                    {selectedUser.notes.map((note) => (
                      <div key={note.id} className="rounded-lg bg-[var(--crm-card)] border border-[var(--crm-border)] px-3.5 py-3 group">
                        {editingNoteId === note.id ? (
                          <div className="flex flex-col gap-2">
                            <textarea
                              value={editingNoteBody}
                              onChange={(e) => setEditingNoteBody(e.target.value)}
                              className="w-full bg-[var(--crm-elevated)] border border-[var(--crm-border)] rounded-lg p-2 text-sm text-[var(--crm-text)] focus:outline-none focus:border-[var(--crm-ember-border)] resize-none"
                              rows={4}
                            />
                            <div className="flex justify-end gap-2">
                              <button onClick={() => setEditingNoteId(null)} className="px-3 py-1 text-xs text-[var(--crm-muted)] hover:text-[var(--crm-text)]">Anuluj</button>
                              <button onClick={() => updateNote(note.id, editingNoteBody)} className="px-3 py-1 bg-[var(--crm-focus)] text-white text-xs rounded hover:opacity-90">Zapisz</button>
                            </div>
                          </div>
                        ) : (
                          <>
                            <div className="flex justify-between items-start gap-4">
                              <p className="text-[var(--crm-text)] text-xs leading-relaxed whitespace-pre-wrap flex-1">{note.body}</p>
                              <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                                <button onClick={() => { setEditingNoteId(note.id); setEditingNoteBody(note.body); }} className="text-[var(--crm-muted)] hover:text-[var(--crm-focus)]" title="Edytuj">✎</button>
                                <button onClick={() => deleteNote(note.id)} className="text-[var(--crm-muted)] hover:text-[var(--crm-accent-red)]" title="Usuń">🗑️</button>
                              </div>
                            </div>
                            <p className="text-[var(--crm-faint)] text-[10px] mt-1.5">{new Date(note.created_at).toLocaleDateString("pl-PL", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}</p>
                          </>
                        )}
                      </div>
                    ))}
                    {selectedUser.notes.length === 0 && <p className="text-[var(--crm-faint)] text-xs">Brak notatek</p>}
                  </div>"""

code = code.replace(notes_old, notes_new)

# 11. AlertPill whitespace nowrap
code = code.replace('function AlertPill({ color, label, bgVar }: { color: string; label: string; bgVar: string }) {\n  return <span className="px-2.5 py-1 rounded-md text-[10px] font-bold uppercase" style={{ backgroundColor: `var(${bgVar})`, color }}>{label}</span>;\n}', 'function AlertPill({ color, label, bgVar }: { color: string; label: string; bgVar: string }) {\n  return <span className="px-2.5 py-1 rounded-md text-[10px] font-bold uppercase whitespace-nowrap" style={{ backgroundColor: `var(${bgVar})`, color }}>{label}</span>;\n}')

with open("marketing-site/src/components/admin/CRMDashboard.tsx", "w") as f:
    f.write(code)

print("Done editing CRMDashboard.tsx")
