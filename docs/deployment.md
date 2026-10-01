# Deployment

The endpoints can be served by Apache on a Linux host, using
[`apache/`](../apache), or by Cloudflare with no origin server, using
[`sites/`](../sites) and [`cloudflare/`](../cloudflare). Both rely on the
`bioconductor.org` DNS zone in Cloudflare. Run the commands from a checkout of
this repository unless a step says otherwise.

## Apache

### Requirements

- A Debian or Ubuntu host with the `apache2` package. The templates use
  Debian's `${APACHE_LOG_DIR}` and the commands use `a2enmod` and `a2ensite`.
- A certificate for `*.bioconductor.org` in one PEM file, leaf first, followed
  by its intermediates, and its private key.
- Edit access to DNS records in the `bioconductor.org` zone.

### Steps

1. Enable the modules the templates use:

   ```sh
   sudo a2enmod ssl alias dir
   ```

2. Install the certificate and key at the paths the templates use, replacing
   `<cert-dir>` with the directory that holds them, outside this checkout:

   ```sh
   sudo install -d -m 0755 /etc/ssl/bioconductor.org
   sudo install -m 0644 <cert-dir>/fullchain.pem /etc/ssl/bioconductor.org/fullchain.pem
   sudo install -m 0600 <cert-dir>/privkey.pem /etc/ssl/bioconductor.org/privkey.pem
   ```

   If the host keeps the certificate elsewhere, change `SSLCertificateFile` and
   `SSLCertificateKeyFile` in each file under `apache/` instead.

3. Install the page. `_headers` is for Cloudflare and is not copied:

   ```sh
   sudo install -d -m 0755 /var/www/slack.bioconductor.org
   sudo install -m 0644 sites/slack.bioconductor.org/public/index.html /var/www/slack.bioconductor.org/
   ```

4. Install and enable the HTTPS virtual hosts from `apache/`, and the plain
   HTTP redirects from
   [examples/apache-http-redirect.conf](examples/apache-http-redirect.conf):

   ```sh
   sudo install -m 0644 apache/*.conf /etc/apache2/sites-available/
   sudo install -m 0644 docs/examples/apache-http-redirect.conf /etc/apache2/sites-available/bioc-redirects-http.conf
   sudo a2ensite slack.bioconductor.org zulip.bioconductor.org chat.bioconductor.org bioc-redirects-http
   sudo apachectl configtest
   sudo systemctl reload apache2
   ```

5. Confirm that every hostname has a virtual host on both ports. Each one is
   listed as a `namevhost` under port 80 and under port 443:

   ```sh
   sudo apachectl -S
   ```

6. Test the host before DNS points at it, replacing `<address>` with its
   public address:

   ```sh
   curl -sI --resolve slack.bioconductor.org:443:<address> https://slack.bioconductor.org/
   curl -sI --resolve slack.bioconductor.org:80:<address> http://slack.bioconductor.org/
   curl -sI --resolve zulip.bioconductor.org:443:<address> https://zulip.bioconductor.org/
   ```

   Expect `200`, a `301` to `https://slack.bioconductor.org/`, and a `302` to
   the invitation link.

7. In the Cloudflare zone, create or update an `A` record for each hostname
   pointing at the host, proxy status **DNS only**, so that visitors receive
   the host's certificate.

8. Run `scripts/check-endpoints.sh`. Every check reads `ok` and the script
   ends with `all checks passed`.

## Cloudflare

### Requirements

- A Cloudflare user in the account that holds `bioconductor.org`, allowed to
  edit Workers, DNS records and Redirect Rules. For the API calls below, an
  API token with **Zone > Single Redirect > Edit** on the zone, exported as
  `CF_RULES_TOKEN`. When `CLOUDFLARE_API_TOKEN` is set, Wrangler uses it in
  place of `npx wrangler login`.
- Node.js, to run Wrangler with `npx`.
- Python 3, for `scripts/csp-hashes.py`.
- `curl` and `jq`, for the API calls.

### Slack page

