// Renders the legal documents as static pages for the site.
//
//   dart run tool/gen_legal.dart
//
// Run by `tool/build_site.sh` before every deploy, so the pages cannot drift
// from the app.
//
// WHY STATIC. The footer used to link to `/app/#/legal/privacy`, which is the
// documents inside the Flutter app: a two-megabyte download, a splash screen,
// and a router, to read a page of text. A store review, a regulator, or
// somebody deciding whether to trust us with a plate number should not have to
// launch an application to read the privacy policy — and a crawler will not.
//
// WHY GENERATED. The obvious alternative is to write the HTML by hand, and it
// is the wrong one: two copies of a legal document drift, and the copy that
// drifts is always the one nobody opens. These pages import the same
// `LegalDocs` the app renders, so there is exactly one source of truth. That
// is also why `legal_docs.dart` carries no Material icon any more — a document
// that imports Flutter cannot be read by a plain Dart script.
import 'dart:io';

import 'package:bonnetcheck/core/constants/legal_docs.dart';
import 'package:bonnetcheck/core/constants/legal_info.dart';

const _outDir = 'landing/legal';

void main() {
  if (!LegalInfo.isPublished) {
    // The same rule the app follows: no operator name or contact address means
    // the documents are not published at all. Writing them anyway would put an
    // unsigned policy on a public URL.
    stderr.writeln('LegalInfo is incomplete — nothing generated.');
    exit(1);
  }

  final dir = Directory(_outDir);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);

  // One directory per document, each holding an index.html, so that
  // `/legal/privacy` resolves with no hosting configuration at all. The
  // alternative — `privacy.html` plus `cleanUrls` — changes how every other
  // URL on the site is served, to save five directories.
  for (final doc in LegalDocs.all) {
    Directory('$_outDir/${doc.id}').createSync(recursive: true);
    File('$_outDir/${doc.id}/index.html').writeAsStringSync(_page(doc));
    stdout.writeln('    /legal/${doc.id}  ${doc.title}');
  }
  File('$_outDir/index.html').writeAsStringSync(_index());
  stdout.writeln('    /legal/');
}

/// One document.
String _page(LegalDoc doc) {
  final body = StringBuffer();
  for (final section in doc.sections) {
    body.writeln('<section>');
    body.writeln('<h2>${_esc(section.heading)}</h2>');
    // A run of consecutive bullets becomes one list, so that six bullets read
    // as six items rather than six paragraphs that happen to start with a dot.
    var inList = false;
    for (final paragraph in section.paragraphs) {
      final bullet = paragraph.startsWith('• ');
      if (bullet && !inList) {
        body.writeln('<ul>');
        inList = true;
      } else if (!bullet && inList) {
        body.writeln('</ul>');
        inList = false;
      }
      final text = _esc(bullet ? paragraph.substring(2) : paragraph);
      body.writeln(bullet ? '<li>$text</li>' : '<p>$text</p>');
    }
    if (inList) body.writeln('</ul>');
    body.writeln('</section>');
  }

  return _shell(
    title: '${doc.title} — BonnetCheck',
    description: doc.summary,
    canonical: 'https://bonnetcheck.web.app/legal/${doc.id}/',
    heading: doc.title,
    lead: doc.summary,
    body: body.toString(),
  );
}

/// The list of documents, which is also what `/legal/` serves.
String _index() {
  final body = StringBuffer('<ul class="docs">');
  for (final doc in LegalDocs.all) {
    body.writeln(
      '<li><a href="/legal/${doc.id}/"><strong>${_esc(doc.title)}</strong>'
      '<span>${_esc(doc.summary)}</span></a></li>',
    );
  }
  body.writeln('</ul>');

  return _shell(
    title: 'מידע משפטי — BonnetCheck',
    description: 'תנאי שימוש, מדיניות פרטיות, עוגיות, הסרת תוכן ותלונות.',
    canonical: 'https://bonnetcheck.web.app/legal/',
    heading: 'מידע משפטי',
    lead: 'מופעל על ידי ${LegalInfo.operatorLine}',
    body: body.toString(),
  );
}

/// The page around the text. Deliberately one file with no external requests:
/// a policy that cannot render without a font server is a policy that
/// sometimes does not render.
String _shell({
  required String title,
  required String description,
  required String canonical,
  required String heading,
  required String lead,
  required String body,
}) {
  return '''<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_esc(title)}</title>
<meta name="description" content="${_esc(description)}">
<link rel="canonical" href="$canonical">
<meta name="theme-color" content="#558B6E">
<link rel="icon" href="/app/favicon.png">
<style>
:root{
  --ink:#1B1F1D; --muted:#5C6661; --line:#E2E7E4; --bg:#FFFFFF;
  --brand:#1E6B45; --surface:#F6F8F7;
}
@media (prefers-color-scheme: dark){
  :root{ --ink:#ECEFED; --muted:#A3ADA8; --line:#2A302D; --bg:#141816;
         --brand:#6FA98A; --surface:#1B201E; }
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font:400 17px/1.75 "Segoe UI",Arial,system-ui,sans-serif;}
.wrap{max-width:44rem;margin:0 auto;padding:2rem 1.25rem 4rem}
a{color:var(--brand)}
header.top{border-bottom:1px solid var(--line);margin-bottom:2rem;padding-bottom:1.25rem}
.back{display:inline-block;margin-bottom:1.5rem;font-size:.95rem;text-decoration:none}
.back:hover{text-decoration:underline}
h1{font-size:1.9rem;line-height:1.25;margin:0 0 .4rem}
h2{font-size:1.15rem;margin:2.2rem 0 .6rem}
p,li{margin:0 0 .85rem}
ul{padding-inline-start:1.2rem}
.lead{color:var(--muted);margin:0}
.updated{color:var(--muted);font-size:.9rem;margin-top:.9rem}
.docs{list-style:none;padding:0}
.docs li{margin-bottom:.75rem}
.docs a{display:block;padding:1rem 1.1rem;border:1px solid var(--line);
  border-radius:14px;background:var(--surface);text-decoration:none;color:var(--ink)}
.docs a:hover{border-color:var(--brand)}
.docs span{display:block;color:var(--muted);font-size:.95rem;margin-top:.2rem}
footer{border-top:1px solid var(--line);margin-top:3rem;padding-top:1.25rem;
  color:var(--muted);font-size:.9rem}
</style>
</head>
<body>
<div class="wrap">
<a class="back" href="/">→ חזרה ל‑BonnetCheck</a>
<header class="top">
<h1>${_esc(heading)}</h1>
<p class="lead">${_esc(lead)}</p>
<p class="updated">עודכן לאחרונה: ${_esc(LegalInfo.lastUpdated)}</p>
</header>
$body
<footer>
<p>שאלות ופניות: <a href="mailto:${LegalInfo.contactEmail}">${LegalInfo.contactEmail}</a></p>
<p><a href="/legal/">כל המסמכים</a> · <a href="/">דף הבית</a> · <a href="/app/">האפליקציה</a></p>
</footer>
</div>
</body>
</html>
''';
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
