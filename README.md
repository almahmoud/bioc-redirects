# bioc-redirects

Pages and server configuration for the Bioconductor redirect endpoints:
`bioconductor.org` hostnames kept so that published links keep working after
the service behind them moved.

| Hostname | Behaviour |
|---|---|
| [slack.bioconductor.org](https://slack.bioconductor.org) | Explains that the Bioconductor community chat moved from Slack to Zulip, shows the announcement, and redirects to the Zulip invitation link after 10 seconds |
| [zulip.bioconductor.org](https://zulip.bioconductor.org) | Redirects to the Zulip invitation link |
| [chat.bioconductor.org](https://chat.bioconductor.org) | Redirects to the Zulip invitation link |

## Repository layout

| Path | Contents |
|---|---|
| [`sites/slack.bioconductor.org/`](sites/slack.bioconductor.org) | The transition page, its response headers and its Cloudflare configuration |
| [`apache/`](apache) | Apache HTTPS virtual hosts, one file per hostname |
| [`cloudflare/`](cloudflare) | Cloudflare redirect rule for `zulip` and `chat` |
| [`scripts/check-endpoints.sh`](scripts/check-endpoints.sh) | Checks every endpoint, its certificate and its target |
| [`scripts/csp-hashes.py`](scripts/csp-hashes.py) | Prints or checks the Content-Security-Policy hashes of the page's inline script and style |
| [`docs/`](docs) | Maintainer documentation |

## Checking the endpoints

```sh
scripts/check-endpoints.sh
```

Requires `bash`, `curl` and `openssl`. Each check prints `ok` or `FAIL`.
Against the production Apache host the three plain HTTP checks fail; see
[docs/architecture.md](docs/architecture.md#known-limitations).

## Documentation

| Document | Answers |
|---|---|
| [docs/architecture.md](docs/architecture.md) | How each endpoint works and where it is served |
| [docs/deployment.md](docs/deployment.md) | Serving the endpoints from Apache or from Cloudflare |
| [docs/operations.md](docs/operations.md) | Checking endpoints, adding one, changing a target |
| [docs/updating.md](docs/updating.md) | Certificates, host updates, moving to static hosting, rotating the invitation link |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Symptom, cause, fix |
| [docs/security.md](docs/security.md) | Trust boundaries, secrets, hardening, reporting issues |
| [docs/examples/](docs/examples) | Apache plain HTTP redirects and hardening, adding a redirect endpoint |

## License

[MIT](LICENSE).
