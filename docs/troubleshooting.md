# Troubleshooting

Start with `scripts/check-endpoints.sh`; each `FAIL` line names the URL and
what it returned.

## Plain HTTP lands on another bioconductor.org site

`http://<host>/` redirects to a different hostname instead of
`https://<host>/`. On the production Apache host, all three hostnames redirect
to `https://git.bioconductor.org/`; see
[Known limitations](architecture.md#known-limitations).

**Cause.** On Apache, no `*:80` virtual host has `<host>` as its `ServerName`
or `ServerAlias`. Apache then answers with the first `*:80` virtual host for
that address, which redirects to its own site.

**Fix.** Install and enable
[examples/apache-http-redirect.conf](examples/apache-http-redirect.conf) as in
step 4 of [deployment.md](deployment.md#steps). `sudo apachectl -S` lists the
default server and every `namevhost` per port; the hostname must appear under
port 80. Reload Apache and check:

```sh
curl -sI http://<host>/ | grep -iE '^(HTTP|location)'
```

On Cloudflare, with the zone's **Always Use HTTPS** setting off, plain HTTP
serves the endpoint without redirecting to HTTPS. The setting applies to every
proxied hostname in the zone, so check the zone's other proxied hostnames
before turning it on. To redirect one hostname only, create a Single Redirect
rule, placed before any other redirect rule that matches the hostname:

- Expression: `http.request.scheme eq "http" and http.host eq "<host>"`
- Dynamic target URL: `concat("https://", http.host, http.request.uri.path)`
- Status code `301`, **Preserve query string** on

## HTTPS serves another site, or a certificate for another name

**Cause.** No `*:443` virtual host matches the hostname, so the default
`*:443` virtual host answers with its own content and certificate.

**Fix.** Install and enable the hostname's file from `apache/` as in step 4
of [deployment.md](deployment.md#steps); the hostname must appear under port
443 in `sudo apachectl -S`. Check the certificate the host sends for the name:

```sh
openssl s_client -connect <host>:443 -servername <host> </dev/null 2>/dev/null |
  openssl x509 -noout -subject -ext subjectAltName -enddate
```

## Certificate expired or about to expire

**Cause.** The certificate on the Apache host was not replaced in time.

**Fix.** Replace it as in [updating.md](updating.md#certificates). A
`*.bioconductor.org` certificate covers one label only: `a.bioconductor.org`,
not `a.b.bioconductor.org`.

## The countdown does not start

The page shows "Redirecting in 10 seconds..." and nothing happens. The
browser console reports a Content-Security-Policy violation.

**Cause.** On Cloudflare, `_headers` allows only the inline script whose hash
it lists. The served script differs from that hash: the page changed without
updating `_headers`, or a zone feature rewrote the HTML.

**Fix.** Compare the hashes and the served page with the repository:

```sh
scripts/csp-hashes.py --check sites/slack.bioconductor.org/public/_headers \
  sites/slack.bioconductor.org/public/index.html
curl -s https://slack.bioconductor.org/ | cmp - sites/slack.bioconductor.org/public/index.html
```

If the first command fails, update the hashes as in
[operations.md](operations.md#changing-a-target) and redeploy. If only the
second fails, find the zone setting that modifies HTML responses, such as
Rocket Loader, and turn it off for the hostname.

## The blog preview is empty or shows an error

**Cause.** One of:

- The blog post moved and its URL returns 404.
- `blog.bioconductor.org` started sending `X-Frame-Options` or a CSP
  `frame-ancestors` directive that forbids framing.
- On Cloudflare, the page's `frame-src` does not list the blog's origin.

**Fix.** Check the post and its framing headers:

```sh
curl -sI https://blog.bioconductor.org/posts/2025-05-29-slack-to-zulip/ |
  grep -iE '^(HTTP|x-frame-options|content-security-policy)'
```

Update the iframe `src`, the link to the post, and `frame-src` in `_headers`
to the post's current URL, or remove the iframe.

## Zulip shows an error instead of the sign-up form

**Cause.** The invitation link expired or was revoked.

**Fix.** Rotate it as in
[updating.md](updating.md#rotating-the-zulip-invitation-link).

## Wrangler reports that the hostname already has DNS records

**Cause.** The hostname has a DNS record that Cloudflare did not create for
the Worker.

**Fix.** Note the record, delete it, and repeat the deploy, as in
[deployment.md](deployment.md#slack-page).

## The redirect rule has no effect

`zulip` or `chat` still answer from the Apache host, or do not answer.

**Cause.** Redirect rules act only on proxied hostnames. The DNS record is
**DNS only**, or points at an address that does not answer.

**Fix.** `dig +short <host>` returns Cloudflare addresses when the record is
proxied. Set the record to an `AAAA` record with content `100::` and proxy
status **Proxied**.

## The status page shows slack.bioconductor.org as up while the page is broken

**Cause.** The status page requests `http://slack.bioconductor.org` and
follows redirects, so it reports whatever the plain HTTP redirect leads to: on
the production Apache host, `git.bioconductor.org`.

**Fix.** Run `scripts/check-endpoints.sh`, which checks the HTTPS page itself,
and fix the HTTP redirect as in the first section.
