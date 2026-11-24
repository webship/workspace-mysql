#!/usr/bin/env bash

# MySQL, for the Webship Workspace (@webship.co/workspace-mysql, an engine of @webship.co/workspace-database): the
# database of a project whose database is MySQL, on the runtime the project is on.
#
# A project's database is reached the three ways the dashboard's DATABASE menu reads it:
#   - DDEV: the project's `db` service, through `ddev mysql`, `ddev export-db`, `ddev import-db` and `ddev exec -s db`;
#   - a project the Workspace built on another runtime (an x-webship block): the same verbs, which the runtime layer
#     (core/scripts/functions/fun-runtime.sh) gives their meaning, once it builds MySQL (it builds MariaDB only so far);
#   - a compose file of the project's own, which the layer does not run: the database's service, through
#     `docker compose`, the way the Docker Compose plugin runs that file's own verbs.
# Nothing here is a person's: the client logs in with what the database's container was made with.

# How the client logs in, read in the database's container: its MYSQL_* user and password (the official image's,
# Bitnami's, Docksal's), root with its password when only that is given, else the container's own option file
# (DDEV's database: root). The password goes in MYSQL_PWD, where MySQL's clients take it without the warning a
# password on the command line prints each time; a container with an option file of its own (which MYSQL_PWD would
# not win over) gets it on the command line. The database: the one the container names, else db, else the first one the server has that
# is not its own. Sets $c (the client), $dump (the dump tool), $d (the database) and the client's login as "$@". It is
# expanded in the container, so it stays in single quotes here.
MYSQL_DB_LOGIN='c="$(command -v mysql || command -v mariadb)"; dump="$(command -v mysqldump || command -v mariadb-dump)"; u="${MYSQL_USER:-${MARIADB_USER:-}}"; p="${MYSQL_PASSWORD:-${MARIADB_PASSWORD:-}}"; d="${MYSQL_DATABASE:-${MARIADB_DATABASE:-}}"; r="${MYSQL_ROOT_PASSWORD:-${MARIADB_ROOT_PASSWORD:-}}"; w=""; if [ -n "$u" ]; then set -- -u"$u"; w="$p"; elif [ -n "$r" ]; then set -- -uroot; w="$r"; else set --; fi; if [ -n "$w" ]; then if [ -f "$HOME/.my.cnf" ]; then set -- "$@" --password="$w"; else export MYSQL_PWD="$w"; fi; fi; [ -n "$d" ] || d="$("$c" "$@" -N -B -e "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN (\"information_schema\", \"mysql\", \"performance_schema\", \"sys\") ORDER BY schema_name <> \"db\", schema_name LIMIT 1")";'

# The engines a project's database can be, as people write them.
function mysql_engine_title() {
  case "$1" in
    mariadb) echo 'MariaDB' ;; mysql) echo 'MySQL' ;; postgresql|postgres) echo 'PostgreSQL' ;; sqlite) echo 'SQLite' ;; *) echo "$1" ;;
  esac
}

# The runtimes, as people write them.
function mysql_runtime_title() {
  case "$1" in
    ddev) echo 'DDEV' ;; docker) echo 'Docker Compose' ;; podman) echo 'Podman' ;; kubernetes) echo 'Kubernetes' ;;
    lando) echo 'Lando' ;; docksal) echo 'Docksal' ;; *) echo "$1" ;;
  esac
}

# A value for a line of shell, in single quotes.
function mysql_q() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")" ;
}

# The database of a DDEV project, as `<type> <version>` (DDEV's default: mariadb 10.11), or `omitted` when its
# config omits the db container. config.yaml first, then the config.*.yaml DDEV merges over it, in its order.
function mysql_ddev_database() {
  local dir="$1/.ddev" f t v type="" version="" omitted="" ;
  for f in "${dir}/config.yaml" $(ls "${dir}"/config.*.yaml 2> /dev/null | sort) ; do
    [ -f "${f}" ] || continue ;
    t="$(sed -n '/^database:/,/^[^[:space:]#]/s/^[[:space:]]\{1,\}type:[[:space:]]*["'"'"']\{0,1\}\([A-Za-z0-9_.-]*\).*/\1/p' "${f}" | head -1)" ;
    v="$(sed -n '/^database:/,/^[^[:space:]#]/s/^[[:space:]]\{1,\}version:[[:space:]]*["'"'"']\{0,1\}\([A-Za-z0-9_.-]*\).*/\1/p' "${f}" | head -1)" ;
    [ -n "${t}" ] && type="${t}" ;
    [ -n "${v}" ] && version="${v}" ;
    if sed -n '/^omit_containers:/,/^[^[:space:]#-]/p' "${f}" | grep -qE '(^|[^A-Za-z0-9_-])db([^A-Za-z0-9_-]|$)' ; then omitted=yes ; fi
  done
  [ -n "${omitted}" ] && { echo 'omitted' ; return 0 ; } ;
  [ -z "${type}" ] && [ -z "${version}" ] && { echo 'mariadb 10.11' ; return 0 ; } ;
  echo "${type:-mariadb} ${version}" ;
}

