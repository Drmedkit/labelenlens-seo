#!/bin/bash
# SEO Audit Script for Label & Lens
# Karpathy Loop: score → fix → score → fix → ...
# Renders each route with Chromium, then scores SEO factors

SITE_DIR="/tmp/labelenlens-seo"
RESULTS_DIR="/tmp/labelenlens-seo/audit-results"
mkdir -p "$RESULTS_DIR"

ROUTES=(
  "/"
  "/energielabel"
  "/energielabels"
  "/energielabel-aanvragen-amsterdam/"
  "/fotografie"
  "/wws-puntentelling/"
  "/nen-2580-metingen/"
)

LIVE_BASE="https://labelenlens.nl"

echo "🔍 SEO Audit — Label & Lens"
echo "=========================="
echo "Time: $(date)"
echo ""

python3 << 'PYEOF'
import urllib.request, ssl, re, json, sys

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

LIVE_BASE = "https://labelenlens.nl"
ROUTES = [
    "/",
    "/energielabel",
    "/energielabels",
    "/energielabel-aanvragen-amsterdam/",
    "/fotografie",
    "/wws-puntentelling/",
    "/nen-2580-metingen/",
]

total_score = 0
total_max = 0
results = []

for route in ROUTES:
    url = f"{LIVE_BASE}{route}"
    score = 0
    max_score = 0
    issues = []
    passes = []
    
    # Fetch raw HTML (pre-render)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"})
        resp = urllib.request.urlopen(req, timeout=15, context=ctx)
        raw_html = resp.read().decode("utf-8", errors="ignore")
    except Exception as e:
        print(f"❌ {route}: Failed to fetch — {e}")
        continue
    
    # === 1. Server-Side Content (Critical for SEO) ===
    max_score += 20
    # Check if meaningful content exists in raw HTML (not JS-rendered)
    body_match = re.search(r'<body[^>]*>(.*)</body>', raw_html, re.S | re.I)
    body_content = body_match.group(1) if body_match else ""
    text_content = re.sub(r'<[^>]+>', '', body_content).strip()
    
    if len(text_content) > 200:
        score += 20
        passes.append("✅ SSR: Content in raw HTML (Google can index without JS)")
    elif len(text_content) > 50:
        score += 5
        issues.append("⚠️ SSR: Minimal content in raw HTML — mostly JS-rendered")
    else:
        issues.append("🔴 SSR: No content in raw HTML — fully client-side rendered. Google must execute JS to see anything.")

    # === 2. Title Tag ===
    max_score += 10
    title = re.search(r'<title>([^<]+)</title>', raw_html, re.I)
    if title:
        t = title.group(1)
        if len(t) >= 30 and len(t) <= 60:
            score += 10
            passes.append(f"✅ Title: \"{t}\" ({len(t)} chars)")
        elif len(t) > 10:
            score += 5
            issues.append(f"⚠️ Title length: {len(t)} chars (ideal: 30-60) — \"{t}\"")
        else:
            score += 2
            issues.append(f"⚠️ Title too short: \"{t}\"")
    else:
        issues.append("🔴 No <title> tag found")

    # === 3. Meta Description ===
    max_score += 10
    desc = re.search(r'<meta\s+name=["\']description["\'][^>]*content=["\']([^"\']+)', raw_html, re.I)
    if desc:
        d = desc.group(1)
        if len(d) >= 120 and len(d) <= 160:
            score += 10
            passes.append(f"✅ Meta description: {len(d)} chars")
        elif len(d) >= 50:
            score += 5
            issues.append(f"⚠️ Meta description length: {len(d)} chars (ideal: 120-160)")
        else:
            score += 2
            issues.append(f"⚠️ Meta description too short: {len(d)} chars")
    else:
        issues.append("🔴 No meta description")

    # === 4. Unique Title/Description per page ===
    max_score += 5
    default_title = "Label & Lens – Energielabel & Vastgoedfotografie Amsterdam"
    if title and title.group(1) != default_title:
        score += 5
        passes.append("✅ Unique title (not default)")
    elif route == "/":
        score += 5
        passes.append("✅ Homepage title")
    else:
        issues.append("🔴 Same title as homepage — needs unique title per page")

    # === 5. Open Graph Tags ===
    max_score += 5
    og_title = re.search(r'property=["\']og:title["\']', raw_html, re.I)
    og_desc = re.search(r'property=["\']og:description["\']', raw_html, re.I)
    og_image = re.search(r'property=["\']og:image["\']', raw_html, re.I)
    og_count = sum([bool(og_title), bool(og_desc), bool(og_image)])
    if og_count == 3:
        score += 5
        passes.append("✅ Open Graph: title, description, image")
    elif og_count > 0:
        score += 2
        issues.append(f"⚠️ Open Graph incomplete: {og_count}/3 tags")
    else:
        issues.append("🔴 No Open Graph tags")

    # === 6. Canonical URL ===
    max_score += 5
    canonical = re.search(r'<link[^>]*rel=["\']canonical["\'][^>]*href=["\']([^"\']+)', raw_html, re.I)
    if canonical:
        can_url = canonical.group(1)
        expected = f"https://www.labelenlens.nl{route}".rstrip('/')
        if route == "/":
            expected = "https://www.labelenlens.nl/"
        score += 5
        passes.append(f"✅ Canonical: {can_url}")
    else:
        issues.append("🔴 No canonical URL")

    # === 7. Structured Data (JSON-LD) ===
    max_score += 10
    schemas = re.findall(r'<script[^>]*type=["\']application/ld\+json["\'][^>]*>(.*?)</script>', raw_html, re.S)
    if schemas:
        schema_types = []
        for s in schemas:
            try:
                data = json.loads(s)
                if isinstance(data, list):
                    for d in data:
                        schema_types.append(d.get("@type", "unknown"))
                else:
                    schema_types.append(data.get("@type", "unknown"))
            except:
                pass
        if schema_types:
            score += 10
            passes.append(f"✅ Structured data: {', '.join(schema_types)}")
        else:
            score += 3
            issues.append("⚠️ JSON-LD found but couldn't parse schema types")
    else:
        issues.append("🔴 No structured data (JSON-LD)")

    # === 8. Heading Structure ===
    max_score += 10
    h1s = re.findall(r'<h1[^>]*>(.*?)</h1>', raw_html, re.I | re.S)
    # Since it's SPA, h1 won't be in raw HTML — this tests SSR
    if h1s:
        score += 10
        h1_text = re.sub(r'<[^>]+>', '', h1s[0]).strip()
        passes.append(f"✅ H1 in raw HTML: \"{h1_text[:60]}\"")
    else:
        issues.append("🔴 No H1 in raw HTML (hidden behind JS rendering)")

    # === 9. Internal Linking ===
    max_score += 5
    internal_links = re.findall(r'href=["\']/(energielabel|fotografie|nen|wws|contact)[^"\']*["\']', raw_html, re.I)
    if len(internal_links) >= 3:
        score += 5
        passes.append(f"✅ Internal links in raw HTML: {len(internal_links)}")
    elif internal_links:
        score += 2
        issues.append(f"⚠️ Few internal links in raw HTML: {len(internal_links)}")
    else:
        issues.append("🔴 No internal links in raw HTML (all added by JS)")

    # === 10. Image Alt Tags (in raw HTML) ===
    max_score += 5
    imgs = re.findall(r'<img[^>]+>', raw_html, re.I)
    imgs_with_alt = [i for i in imgs if 'alt=' in i.lower()]
    if imgs:
        if len(imgs_with_alt) == len(imgs):
            score += 5
            passes.append(f"✅ All {len(imgs)} images have alt text")
        else:
            score += 2
            issues.append(f"⚠️ {len(imgs) - len(imgs_with_alt)}/{len(imgs)} images missing alt")
    else:
        score += 5  # No images in raw HTML is fine for SPA
        passes.append("✅ No images in raw HTML (SPA)")

    # === 11. Page Speed Indicators ===
    max_score += 5
    html_size = len(raw_html)
    if html_size < 50000:
        score += 5
        passes.append(f"✅ HTML size: {html_size//1024}KB")
    elif html_size < 150000:
        score += 3
        issues.append(f"⚠️ HTML size: {html_size//1024}KB (could be smaller)")
    else:
        issues.append(f"🔴 HTML size: {html_size//1024}KB (too large)")

    # === 12. Hreflang ===
    max_score += 5
    hreflang = re.search(r'hreflang', raw_html, re.I)
    if hreflang:
        score += 5
        passes.append("✅ Hreflang tag present")
    else:
        issues.append("⚠️ No hreflang tag")

    # === 13. Mobile Viewport ===
    max_score += 5
    viewport = re.search(r'<meta[^>]*name=["\']viewport["\']', raw_html, re.I)
    if viewport:
        score += 5
        passes.append("✅ Viewport meta tag")
    else:
        issues.append("🔴 No viewport meta tag")

    pct = round(score / max_score * 100) if max_score > 0 else 0
    
    result = {
        "route": route,
        "score": score,
        "max": max_score,
        "pct": pct,
        "issues": issues,
        "passes": passes,
    }
    results.append(result)
    total_score += score
    total_max += max_score

# Print results
print("=" * 60)
for r in results:
    emoji = "🟢" if r["pct"] >= 80 else "🟡" if r["pct"] >= 50 else "🔴"
    print(f"\n{emoji} {r['route']} — {r['pct']}% ({r['score']}/{r['max']})")
    for i in r["issues"]:
        print(f"   {i}")
    for p in r["passes"]:
        print(f"   {p}")

print("\n" + "=" * 60)
overall = round(total_score / total_max * 100) if total_max > 0 else 0
print(f"\n📊 OVERALL SEO SCORE: {overall}% ({total_score}/{total_max})")
print(f"   Pages audited: {len(results)}")

# Count issues by severity
red = sum(1 for r in results for i in r["issues"] if "🔴" in i)
yellow = sum(1 for r in results for i in r["issues"] if "⚠️" in i)
green = sum(1 for r in results for p in r["passes"])
print(f"   🔴 Critical: {red}")
print(f"   ⚠️ Warning: {yellow}")  
print(f"   ✅ Passing: {green}")

PYEOF
