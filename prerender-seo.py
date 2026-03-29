#!/usr/bin/env python3
"""
Karpathy Loop: SEO Prerender for Label & Lens
Extracts SEO data from React components and generates per-route HTML shells
with all meta tags, structured data, and key content baked into the HTML.
"""
import re, json, os, sys

SITE_URL = "https://www.labelenlens.nl"
SITE_NAME = "Label & Lens"
DEFAULT_OG_IMAGE = f"{SITE_URL}/og-image.png"

# Parse SEO data from each page component
def extract_seo(filepath):
    with open(filepath) as f:
        content = f.read()
    
    seo = {}
    
    # Find useSEO call
    m = re.search(r'useSEO\(\{(.*?)\}\)', content, re.S)
    if not m:
        return None
    block = m.group(1)
    
    # Title
    t = re.search(r'title:\s*["\']([^"\']+)', block)
    if t: seo['title'] = t.group(1)
    
    # Description - handle multiline template literals and concatenation
    d = re.search(r'description:\s*["\']([^"\']+)', block)
    if not d:
        d = re.search(r'description:\s*`([^`]+)', block)
    if d: seo['description'] = d.group(1).strip()
    
    # Canonical
    c = re.search(r'canonical:\s*["\']([^"\']+)', block)
    if c: seo['canonical'] = c.group(1)
    
    # JSON-LD - extract the full object
    jsonld_match = re.search(r'(?:const\s+\w+JsonLd|const\s+jsonLd)\s*=\s*(\[[\s\S]*?\]);', content)
    if not jsonld_match:
        jsonld_match = re.search(r'(?:const\s+\w+JsonLd|const\s+jsonLd)\s*=\s*(\{[\s\S]*?\});', content)
    if jsonld_match:
        try:
            # Clean JS object to JSON (add quotes to keys)
            js_obj = jsonld_match.group(1)
            # Replace JS-style keys with JSON keys
            js_obj = re.sub(r'(\s)(\w+)(\s*:)', r'\1"\2"\3', js_obj)
            # Replace single quotes with double
            js_obj = js_obj.replace("'", '"')
            # Remove trailing commas
            js_obj = re.sub(r',\s*([}\]])', r'\1', js_obj)
            seo['jsonld_raw'] = jsonld_match.group(1)[:500]  # Keep raw for reference
        except:
            pass
    
    return seo

# Extract key content text from component for SSR fallback
def extract_headings(filepath):
    with open(filepath) as f:
        content = f.read()
    
    headings = []
    # Find h1, h2 text in JSX
    for match in re.finditer(r'<h[12][^>]*>(.*?)</h[12]>', content, re.S):
        text = re.sub(r'<[^>]+>', '', match.group(1))
        text = re.sub(r'\{[^}]+\}', '', text)  # Remove JSX expressions
        text = text.strip()
        if text and len(text) > 3:
            headings.append(text)
    
    # Also get paragraph text
    paragraphs = []
    for match in re.finditer(r'<p[^>]*>(.*?)</p>', content, re.S):
        text = re.sub(r'<[^>]+>', '', match.group(1))
        text = re.sub(r'\{[^}]+\}', '', text)
        text = text.strip()
        if text and len(text) > 30:
            paragraphs.append(text)
    
    return headings, paragraphs[:3]

# Map of route -> page file
PAGES = {
    '/': 'client/src/pages/Home.tsx',
    '/energielabel': 'client/src/pages/Energielabel.tsx',
    '/energielabels': 'client/src/pages/Energielabels.tsx',
    '/energielabel-aanvragen-amsterdam/': 'client/src/pages/EnergielabelAmsterdam.tsx',
    '/fotografie': 'client/src/pages/Fotografie.tsx',
    '/wws-puntentelling/': 'client/src/pages/WwsPuntentelling.tsx',
    '/nen-2580-metingen/': 'client/src/pages/Nen2580Metingen.tsx',
}

# Read the original index.html template
with open('client/index.html') as f:
    template = f.read()

print("🔧 Prerendering SEO data into HTML...\n")

