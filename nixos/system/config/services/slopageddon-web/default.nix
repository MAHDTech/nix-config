# cspell:ignore labelledby nosniff
{ lib, pkgs }:
let
  fleet = import ../../../../hosts/fleet.nix;

  cspHeader = "default-src 'none'; style-src 'self'; script-src 'self'; connect-src 'self'; img-src 'self' data:; base-uri 'none'; frame-ancestors 'none'";

  assets = pkgs.linkFarm "slopageddon-web-assets" [
    {
      name = "landing.css";
      path = ./theme.css;
    }
    {
      name = "browser.css";
      path = ./browser.css;
    }
    {
      name = "common.js";
      path = ./common.js;
    }
    {
      name = "favicon.svg";
      path = ./favicon.svg;
    }
  ];

  navItems = [
    {
      id = "nix-cache";
      label = "Nix Cache";
      href = fleet.web.nixCache;
    }
    {
      id = "mirror";
      label = "Mirror";
      href = fleet.web.mirror;
    }
    {
      id = "hub";
      label = "Hub";
      href = fleet.web.hub;
    }
    {
      id = "s3";
      label = "S3 Console";
      href = fleet.web.s3Console;
    }
  ];

  renderNav = activeNav: ''
    <nav class="fleet-nav" aria-label="Fleet services">
      ${lib.concatMapStringsSep "\n        " (
        item:
        let
          current = if item.id == activeNav then " aria-current=\"page\"" else "";
        in
        ''<a href="${lib.escapeXML item.href}"${current}>${lib.escapeXML item.label}</a>''
      ) navItems}
    </nav>
  '';

  renderHubCard = hubUrl: ''
    <a class="panel hub-card" href="${lib.escapeXML hubUrl}">
      <div>
        <h2 class="panel-title">OBSERVABILITY</h2>
        <h3>Open the hub <span aria-hidden="true">↗</span></h3>
        <p>Host metrics, service status and fleet history in Beszel.</p>
      </div>
      <span class="button-label">VIEW FLEET <span aria-hidden="true">→</span></span>
    </a>
  '';

  renderSystemSummary =
    {
      hostname,
      version,
      system,
    }:
    ''
      <section class="panel" aria-labelledby="summary-title">
        <h2 class="panel-title" id="summary-title">SYSTEM SUMMARY</h2>
        <dl>
          <div>
            <dt>HOST</dt>
            <dd>${lib.escapeXML hostname}</dd>
          </div>
          <div>
            <dt>CONFIGURATION</dt>
            <dd>NixOS ${lib.escapeXML version}</dd>
          </div>
          <div>
            <dt>ARCHITECTURE</dt>
            <dd>${lib.escapeXML system}</dd>
          </div>
        </dl>
        <p class="muted">Declared configuration. Live status is available in the hub.</p>
      </section>
    '';

  mkPage =
    {
      title,
      activeNav,
      brandIsLink ? false,
      headerLinkHref,
      headerLinkLabel,
      headerLinkBack ? false,
      includeBrowserCss ? false,
      includeCommonJs ? true,
      extraScripts ? [ ],
      heroHtml,
      compactHero ? false,
      hubUrl ? null,
      bodyHtml,
      systemSummary ? null,
    }:
    let
      brand =
        if brandIsLink then
          ''<a class="brand" href="/">SLOPAGEDDON<span class="brand-mark" aria-hidden="true">_</span></a>''
        else
          ''<span class="brand">SLOPAGEDDON<span class="brand-mark" aria-hidden="true">_</span></span>'';
      headerLink =
        if headerLinkBack then
          ''<a class="header-link" href="${lib.escapeXML headerLinkHref}"><span aria-hidden="true">←</span> ${lib.escapeXML headerLinkLabel}</a>''
        else
          ''<a class="header-link" href="${lib.escapeXML headerLinkHref}">${lib.escapeXML headerLinkLabel} <span aria-hidden="true">→</span></a>'';
      heroClass = if compactHero then "hero hero--compact" else "hero";
      scripts = (lib.optional includeCommonJs "/_common.js") ++ extraScripts;
    in
    ''
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta name="color-scheme" content="dark" />
          <title>${title}</title>
          <link rel="icon" type="image/svg+xml" href="/_favicon.svg" />
          <link rel="stylesheet" href="/_landing.css" />
          ${lib.optionalString includeBrowserCss ''<link rel="stylesheet" href="/_browse.css" />''}
          ${lib.concatMapStringsSep "\n          " (
            src: ''<script src="${lib.escapeXML src}" defer></script>''
          ) scripts}
        </head>
        <body>
          <main>
            <header class="masthead">
              ${brand}
              ${renderNav activeNav}
              ${headerLink}
            </header>
            <section class="${heroClass}" aria-labelledby="title">
              ${heroHtml}
            </section>
            ${lib.optionalString (hubUrl != null) (renderHubCard hubUrl)}
            ${bodyHtml}
            ${lib.optionalString (systemSummary != null) (renderSystemSummary systemSummary)}
          </main>
        </body>
      </html>
    '';
in
{
  inherit
    assets
    cspHeader
    mkPage
    ;
}
