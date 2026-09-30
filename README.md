# pcshop-ldap

Directorio OpenLDAP para el dashboard de componentes de PC. Es el **tercer repo**
del entregable: aquí vive el origen de identidad contra el que el backend valida
las credenciales antes de firmar el JWT.

## Contenido

| Archivo | Rol |
|---|---|
| `Dockerfile` | Imagen `osixia/openldap:1.5.0` + hashing de contraseñas con `slappasswd` |
| `bootstrap/10-people.ldif` | Seeds del directorio (personas + cuenta de servicio) |

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