# The engine and version a runtime layer's block names: the version of its MariaDB ("10.11"), or another engine before
# a colon ("postgres:16"), as `<engine> <version>`.
function mysql_layer_database() {
  local value="$1" ;
  [ -z "${value}" ] && { echo 'mariadb 10.11' ; return 0 ; } ;
  case "${value}" in
    *:*) local e="${value%%:*}" ; [ "${e}" = postgres ] && e=postgresql ; echo "${e} ${value#*:}" ;;
    *) echo "mariadb ${value}" ;;
  esac
}

# Each service of a compose file and its image, as `<service> <image>`, read without a YAML parser: the keys one level
# under `services:` and an `image:` one level further in. The dashboard names the service it means (--service).
function mysql_compose_services() {
  awk '
    /^services:[[:space:]]*$/ { inside = 1 ; svc = "" ; level = -1 ; next }
    inside && /^[^[:space:]#]/ { inside = 0 }
    !inside || /^[[:space:]]*(#|$)/ { next }
    {
      match($0, /^[[:space:]]*/) ; ind = RLENGTH ;
      if (level < 0) level = ind ;
      if (ind == level && $0 ~ /^[[:space:]]*[A-Za-z0-9._-]+:[[:space:]]*$/) { svc = $1 ; sub(/:$/, "", svc) ; next }
      if (ind > level && svc != "" && $1 == "image:") { img = $2 ; gsub(/["\047]/, "", img) ; print svc, img }
    }' "$1" ;
}

# Is an image MySQL's (the official one, mysql/mysql-server, Percona Server, their Bitnami and Docksal builds)? Its name,
# without a registry or a tag.
function mysql_is_my_image() {
  local ref="${1%%@*}" ; ref="${ref##*/}" ;
  case "${ref%%:*}" in mysql|mysql-server|percona|percona-server) return 0 ;; esac
  return 1 ;
}

# The version an image's tag says: mysql:8.4.3 is 8.4, mysql:8 is 8, no tag says none.
function mysql_image_version() {
  local ref="${1%%@*}" tag="" ; ref="${ref##*/}" ;
  case "${ref}" in *:*) tag="${ref#*:}" ;; esac
  [[ "${tag}" =~ ^([0-9]+)(\.([0-9]+))? ]] && echo "${BASH_REMATCH[1]}${BASH_REMATCH[3]:+.${BASH_REMATCH[3]}}" ;
}

# Where the project's MySQL runs, as `<via>|<runtime>|<service>|<version>|<compose file>` (via: ddev, layer or
# compose), or why it does not, on stderr: another engine, no database, a runtime file whose engine is not read yet.
function mysql_locate() {
  local dir="$1" want="${2:-}" found="" rt="" engine="" version="" ;
  [ "${want}" = '_none_' ] && want="" ;
  if declare -f rt_find_project > /dev/null ; then found="$(rt_find_project "${dir}" 2> /dev/null)" || found="" ; fi
  # A project above this folder is not this one.
  [ -n "${found}" ] && [ "${found#* }" != "${dir}" ] && found="" ;
  # A workspace whose core has no runtime layer yet: DDEV.
  [ -z "${found}" ] && [ -f "${dir}/.ddev/config.yaml" ] && found="ddev ${dir}" ;
  if [ -n "${found}" ] ; then
    rt="${found%% *}" ;
    if [ "${rt}" = ddev ] ; then
      read -r engine version <<< "$(mysql_ddev_database "${dir}")" ;
      [ "${engine}" = omitted ] && { echo "${PROJECT_NAME} has no database: its DDEV config omits the db container." >&2 ; return 1 ; } ;
    else
      if [ -z "$(rt_meta runtime "${dir}")" ] ; then
        echo "${PROJECT_NAME} runs on a $(mysql_runtime_title "${rt}") file of its own: the database it holds is not read yet." >&2 ;
        return 1 ;
      fi
      read -r engine version <<< "$(mysql_layer_database "$(rt_meta database "${dir}")")" ;
    fi
    if [ "${engine}" != mysql ] ; then
      echo "The database of ${PROJECT_NAME} is $(mysql_engine_title "${engine}")${version:+ ${version}} ($(mysql_runtime_title "${rt}")), not MySQL: its tool is cmd-tools-${engine/postgres/postgresql}.sh." >&2 ;
      return 1 ;
    fi
    echo "$( [ "${rt}" = ddev ] && echo ddev || echo layer )|${rt}|db|${version}|" ;
    return 0 ;
  fi
  # A compose file of the project's own: the service asked for, else the first MySQL one.
  local f svc img ;
  for f in compose.yaml compose.yml docker-compose.yml docker-compose.yaml ; do
    [ -f "${dir}/${f}" ] || continue ;
    while read -r svc img ; do
      [ -n "${want}" ] && [ "${svc}" != "${want}" ] && continue ;
      if mysql_is_my_image "${img}" ; then echo "compose|docker|${svc}|$(mysql_image_version "${img}")|${f}" ; return 0 ; fi
      [ -n "${want}" ] && { echo "The service ${want} of ${f} is not MySQL (${img})." >&2 ; return 1 ; } ;
    done < <(mysql_compose_services "${dir}/${f}") ;
    echo "${f} of ${PROJECT_NAME} has no MySQL service${want:+ named ${want}}." >&2 ;
    return 1 ;
  done
  echo "${PROJECT_NAME} has no MySQL: no DDEV config, no file of the Workspace's runtime layer, no compose file with a MySQL service." >&2 ;
  return 1 ;
}

# A line of shell in the database's container: through `ddev exec` on DDEV and on the runtime layer (in /, which every
# image has), through `docker compose exec` for a compose file of the project's own. -t: a terminal of its own.
function mysql_in_db() {
  local tty="" ;
  [ "$1" = '-t' ] && { tty=yes ; shift ; } ;
  if [ "${MYSQL_DB_VIA}" = compose ] ; then
    if [ -n "${tty}" ] && [ -t 0 ] ; then docker compose -f "${MYSQL_DB_COMPOSE}" exec "${MYSQL_DB_SERVICE}" sh -c "$1" ;
    else docker compose -f "${MYSQL_DB_COMPOSE}" exec -T "${MYSQL_DB_SERVICE}" sh -c "$1" ; fi
  else
    ddev exec -s "${MYSQL_DB_SERVICE}" -d / "$1" ;
  fi
}

# SQL through the client in the database's container. $1: the client's flags (-t a table, -N -B tab-separated lines).
function mysql_sql() {
  mysql_in_db "${MYSQL_DB_LOGIN} \"\$c\" \"\$@\" $1 \"\$d\" -e $(mysql_q "$2")" ;
}

# Where this machine's clients reach the database.
function mysql_connect_line() {
  local port="" ;
  case "${MYSQL_DB_VIA}" in
    ddev)
      port="$(ddev describe -j 2> /dev/null | python3 -c 'import json,sys
try: print((json.load(sys.stdin)["raw"].get("dbinfo") or {}).get("published_port") or "")
except Exception: pass' 2> /dev/null)" ;
      if [ -n "${port}" ] ; then echo "A client on this machine: host 127.0.0.1, port ${port}, user db, password db, database db (root: root). The port changes when the project restarts." ;
      else echo "A client on this machine: start the project, and DDEV publishes the database on a port (ddev describe)." ; fi ;;
    compose)
      port="$(docker compose -f "${MYSQL_DB_COMPOSE}" port "${MYSQL_DB_SERVICE}" 3306 2> /dev/null | tail -1)" ;
      # An unpublished port is answered as ":0".
      if [[ "${port}" =~ :[1-9][0-9]*$ ]] ; then echo "A client on this machine: ${port}, with the user and password ${MYSQL_DB_COMPOSE} gives the service ${MYSQL_DB_SERVICE}." ;
      else echo "${MYSQL_DB_COMPOSE} publishes no port of ${MYSQL_DB_SERVICE}: in the project's network it is ${MYSQL_DB_SERVICE}:3306." ; fi ;;
    *) echo "In the project's network: host db, port 3306, user db, password db, database db. $(mysql_runtime_title "${MYSQL_DB_RUNTIME}") publishes no port of the database to this machine." ;;
  esac
}

