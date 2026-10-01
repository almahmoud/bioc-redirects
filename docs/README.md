# Redirect endpoints documentation

Maintainer documentation for the `bioconductor.org` hostnames that send
visitors elsewhere.

## Quick facts

| | |
|---|---|
| Hostnames | `slack.bioconductor.org`, `zulip.bioconductor.org`, `chat.bioconductor.org` |
| Targets | The `community-bioc` Zulip invitation link; the transition page also frames a `blog.bioconductor.org` post |
| Served by | Apache httpd, on the host that serves `git.bioconductor.org` |
| DNS | The `bioconductor.org` zone on Cloudflare; the records are DNS only |
| TLS | A `*.bioconductor.org` wildcard certificate installed on the Apache host |
| Static hosting | Prepared in this repository, not deployed: Cloudflare Workers static assets for the page and a Single Redirect rule for `zulip` and `chat` |
| Checks | `scripts/check-endpoints.sh` |

## Pages

| Document | Answers |
|---|---|
| [architecture.md](architecture.md) | How each endpoint works, where it is served, and what it depends on |
| [deployment.md](deployment.md) | Serving the endpoints from Apache or from Cloudflare, step by step |
| [operations.md](operations.md) | Checking the endpoints, adding one, changing a target, logs |
| [updating.md](updating.md) | Certificates, the host OS and Apache, moving to static hosting, rotating the Zulip invitation link |
| [troubleshooting.md](troubleshooting.md) | Symptom, cause, fix |
| [security.md](security.md) | Trust boundaries, secrets, the public invitation link, hardening |
| [examples/](examples/) | Plain HTTP redirects and hardening for Apache, and adding a redirect endpoint |