for route, pagefile in PAGES.items():
    seo = extract_seo(pagefile)
    if not seo:
        print(f"  ⚠️ {route}: No SEO data found")
        continue
    
    headings, paragraphs = extract_headings(pagefile)
    
    full_title = f"{seo.get('title', SITE_NAME)} | {SITE_NAME}"
    description = seo.get('description', '')
    canonical = f"{SITE_URL}{seo.get('canonical', route)}"
    
    # Build the enhanced <head>
    head_inject = f'''
    <!-- SSR SEO Meta — {route} -->
    <title>{full_title}</title>
    <meta name="description" content="{description}" />
    <meta name="robots" content="index,follow" />
    <link rel="canonical" href="{canonical}" />
    
    <!-- Open Graph -->
    <meta property="og:site_name" content="{SITE_NAME}" />
    <meta property="og:type" content="website" />
    <meta property="og:title" content="{full_title}" />
    <meta property="og:description" content="{description}" />
    <meta property="og:url" content="{canonical}" />
    <meta property="og:image" content="{DEFAULT_OG_IMAGE}" />
    <meta property="og:locale" content="nl_NL" />
    
    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="{full_title}" />
    <meta name="twitter:description" content="{description}" />
    <meta name="twitter:image" content="{DEFAULT_OG_IMAGE}" />
    
    <!-- Geo -->
    <meta name="geo.region" content="NL-NH" />
    <meta name="geo.placename" content="Amsterdam" />
    
    <!-- Hreflang -->
    <link rel="alternate" hreflang="nl" href="{canonical}" />
    <link rel="alternate" hreflang="x-default" href="{canonical}" />'''
    
    # Build noscript/SSR content for crawlers
    noscript_content = '<div id="ssr-content" style="display:none" aria-hidden="true">'
    if headings:
        noscript_content += f'\n      <h1>{headings[0]}</h1>'
        for h in headings[1:5]:
            noscript_content += f'\n      <h2>{h}</h2>'
    if paragraphs:
        for p in paragraphs:
            noscript_content += f'\n      <p>{p}</p>'
    
    # Add internal links for crawlers
    noscript_content += '''
      <nav>
        <a href="/energielabel">Energielabel</a>
        <a href="/energielabels">Energielabels</a>
        <a href="/fotografie">Vastgoedfotografie</a>
        <a href="/wws-puntentelling/">WWS Puntentelling</a>
        <a href="/nen-2580-metingen/">NEN 2580 Metingen</a>
        <a href="/energielabel-aanvragen-amsterdam/">Energielabel Aanvragen Amsterdam</a>
      </nav>'''
    noscript_content += '\n    </div>'
    
    # Modify the template
    new_html = template
    
    # Replace the existing head content
    # Remove old meta tags that we're replacing
    new_html = re.sub(r'<!-- Primary meta.*?-->', '', new_html, flags=re.S)
    new_html = re.sub(r'<title>[^<]+</title>', '', new_html)
    new_html = re.sub(r'<meta\s+name="description"[^>]+>', '', new_html)
    new_html = re.sub(r'<meta\s+name="robots"[^>]+>', '', new_html)
    new_html = re.sub(r'<!-- Geo -->.*?<meta name="geo.placename"[^>]+>', '', new_html, flags=re.S)
    new_html = re.sub(r'<!-- Canonical.*?-->\s*<link rel="canonical"[^>]+>', '', new_html, flags=re.S)
    new_html = re.sub(r'<!-- Open Graph.*?<meta property="og:locale"[^>]+>', '', new_html, flags=re.S)
    new_html = re.sub(r'<!-- Twitter Card.*?<meta name="twitter:image"[^>]+>', '', new_html, flags=re.S)
    
    # Inject new head content after <meta charset>
    new_html = new_html.replace(
        '<meta name="viewport"',
        f'{head_inject}\n    <meta name="viewport"'
    )
    
    # Inject SSR content before the root div
    new_html = new_html.replace(
        '<div id="root"></div>',
        f'{noscript_content}\n    <div id="root"></div>'
    )
    
    # Write to output directory
    if route == '/':
        outpath = 'client/index.html'
    else:
        outdir = f'client/public{route.rstrip("/")}'
        os.makedirs(outdir, exist_ok=True)
        outpath = f'{outdir}/index.html'
    
    # For the main index.html, we write the homepage version
    if route == '/':
        with open(outpath, 'w') as f:
            f.write(new_html)
    else:
        with open(outpath, 'w') as f:
            f.write(new_html)
    
    print(f"  ✅ {route} → {outpath}")
    print(f"     Title: {full_title}")
    print(f"     H1: {headings[0] if headings else 'N/A'}")

print(f"\n✅ Prerendering complete!")
