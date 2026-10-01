# Security

## Trust boundaries

- The endpoints serve public, static responses. They have no forms, cookies,
  sign-in or user input, and nothing they serve is secret.
- They send visitors to third parties: the `community-bioc` organization on
  Zulip Cloud, and `blog.bioconductor.org` on GitHub Pages, which the
  transition page frames.
- Whoever can change a target, the DNS records, the Apache files or the
  Cloudflare configuration decides where every visitor lands. Make target
  changes through pull requests to this repository.

## Secrets and where they live

The repository holds no secrets.

| Secret | Where it lives | What it allows |
|---|---|---|
| Private key of the `*.bioconductor.org` certificate | The Apache host; with the files in `apache/`, `/etc/ssl/bioconductor.org/privkey.pem`, mode `0600`, owned by root | Impersonating every hostname the certificate covers |
| Cloudflare login or API token | The maintainer's machine, or the secret store of the system that deploys | Changing DNS, Workers and redirect rules for the zone |

Scope Cloudflare API tokens to the `bioconductor.org` zone and to the
permissions a task needs, such as **Zone > Single Redirect > Edit** for the
redirect rule.

## The invitation link

The Zulip invitation link is public: it is in this repository and in every
redirect. Anyone with it can create an account in the organization with the
role and channels chosen when the link was created.

- Create links with the **Member** role.
- Choose an expiry, and rotate the link before it as in
  [updating.md](updating.md#rotating-the-zulip-invitation-link).
- If unwanted accounts appear, rotate the link and revoke the old one.

## Hardening

### Cloudflare

[`sites/slack.bioconductor.org/public/_headers`](../sites/slack.bioconductor.org/public/_headers)
sets these headers on the transition page:

| Header | Effect |
|---|---|
| `Content-Security-Policy` | `default-src 'none'` blocks every resource not listed. Only the page's inline script and style run, matched by SHA-256 hash. Only `https://blog.bioconductor.org` can be framed. No other site can frame the page, and the page cannot set a `<base>` URL or submit a form. |
| `Strict-Transport-Security: max-age=31536000` | After one visit, browsers use HTTPS for `slack.bioconductor.org` for a year. Other hostnames are not affected. |
| `X-Content-Type-Options: nosniff` | Browsers use the declared content type only. |
| `Referrer-Policy: strict-origin-when-cross-origin` | The blog and Zulip receive the page's origin, not its full URL. |

Any edit to the inline script or style needs new hashes; see
[operations.md](operations.md#changing-a-target).

### Apache

The templates in `apache/` set no response headers and leave TLS settings to
the server-wide configuration. With the Debian and Ubuntu default
`ServerTokens OS`, every response's `Server` header names the Apache version
and the operating system.

Recommended changes, applied as in
[updating.md](updating.md#hardening):

- Server-wide, in
  [examples/apache-hardening.conf](examples/apache-hardening.conf). These also
  apply to `git.bioconductor.org` on the same host.
  - `ServerTokens Prod` and `ServerSignature Off`, so responses do not reveal
    the Apache and OS versions.
  - `TraceEnable Off`.
  - TLS 1.2 and 1.3 only. TLS 1.3 needs Apache 2.4.36 or later with OpenSSL
    1.1.1 or later.
- Inside each `*:443` virtual host for the endpoints, in
  [examples/apache-headers.conf](examples/apache-headers.conf), with
  `mod_headers` enabled: `Strict-Transport-Security`,
  `X-Content-Type-Options`, `Referrer-Policy`, and a
  `Content-Security-Policy` that blocks framing of the endpoints. It does not
  restrict scripts, so page edits need no Apache change.

## Known limitations

- The production Apache host reports `Apache/2.4.18 (Ubuntu)`, the Apache
  package of Ubuntu 16.04, whose standard support ended in April 2021.
  Without an extended-support subscription it receives no security fixes.
  Moving the endpoints to static hosting, or to a host on a current Ubuntu LTS
  release, removes the dependency; see
  [updating.md](updating.md#host-os-and-web-server).
- That host accepts TLS 1.0, 1.1 and 1.2 but not TLS 1.3, and sends none of
  the response headers above. On its Apache version,
  `SSLProtocol -all +TLSv1.2` removes TLS 1.0 and 1.1.

## Reporting a vulnerability

Do not open a public issue. Email the Bioconductor core team at
[bioconductorcoreteam@gmail.com](mailto:bioconductorcoreteam@gmail.com), the
contact published on [bioconductor.org/about](https://bioconductor.org/about/).