# --info: what the database is and where it runs.
function mysql_info() {
  echo "Project:   ${doc_name}/${PROJECT_NAME}" ;
  echo "Database:  MySQL${MYSQL_DB_VERSION:+ ${MYSQL_DB_VERSION}} on $(mysql_runtime_title "${MYSQL_DB_RUNTIME}"), service ${MYSQL_DB_SERVICE}${MYSQL_DB_COMPOSE:+ of ${MYSQL_DB_COMPOSE}}" ;
  mysql_sql '-t' "$(mysql_fresh_stats)"'SELECT VERSION() AS `Server`, DATABASE() AS `Database`, CURRENT_USER() AS `User`, @@character_set_database AS `Character set`, @@collation_database AS `Collation`, (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE()) AS `Tables`, (SELECT CONCAT(ROUND(IFNULL(SUM(data_length + index_length), 0) / 1048576, 2), " MB") FROM information_schema.tables WHERE table_schema = DATABASE()) AS `Size`' || return 1 ;
  mysql_connect_line ;
  if [ "${MYSQL_DB_VIA}" = ddev ] ; then
    local t ;
    for t in adminer phpmyadmin ; do
      [ -f ".ddev/docker-compose.${t}.yaml" ] && echo "Web admin: ${t} is added ($(mysql_admin_url "${t}"))." ;
    done
  fi
  return 0 ;
}

