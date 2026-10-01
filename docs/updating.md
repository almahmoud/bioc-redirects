# Updating

The endpoints do not depend on the Bioconductor release cycle, and the
repository has no CI workflows or pinned dependencies. The parts that need
updates:

| Part | Cadence | Procedure |
|---|---|---|
| TLS certificate on Apache | Before each expiry; at most every 100 days for certificates issued from 15 March 2027 | [Certificates](#certificates) |
| Ubuntu packages, including Apache and OpenSSL | Security updates as released; check monthly | [Security updates](#security-updates) |
| Ubuntu LTS release | Before the running release leaves standard support; overdue on the production host | [Release upgrades](#release-upgrades) |
| Hosting | Once, when moving off the Apache host | [Moving to static hosting](#moving-to-static-hosting) |
| Zulip invitation link | Before it expires, or when it is revoked or abused | [Rotating the Zulip invitation link](#rotating-the-zulip-invitation-link) |
| Wrangler and `wrangler.jsonc` | When deploying | [Cloudflare configuration](#cloudflare-configuration) |
| Endpoint check | Monthly and after every change | [operations.md](operations.md#checking-the-endpoints) |

## Certificates

### Apache

Apache serves a wildcard certificate for `*.bioconductor.org` and
`bioconductor.org`. Check its issuer and expiry:

```sh
openssl s_client -connect slack.bioconductor.org:443 -servername slack.bioconductor.org </dev/null 2>/dev/null |
  openssl x509 -noout -issuer -enddate
```

`scripts/check-endpoints.sh` fails 21 days before expiry.

Publicly trusted certificates issued from 15 March 2026 are valid for at most
200 days, from 15 March 2027 for at most 100 days, and from 15 March 2029 for
at most 47 days (CA/Browser Forum ballot SC-081). A manually installed
certificate needs replacing at least that often.

To replace it on the host:

1. Put the new certificate with its intermediates in `<cert-dir>/fullchain.pem`
   and the key in `<cert-dir>/privkey.pem`, where `<cert-dir>` is a directory
   outside this checkout, and confirm that they belong together. The two
   digests must be equal:

   ```sh
   openssl x509 -noout -pubkey -in <cert-dir>/fullchain.pem | openssl sha256
   openssl pkey -pubout -in <cert-dir>/privkey.pem | openssl sha256
   ```

2. Find the certificate and key files the virtual hosts read:

   ```sh
   sudo apachectl -S
   sudo grep -Rn SSLCertificate /etc/apache2/sites-enabled/
   ```

   The commands below use the paths in the files under `apache/`. Replace
   them with the paths the host reports.

3. Keep a copy of the current files, replacing the copy from the previous
   replacement, and install the new ones:

   ```sh
   sudo cp -a /etc/ssl/bioconductor.org/fullchain.pem /etc/ssl/bioconductor.org/fullchain.pem.previous
   sudo cp -a /etc/ssl/bioconductor.org/privkey.pem /etc/ssl/bioconductor.org/privkey.pem.previous
   sudo install -m 0644 <cert-dir>/fullchain.pem /etc/ssl/bioconductor.org/fullchain.pem
   sudo install -m 0600 <cert-dir>/privkey.pem /etc/ssl/bioconductor.org/privkey.pem
   sudo apachectl configtest && sudo systemctl reload apache2
   ```

4. Run the `openssl` command above and confirm the new expiry date, then run
   `scripts/check-endpoints.sh`.

To roll back, restore the copies kept in step 3 and reload Apache:

```sh
sudo cp -a /etc/ssl/bioconductor.org/fullchain.pem.previous /etc/ssl/bioconductor.org/fullchain.pem
sudo cp -a /etc/ssl/bioconductor.org/privkey.pem.previous /etc/ssl/bioconductor.org/privkey.pem
sudo apachectl configtest && sudo systemctl reload apache2
```

The `bioconductor.org` zone's authoritative DNS is Cloudflare. A certificate
obtained through ACME with the DNS-01 challenge, which wildcard certificates
require, must publish its `_acme-challenge` records in Cloudflare: for
example, certbot with the `certbot-dns-cloudflare` plugin and an API token
limited to **Zone > DNS > Edit** on `bioconductor.org`.

### Cloudflare

Cloudflare issues and renews the edge certificates for proxied hostnames and
Custom Domains. There is nothing to update; the `openssl` command above shows
the certificate in use.

## Host OS and web server

The production host's `Server` header reports `Apache/2.4.18 (Ubuntu)`, the
Apache package of Ubuntu 16.04, whose standard support ended in April 2021.
Without an extended-support subscription, `apt upgrade` installs no security
fixes there, so the release upgrade below or
[moving to static hosting](#moving-to-static-hosting) is due. See
[security.md](security.md#known-limitations).

The templates need Apache 2.4.8 or later, which reads intermediates from
`SSLCertificateFile`. Every supported Debian and Ubuntu release ships a later
version.

### Security updates

Take a snapshot of the host's disk first if its platform supports one, then
run on the host:

```sh
sudo apt update
sudo apt upgrade
apache2 -v
sudo apachectl configtest
```

Then run `scripts/check-endpoints.sh` from any machine.

To roll back, restore the snapshot. `/var/log/apt/history.log` lists the
packages each upgrade changed, with their previous versions;
`sudo apt install <package>=<version>` reinstalls a previous version while the
configured archives still carry it.

### Release upgrades

Build a new host on the current Ubuntu LTS release rather than upgrading in
place, before the running release leaves standard support.

1. Deploy to the new host as in [deployment.md](deployment.md#apache),
   steps 1 to 6. Step 6 tests the new host while DNS still points at the old
   one.
2. Change each hostname's `A` record to the new host.
3. Run `scripts/check-endpoints.sh` and watch the new host's access logs for
   requests to each hostname.
4. Disable the redirect virtual hosts on the old host once the old records'
   TTL has expired and its logs show no more requests for these hostnames.

To roll back, point the `A` records back at the old host.

The new host serves only the redirect endpoints; `git.bioconductor.org` stays
on the old host and is not configured in this repository.

### Hardening

The examples restrict TLS versions, hide version details and add response
headers. On the host:

1. Enable the server-wide settings in
   [examples/apache-hardening.conf](examples/apache-hardening.conf). They also
   apply to `git.bioconductor.org` on the same host. On Apache older than
   2.4.36, remove `+TLSv1.3` from the file's `SSLProtocol` line before
   installing it.

   ```sh
   sudo install -m 0644 docs/examples/apache-hardening.conf /etc/apache2/conf-available/hardening.conf
   sudo a2enconf hardening
   ```

2. Enable `mod_headers` with `sudo a2enmod headers`, and paste the lines of
   [examples/apache-headers.conf](examples/apache-headers.conf) inside each
   `*:443` virtual host for the endpoints, not at server level.

3. Reload Apache and check the headers:

   ```sh
   sudo apachectl configtest && sudo systemctl reload apache2
   curl -sI https://slack.bioconductor.org/ | grep -iE '^(server|strict-transport-security|content-security-policy):'
   ```

   Expect `Server: Apache` with no version, and both headers.

To roll back, run `sudo a2disconf hardening`, remove the pasted lines, and
reload Apache.

## Moving to static hosting

Moving the endpoints to Cloudflare removes their dependency on the Apache
host, its operating system and its certificate.

1. Run `scripts/check-endpoints.sh` and keep the output for comparison.
2. Move `zulip` and `chat` as in
   [deployment.md](deployment.md#zulip-and-chat-redirect-rule): rule first,
   then DNS. Run the check.
3. Move `slack` as in [deployment.md](deployment.md#slack-page). Run the
   check.
4. Confirm that each hostname resolves to Cloudflare addresses:

   ```sh
   for h in slack zulip chat; do dig +short "$h.bioconductor.org"; done
   ```

5. After the old records' TTL has expired and the Apache access logs show no
   more requests for the three hostnames, disable their virtual hosts on
   Apache. `sudo apachectl -S` lists the file of each; for the files
   installed as in [deployment.md](deployment.md#steps):

   ```sh
   sudo a2dissite slack.bioconductor.org zulip.bioconductor.org chat.bioconductor.org bioc-redirects-http
   sudo systemctl reload apache2
   ```

To roll back before step 5, follow the rollback of each section of
[deployment.md](deployment.md#cloudflare): remove the Custom Domain of
`slack`, delete the `AAAA` records of `zulip` and `chat`, and restore the
noted `A` records with proxy status **DNS only**. After step 5, re-enable the
sites with `a2ensite` first.

## Rotating the Zulip invitation link

Rotate the link before its expiry date, when it has been revoked, or when it
attracts unwanted sign-ups. Creating and revoking links needs an
administrator or owner of the `community-bioc` organization.

1. In Zulip, open the gear menu, select **Invite users**, then **Invitation
   link**. Choose the expiry, the **Member** role and the default channels,
   select **Create link**, and copy it.
2. Replace the old link in every file that holds it:

   ```sh
   git grep -n 'zulipchat.com/join/'
   ```

   The link is in the page's `redirectUrl`, the `apache/` files for `zulip`
   and `chat`, and `cloudflare/zulip-redirect-rule.json`.
3. Update the page's script hash in `_headers` as in
   [operations.md](operations.md#changing-a-target), step 1.
4. Deploy as in [operations.md](operations.md#changing-a-target), step 2, and
   run `scripts/check-endpoints.sh`. The check reads the link
   from the page, so it confirms that the new link shows the sign-up form and
   that `zulip` and `chat` redirect to it.
5. Revoke the old link: gear menu, **Organization settings**, **Users**, the
   **Invitations** tab, then the revoke icon next to it. Revoking after step 4
   means the endpoints never send visitors to a revoked link.

To roll back before step 5, deploy the previous commit.

## Cloudflare configuration

- `npx wrangler` runs the Wrangler release that npm resolves. To pin the
  major version, run `npx wrangler@4 deploy`.
- Set `compatibility_date` in `wrangler.jsonc` to the current date when
  changing the file.
- Changes to `_headers` or `public/` take effect on the next
  `npx wrangler deploy`.
- Changes to the redirect rule take effect when saved in the dashboard or
  sent through the API; see [operations.md](operations.md#changing-a-target).

After each change, run `scripts/check-endpoints.sh` and the header check in
step 6 of [deployment.md](deployment.md#slack-page).

To roll back the page, run `npx wrangler rollback` in
`sites/slack.bioconductor.org`, which deploys the version uploaded before the
current one, or deploy the previous commit. To roll back the rule, send the
file as it was before the change, replacing `<commit>` with the last commit
before it:

```sh
git show <commit>:cloudflare/zulip-redirect-rule.json |
  curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/rulesets/<ruleset-id>/rules/<rule-id>" \
    -H "Authorization: Bearer $CF_RULES_TOKEN" \
    -H "Content-Type: application/json" \
    --data @-
```

`ZONE_ID`, `<ruleset-id>` and `<rule-id>` are as in
[operations.md](operations.md#changing-a-target).
