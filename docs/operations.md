# Operations

## Checking the endpoints

```sh
scripts/check-endpoints.sh
```

The script needs `bash`, `curl` and `openssl`, and no credentials. It checks:

- `https://slack.bioconductor.org/` returns 200 with the same bytes as
  `sites/slack.bioconductor.org/public/index.html`.
- Each redirect hostname returns a 302 to its target over HTTPS.
- Plain HTTP on every hostname returns a 301 to the same hostname over HTTPS.
- Every certificate is valid for at least 21 more days. Set `CERT_DAYS` to
  change the window.
- Each target returns 200, the invitation link shows the Zulip sign-up form,
  and the framed blog post returns 200.

It prints one `ok` or `FAIL` line per check and exits 1 if any check failed.
Run it after every change and at least monthly. Against the production Apache
host, the three plain HTTP checks fail; see
[Known limitations](architecture.md#known-limitations).

## Monitoring

The status page, [dev.status.bioconductor.org](https://dev.status.bioconductor.org),
lists the endpoint as the "Slack invite app" component, linked to
`https://slack.bioconductor.org`.
Its check requests `http://slack.bioconductor.org` and follows redirects, so it
reports the status of the last URL in the redirect chain. While plain HTTP
redirects to `git.bioconductor.org`
([Known limitations](architecture.md#known-limitations)), that is the Git
server's status, not the page's. `zulip` and `chat` are not monitored there.

## Adding a redirect endpoint

For an HTTP redirect, follow
[examples/add-redirect-endpoint.md](examples/add-redirect-endpoint.md).

For a page:

1. Add the page as `sites/<host>/public/index.html`, with all CSS and
   JavaScript inline.
2. Copy `apache/slack.bioconductor.org.conf` to `apache/<host>.conf` and
   replace every `slack.bioconductor.org` in it.
3. Copy `sites/slack.bioconductor.org/wrangler.jsonc` to `sites/<host>/` and
   `sites/slack.bioconductor.org/public/_headers` to `sites/<host>/public/`.
   In `wrangler.jsonc`, change `name` and the route `pattern`. In `_headers`,
   replace the `script-src` and `style-src` hashes with the output of
   `scripts/csp-hashes.py sites/<host>/public/index.html`, and set
   `frame-src` to the origins the page frames, or remove it.
4. Add checks for the new hostname to `scripts/check-endpoints.sh`, following
   the ones for `slack.bioconductor.org`.
5. Deploy as in [deployment.md](deployment.md).

## Changing a target

| Endpoint | Where the target is written |
|---|---|
| `slack.bioconductor.org` | `redirectUrl` (the invitation link) in `sites/slack.bioconductor.org/public/index.html`, and the manual link (the organization URL) when the destination service changes |
| `zulip.bioconductor.org`, `chat.bioconductor.org` | `apache/zulip.bioconductor.org.conf`, `apache/chat.bioconductor.org.conf`, `cloudflare/zulip-redirect-rule.json` |

`git grep -n '<old-url>'` lists every occurrence. After editing:

1. If the page's script changed, update its hash in `_headers`:

   ```sh
   scripts/csp-hashes.py sites/slack.bioconductor.org/public/index.html
   # copy the script-src value into public/_headers, then:
   scripts/csp-hashes.py --check sites/slack.bioconductor.org/public/_headers \
     sites/slack.bioconductor.org/public/index.html
   ```

2. Deploy the change where the endpoints are served:
   - Apache: repeat steps 3 and 4 of [deployment.md](deployment.md#steps).
     First run `sudo apachectl -S`, which lists the file and line of each
     `namevhost`. If the hostname's virtual hosts are in other files, edit
     those files and install the page in their `DocumentRoot`, instead of
     enabling a second virtual host with the same `ServerName`: Apache uses
     the first one it loads.
   - Cloudflare page: `npx wrangler deploy` in `sites/slack.bioconductor.org`.
   - Cloudflare rule: edit the rule's URL under the zone's **Rules**, or send
     the updated JSON to the rule:

     ```sh
     curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets/<ruleset-id>/rules/<rule-id>" \
       -H "Authorization: Bearer $CF_RULES_TOKEN" \
       -H "Content-Type: application/json" \
       --data @cloudflare/zulip-redirect-rule.json
     ```

     `<rule-id>` is the `id` of the rule in the ruleset returned by the
     entry point request in [deployment.md](deployment.md#zulip-and-chat-redirect-rule).

3. Run `scripts/check-endpoints.sh` from the repository root.

Replacing the Zulip invitation link has extra steps in Zulip; see
[updating.md](updating.md#rotating-the-zulip-invitation-link).

## Removing an endpoint

1. Apache: disable the virtual hosts for `<host>`, which `sudo apachectl -S`
   lists with their files (`sudo a2dissite <host>` for a file installed from
   `apache/`), run `sudo systemctl reload apache2`, and delete
   `apache/<host>.conf`.
2. Cloudflare: delete the Worker or remove the hostname from the redirect
   rule's expression.
3. Delete the hostname's DNS record.
4. Remove the hostname from `scripts/check-endpoints.sh`.

## Logs

On Apache, each hostname logs to `<host>-access.log` and `<host>-error.log` in
`${APACHE_LOG_DIR}`, which is `/var/log/apache2` on Debian and Ubuntu. On
Cloudflare, requests appear in the zone's analytics and the Worker's metrics
in the dashboard.

## Backup and restore

The pages and configurations are in this repository; restoring an endpoint is
a deployment from it. Outside the repository:

- The certificate and key are reissued from the certificate authority
  account that issues the `bioconductor.org` wildcard certificate.
- Before changing DNS records, export the zone with **DNS > Records > Export**
  in the Cloudflare dashboard, which downloads a BIND-format file.