# MySQL 8 answers the sizes in information_schema from statistics it keeps for a day (information_schema_stats_expiry):
# a session that lists tables asks for them as they are now. MySQL 5.7 has no such cache, and no such variable.
function mysql_fresh_stats() {
  local v ;
  v="$(mysql_sql '-N -B' 'SELECT @@version' 2> /dev/null | tr -dc '0-9.\n' | head -1)" ;
  [ "${v%%.*}" -ge 8 ] 2> /dev/null && printf '%s' 'SET SESSION information_schema_stats_expiry = 0; ' ;
}

# --tables: the tables, largest first. With --tsv: name, rows and bytes, separated by tabs.
function mysql_tables() {
  local fresh ; fresh="$(mysql_fresh_stats)" ;
  if [ "${TSV}" = yes ] ; then
    mysql_sql '-N -B' "${fresh}SELECT table_name, IFNULL(table_rows, ''), IFNULL(data_length + index_length, '') FROM information_schema.tables WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE' ORDER BY data_length + index_length DESC, table_name" ;
    return $? ;
  fi
  mysql_sql '-t' "${fresh}SELECT table_name AS \`Table\`, table_rows AS \`Rows (estimate)\`, CONCAT(ROUND((data_length + index_length) / 1048576, 2), ' MB') AS \`Size\`, engine AS \`Engine\` FROM information_schema.tables WHERE table_schema = DATABASE() AND table_type = 'BASE TABLE' ORDER BY data_length + index_length DESC, table_name; SELECT COUNT(*) AS \`Tables\`, CONCAT(ROUND(IFNULL(SUM(data_length + index_length), 0) / 1048576, 2), ' MB') AS \`In all\` FROM information_schema.tables WHERE table_schema = DATABASE()" ;
}

# --running: what runs now, longest first, and the slow statements the server counted.
function mysql_running() {
  local now ;
  now="$(mysql_sql '-N -B' "SELECT COUNT(*) FROM information_schema.processlist WHERE command NOT IN ('Sleep', 'Daemon') AND user <> 'event_scheduler' AND id <> CONNECTION_ID()")" || return 1 ;
  if [ "$(printf '%s' "${now}" | tr -dc '0-9')" = 0 ] ; then
    echo "No statement runs now, besides this one." ;
  else
    mysql_sql '-t' "SELECT id AS \`Id\`, user AS \`User\`, db AS \`Database\`, command AS \`Command\`, time AS \`Seconds\`, state AS \`State\`, LEFT(REPLACE(IFNULL(info, ''), '\\n', ' '), 160) AS \`Statement\` FROM information_schema.processlist WHERE command NOT IN ('Sleep', 'Daemon') AND user <> 'event_scheduler' AND id <> CONNECTION_ID() ORDER BY time DESC" || return 1 ;
  fi
  mysql_sql '-t' "SHOW GLOBAL STATUS LIKE 'Slow_queries'; SELECT @@slow_query_log AS \`Slow query log on\`, @@long_query_time AS \`Slow after (seconds)\`" ;
}

