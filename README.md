# mark-site

Mark Matheson's personal resume site. Plain HTML/CSS, no build step.

- `site/` — what gets published (Cloudflare Pages build output directory)
- `resume/resume.html` — source for the downloadable PDF

## Regenerate the resume PDF

```bash
"/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" --headless=new --disable-gpu \
  --no-pdf-header-footer --print-to-pdf="C:/Users/palme/Projects/mark-site/site/Mark_Matheson_Resume.pdf" \
  "file:///C:/Users/palme/Projects/mark-site/resume/resume.html"
```

## Photos

Source photos live in `Desktop\site-photos`. Anything added to `site/img/` must be
re-saved first (resize + strip EXIF/GPS) — phone photos carry location data.

## Deploy

Cloudflare Pages, connected to this GitHub repo. Framework preset: None.
Build command: empty. Build output directory: `site`. Every push to `main` redeploys.

## Regenerate the Word resume

`resume/resume-docx.js` builds the .docx with the `docx` npm package (keep its
text in sync with `resume.html` by hand):

```bash
cd resume && npm install docx && node resume-docx.js "C:/Users/palme/Desktop/Mark_Matheson_resume_Amazon_PrimeAir.docx"
```
