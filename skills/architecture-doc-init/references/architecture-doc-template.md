# Architecture doc (`docs/architecture.html`)

A self-contained, **dependency-free** living system map that ships with every scaffolded repo.
One HTML file, no build step, no CDN, no JS framework — open it in a browser and it renders.
Dark GitHub-style theme (CSS variables, plain CSS — never Tailwind). It contains:

1. **Inline-SVG data-flow diagram** — rounded-rect nodes = components, arrows (with `<marker>`
   arrowheads) = flow, color-coded lanes: inputs = blue, guards = amber, engine = green,
   alerts/notifications = purple, failure paths = dashed red.
2. **Known failure modes & fixes table** — symptom / root cause / fix / status (pill tags).
3. **Two-column key files & paths list.**
4. **Legend, an "operate it" note box, and a footer.**

> Design source: generalized from a proven architecture doc that had already paid for itself on a
> real production pipeline — same theme, class conventions, and section set, with every node, row,
> and path reduced to a clearly-marked `«placeholder»` the project's real components slot into.

## Who uses this template

- **`/architecture-doc-init`** (owner) fills it in for **existing repos** — real components from
  the codebase, real failure modes from git history. See that skill's flow.
- **`/project-scaffold` Step 10** writes the HTML block below verbatim (blank) for **new repos**,
  replacing only `«PROJECT_NAME»`, `«REPO»`, and `«DATE»` (today, YYYY-MM-DD). Every other `«…»`
  token stays as a fill-in placeholder — the doc's own intro tells the user (or the next Claude
  session) to replace them as the system takes shape.

Written for every project type (frontend, backend, fullstack, library, research) — the starter
pipeline (entrypoint → guard → engine → outputs, with an inputs lane and an alerts lane) is
generic enough to retheme to any of them.

## Editing guide — the coordinate grid

The SVG is hand-editable on purpose: one **center-pipeline grid** so moving or adding a node is
arithmetic, not guesswork. The same constants are documented in the `GRID` comment at the top of
the `<svg>` so they travel with the file:

```
viewBox = "0 0 1040 620"
Main pipeline (top → bottom, boxes centered on CENTER_X = 500):
    wide box   x=330 w=340   (entrypoint, engine, outputs)
    guard box  x=345 w=310   (guards/gates — slightly narrower, amber)
    box heights: 66 (title+subtitle), 46 (guard), 100 (engine, multi-line)
    vertical gap between boxes = 32 (a straight arrow: bottom of one → top of next)
Side lanes:
    INPUTS  (left,  blue):   container x=20  w=230 · inner boxes x=34 w=202 h=44
    ALERTS  (right, purple): container x=770 w=250 · text entries at x=786
Full-width note box: x=20 w=1000
Text inside a box: title (.lc) at top+21..26 · subtitle (.smc) ~17px below it
```

Class conventions (defined in `<svg><defs><style>`, colors are raw hex from the theme):

- Node fills by lane: `.box` (neutral), `.guard` (amber), `.engine` (green), `.inp` (blue),
  `.disc` (purple — alerts).
- Text: `.lc` centered title, `.smc` centered mono subtitle, `.lab`/`.sm` left-aligned variants.
- Edges: `.flow` (gray, `marker-end="url(#arw)"`), `.ok` (green, `#arwG`), `.fail` (dashed red,
  `#arwR`). Straight pipeline steps are `<line>`; lane hops are curved `<path d="M… C…">`.

**To add a pipeline step:** copy a `<rect class="box">` + its `.lc`/`.smc` text lines, shift
everything below it down by (box height + 32), and join with a `<line class="flow">` from the
previous box's bottom-center `(500, y)` to the new box's top `(500, y-2)`.

**To add an input or alert:** copy an inner lane box (inputs) or a `.lab`+`.sm` text pair (alerts)
and connect with a curved `.ok` / `.fail` path from the source box's edge into the lane.

Keep the grid convention when you edit — the whole point is that the next person can too.

---

