# Architecture

A redirect endpoint is a `bioconductor.org` hostname kept so that published
links keep working after the service behind them moved. It stores no data and
runs no application code: every request gets either a static page or an HTTP
redirect.

## Endpoints

| Hostname | Kind | Sends visitors to |
|---|---|---|
| `slack.bioconductor.org` | Transition page | The Zulip invitation link, after a 10-second countdown |
| `zulip.bioconductor.org` | HTTP 302 | The Zulip invitation link |
| `chat.bioconductor.org` | HTTP 302 | The Zulip invitation link |

The Zulip invitation link is a reusable invitation to the
`community-bioc.zulipchat.com` organization. It is the `redirectUrl` in the
page's script and the redirect target in the other configurations.

## The Slack transition page

```text
browser ── GET https://slack.bioconductor.org/ ──▶ index.html (200)
   │
   ├─ iframe ──▶ https://blog.bioconductor.org/posts/2025-05-29-slack-to-zulip/
   │
   └─ after 10 s, in JavaScript: window.location.href = <invitation link>
```

- [`sites/slack.bioconductor.org/public/index.html`](../sites/slack.bioconductor.org/public/index.html)
  is the whole site: one file with inline CSS and JavaScript. On Apache, `/`
  and `/index.html` return it; on Cloudflare, `/index.html` redirects to `/`.
  Every other path returns 404.
- The countdown and the redirect run in the browser. Without JavaScript the
  visitor stays on the page.
- The page frames the blog post announcing the move. `blog.bioconductor.org`
  is served by GitHub Pages and sends neither `X-Frame-Options` nor a
  `frame-ancestors` policy, so browsers allow the frame.
- The manual "click here" link points to `https://community-bioc.zulipchat.com/`,
  which redirects to the organization's login page, not to the invitation link.

## HTTP redirects

`zulip.bioconductor.org` and `chat.bioconductor.org` answer every path with a
302 whose `Location` is the invitation link, keeping the request's query
string. Unlike a 301, a 302 sent without caching headers is not cached by
browsers, so a new invitation link reaches returning visitors as soon as it is
deployed.

## Where the endpoints are served

The `bioconductor.org` zone is hosted on Cloudflare DNS. The three hostnames
are `A` records with proxy status DNS only, resolving to the same address as
`git.bioconductor.org`. Apache httpd on that host answers for all of them over
HTTPS with a wildcard certificate for `*.bioconductor.org` and
`bioconductor.org`.

[`apache/`](../apache) holds one file per hostname, with the `*:443` virtual
host that serves the page or the redirect. The files reproduce the endpoints'
HTTPS behaviour, not the production host's files: on the host,
`sudo apachectl -S` lists the file that defines each virtual host. They do not
configure plain HTTP; see [Known limitations](#known-limitations).

### Static hosting on Cloudflare

The repository also holds a configuration that serves the endpoints from
Cloudflare with no origin server:

| Endpoint | Cloudflare feature | Configuration |
|---|---|---|
| `slack.bioconductor.org` | Workers static assets with a Custom Domain | [`sites/slack.bioconductor.org/wrangler.jsonc`](../sites/slack.bioconductor.org/wrangler.jsonc), [`public/_headers`](../sites/slack.bioconductor.org/public/_headers) |
| `zulip.bioconductor.org`, `chat.bioconductor.org` | Single Redirect rule on proxied, originless DNS records | [`cloudflare/zulip-redirect-rule.json`](../cloudflare/zulip-redirect-rule.json) |

The Worker has no script. Cloudflare serves the files in `public/` and applies
the response headers listed in `_headers`; the `_headers` file itself is not
served. Cloudflare creates the DNS record and the certificate for the Custom
Domain. The same `public/` directory deploys unchanged to Cloudflare Pages,
which reads `_headers` the same way.

[deployment.md](deployment.md) covers both options and
[updating.md](updating.md#moving-to-static-hosting) the move between them.

## State and dependencies

Nothing on the endpoints changes at runtime, and everything they serve is in
this repository. The rest of their configuration lives elsewhere:

| Item | Where it lives |
|---|---|
| TLS certificate and private key for Apache | The Apache host |
| DNS records, the Worker and the redirect rule | The Cloudflare account that holds `bioconductor.org` |
| The invitation link's expiry and the channels new members join | Zulip organization settings for `community-bioc` |

External services the endpoints depend on:

- Zulip Cloud, for the invitation link. For an invalid link, Zulip shows an
  error page instead of the sign-up form; a link that does not exist answers
  404.
- `blog.bioconductor.org`, for the framed post.
- Cloudflare DNS, for every hostname.

The invitation link appears in four files: the page, the two Apache redirect
files and the Cloudflare rule. [updating.md](updating.md#rotating-the-zulip-invitation-link)
lists the steps to replace it.

## Repository layout

| Path | Contents |
|---|---|
| `sites/slack.bioconductor.org/public/index.html` | The transition page |
| `sites/slack.bioconductor.org/public/_headers` | Response headers for Cloudflare static hosting |
| `sites/slack.bioconductor.org/wrangler.jsonc` | Cloudflare Worker and Custom Domain for the page |
| `apache/*.conf` | The Apache HTTPS virtual host for each hostname |
| `cloudflare/zulip-redirect-rule.json` | Cloudflare Single Redirect rule for `zulip` and `chat` |
| `scripts/check-endpoints.sh` | Live checks of every endpoint |
| `scripts/csp-hashes.py` | Content-Security-Policy hashes of the page's inline script and style |

## Known limitations

- On the production Apache host, plain HTTP for `slack`, `zulip` and `chat`
  is answered by the `*:80` virtual host of `git.bioconductor.org`:
  `http://<host>/<path>` redirects to `https://git.bioconductor.org/<path>`.
  Visitors who type a hostname without `https://` reach the Git server, and
  the three plain HTTP checks in `scripts/check-endpoints.sh` fail.
  [examples/apache-http-redirect.conf](examples/apache-http-redirect.conf)
  adds a `*:80` virtual host for each hostname;
  [moving to static hosting](updating.md#moving-to-static-hosting) takes the
  hostnames off the host.
- The Apache host runs a release past standard support; see
  [security.md](security.md#known-limitations).
- The manual link on the transition page opens the Zulip login page, which
  tells visitors without an account that they need an invitation. Only the
  automatic redirect uses the invitation link.
- The page has no `viewport` meta tag, so phones render it at desktop width.
