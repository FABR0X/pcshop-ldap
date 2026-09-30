# pcshop-ldap

OpenLDAP directory for the PC component dashboard. This is the **third repo** of
the deliverable: the source of identity the backend validates against before it
signs a JWT.

| | |
|---|---|
| Image | `osixia/openldap:1.5.0` |
| Base DN | `dc=lab,dc=local` |
| Host port | 1389 (mapped to 389 in the container) |
| Bootstrapped by | `pcshop-backend/docker-compose.yml` |
| Sibling repos | [`pcshop-frontend`](../pcshop-frontend) · [`pcshop-backend`](../pcshop-backend) |

## Files

| File | Role |
|---|---|
| `Dockerfile` | The `osixia/openldap:1.5.0` image plus password hashing with `slappasswd` |
| `bootstrap/10-people.ldif` | Directory seeds (people + the service account) |
| `bootstrap/20-acl.ldif` | Access rules — read this before touching anything here |

## Why `20-acl.ldif` exists

This is the gotcha in this repo, and it is not obvious until a login fails.

The ACLs installed by Debian's `slapd` package end with:

```
olcAccess: {2} to * by self read by dn="cn=admin,..." write by * none
```

With that rule, `svc-pcshop` **can bind successfully** (simple binds do not
consult the ACLs) but **cannot see anything**: every search returns
`error 32 (no such object)`. The symptom is misleading, because the service bind
looks correct and the backend only ever reports "user does not exist".

`20-acl.ldif` adds `by dn="cn=svc-pcshop,..." read` to the tree rule without
touching the `userPassword` rule. The service can search for people but cannot
read passwords — the actual verification is a bind using the user's own DN.

The first two rules are left **byte-identical to the Debian defaults**, and the
order matters:

- Rewriting the whole block breaks every non-admin simple bind with
  `invalid credentials`, because the `by * break` in the `to *` rule short
  circuits evaluation before it ever reaches the user rule.
- Granting `read` on `*` (which includes `userPassword`) in an earlier rule
  breaks the bind the same way: the server evaluates the first matching
  `access to` and does not reconsider the ones after it.

## Seeded accounts

| DN | Handle | Password | Role |
|---|---|---|---|
| `cn=juan,ou=People,dc=lab,dc=local` | `juan` | `LabPass-@juan` | Application user |
| `cn=maria,ou=People,dc=lab,dc=local` | `maria` | `LabPass-@maria` | Application user |
| `cn=svc-pcshop,ou=Services,dc=lab,dc=local` | — | `SvcPcshop-@2026` | Service account the backend uses to *search* before binding |

`cn=admin,dc=lab,dc=local` is the OpenLDAP administrator. Its password is
injected from `LDAP_ADMIN_PASSWORD` (see `docker-compose.yml` in the backend
repo, default `LdapAdmin-@2026`).

The service account can list a person but cannot read their `userPassword`:

```console
$ docker compose exec ldap ldapsearch -x -H ldap://127.0.0.1:389 \
    -D "cn=svc-pcshop,ou=Services,dc=lab,dc=local" -w "SvcPcshop-@2026" \
    -b "ou=People,dc=lab,dc=local" "(cn=juan)" userPassword
...
dn: cn=juan,ou=People,dc=lab,dc=local
uid: juan
displayName: Juan Perez
# no userPassword attribute in the response
```

That is the intended result, not a misconfiguration.

## Why `slappasswd` runs at build time

The committed LDIF holds the *placeholders* `__JUAN_PW__`, `__MARIA_PW__` and
`__SVC_PW__` — never real passwords. The `Dockerfile` substitutes SSHA hashes
during the build, so neither the repository nor the image history stores
credentials in plain text.

## Changing a password

Passwords are baked into the image, so a change means rebuilding and recreating
the volume (the directory only bootstraps on first boot):

1. Edit the `Dockerfile` (the matching `slappasswd -s '...'`).
2. Edit the LDIF if you are adding or removing entries.
3. From `pcshop-backend/`: `docker compose down -v && docker compose up -d --build ldap`

The `down -v` is mandatory: without it the `ldap-data` volume persists and the
bootstrap runs again on top of an already-populated database.

## Running it

The service publishes on host port **1389** (mapped to 389 inside the container)
to avoid colliding with the previous project's OpenLDAP.

```powershell
# Confirm the directory answers
docker compose exec ldap ldapsearch -x -H ldap://127.0.0.1:389 `
  -D "cn=admin,dc=lab,dc=local" -w "LdapAdmin-@2026" -b "dc=lab,dc=local" "(objectClass=*)" dn
```

## Tree layout

```
dc=lab,dc=local
├── ou=People
│   ├── cn=juan
│   └── cn=maria
└── ou=Services
    └── cn=svc-pcshop
```