## Template — write verbatim to `docs/architecture.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>«PROJECT_NAME» — Architecture</title>
<style>
  :root {
    --bg: #0d1117; --panel: #161b22; --panel2: #1c2431;
    --ink: #c9d1d9; --muted: #8b949e; --line: #30363d;
    --blue: #58a6ff; --green: #3fb950; --amber: #d29922; --red: #f85149;
    --purple: #bc8cff; --mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--ink);
    font: 15px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    padding: 32px 20px 80px;
  }
  .wrap { max-width: 1040px; margin: 0 auto; }
  h1 { font-size: 26px; margin: 0 0 4px; letter-spacing: -.01em; }
  h2 { font-size: 18px; margin: 40px 0 14px; padding-bottom: 6px; border-bottom: 1px solid var(--line); }
  .sub { color: var(--muted); margin: 0 0 6px; }
  code, .m { font-family: var(--mono); font-size: .9em; }
  .m { color: var(--purple); }
  .card { background: var(--panel); border: 1px solid var(--line); border-radius: 10px; padding: 4px 16px 16px; }
  svg { width: 100%; height: auto; display: block; }
  table { width: 100%; border-collapse: collapse; margin-top: 8px; font-size: 14px; }
  th, td { text-align: left; padding: 9px 12px; border-bottom: 1px solid var(--line); vertical-align: top; }
  th { color: var(--muted); font-weight: 600; font-size: 12.5px; text-transform: uppercase; letter-spacing: .04em; }
  .tag { display: inline-block; padding: 1px 8px; border-radius: 999px; font-size: 12px; font-weight: 600; white-space: nowrap; }
  .fixed { background: rgba(63,185,80,.15); color: var(--green); border: 1px solid rgba(63,185,80,.35); }
  .prog  { background: rgba(210,153,34,.15); color: var(--amber); border: 1px solid rgba(210,153,34,.4); }
  .open  { background: rgba(248,81,73,.15); color: var(--red); border: 1px solid rgba(248,81,73,.35); }
  .grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
  .note { background: var(--panel2); border-left: 3px solid var(--blue); border-radius: 4px; padding: 10px 14px; margin: 12px 0; color: var(--ink); font-size: 14px; }
  ul { margin: 6px 0; padding-left: 20px; } li { margin: 3px 0; }
  .legend { display: flex; flex-wrap: wrap; gap: 14px; margin-top: 10px; font-size: 13px; color: var(--muted); }
  .legend span { display: inline-flex; align-items: center; gap: 6px; }
  .sw { width: 13px; height: 13px; border-radius: 3px; display: inline-block; }
  footer { color: var(--muted); font-size: 12.5px; margin-top: 44px; border-top: 1px solid var(--line); padding-top: 14px; }
  @media (max-width: 720px) { .grid2 { grid-template-columns: 1fr; } }