# This project's exports past the keep: setting go, the oldest first.
function mysql_keep() {
  local keep="${plugin_mysql_keep:-0}" dir="${backups}/${doc_name}" old ;
  [[ "${keep}" =~ ^[0-9]+$ ]] && [ "${keep}" -gt 0 ] || return 0 ;
  ls -1t "${dir}/${PROJECT_NAME}--mysql--"*.sql.gz 2> /dev/null | tail -n +$(( keep + 1 )) | while read -r old ; do
    rm -f "${old:?}" && echo "Removed an older export (keep: ${keep}): $(basename "${old}")" ;
  done
}

# --export: a dump into the backups folder (or --file). $1: the file ('' for the backups folder), $2: what it is for.
function mysql_export() {
  local file="$1" what="${2:-}" ;
  if [ -z "${file}" ] ; then
    mkdir -p "${backups}/${doc_name}" || return 1 ;
    file="${backups}/${doc_name}/${PROJECT_NAME}--mysql--${what:+${what}--}$(date -u +%Y-%m-%d-%H-%M-%S).sql.gz" ;
  fi
  case "${file}" in *.sql.gz) ;; *) echo "An export is a .sql.gz file: ${file}" ; return 1 ;; esac
  echo "Exporting the MySQL database of ${PROJECT_NAME} ($(mysql_runtime_title "${MYSQL_DB_RUNTIME}")) to ${file}" ;
  if [ "${MYSQL_DB_VIA}" = compose ] ; then
    mysql_in_db "${MYSQL_DB_LOGIN} exec \"\$dump\" \"\$@\" --single-transaction --routines --triggers --add-drop-table --no-tablespaces \"\$d\"" | gzip > "${file}" ;
    [ "${PIPESTATUS[0]}" -eq 0 ] || { rm -f "${file:?}" ; echo "The export failed." ; return 1 ; } ;
  else
    ddev export-db --file="${file}" || { rm -f "${file:?}" ; echo "The export failed." ; return 1 ; } ;
  fi
  # A dump with nothing in it is no export: a database that does not answer still leaves a few bytes of gzip.
  if [ -z "$(gunzip -c "${file}" 2> /dev/null | head -c 64 | tr -d '\0')" ] ; then
    rm -f "${file:?}" ;
    echo "The export is empty: is ${PROJECT_NAME} running?" ;
    return 1 ;
  fi
  echo "Exported: ${file} ($(du -h "${file}" | cut -f1))" ;
  mysql_keep ;
}

