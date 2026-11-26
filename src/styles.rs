/// Quiet Signal Minimalist Design System CSS (100% embedded in Rust binary, zero CDN requests).
/// WCAG 2.2 AA verified Light & Dark palettes, Safe Area insets, Adaptive Mobile/Tablet navigation.
pub const QUIET_SIGNAL_CSS: &str = r#"
:root {
  color-scheme: light;
  --bg-canvas: #F8FAFC;
  --bg-surface: #FFFFFF;
  --bg-subtle: #F1F5F9;
  --bg-hover: #E2E8F0;
  --bg-scrim: rgba(9, 13, 22, 0.52);

  --text-primary: #090D16;
  --text-secondary: #334155;
  --text-muted: #475569;
  --text-on-accent: #FFFFFF;

  --border-subtle: #E2E8F0;
  --border-strong: #94A3B8;

  --accent: #0F52BA;
  --accent-hover: #0A3F91;
  --accent-text: #0F52BA;
  --accent-soft: #EFF6FF;
  --accent-border: #93C5FD;

  --bubble-out-bg: #0F52BA;
  --bubble-out-text: #FFFFFF;
  --bubble-in-bg: #FFFFFF;
  --bubble-in-text: #090D16;

  --status-online: #15803D;
  --status-online-bg: #F0FDF4;
  --status-idle: #B45309;
  --status-idle-bg: #FFFBEB;
  --status-sleep: #6D28D9;
  --status-sleep-bg: #F5F3FF;
  --status-danger: #B91C1C;
  --status-danger-bg: #FEF2F2;
  --status-danger-border: #FCA5A5;
  --status-offline: #64748B;

  --radius-xs: 6px;
  --radius-sm: 10px;
  --radius-md: 14px;
  --radius-lg: 18px;
  --radius-full: 9999px;

  --safe-top: env(safe-area-inset-top, 0px);
  --safe-bottom: env(safe-area-inset-bottom, 0px);
  --safe-left: env(safe-area-inset-left, 0px);
  --safe-right: env(safe-area-inset-right, 0px);

  --font-sans: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Roboto", "Segoe UI", sans-serif;
  --font-mono: ui-monospace, "SF Mono", "Roboto Mono", monospace;
}

.app-root.dark {
  color-scheme: dark;
  --bg-canvas: #090D16;
  --bg-surface: #0F1623;
  --bg-subtle: #162032;
  --bg-hover: #1E293B;
  --bg-scrim: rgba(2, 6, 14, 0.72);

  --text-primary: #F8FAFC;
  --text-secondary: #CBD5E1;
  --text-muted: #94A3B8;
  --text-on-accent: #FFFFFF;

  --border-subtle: #1E293B;
  --border-strong: #475569;

  --accent: #2563EB;
  --accent-hover: #1D4ED8;
  --accent-text: #60A5FA;
  --accent-soft: #172554;
  --accent-border: #1D4ED8;

  --bubble-out-bg: #1D4ED8;
  --bubble-out-text: #FFFFFF;
  --bubble-in-bg: #162032;
  --bubble-in-text: #F8FAFC;

  --status-online: #4ADE80;
  --status-online-bg: rgba(21, 128, 61, 0.22);
  --status-idle: #FBBF24;
  --status-idle-bg: rgba(180, 83, 9, 0.24);
  --status-sleep: #C4B5FD;
  --status-sleep-bg: rgba(109, 40, 217, 0.24);
  --status-danger: #FCA5A5;
  --status-danger-bg: rgba(185, 28, 28, 0.24);
  --status-danger-border: rgba(252, 165, 165, 0.36);
  --status-offline: #94A3B8;
}

*, *::before, *::after {
  box-sizing: border-box;
  -webkit-tap-highlight-color: transparent;
}

html, body {
  margin: 0;
  padding: 0;
  width: 100%;
  height: 100%;
  overflow: hidden;
  font-family: var(--font-sans);
  font-size: 16px;
  line-height: 1.45;
  background: var(--bg-canvas);
  color: var(--text-primary);
}

button, input, textarea, select {
  font-family: inherit;
  font-size: 16px;
  color: inherit;
  touch-action: manipulation;
}

