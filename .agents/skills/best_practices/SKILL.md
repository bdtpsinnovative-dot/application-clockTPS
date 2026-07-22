---
name: best-practices
description: Apply modern web development best practices for security, compatibility, and code quality. Use when asked to "apply best practices", "security audit", "modernize code", "code quality review", or "check for vulnerabilities".
---

# Best Practices - Web Security, Compatibility, and Quality

This skill defines the modern web development standards and best practices based on security, browser compatibility, performance, and code quality.

---

## When to Use
Use this skill when:
* Auditing web applications, websites, or Go backend APIs
* Designing security headers, CORS, or Content Security Policies (CSP)
* Reviewing HTML/CSS/JS code quality, compatibility, or performance audits

---

## 1. Web Security

### HTTPS & Security Headers
* Ensure all links, resources (images, scripts) load over HTTPS.
* Configure key security headers:
  * `Strict-Transport-Security` (HSTS)
  * `X-Frame-Options: DENY` (Prevent Clickjacking)
  * `X-Content-Type-Options: nosniff` (Prevent MIME sniffing)
  * `Referrer-Policy: strict-origin-when-cross-origin`

### Content Security Policy (CSP)
Configure robust CSP meta tags or HTTP headers to prevent XSS:
```html
<meta http-equiv="Content-Security-Policy" 
      content="default-src 'self'; script-src 'self' https://trusted-cdn.com; style-src 'self' 'unsafe-inline';">
```

### Dependency Audit
Keep npm packages and server dependencies secure:
* Use `npm audit` or `yarn audit` to identify vulnerabilities.
* Prevent prototype pollution and XSS.

---

## 2. Browser Compatibility & Doctype
* Declare HTML5 Doctype: `<!DOCTYPE html>`
* Declare UTF-8 Charset as the first child of the `<head>`.
* Set responsive viewport: `<meta name="viewport" content="width=device-width, initial-scale=1">`

---

## 3. Code Quality & Performance
* Avoid deprecated APIs (like `document.write` or synchronous XHR).
* Add `passive: true` listeners for scroll and touch events to ensure smooth rendering:
```javascript
window.addEventListener('wheel', handler, { passive: true });
```
* Use semantic HTML elements (`<header>`, `<nav>`, `<main>`, `<article>`, `<footer>`).
