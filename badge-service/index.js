/**
 * Project Launcher — GitHub Health Badge Service
 *
 * Generates SVG badges showing project health scores.
 * Deploy as a Vercel serverless function, Cloudflare Worker, or standalone.
 *
 * Usage in README.md:
 *   ![Health](https://badge.projectlauncher.dev/health?score=85)
 *   ![Health](https://badge.projectlauncher.dev/health?score=85&label=project+health)
 *   ![Health](https://badge.projectlauncher.dev/health?score=85&style=flat)
 */

const http = require('http');
const url = require('url');

const PORT = process.env.PORT || 3000;

// ── Badge Colors ──

function scoreColor(score) {
  if (score >= 80) return { bg: '#22c55e', label: 'healthy' };
  if (score >= 50) return { bg: '#f59e0b', label: 'needs attention' };
  return { bg: '#ef4444', label: 'critical' };
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
    <text x="${lw / 2}" y="18" font-size="10" text-transform="uppercase" letter-spacing="1">${label.toUpperCase()}</text>
    <text x="${lw + vw / 2}" y="18" font-size="11" font-weight="bold">${value}</text>
  </g>
</svg>`;
}

// ── Text Width Estimation ──

function estimateWidth(text, padding = 10) {
  // Approximate character widths for Verdana at size 11
  return Math.round(text.length * 6.5 + padding * 2);
}

// ── Route Handlers ──

function handleHealth(query) {
  const score = parseInt(query.score || '0', 10);
  const label = (query.label || 'health').replace(/\+/g, ' ');
  const style = query.style || 'flat';
  const { bg } = scoreColor(score);

  const valueText = `${score}/100`;
  const labelWidth = estimateWidth(label);
  const valueWidth = estimateWidth(valueText);

  const params = {
    label,
    value: valueText,
    labelColor: '#555',
    valueColor: bg,
    labelWidth,
    valueWidth,
  };

  switch (style) {
    case 'flat-square': return flatSquareBadge(params);
    case 'for-the-badge': return forTheBadgeBadge(params);
    default: return flatBadge(params);
  }
}

function handleCategory(query) {
  const category = query.category || 'healthy';
  const label = (query.label || 'status').replace(/\+/g, ' ');
  const style = query.style || 'flat';
  const color = categoryColor(category);

  const labelWidth = estimateWidth(label);
  const valueWidth = estimateWidth(category);

  const params = {
    label,
    value: category,
    labelColor: '#555',
    valueColor: color,
    labelWidth,
    valueWidth,
  };

  switch (style) {
    case 'flat-square': return flatSquareBadge(params);
    case 'for-the-badge': return forTheBadgeBadge(params);
    default: return flatBadge(params);
  }
}

function handleGit(query) {
  const commits = query.commits || '0';
  const label = (query.label || 'commits').replace(/\+/g, ' ');
  const style = query.style || 'flat';

  const labelWidth = estimateWidth(label);
  const valueWidth = estimateWidth(commits);

  const params = {
    label,
    value: commits,
    labelColor: '#555',
    valueColor: '#7c3aed',
    labelWidth,
    valueWidth,
  };

  switch (style) {
    case 'flat-square': return flatSquareBadge(params);
    case 'for-the-badge': return forTheBadgeBadge(params);
    default: return flatBadge(params);
  }
}

function handleBreakdown(query) {
  const git = parseInt(query.git || '0', 10);
  const deps = parseInt(query.deps || '0', 10);
  const tests = parseInt(query.tests || '0', 10);
  const style = query.style || 'flat';

  const total = git + deps + tests;
  const { bg } = scoreColor(total);
  const value = `git:${git} deps:${deps} tests:${tests}`;
  const label = (query.label || 'health breakdown').replace(/\+/g, ' ');

  const labelWidth = estimateWidth(label);
  const valueWidth = estimateWidth(value);

  const params = {
    label,
    value,
    labelColor: '#555',
    valueColor: bg,
    labelWidth,
    valueWidth,
  };

  switch (style) {
    case 'flat-square': return flatSquareBadge(params);
    case 'for-the-badge': return forTheBadgeBadge(params);
    default: return flatBadge(params);
  }
}

// ── Server ──

const server = http.createServer((req, res) => {
  const parsed = url.parse(req.url, true);
  const path = parsed.pathname;
  const query = parsed.query;

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');

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
    'Cache-Control': 'max-age=300',
  });
  res.end(svg);
});

function landingPage() {
  return `<!DOCTYPE html>
<html><head><title>Project Launcher Badges</title>
<style>body{font-family:system-ui;max-width:700px;margin:40px auto;padding:0 20px;color:#e5e5e5;background:#0a0a0a}
h1{color:#fff}code{background:#1a1a2e;padding:2px 6px;border-radius:4px;font-size:14px}
pre{background:#1a1a2e;padding:16px;border-radius:8px;overflow-x:auto}
.badge{margin:8px 0;display:flex;align-items:center;gap:12px}
a{color:#7c3aed}</style></head>
<body>
<h1>Project Launcher Badges</h1>
<p>Add health badges to your GitHub README.</p>

<h2>Health Score</h2>
<div class="badge"><img src="/health?score=92"/> <code>![Health](/health?score=92)</code></div>
<div class="badge"><img src="/health?score=65"/> <code>![Health](/health?score=65)</code></div>
<div class="badge"><img src="/health?score=30"/> <code>![Health](/health?score=30)</code></div>

<h2>Styles</h2>
<div class="badge"><img src="/health?score=85&style=flat"/> <code>style=flat</code></div>
<div class="badge"><img src="/health?score=85&style=flat-square"/> <code>style=flat-square</code></div>
<div class="badge"><img src="/health?score=85&style=for-the-badge"/> <code>style=for-the-badge</code></div>

<h2>Category Badge</h2>
<div class="badge"><img src="/category?category=healthy"/> <code>/category?category=healthy</code></div>
<div class="badge"><img src="/category?category=attention"/> <code>/category?category=attention</code></div>

<h2>Commit Count</h2>
<div class="badge"><img src="/git?commits=1,234"/> <code>/git?commits=1,234</code></div>

<h2>Score Breakdown</h2>
<div class="badge"><img src="/breakdown?git=35&deps=25&tests=20"/> <code>/breakdown?git=35&deps=25&tests=20</code></div>

<h2>Custom Labels</h2>
<div class="badge"><img src="/health?score=88&label=my+project"/> <code>&label=my+project</code></div>

<h2>Usage</h2>
<pre>![Health](https://badge.projectlauncher.dev/health?score=85)
![Status](https://badge.projectlauncher.dev/category?category=healthy)
![Commits](https://badge.projectlauncher.dev/git?commits=1234)</pre>

<p><a href="https://projectlauncher.dev">Project Launcher</a> — The dashboard for your dev life.</p>
</body></html>`;
}

server.listen(PORT, () => {
  console.log(`Badge service running on http://localhost:${PORT}`);
});

// Export for Vercel serverless
module.exports = (req, res) => {
  server.emit('request', req, res);
};
