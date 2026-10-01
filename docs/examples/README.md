# Examples

| File | Use |
|---|---|
| [add-redirect-endpoint.md](add-redirect-endpoint.md) | A new HTTP redirect endpoint, on Apache and on Cloudflare |
| [apache-http-redirect.conf](apache-http-redirect.conf) | Plain HTTP to HTTPS redirects for the hostnames in `apache/` |
| [apache-hardening.conf](apache-hardening.conf) | Server-wide TLS and version-disclosure settings for the Apache host |
| [apache-headers.conf](apache-headers.conf) | Response headers for each `*:443` virtual host in `apache/` |

The configurations for the existing endpoints are the files under
[`apache/`](../../apache), [`sites/`](../../sites) and
[`cloudflare/`](../../cloudflare). The three `apache-*.conf` files are
recommended changes that the production host does not have; see
[architecture.md](../architecture.md#known-limitations) and
[security.md](../security.md#apache).