:focus-visible {
  outline: 2px solid var(--accent-text);
  outline-offset: 2px;
}

.app-root {
  display: flex;
  flex-direction: column;
  width: 100vw;
  height: 100vh;
  height: 100dvh;
  background: var(--bg-canvas);
  color: var(--text-primary);
  overflow: hidden;
}

/* ---- Update Banner (Top Non-Intrusive Bar) ---- */
.update-banner {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: calc(8px + var(--safe-top)) 14px 8px;
  background: var(--accent-soft);
  border-bottom: 1px solid var(--accent-border);
  color: var(--accent-text);
  font-size: 0.85rem;
  font-weight: 600;
  flex-shrink: 0;
}

.update-banner-actions {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-shrink: 0;
}

/* ---- Auth Shell ---- */
.auth-shell {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  padding: calc(28px + var(--safe-top)) 18px calc(28px + var(--safe-bottom));
  background: var(--bg-canvas);
}

.auth-card {
  width: 100%;
  max-width: 440px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: 24px 20px;
}

.brand-row {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 20px;
}

.brand-badge {
  width: 42px;
  height: 42px;
  border-radius: 12px;
  background: var(--accent);
  color: #FFFFFF;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.brand-title {
  font-size: 1.25rem;
  font-weight: 700;
  margin: 0;
  letter-spacing: -0.02em;
}

.brand-sub {
  font-size: 0.84rem;
  color: var(--text-muted);
  margin: 2px 0 0;
}

/* ---- Form Controls ---- */
.field {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-bottom: 14px;
}

.field-label {
  font-size: 0.82rem;
  font-weight: 600;
  color: var(--text-secondary);
}

.ui-input {
  width: 100%;
  min-height: 46px;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--border-strong);
  background: var(--bg-surface);
  color: var(--text-primary);
  font-size: 16px;
}

.ui-input:focus {
  border-color: var(--accent);
  outline: 2px solid var(--accent-soft);
}

.ui-btn {
  min-height: 46px;
  padding: 0 16px;
  border-radius: var(--radius-sm);
  border: 1px solid transparent;
  font-size: 0.92rem;
  font-weight: 600;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  cursor: pointer;
  transition: background-color 140ms ease, transform 110ms ease;
}

.ui-btn:active:not(:disabled) {
  transform: scale(0.98);
}

.ui-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.ui-btn.sm {
  min-height: 36px;
  padding: 0 12px;
  font-size: 0.82rem;
}

.ui-btn.block {
  width: 100%;
}

.ui-btn-primary {
  background: var(--accent);
  color: var(--text-on-accent);
}

.ui-btn-secondary {
  background: var(--bg-subtle);
  border-color: var(--border-subtle);
  color: var(--text-primary);
}

.ui-btn-outline {
  background: transparent;
  border-color: var(--border-strong);
  color: var(--text-primary);
}

.ui-btn-danger {
  background: var(--status-danger);
  color: #FFFFFF;
}

.ui-btn-danger-soft {
  background: var(--status-danger-bg);
  border-color: var(--status-danger-border);
  color: var(--status-danger);
}

.icon-btn {
  width: 44px;
  height: 44px;
  border-radius: var(--radius-sm);
  border: 1px solid transparent;
  background: transparent;
  color: var(--text-secondary);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  flex-shrink: 0;
}

.icon-btn:active {
  background: var(--bg-subtle);
}

.alert {
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--border-subtle);
  font-size: 0.85rem;
  margin-bottom: 14px;
}

.alert-error {
  background: var(--status-danger-bg);
  border-color: var(--status-danger-border);
  color: var(--status-danger);
}

.alert-success {
  background: var(--status-online-bg);
  border-color: var(--status-online);
  color: var(--status-online);
}

.alert-info {
  background: var(--accent-soft);
  border-color: var(--accent-border);
  color: var(--accent-text);
}

/* ---- Main Shell (Adaptive Bottom Bar / Rail) ---- */
.main-shell {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
  overflow: hidden;
}

.shell-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
  overflow: hidden;
}

.top-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: calc(10px + var(--safe-top)) 14px 10px;
  background: var(--bg-surface);
  border-bottom: 1px solid var(--border-subtle);
  flex-shrink: 0;
}

