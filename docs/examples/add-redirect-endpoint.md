# Adding a redirect endpoint

Worked example: `<name>.bioconductor.org` answers every request with a 302 to
`<target-url>`. Replace both placeholders throughout.

## Apache

`apache/<name>.bioconductor.org.conf`:

```apache
# <name>.bioconductor.org: redirects every path to <target-url>.
# Requires mod_ssl and mod_alias.

<VirtualHost *:80>
    ServerName <name>.bioconductor.org
    Redirect permanent / https://<name>.bioconductor.org/
</VirtualHost>

<VirtualHost *:443>
    ServerName <name>.bioconductor.org

    SSLEngine on
    SSLCertificateFile    /etc/ssl/bioconductor.org/fullchain.pem
    SSLCertificateKeyFile /etc/ssl/bioconductor.org/privkey.pem

    RedirectMatch 302 ^ <target-url>

    ErrorLog ${APACHE_LOG_DIR}/<name>.bioconductor.org-error.log
    CustomLog ${APACHE_LOG_DIR}/<name>.bioconductor.org-access.log combined
</VirtualHost>
```

On the Apache host:

```sh
sudo cp apache/<name>.bioconductor.org.conf /etc/apache2/sites-available/
sudo a2ensite <name>.bioconductor.org
sudo apachectl configtest && sudo systemctl reload apache2
```

In the Cloudflare zone, add an `A` record for `<name>` pointing at the Apache
host, proxy status **DNS only**.

## Cloudflare

If `<target-url>` is the target of an existing rule, add the hostname to that
rule's expression:

```text
http.host in {"zulip.bioconductor.org" "chat.bioconductor.org" "<name>.bioconductor.org"}
```

Otherwise create `cloudflare/<name>-redirect-rule.json` and deploy it as in
[deployment.md](../deployment.md#zulip-and-chat-redirect-rule):

```json
{
  "description": "<name>.bioconductor.org to <target-url>",
  "expression": "http.host eq \"<name>.bioconductor.org\"",
  "action": "redirect",
  "action_parameters": {
    "from_value": {
      "target_url": { "value": "<target-url>" },
      "status_code": 302,
      "preserve_query_string": true
    }
  },
  "enabled": true
}
```

In the Cloudflare zone, add an `AAAA` record for `<name>` with content `100::`,
proxy status **Proxied**.

## Check

Add the endpoint to `redirects` in `scripts/check-endpoints.sh`:

```text
<name>.bioconductor.org <target-url>
```

Then run `scripts/check-endpoints.sh`. Every line for `<name>` reads `ok`.
