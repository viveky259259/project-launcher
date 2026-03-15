/**
 * Vercel Serverless Function — Project Launcher Badge API
 *
 * Endpoints:
 *   /health?score=85&label=health&style=flat
 *   /category?category=healthy&style=flat-square
 *   /git?commits=1234
 *   /breakdown?git=35&deps=25&tests=20
 */

// ── Badge Colors ──

function scoreColor(score) {
  if (score >= 80) return '#22c55e';
  if (score >= 50) return '#f59e0b';
  return '#ef4444';
}

function categoryColor(category) {
  switch (category) {
    case 'healthy': return '#22c55e';
    case 'attention': return '#f59e0b';
    case 'critical': return '#ef4444';
    default: return '#6b7280';
  }
}

// ── SVG Templates ──

function flatBadge({ label, value, labelColor, valueColor, labelWidth, valueWidth }) {
  const totalWidth = labelWidth + valueWidth;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${totalWidth}" height="20" role="img" aria-label="${label}: ${value}">
  <title>${label}: ${value}</title>
  <linearGradient id="s" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <clipPath id="r"><rect width="${totalWidth}" height="20" rx="3" fill="#fff"/></clipPath>
  <g clip-path="url(#r)">
    <rect width="${labelWidth}" height="20" fill="${labelColor}"/>
    <rect x="${labelWidth}" width="${valueWidth}" height="20" fill="${valueColor}"/>
    <rect width="${totalWidth}" height="20" fill="url(#s)"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110">
    <text aria-hidden="true" x="${labelWidth * 5}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)">${label}</text>
    <text x="${labelWidth * 5}" y="140" transform="scale(.1)">${label}</text>
    <text aria-hidden="true" x="${(labelWidth + valueWidth / 2) * 10}" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)">${value}</text>
    <text x="${(labelWidth + valueWidth / 2) * 10}" y="140" transform="scale(.1)">${value}</text>
  </g>
</svg>`;
}

function flatSquareBadge({ label, value, labelColor, valueColor, labelWidth, valueWidth }) {
  const totalWidth = labelWidth + valueWidth;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${totalWidth}" height="20" role="img" aria-label="${label}: ${value}">
  <title>${label}: ${value}</title>
  <g shape-rendering="crispEdges">
    <rect width="${labelWidth}" height="20" fill="${labelColor}"/>
    <rect x="${labelWidth}" width="${valueWidth}" height="20" fill="${valueColor}"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110">
    <text x="${labelWidth * 5}" y="140" transform="scale(.1)">${label}</text>
    <text x="${(labelWidth + valueWidth / 2) * 10}" y="140" transform="scale(.1)">${value}</text>
  </g>
</svg>`;
}

