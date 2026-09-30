# pcshop-ldap

Directorio OpenLDAP para el dashboard de componentes de PC. Es el **tercer repo**
del entregable: aquí vive el origen de identidad contra el que el backend valida
las credenciales antes de firmar el JWT.

## Contenido

| Archivo | Rol |
|---|---|
| `Dockerfile` | Imagen `osixia/openldap:1.5.0` + hashing de contraseñas con `slappasswd` |
| `bootstrap/10-people.ldif` | Seeds del directorio (personas + cuenta de servicio) |
| `bootstrap/20-acl.ldif` | ACLs: la parte que hay que entender antes de tocar nada aquí |

## Por qué existe `20-acl.ldif`

Este es el gotcha del repo, y no es evidente hasta que falla el login.

Las ACLs por defecto que instala el paquete Debian de `slapd` terminan con:

```
olcAccess: {2} to * by self read by dn="cn=admin,..." write by * none
```

Con esa regla, `svc-pcshop` **sí consegue hacer bind** (los binds simples no
dependen de las ACLs) pero **no puede ver nada**: toda búsqueda devuelve
`error 32 (no such object)`. El síntoma es desconcertante porque el bind de
servicio parece correcto y el backend solo ve "usuario inexistente".

`20-acl.ldif` añade `by dn="cn=svc-pcshop,..." read` a la regla del árbol, sin
tocar la regla de `userPassword`. El servicio puede buscar personas, pero no
puede leer contraseñas — la validación real la hace un bind con el DN del usuario.

Las dos primeras reglas se dejan **idénticas a las de Debian**, y el orden importa:

- Reescribir el bloque entero rompe todos los binds simples no-admin con
  `invalid credentials`, porque `by * break` de la regla `to *` corta el
  recorrido antes de llegar a la regla del usuario.
- Conceder `read` sobre `*` (que incluye `userPassword`) en una regla anterior
  rompe el bind de la misma forma: el servidor evalúa el primer `access to`
  que casa y no vuelve a mirar las siguientes.

## Cuentas sembradas

| DN | Handle | Contraseña | Rol |
|---|---|---|---|
| `cn=juan,ou=People,dc=lab,dc=local` | `juan` | `LabPass-@juan` | Usuario de la aplicación |
| `cn=maria,ou=People,dc=lab,dc=local` | `maria` | `LabPass-@maria` | Usuario de la aplicación |
| `cn=svc-pcshop,ou=Services,dc=lab,dc=local` | — | `SvcPcshop-@2026` | Cuenta de servicio que usa el backend para *buscar* antes de hacer bind |

`cn=admin,dc=lab,dc=local` es el administrador de OpenLDAP. Su contraseña se
inyecta desde `LDAP_ADMIN_PASSWORD` (ver `docker-compose.yml` en el repo
backend, default `LdapAdmin-@2026`).

## Por qué `slappasswd` en el build

El LDIF versionado contiene los *placeholders* `__JUAN_PW__`, `__MARIA_PW__` y
`__SVC_PW__` — nunca contraseñas reales. El `Dockerfile` las sustituye por hashes
SSHA durante el build, así que ni el repositorio ni el historial de la imagen
guardan credenciales en texto plano.

## Cambiar una contraseña

Las contraseñas se hornean en la imagen, así que un cambio exige reconstruir y
volver a crear el volumen (el directorio es *idempotente* en el primer arranque):

1. Edita el `Dockerfile` (el `slappasswd -s '...'` correspondiente).
2. Edita el LDIF si agregas o quitas entradas.
3. Desde `pcshop-backend/`: `docker compose down -v && docker compose up -d --build ldap`

`down -v` es obligatorio: sin él el volumen `ldap-data` persiste y el bootstrap
vuelve a aplicarse sobre una base ya poblada.

## Uso directo

El servicio se publica en el host en el puerto **1389** (mapeado a 389 dentro del
contenedor) para no chocar con el OpenLDAP del proyecto anterior.

```powershell
# Verificar que el directorio responde
docker compose exec ldap ldapsearch -x -H ldap://127.0.0.1:389 `
  -D "cn=admin,dc=lab,dc=local" -w "LdapAdmin-@2026" -b "dc=lab,dc=local" "(objectClass=*)" dn
```

## Estructura del árbol

```
dc=lab,dc=local
├── ou=People
│   ├── cn=juan
│   └── cn=maria
└── ou=Services
    └── cn=svc-pcshop
```
