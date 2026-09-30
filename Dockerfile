FROM osixia/openldap:1.5.0

# Bootstrap LDIFs are applied by the image on the first boot of the volume.
# The numeric prefixes control the order, and it matters: 10 adds the entries,
# 20 replaces the access rules that Debian's slapd package installs by default.
COPY bootstrap/10-people.ldif /container/service/slapd/assets/config/bootstrap/ldif/custom/10-people.ldif
COPY bootstrap/20-acl.ldif   /container/service/slapd/assets/config/bootstrap/ldif/custom/20-acl.ldif

# The committed LDIF carries placeholders, never real hashes, so the repository
# does not depend on a particular salt. They are filled in here so the directory
# stores SSHA digests instead of plain-text passwords.
#
# Be aware of what this does and does not achieve: the passwords below are
# visible in the image's build history. That is acceptable because they are
# throwaway lab credentials committed to a public teaching repository, not real
# secrets. The property worth keeping is that the running directory never holds
# a reversible password, and that the LDIF in git has no environment-specific
# values baked into it.
RUN hash_juan="$(slappasswd -s 'LabPass-@juan' -h '{SSHA}')" \
    && hash_maria="$(slappasswd -s 'LabPass-@maria' -h '{SSHA}')" \
    && hash_svc="$(slappasswd -s 'SvcPcshop-@2026' -h '{SSHA}')" \
    && sed -i \
        -e "s|__JUAN_PW__|$hash_juan|" \
        -e "s|__MARIA_PW__|$hash_maria|" \
        -e "s|__SVC_PW__|$hash_svc|" \
        /container/service/slapd/assets/config/bootstrap/ldif/custom/10-people.ldif
