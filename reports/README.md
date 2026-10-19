# Scan report — LDAP (PCShop OpenLDAP)

Result of the security analysis with ProjectDiscovery **Nuclei** against the LDAP
directory. This document renders
[`ldap-nuclei.jsonl`](./ldap-nuclei.jsonl) in readable form.

## Summary

| | |
|---|---|
| Target | `host.docker.internal:1389` (OpenLDAP on `osixia/openldap:1.5.0`) |
| Scope | unauthenticated, `javascript/…/ldap` templates |
| Date | 2026-10-18, 00:16 UTC |
| Findings | **1**, severity **`medium`** |
| Real vulnerabilities (low/medium/high/critical) | **1** (medium) |

Unlike the frontend and the backend, here the scan **does** detect a
medium-severity finding: the server allows **anonymous bind**.

## Distribution

| Category | # | Severity |
|---|---:|---|
| Anonymous bind allowed | 1 | **medium** |
| **Total** | **1** | |

## Detailed finding

### 1. Anonymous bind allowed — *`ldap-anonymous-login-detect`* (medium)

The template tries to authenticate with no username or password and checks
whether the server allows it. **It does.** The response exported by Nuclei
confirms the anonymous bind completed:

```json
{
  "BaseDN": "dc=anonymous",
  "Domain": "anonymous",
  "DefaultNamingContext": "",
  "DomainFunctionality": "",
  "ForestFunctionality": "",
  "DomainControllerFunctionality": "",
  "DnsHostName": ""
}
```

**What it means:** any client can establish an LDAP session without credentials.
This can expose directory information (schema, structure, readable entries) and is
a common reconnaissance vector ahead of a more targeted attack.

**CWE-287** (Improper Authentication) / information exposure.

#### Context in this repository

Anonymous bind in OpenLDAP is the **default** behavior. In this repo the ACLs
(`bootstrap/20-acl.ldif`) heavily limit what an anonymous user can do: rule `{1}`
grants it only `auth` on `userPassword` (needed so a *bind* can verify a
password), and rule `{2}` denies reading the tree (`by * none`). That is why an
anonymous user can *authenticate* but **cannot read** the directory.

Even so, the standard recommendation is to **disable anonymous bind** rather than
rely on ACLs alone.

**Recommendation (fix):** add to the slapd configuration:

```
disallow bind_anon
```

(or, in `olcGlobal`, `olcDisallows: bind_anon`), and keep the current ACLs. With
that, a credential-less bind is rejected even though the ACLs stay strict.

## Scope notes

- Nuclei ran with the three LDAP templates in its catalog:
  `ldap-anonymous-login-detect` (this one), `ldap-metadata`, and
  `ldap-default-login`. Only the first matched.
- No real username/password pair was tested (that would already be exploitation);
  the *default logins* template found no default credentials.
- The service publishes on **1389** on the host (389 inside the container).

## Relation to the code

- `bootstrap/20-acl.ldif` — defines the ACLs that restrict anonymous users; this
  is where the behavior is documented/adjusted.
- `Dockerfile` — base `osixia/openldap:1.5.0`; the `disallow bind_anon` directive
  would go in the slapd configuration baked by this repo.

## Recommendations

1. **Disable anonymous bind** (`disallow bind_anon`).
2. Keep the current ACLs, which already prevent anonymous reads of the tree.
3. Re-scan after the change to confirm the finding disappears.

## Notice

Run active scans only against systems you own or are authorized to test. This
analysis was limited to a local lab environment.