function forTheBadgeBadge({ label, value, labelColor, valueColor, labelWidth, valueWidth }) {
  const scale = 1.3;
  const lw = Math.round(labelWidth * scale);
  const vw = Math.round(valueWidth * scale);
  const totalWidth = lw + vw;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${totalWidth}" height="28" role="img" aria-label="${label}: ${value}">
  <title>${label}: ${value}</title>
  <g shape-rendering="crispEdges">
    <rect width="${lw}" height="28" fill="${labelColor}"/>
    <rect x="${lw}" width="${vw}" height="28" fill="${valueColor}"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision">
    <text x="${lw / 2}" y="18" font-size="10" letter-spacing="1">${label.toUpperCase()}</text>
    <text x="${lw + vw / 2}" y="18" font-size="11" font-weight="bold">${value}</text>
  </g>
</svg>`;
}

function estimateWidth(text, padding = 10) {
  return Math.round(text.length * 6.5 + padding * 2);
}

// ── Route Handlers ──

function handleHealth(query) {
  const score = Math.max(0, Math.min(100, parseInt(query.score || '0', 10)));
  const label = (query.label || 'health').replace(/\+/g, ' ');
  const style = query.style || 'flat';
  const valueText = `${score}/100`;

  return makeBadge({ label, value: valueText, valueColor: scoreColor(score), style });
}

function handleCategory(query) {
  const category = query.category || 'healthy';
  const label = (query.label || 'status').replace(/\+/g, ' ');
  const style = query.style || 'flat';

  return makeBadge({ label, value: category, valueColor: categoryColor(category), style });
}

function handleGit(query) {
  const commits = query.commits || '0';
  const label = (query.label || 'commits').replace(/\+/g, ' ');
  const style = query.style || 'flat';

  return makeBadge({ label, value: commits, valueColor: '#7c3aed', style });
}

function handleBreakdown(query) {
  const git = parseInt(query.git || '0', 10);
  const deps = parseInt(query.deps || '0', 10);
  const tests = parseInt(query.tests || '0', 10);
  const total = git + deps + tests;
  const value = `git:${git} deps:${deps} tests:${tests}`;
  const label = (query.label || 'health breakdown').replace(/\+/g, ' ');
  const style = query.style || 'flat';

  return makeBadge({ label, value, valueColor: scoreColor(total), style });
}

function makeBadge({ label, value, valueColor, style }) {
  const labelWidth = estimateWidth(label);
  const valueWidth = estimateWidth(value);
  const params = { label, value, labelColor: '#555', valueColor, labelWidth, valueWidth };

  switch (style) {
    case 'flat-square': return flatSquareBadge(params);
    case 'for-the-badge': return forTheBadgeBadge(params);
    default: return flatBadge(params);
  }
}

// ── Landing Page ──

function landingPage() {
  const base = '';
  return `<!DOCTYPE html>
<html><head><title>Project Launcher Badges</title>
<style>body{font-family:system-ui;max-width:700px;margin:40px auto;padding:0 20px;color:#e5e5e5;background:#0a0a0a}
h1{color:#fff}h2{color:#d4d4d4;margin-top:28px}code{background:#1a1a2e;padding:2px 6px;border-radius:4px;font-size:13px}
pre{background:#1a1a2e;padding:16px;border-radius:8px;overflow-x:auto;font-size:13px}
.badge{margin:8px 0;display:flex;align-items:center;gap:12px}
a{color:#7c3aed}</style></head>
<body>
<h1>Project Launcher Badges</h1>
<p>Add health badges to your GitHub README.</p>

<h2>Health Score</h2>
<div class="badge"><img src="${base}/health?score=92"/> <code>/health?score=92</code></div>
<div class="badge"><img src="${base}/health?score=65"/> <code>/health?score=65</code></div>
<div class="badge"><img src="${base}/health?score=30"/> <code>/health?score=30</code></div>

<h2>Styles</h2>
<div class="badge"><img src="${base}/health?score=85&style=flat"/> <code>style=flat</code> (default)</div>
<div class="badge"><img src="${base}/health?score=85&style=flat-square"/> <code>style=flat-square</code></div>
<div class="badge"><img src="${base}/health?score=85&style=for-the-badge"/> <code>style=for-the-badge</code></div>

<h2>Category</h2>
<div class="badge"><img src="${base}/category?category=healthy"/> <code>/category?category=healthy</code></div>
<div class="badge"><img src="${base}/category?category=attention"/> <code>/category?category=attention</code></div>
<div class="badge"><img src="${base}/category?category=critical"/> <code>/category?category=critical</code></div>

<h2>Commit Count</h2>
<div class="badge"><img src="${base}/git?commits=1,234"/> <code>/git?commits=1,234</code></div>

<h2>Score Breakdown</h2>
<div class="badge"><img src="${base}/breakdown?git=35&deps=25&tests=20"/> <code>/breakdown?git=35&amp;deps=25&amp;tests=20</code></div>

<h2>Custom Labels</h2>
<div class="badge"><img src="${base}/health?score=88&label=my+project"/> <code>&amp;label=my+project</code></div>

<h2>README Usage</h2>
<pre>![Health](https://badge.projectlauncher.dev/health?score=85)
![Status](https://badge.projectlauncher.dev/category?category=healthy)
![Commits](https://badge.projectlauncher.dev/git?commits=1234)
![Breakdown](https://badge.projectlauncher.dev/breakdown?git=35&deps=25&tests=20)</pre>

<p style="margin-top:32px;opacity:0.6"><a href="https://projectlauncher.dev">Project Launcher</a> — The dashboard for your dev life.</p>
</body></html>`;
}

// ── Vercel Handler ──

module.exports = (req, res) => {
  const parsed = new URL(req.url, `http://${req.headers.host}`);
  const path = parsed.pathname;
  const query = Object.fromEntries(parsed.searchParams);

  res.setHeader('Access-Control-Allow-Origin', '*');

  let svg;
  switch (path) {
    case '/health':
      svg = handleHealth(query);
      break;
    case '/category':
      svg = handleCategory(query);
      break;
    case '/git':
      svg = handleGit(query);
      break;
    case '/breakdown':
      svg = handleBreakdown(query);
      break;
    default:
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(landingPage());
      return;
  }

  res.writeHead(200, {
    'Content-Type': 'image/svg+xml',
    'Cache-Control': 'max-age=300, s-maxage=300',
  });
  res.end(svg);
};