1. Check that the CSP hashes in `_headers` match the page:

   ```sh
   scripts/csp-hashes.py --check sites/slack.bioconductor.org/public/_headers \
     sites/slack.bioconductor.org/public/index.html
   ```

2. Optionally preview the site at `http://localhost:8787`:

   ```sh
   cd sites/slack.bioconductor.org
   npx wrangler dev
   ```

3. Note the type and value of the current DNS record for
   `slack.bioconductor.org` under **DNS > Records**, for rollback.

4. Deploy from `sites/slack.bioconductor.org`:

   ```sh
   npx wrangler login
   npx wrangler deploy
   ```

   This creates the Worker `slack-bioconductor-org` and attaches the Custom
   Domain `slack.bioconductor.org`; Cloudflare creates its DNS record and
   certificate. If Wrangler reports that the hostname already has DNS records,
   delete the record noted in step 3 and repeat `npx wrangler deploy`. The
   hostname does not resolve between the two steps.

5. Check that plain HTTP redirects to HTTPS:

   ```sh
   curl -sI http://slack.bioconductor.org/
   ```

   Expect a `301` to `https://slack.bioconductor.org/`. Cloudflare sends it
   when the zone's **Always Use HTTPS** setting (**SSL/TLS > Edge
   Certificates**) is on; the setting applies to every proxied hostname in the
   zone.

6. Return to the repository root with `cd ../..`, run
   `scripts/check-endpoints.sh`, and confirm the headers from `_headers`:

   ```sh
   curl -sI https://slack.bioconductor.org/ | grep -iE '^(content-security-policy|strict-transport-security):'
   ```

To roll back, remove the Custom Domain under **Workers & Pages >
slack-bioconductor-org > Settings > Domains & Routes** and recreate the record
noted in step 3 with proxy status **DNS only**.

### zulip and chat redirect rule

1. Create the rule in
   [`cloudflare/zulip-redirect-rule.json`](../cloudflare/zulip-redirect-rule.json).
   Redirect rules act only on proxied requests, so the rule has no effect
   until step 2.

   In the dashboard, under the zone's **Rules**, create a **Redirect Rule**
   with a custom filter expression equal to the file's `expression`, a static
   URL redirect to the file's `target_url.value`, status code `302`, and
   **Preserve query string** on.

   With the API, set `ZONE_ID` to the zone ID shown on the zone's
   **Overview** page, find the zone's redirect ruleset, and add the rule to it:

   ```sh
   curl -s "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets/phases/http_request_dynamic_redirect/entrypoint" \
     -H "Authorization: Bearer $CF_RULES_TOKEN"

   curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets/<ruleset-id>/rules" \
     -H "Authorization: Bearer $CF_RULES_TOKEN" \
     -H "Content-Type: application/json" \
     --data @cloudflare/zulip-redirect-rule.json
   ```

   `<ruleset-id>` is `result.id` from the first response. If the first request
   returns 404, the zone has no redirect rules yet; create the ruleset with
   this rule in it:

   ```sh
   jq '{name: "default", kind: "zone", phase: "http_request_dynamic_redirect", rules: [.]}' \
     cloudflare/zulip-redirect-rule.json |
     curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets" \
       -H "Authorization: Bearer $CF_RULES_TOKEN" \
       -H "Content-Type: application/json" \
       --data @-
   ```

2. For each of `zulip` and `chat`, note the current DNS record, then replace
   it with an `AAAA` record with content `100::` and proxy status **Proxied**.
   `100::` is Cloudflare's placeholder for hostnames with no origin; requests
   never reach it.

3. Check that plain HTTP redirects to HTTPS:

   ```sh
   curl -sI http://zulip.bioconductor.org/
   ```

   Expect a `301` to `https://zulip.bioconductor.org/`. Cloudflare sends it
   when the zone's **Always Use HTTPS** setting is on, as in step 5 of
   [Slack page](#slack-page); with the setting off, the rule answers plain
   HTTP with its `302`.

4. Run `scripts/check-endpoints.sh`.

To roll back, delete the `AAAA` records and restore the noted records with
proxy status **DNS only**.