.has-banner .top-bar {
  padding-top: 10px;
}

.top-bar-title {
  font-size: 1.12rem;
  font-weight: 700;
  margin: 0;
  letter-spacing: -0.02em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.top-bar-sub {
  font-size: 0.78rem;
  color: var(--text-muted);
  display: flex;
  align-items: center;
  gap: 5px;
}

.bottom-nav {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  background: var(--bg-surface);
  border-top: 1px solid var(--border-subtle);
  padding: 4px 6px calc(6px + var(--safe-bottom));
  flex-shrink: 0;
}

.nav-item {
  min-height: 50px;
  border: none;
  background: transparent;
  color: var(--text-muted);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 3px;
  font-size: 0.72rem;
  font-weight: 600;
  border-radius: var(--radius-sm);
  cursor: pointer;
  position: relative;
}

.nav-item.active {
  color: var(--accent-text);
  background: var(--accent-soft);
}

.nav-badge {
  position: absolute;
  top: 4px;
  right: 16px;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  border-radius: var(--radius-full);
  background: var(--status-danger);
  color: #FFFFFF;
  font-size: 0.68rem;
  font-weight: 700;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-variant-numeric: tabular-nums;
}

@media (min-width: 640px) {
  .main-shell {
    flex-direction: row-reverse;
  }
  .bottom-nav {
    width: 84px;
    grid-template-columns: 1fr;
    grid-auto-rows: 64px;
    border-top: none;
    border-right: 1px solid var(--border-subtle);
    padding: calc(12px + var(--safe-top)) 8px calc(12px + var(--safe-bottom));
    gap: 6px;
  }
}

/* ---- Scrollable Lists & Cards ---- */
.scroll-pane {
  flex: 1;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
  padding: 12px 14px;
}

.chip-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 14px;
  background: var(--bg-surface);
  border-bottom: 1px solid var(--border-subtle);
  overflow-x: auto;
  flex-shrink: 0;
}

.chip {
  min-height: 34px;
  padding: 0 12px;
  border-radius: var(--radius-full);
  border: 1px solid var(--border-subtle);
  background: var(--bg-subtle);
  color: var(--text-secondary);
  font-size: 0.82rem;
  font-weight: 600;
  cursor: pointer;
  white-space: nowrap;
}

.chip.active {
  background: var(--accent);
  border-color: var(--accent);
  color: #FFFFFF;
}

.list-card {
  display: flex;
  align-items: center;
  gap: 12px;
  width: 100%;
  padding: 11px 12px;
  margin-bottom: 8px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-subtle);
  background: var(--bg-surface);
  text-align: left;
  cursor: pointer;
}

.list-card:active {
  background: var(--bg-subtle);
}

.avatar-wrap {
  position: relative;
  width: 46px;
  height: 46px;
  flex-shrink: 0;
}

.avatar-circle {
  width: 46px;
  height: 46px;
  border-radius: var(--radius-full);
  background: var(--accent-soft);
  color: var(--accent-text);
  border: 1px solid var(--border-subtle);
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 0.95rem;
  overflow: hidden;
}

.avatar-circle img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.presence-badge {
  position: absolute;
  right: -1px;
  bottom: -1px;
  width: 14px;
  height: 14px;
  border-radius: var(--radius-full);
  border: 2px solid var(--bg-surface);
}

.presence-online { background: var(--status-online); }
.presence-idle { background: var(--status-idle); }
.presence-sleep { background: var(--status-sleep); }
.presence-dnd { background: var(--status-danger); }
.presence-offline { background: var(--status-offline); }

.card-main {
  flex: 1;
  min-width: 0;
}