# --import <file>: the database as it is, exported first; then emptied and filled from the dump. DDEV's import-db
# empties it itself.
function mysql_import() {
  local file="$1" ;
  case "${file}" in /*) ;; *) file="${current_path:-$PWD}/${file}" ;; esac
  [ -f "${file}" ] || { echo "No such file: ${file}" ; return 1 ; } ;
  case "${file}" in *.sql|*.sql.gz) ;; *) echo "A MySQL dump is a .sql or .sql.gz file: ${file}" ; return 1 ;; esac
  if [ "${NO_SAFETY_EXPORT}" != yes ] ; then
    mysql_export '' before-import || { echo "The export of the database as it is failed: nothing was imported." ; return 1 ; } ;
  fi
  echo "Importing $(basename "${file}") into the MySQL database of ${PROJECT_NAME} ($(mysql_runtime_title "${MYSQL_DB_RUNTIME}"))" ;
  if [ "${MYSQL_DB_VIA}" = ddev ] ; then
    ddev import-db --file="${file}" || return 1 ;
  else
    # Emptied first, as DDEV does, keeping the database's character set and collation: a table the dump does not
    # have would stay otherwise.
    mysql_in_db "${MYSQL_DB_LOGIN}"' cs="$("$c" "$@" -N -B -e "SELECT CONCAT(default_character_set_name, \" \", default_collation_name) FROM information_schema.schemata WHERE schema_name = \"$d\"")"; extra=""; [ -n "$cs" ] && extra=" CHARACTER SET ${cs% *} COLLATE ${cs#* }"; "$c" "$@" -e "DROP DATABASE IF EXISTS \`$d\`; CREATE DATABASE \`$d\`$extra"' || { echo "The database could not be emptied: nothing was imported." ; return 1 ; } ;
    if [ "${MYSQL_DB_VIA}" = compose ] ; then
      case "${file}" in *.gz) gunzip -c "${file}" ;; *) cat "${file}" ;; esac | mysql_in_db "${MYSQL_DB_LOGIN} exec \"\$c\" \"\$@\" \"\$d\"" || return 1 ;
    else
      ddev import-db --file="${file}" || return 1 ;
    fi
  fi
  echo "Imported $(basename "${file}")." ;
  [ "${NO_SAFETY_EXPORT}" != yes ] && echo "The database as it was is the before-import export above, in ${backups}/${doc_name}." ;
  return 0 ;
}

# A command with a terminal of its own, when its input is a terminal and its output is not: a screen session of the
# dashboard logs what a command prints through a pipe, and a client with no terminal shows no prompt. util-linux's
# script gives it one; anywhere else the command runs as it is.
function mysql_with_terminal() {
  if [ -t 0 ] && [ ! -t 1 ] && script --version 2> /dev/null | grep -q util-linux ; then
    script -qefc "$(printf '%q ' "$@")" /dev/null ;
  else
    "$@" ;
  fi
}

# --console: the client on the database, in this terminal.
function mysql_console() {
  case "${MYSQL_DB_VIA}" in
    ddev) mysql_with_terminal ddev mysql ;;
    compose)
      if [ -t 0 ] ; then mysql_with_terminal docker compose -f "${MYSQL_DB_COMPOSE}" exec "${MYSQL_DB_SERVICE}" sh -c "${MYSQL_DB_LOGIN} exec \"\$c\" \"\$@\" \"\$d\"" ;
      else mysql_in_db "${MYSQL_DB_LOGIN} exec \"\$c\" \"\$@\" --table --unbuffered \"\$d\"" ; fi ;;
    *)
      echo "MySQL${MYSQL_DB_VERSION:+ ${MYSQL_DB_VERSION}} of ${PROJECT_NAME} on $(mysql_runtime_title "${MYSQL_DB_RUNTIME}"). The runtime gives the client no terminal of its own, so it shows no prompt: type a statement ending with ; and Enter, and Ctrl-D leaves." ;
      mysql_in_db "${MYSQL_DB_LOGIN} exec \"\$c\" \"\$@\" --table --unbuffered \"\$d\"" ;;
  esac
}

# The address of a web admin DDEV added to the project, from DDEV itself.
function mysql_admin_url() {
  ddev describe -j 2> /dev/null | python3 -c 'import json,sys
try:
  s = json.load(sys.stdin)["raw"]["services"].get(sys.argv[1]) or {}
  print(s.get("https_url") or s.get("http_url") or "no address: start the project")
except Exception: print("no address: start the project")' "$1" ;
}

# The official DDEV add-on of a web admin, and its last release for a DDEV older than 1.24.10 (what newer ones ask for).
function mysql_admin_addon() {
  case "$1" in
    adminer) echo 'ddev/ddev-adminer v1.1.4 Adminer' ;;
    phpmyadmin) echo 'ddev/ddev-phpmyadmin v1.0.1 phpMyAdmin' ;;
  esac
}

# The Adminer image the add-on's last release for an older DDEV logs in with. That release fills Adminer 4's login
# itself, and its image tag (standalone) is Adminer 6 now, which shows the login form instead: the project's
# .ddev/.env names Adminer 4 (the add-on reads ADMINER_DOCKER_IMAGE), as long as the add-on is there.
MYSQL_DB_ADMINER_PIN='ADMINER_DOCKER_IMAGE=adminer:4.8.1-standalone'

# --admin <tool>: the add-on in the project, the project restarted, and the address.
function mysql_admin_add() {
  local tool="$1" repo pin label v ;
  read -r repo pin label <<< "$(mysql_admin_addon "${tool}")" ;
  if [ "${MYSQL_DB_VIA}" != ddev ] ; then
    echo "A web admin is a service of its own beside the project: on $( [ "${MYSQL_DB_VIA}" = compose ] && echo "a compose file of the project's own" || mysql_runtime_title "${MYSQL_DB_RUNTIME}") the Workspace cannot add one yet (on DDEV it is the official add-on ${repo})." ;
    return 1 ;
  fi
  if [ -f ".ddev/docker-compose.${tool}.yaml" ] ; then
    echo "${label} is already added to ${PROJECT_NAME}." ;
  else
    v="$(ddev --version 2> /dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)" ;
    if [ -n "${v}" ] && [ "$(printf '%s\n' "${v}" 1.24.10 | sort -V | head -1)" != 1.24.10 ] ; then
      echo "DDEV ${v}: ${repo} ${pin}, its last release for a DDEV older than 1.24.10." ;
      ddev add-on get "${repo}" --version "${pin}" || return 1 ;
      if [ "${tool}" = adminer ] && ! grep -q '^ADMINER_DOCKER_IMAGE=' .ddev/.env 2> /dev/null ; then
        echo "${MYSQL_DB_ADMINER_PIN}" >> .ddev/.env && echo "Adminer 4 in .ddev/.env (${MYSQL_DB_ADMINER_PIN}): the login that release fills in is Adminer 4's." ;
      fi
    else
      ddev add-on get "${repo}" || return 1 ;
    fi
    echo "Restarting ${PROJECT_NAME}, so ${label} runs beside it." ;
    ddev restart || return 1 ;
  fi
  echo "${label}: $(mysql_admin_url "${tool}")" ;
}

# --admin-remove <tool>: the add-on out of the project (and the Adminer line the tool wrote), the project restarted.
function mysql_admin_remove() {
  local tool="$1" repo pin label ;
  read -r repo pin label <<< "$(mysql_admin_addon "${tool}")" ;
  [ "${MYSQL_DB_VIA}" = ddev ] || { echo "Only a DDEV project carries a web admin add-on." ; return 1 ; } ;
  [ -f ".ddev/docker-compose.${tool}.yaml" ] || { echo "${label} is not added to ${PROJECT_NAME}." ; return 0 ; } ;
  ddev add-on remove "${tool}" || return 1 ;
  if [ "${tool}" = adminer ] && [ -f .ddev/.env ] ; then
    sed -i "/^${MYSQL_DB_ADMINER_PIN//./\\.}\$/d" .ddev/.env ;
    [ -s .ddev/.env ] || rm -f .ddev/.env ;
  fi
  echo "Restarting ${PROJECT_NAME} without ${label}." ;
  ddev restart ;
}

# The tool: one action on the MySQL database of a project of this workspace folder.
function mysql_tool() {
  declare -f trim_project_name > /dev/null && trim_project_name ;
  local dir="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" where ;
  [ -d "${dir}" ] || { echo "No such project: ${doc_name}/${PROJECT_NAME}" ; return 1 ; } ;
  dir="$(cd "${dir}" && pwd)" ;
  where="$(mysql_locate "${dir}" "${SERVICE:-}")" || return 1 ;
  IFS='|' read -r MYSQL_DB_VIA MYSQL_DB_RUNTIME MYSQL_DB_SERVICE MYSQL_DB_VERSION MYSQL_DB_COMPOSE <<< "${where}" ;
  cd "${dir}" || return 1 ;
  # A local kind cluster's CLI is often in ~/.local/bin, which a session started by the dashboard may not have.
  case ":${PATH}:" in *":${HOME}/.local/bin:"*) ;; *) [ -d "${HOME}/.local/bin" ] && PATH="${PATH}:${HOME}/.local/bin" ;; esac
  if [ "${CONSOLE}" = yes ] ; then mysql_console ;
  elif [ "${TABLES}" = yes ] ; then mysql_tables ;
  elif [ "${RUNNING}" = yes ] ; then mysql_running ;
  elif [ "${EXPORT}" = yes ] ; then mysql_export "$( [ "${FILE:-_none_}" = '_none_' ] || echo "${FILE}" )" ;
  elif [ "${IMPORT:-_none_}" != '_none_' ] ; then mysql_import "${IMPORT}" ;
  elif [ "${QUERY:-_none_}" != '_none_' ] ; then mysql_sql '-t' "${QUERY}" ;
  elif [ "${ADMIN:-_none_}" != '_none_' ] ; then mysql_admin_add "${ADMIN}" ;
  elif [ "${ADMIN_REMOVE:-_none_}" != '_none_' ] ; then mysql_admin_remove "${ADMIN_REMOVE}" ;
  else mysql_info ; fi
}