</style>
</head>
<body>
<div class="wrap">
  <h1>«PROJECT_NAME» — Architecture</h1>
  <p class="sub">«One-line description of what this system does and where it runs.» Repo: <code>«REPO»</code></p>
  <p class="sub">Snapshot: «DATE» · <b>living doc</b> — replace every <code>«placeholder»</code> with the real component as it lands, and keep it current.</p>

  <h2>Data flow</h2>
  <div class="card">
  <!-- =====================================================================
       GRID (viewBox 0 0 1040 620) — keep this convention when editing:
         · pipeline boxes centered on CENTER_X=500: wide x=330 w=340, guard x=345 w=310
         · vertical gap between pipeline boxes = 32 (straight <line class="flow">)
         · INPUTS lane (blue):  container x=20 w=230, inner boxes x=34 w=202 h=44
         · ALERTS lane (purple): container x=770 w=250, text entries at x=786
         · box text: .lc title at top+21..26, .smc subtitle ~17px below
         · edges: .flow gray→#arw · .ok green→#arwG · .fail dashed red→#arwR
       ✎ EDIT: replace the «placeholder» nodes with your real components;
         add/remove pipeline steps, inputs, and alert entries as the system grows.
  ====================================================================== -->
  <svg viewBox="0 0 1040 620" role="img" aria-label="«PROJECT_NAME» data flow diagram">
    <defs>
      <marker id="arw" markerWidth="9" markerHeight="9" refX="7" refY="3" orient="auto">
        <path d="M0,0 L7,3 L0,6 Z" fill="#8b949e"/>
      </marker>
      <marker id="arwR" markerWidth="9" markerHeight="9" refX="7" refY="3" orient="auto">
        <path d="M0,0 L7,3 L0,6 Z" fill="#f85149"/>
      </marker>
      <marker id="arwG" markerWidth="9" markerHeight="9" refX="7" refY="3" orient="auto">
        <path d="M0,0 L7,3 L0,6 Z" fill="#3fb950"/>
      </marker>
      <style>
        .box { fill: #1c2431; stroke: #30363d; stroke-width: 1.5; }
        .lab { fill: #c9d1d9; font: 600 14px sans-serif; }
        .sm  { fill: #8b949e; font: 12px ui-monospace, monospace; }
        .smc { fill: #8b949e; font: 12px ui-monospace, monospace; text-anchor: middle; }
        .lc  { fill: #c9d1d9; font: 600 14px sans-serif; text-anchor: middle; }
        .flow { stroke: #8b949e; stroke-width: 1.6; fill: none; }
        .fail { stroke: #f85149; stroke-width: 1.5; fill: none; stroke-dasharray: 5 4; }
        .ok   { stroke: #3fb950; stroke-width: 1.6; fill: none; }
        .guard { fill: #241c14; stroke: #d29922; stroke-width: 1.5; }
        .engine { fill: #16241a; stroke: #3fb950; stroke-width: 1.75; }
        .disc { fill: #201a2e; stroke: #bc8cff; stroke-width: 1.5; }
        .inp  { fill: #131d2b; stroke: #58a6ff; stroke-width: 1.5; }
      </style>
    </defs>

    <!-- ===== ENTRYPOINT / TRIGGER ===== -->
    <rect x="330" y="40" width="340" height="66" rx="9" class="box"/>
    <text x="500" y="66" class="lc">«Entrypoint»</text>
    <text x="500" y="86" class="smc">«e.g. HTTP request · cron · CLI invocation»</text>
    <line x1="500" y1="106" x2="500" y2="138" class="flow" marker-end="url(#arw)"/>

    <!-- ===== GUARD / GATE (amber; may short-circuit to alerts) ===== -->
    <rect x="345" y="140" width="310" height="46" rx="8" class="guard"/>
    <text x="500" y="161" class="lc">Guard · «precondition?»</text>
    <text x="500" y="178" class="smc">«e.g. auth valid · input present · deps up»</text>
    <path d="M655,163 C710,163 740,205 770,215" class="fail" marker-end="url(#arwR)"/>
    <line x1="500" y1="186" x2="500" y2="218" class="flow" marker-end="url(#arw)"/>

    <!-- ===== ENGINE (green; the core work) ===== -->
    <rect x="330" y="220" width="340" height="100" rx="10" class="engine"/>
    <text x="500" y="248" class="lc">«Engine core»</text>
    <text x="500" y="268" class="smc">«the component that does the real work»</text>
    <text x="500" y="288" class="smc">«key detail: model / algorithm / library»</text>
    <text x="500" y="304" class="smc">«key detail: what it reads»</text>
    <path d="M670,270 C715,270 742,282 770,288" class="fail" marker-end="url(#arwR)"/>

    <!-- ===== INPUTS LANE (left, blue; feeds the engine) ===== -->
    <text x="135" y="204" class="smc">«inputs»</text>
    <rect x="20" y="214" width="230" height="126" rx="10" fill="none" stroke="#30363d" stroke-dasharray="4 4"/>
    <rect x="34" y="226" width="202" height="44" rx="7" class="inp"/>
    <text x="135" y="246" class="lc">«Input A»</text>
    <text x="135" y="262" class="smc">«e.g. db · file · queue»</text>
    <rect x="34" y="282" width="202" height="44" rx="7" class="inp"/>
    <text x="135" y="302" class="lc">«Input B»</text>
    <text x="135" y="318" class="smc">«e.g. env config · API»</text>
    <path d="M236,248 C285,252 300,258 328,260" class="ok" marker-end="url(#arwG)"/>
    <path d="M236,304 C285,300 300,292 328,286" class="ok" marker-end="url(#arwG)"/>

    <!-- ===== OUTPUTS ===== -->
    <line x1="500" y1="320" x2="500" y2="352" class="flow" marker-end="url(#arw)"/>
    <rect x="330" y="354" width="340" height="66" rx="9" class="box"/>
    <text x="500" y="380" class="lc">«Writes / outputs»</text>
    <text x="500" y="400" class="smc">«e.g. db rows · rendered pages · files»</text>
    <path d="M670,387 C715,387 742,382 770,380" class="ok" marker-end="url(#arwG)"/>

    <!-- ===== ALERTS / NOTIFICATIONS LANE (right, purple) ===== -->
    <rect x="770" y="140" width="250" height="280" rx="10" class="disc"/>
    <text x="895" y="164" class="lc">«Alerts / observability»</text>
    <text x="895" y="182" class="smc">«e.g. logs · Discord · Sentry»</text>
    <line x1="770" y1="194" x2="1020" y2="194" stroke="#30363d"/>
    <text x="786" y="222" class="lab">⚠️ «guard failed»</text>
    <text x="786" y="240" class="sm">«what gets reported, where»</text>
    <text x="786" y="294" class="lab" fill="#f85149">🚨 «engine failed»</text>
    <text x="786" y="312" class="sm">«non-zero exit / exception path»</text>
    <text x="786" y="386" class="lab" fill="#3fb950">✅ «success»</text>
    <text x="786" y="404" class="sm">«how you know it worked»</text>

    <!-- ===== DEPLOY / RUNTIME NOTE (full width) =====
         ✎ EDIT: state what triggers a production deploy, precisely. "Deploys from main"
         is not enough — say whether EVERY push to main deploys or only a tagged release,
         and which commit ends up running. Repos scaffolded with the tagged-only model
         (gh-actions-init/references/tagged-deploy.md) should read like the placeholder
         below; delete the tagged-only lines if this repo really does branch-auto-deploy. -->
    <rect x="20" y="460" width="1000" height="132" rx="10" class="box"/>
    <text x="40" y="488" class="lab">Deploy model — «tagged-only | branch auto-deploy»</text>
    <text x="40" y="512" class="sm">«Host auto-deploy is OFF. Prod deploys only when release-please cuts a vX.Y.Z tag — its workflow triggers the deploy against that tagged commit.»</text>
    <text x="40" y="532" class="sm">«So production runs the exact tagged commit, once; the untagged develop→main promotion merge never deploys.»</text>
    <text x="40" y="552" class="sm">«Every promotion releases: release-please tracks the repo root, so any change anywhere cuts ≥ a patch (feat→minor, breaking→major) → no drift.»</text>
    <text x="40" y="572" class="sm">«Migrations / build-time env needs · Logs and dashboards: where to look when it misbehaves.»</text>
  </svg>
  </div>
  <div class="legend">
    <span><i class="sw" style="background:#d29922"></i> guard / gate (may short-circuit)</span>
    <span><i class="sw" style="background:#3fb950"></i> engine · success path</span>
    <span><i class="sw" style="background:#bc8cff"></i> alerts / notifications</span>
    <span><i class="sw" style="background:#58a6ff"></i> inputs</span>
    <span><span style="color:#f85149">– – –</span> failure / skip → alert</span>
  </div>

  <h2>Known failure modes &amp; fixes</h2>
  <!-- ✎ EDIT: replace these placeholder rows with real incidents as they happen.
       Status tags: fixed · prog (in progress) · open -->
  <table>
    <thead><tr><th>Symptom</th><th>Root cause</th><th>Fix</th><th>Status</th></tr></thead>
    <tbody>
      <tr>
        <td>«What you observe when it breaks»</td>
        <td>«Why it actually happens (the real mechanism, not the first guess)»</td>
        <td>«The change that resolved it (link the PR)»</td>
        <td><span class="tag fixed">fixed</span></td>
      </tr>
      <tr>
        <td>«Second symptom»</td>
        <td>«Root cause»</td>
        <td>«Mitigation underway»</td>
        <td><span class="tag prog">in progress</span></td>
      </tr>
      <tr>
        <td>«Known gap»</td>
        <td>«Root cause»</td>
        <td>«Not yet addressed»</td>
        <td><span class="tag open">open</span></td>
      </tr>
    </tbody>
  </table>

  <h2>Key files &amp; paths</h2>
  <!-- ✎ EDIT: the files a newcomer must know to navigate the repo. -->
  <div class="grid2">
    <div>
      <ul>
        <li><span class="m">«path/to/entrypoint»</span> — app / service entry point</li>
        <li><span class="m">«path/to/core-module»</span> — the engine (core logic)</li>
        <li><span class="m">«path/to/data-layer»</span> — persistence / data access</li>
        <li><span class="m">«path/to/config»</span> — configuration &amp; env wiring</li>
      </ul>
    </div>
    <div>
      <ul>
        <li><span class="m">.env.example</span> — required env vars (copy to <code>.env</code>)</li>
        <li><span class="m">.github/workflows/</span> — CI · release-please · deploy</li>
        <li><span class="m">docs/architecture.html</span> — this file (keep it current)</li>
        <li><span class="m">«path/to/logs-or-dashboard»</span> — where to look when it breaks</li>
      </ul>
    </div>
  </div>

  <div class="note">
    <b>Operate it:</b> «the 2-3 commands that matter day-to-day — run it locally
    (<code>npm run dev</code> or equivalent), run the full check suite (<code>npm run check:all</code>),
    and how to inspect / restart / roll back the deployed thing».
  </div>

  <footer>
    Generated as a repo artifact · open locally with <code>open docs/architecture.html</code>.
    Reflects the system as of «DATE»; update alongside changes to the components it maps.
  </footer>
</div>
</body>
</html>
```