.card-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.card-title {
  font-size: 0.95rem;
  font-weight: 600;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.card-time {
  font-size: 0.74rem;
  color: var(--text-muted);
  font-variant-numeric: tabular-nums;
  flex-shrink: 0;
}

.card-sub {
  margin-top: 3px;
  font-size: 0.83rem;
  color: var(--text-muted);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 8px;
  border-radius: var(--radius-full);
  font-size: 0.72rem;
  font-weight: 600;
  background: var(--bg-subtle);
  color: var(--text-secondary);
  border: 1px solid var(--border-subtle);
}

.pill-accent {
  background: var(--accent-soft);
  color: var(--accent-text);
  border-color: var(--accent-border);
}

/* ---- Chat Room ---- */
.messages-pane {
  flex: 1;
  overflow-y: auto;
  -webkit-overflow-scrolling: touch;
  padding: 12px 14px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.msg-row {
  display: flex;
  flex-direction: column;
  max-width: 82%;
  margin-top: 6px;
}

.msg-row.grouped {
  margin-top: 2px;
}

.msg-row.mine {
  align-self: flex-end;
  align-items: flex-end;
}

.msg-row.other {
  align-self: flex-start;
  align-items: flex-start;
}

.msg-sender {
  font-size: 0.72rem;
  font-weight: 600;
  color: var(--text-muted);
  margin: 0 0 3px 6px;
}

.msg-bubble {
  padding: 9px 13px;
  border-radius: 16px;
  font-size: 0.94rem;
  line-height: 1.42;
  word-break: break-word;
  border: 1px solid var(--border-subtle);
  background: var(--bubble-in-bg);
  color: var(--bubble-in-text);
}

.msg-row.mine .msg-bubble {
  background: var(--bubble-out-bg);
  color: var(--bubble-out-text);
  border-color: transparent;
}

.msg-row.selected .msg-bubble {
  outline: 2px solid var(--status-danger);
  outline-offset: 1px;
}

.msg-meta {
  font-size: 0.68rem;
  color: var(--text-muted);
  margin-top: 3px;
  font-variant-numeric: tabular-nums;
}

.msg-img {
  max-width: 240px;
  max-height: 260px;
  border-radius: 10px;
  display: block;
  margin-top: 4px;
}

.composer-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px calc(8px + var(--safe-bottom));
  background: var(--bg-surface);
  border-top: 1px solid var(--border-subtle);
  flex-shrink: 0;
}

.composer-input {
  flex: 1;
  min-height: 44px;
  padding: 8px 14px;
  border-radius: var(--radius-full);
  border: 1px solid var(--border-strong);
  background: var(--bg-subtle);
  color: var(--text-primary);
}

/* ---- Sections, Modals & Update Checker ---- */
.section-card {
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  padding: 16px;
  margin-bottom: 12px;
}

.section-title {
  font-size: 0.9rem;
  font-weight: 700;
  margin: 0 0 10px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}

.modal-scrim {
  position: fixed;
  inset: 0;
  z-index: 900;
  background: var(--bg-scrim);
  display: flex;
  align-items: flex-end;
  justify-content: center;
  padding: 16px 12px calc(16px + var(--safe-bottom));
}

@media (min-width: 640px) {
  .modal-scrim {
    align-items: center;
  }
}

.modal-sheet {
  width: 100%;
  max-width: 480px;
  max-height: 86vh;
  overflow-y: auto;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: 18px 16px;
}

.changelog-box {
  background: var(--bg-subtle);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  padding: 12px;
  font-size: 0.83rem;
  line-height: 1.5;
  white-space: pre-wrap;
  max-height: 220px;
  overflow-y: auto;
  margin: 10px 0 14px;
}

.toast {
  position: fixed;
  left: 50%;
  bottom: calc(74px + var(--safe-bottom));
  transform: translateX(-50%);
  z-index: 1000;
  background: var(--text-primary);
  color: var(--bg-surface);
  padding: 10px 16px;
  border-radius: var(--radius-full);
  font-size: 0.84rem;
  font-weight: 600;
  max-width: 90vw;
  text-align: center;
}

.empty-box {
  text-align: center;
  padding: 36px 20px;
  color: var(--text-muted);
  font-size: 0.9rem;
}

.row-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.kv-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  padding: 7px 0;
  border-bottom: 1px solid var(--border-subtle);
  font-size: 0.88rem;
}

.kv-row:last-child {
  border-bottom: none;
}

.kv-key {
  color: var(--text-muted);
}

.kv-val {
  font-weight: 600;
  text-align: right;
  font-variant-numeric: tabular-nums;
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    transition-duration: 0.01ms !important;
    animation-duration: 0.01ms !important;
  }
}
"#;
