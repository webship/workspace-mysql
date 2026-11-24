/**
 * cmd-tools-mysql.sh's functions against scaffolded projects, with `ddev` and `docker` replaced by recorders: what
 * each flag runs on DDEV, on the runtime layer and on a compose file of the project's own, and the client's login in
 * the database's container, run in a real shell with a stand-in client.
 */
import test, { after } from 'node:test';
import assert from 'node:assert';
import { spawnSync } from 'child_process';
import fs from 'fs';
import os from 'os';
import path from 'path';
import zlib from 'zlib';

// Compiled, this test runs from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUN = path.join(PKG, 'scripts', 'functions', 'fun-mysql.sh');
const ROOT = fs.mkdtempSync(path.join(os.tmpdir(), 'mysql-tool-'));
after(() => fs.rmSync(ROOT, { recursive: true, force: true }));

function write(rel: string, body: string) {
  fs.mkdirSync(path.dirname(path.join(ROOT, rel)), { recursive: true });
  fs.writeFileSync(path.join(ROOT, rel), body);
}

write('dev/shop/.ddev/config.yaml', 'name: shop\ntype: drupal11\ndocroot: web\ndatabase:\n    type: mysql\n    version: "8.0"\n');
write('dev/maria/.ddev/config.yaml', 'name: maria\ntype: php\n');
write('dev/pg/.ddev/config.yaml', 'name: pg\ndatabase:\n  type: postgres\n  version: "16"\n');
write('dev/static/.ddev/config.yaml', 'name: static\nomit_containers:\n  - db\n');
write('dev/layered/compose.yaml', 'name: layered\nx-webship:\n  runtime: docker\n  stack: php\n  database: "mysql:8.0"\n  port: 38001\nservices:\n  db:\n    image: mysql:8.0\n');
write('dev/docked/compose.yaml', 'name: docked\nx-webship:\n  runtime: kubernetes\n  database: "10.11"\n');
write('dev/own/compose.yaml', 'services:\n  app:\n    image: node:22\n  mysql:\n    image: "mysql:8.4.3"\n    environment:\n      MYSQL_ROOT_PASSWORD: x\n');
write('dev/perc/docker-compose.yml', 'services:\n  db:\n    image: percona/percona-server:8.0\n');
write('dev/ownpg/docker-compose.yml', 'services:\n  pg:\n    image: postgres:16\n');
write('dev/landoown/.lando.yml', 'name: landoown\nrecipe: lamp\n');
write('dev/nothing/README.md', '');

/**
 * A shell with the plugin's functions, the two layer functions they ask (as the core's runtime layer answers them),
 * and `ddev`, `docker` and `date` recorded into $LOG. An export's recorder writes a small gzip, so the dump has content.
 */
function run(script: string, env: Record<string, string> = {}, opts: { layer?: boolean; ddevVersion?: string } = {}): { code: number; out: string; log: string[] } {
  const log = path.join(ROOT, `log-${Math.random().toString(36).slice(2)}`);
  const layer = opts.layer === false ? '' : `
function rt_find_project() { local d="\${1:-\$PWD}" ; d="\$(cd "\$d" && pwd)" ;
  while [ "\$d" != / ] ; do
    for f in compose.yaml .lando.yml .docksal/docksal.yml ; do
      if [ -f "\$d/\$f" ] && grep -q '^x-webship:' "\$d/\$f" ; then echo "\$(sed -n '/^x-webship:/,/^[^ ]/s/^  runtime: *//p' "\$d/\$f" | head -1) \$d" ; return 0 ; fi
    done
    [ -f "\$d/.ddev/config.yaml" ] && { echo "ddev \$d" ; return 0 ; } ;
    [ -f "\$d/.lando.yml" ] && { echo "lando \$d" ; return 0 ; } ;
    d="\$(dirname "\$d")" ;
  done ; return 1 ; }
function rt_meta() { local f ; for f in compose.yaml .lando.yml .docksal/docksal.yml ; do [ -f "\$2/\$f" ] && grep -q '^x-webship:' "\$2/\$f" && { sed -n '/^x-webship:/,/^[^ x]/s/^  '"\$1"': *//p' "\$2/\$f" | head -1 | tr -d '"' ; return 0 ; } ; done ; }`;
  const src = `
LOG='${log}'
rec() { printf '%s\\n' "\$*" >> "\$LOG" ; }
function ddev() {
  rec ddev "\$@" ;
  case "\$1" in
    export-db) local f="\${2#--file=}" ; echo 'CREATE TABLE x (id int);' | gzip > "\$f" ;;
    --version) echo 'ddev version v${opts.ddevVersion || '1.24.7'}' ;;
    describe) echo '{"raw":{"dbinfo":{"published_port":32801},"services":{"adminer":{"https_url":"https://shop.ddev.site:9101","status":"running"}}}}' ;;
    exec) [ -n "\${DDEV_EXEC_OUT:-}" ] && printf '%b' "\$DDEV_EXEC_OUT" ;;
  esac
  return 0 ; }
function docker() { rec docker "\$@" ; [ -t 0 ] || cat > /dev/null ; [ -n "\${DOCKER_OUT:-}" ] && printf '%b' "\$DOCKER_OUT" ; return 0 ; }
${layer}
source '${FUN}'
WORKSPACE_ROOT='${ROOT}' ; doc_name=dev ; backups='${ROOT}/backups' ; current_path='${ROOT}'
${script}`;
  const r = spawnSync('bash', ['-c', src], { encoding: 'utf8', env: { PATH: process.env.PATH, HOME: ROOT, ...env } });
  const lines = fs.existsSync(log) ? fs.readFileSync(log, 'utf8').split('\n').filter(Boolean) : [];
  return { code: r.status === null ? -1 : r.status, out: `${r.stdout}${r.stderr}`, log: lines };
}

test('where a project\'s MySQL runs: DDEV, the runtime layer once it builds MySQL, a compose file of its own; another engine or none is said', () => {
  const at = (p: string, want = '') => run(`PROJECT_NAME=${p} ; mysql_locate '${ROOT}/dev/${p}' '${want}'`);
  assert.strictEqual(at('shop').out.trim(), 'ddev|ddev|db|8.0|');
  assert.strictEqual(at('layered').out.trim(), 'layer|docker|db|8.0|');
  assert.strictEqual(at('own').out.trim(), 'compose|docker|mysql|8.4|compose.yaml');
  assert.strictEqual(at('perc').out.trim(), 'compose|docker|db|8.0|docker-compose.yml', 'Percona Server is MySQL');
  assert.match(at('maria').out, /The database of maria is MariaDB 10\.11 \(DDEV\), not MySQL: its tool is cmd-tools-mariadb\.sh\./);
  assert.match(at('pg').out, /The database of pg is PostgreSQL 16 \(DDEV\), not MySQL: its tool is cmd-tools-postgresql\.sh\./);
  assert.match(at('docked').out, /The database of docked is MariaDB 10\.11 \(Kubernetes\), not MySQL/);
  assert.match(at('static').out, /static has no database: its DDEV config omits the db container\./);
  assert.match(at('own', 'app').out, /The service app of compose\.yaml is not MySQL \(node:22\)\./);
  assert.match(at('ownpg').out, /docker-compose\.yml of ownpg has no MySQL service\./);
  assert.match(at('landoown').out, /runs on a Lando file of its own: the database it holds is not read yet\./);
  assert.strictEqual(run(`PROJECT_NAME=shop ; mysql_locate '${ROOT}/dev/shop'`, {}, { layer: false }).out.trim(), 'ddev|ddev|db|8.0|');
});

test('the tables (with MySQL 8\'s statistics asked fresh), the running statements, the info and a query', () => {
  const tsv = run('PROJECT_NAME=shop ; TABLES=yes ; TSV=yes ; DDEV_EXEC_OUT="8.0.36\\n" ; mysql_tool');
  assert.strictEqual(tsv.code, 0, tsv.out);
  assert.strictEqual(tsv.log.length, 2, 'the version, then the tables');
  assert.match(tsv.log[0], /-N -B "\$d" -e 'SELECT @@version'$/);
  assert.match(tsv.log[1], /^ddev exec -s db -d \/ c="\$\(command -v mysql \|\| command -v mariadb\)"; .* -N -B "\$d" -e 'SET SESSION information_schema_stats_expiry = 0; SELECT table_name, IFNULL\(table_rows, /);
  const old = run('PROJECT_NAME=shop ; TABLES=yes ; TSV=yes ; DDEV_EXEC_OUT="5.7.44\\n" ; mysql_tool');
  assert.match(old.log[1], /-e 'SELECT table_name/, 'MySQL 5.7 has no statistics to ask fresh');
  const own = run('PROJECT_NAME=own ; RUNNING=yes ; mysql_tool');
  assert.match(own.log[0], /^docker compose -f compose\.yaml exec -T mysql sh -c .* -N -B "\$d" -e 'SELECT COUNT\(\*\) FROM information_schema\.processlist WHERE command NOT IN /);
  assert.match(own.log[0], /AND user <> .{1,6}event_scheduler/);
  const idle = run('PROJECT_NAME=shop ; RUNNING=yes ; DDEV_EXEC_OUT="0\\n" ; mysql_tool');
  assert.match(idle.out, /No statement runs now, besides this one\./);
  const info = run('PROJECT_NAME=shop ; INFO=yes ; mysql_tool');
  assert.match(info.out, /Database:  MySQL 8\.0 on DDEV, service db/);
  assert.match(info.out, /A client on this machine: host 127\.0\.0\.1, port 32801, user db, password db, database db/);
  const q = run(`PROJECT_NAME=shop ; QUERY="SELECT 1" ; mysql_tool`);
  assert.match(q.log[0], /-t "\$d" -e 'SELECT 1'$/);
});

test('an export goes to the backups folder with the engine in its name; a dump of a compose file of its own skips the tablespaces an application user may not read', () => {
  const ddev = run('PROJECT_NAME=shop ; EXPORT=yes ; mysql_tool');
  assert.strictEqual(ddev.code, 0, ddev.out);
  assert.match(ddev.log[0], new RegExp(`^ddev export-db --file=${ROOT}/backups/dev/shop--mysql--\\d{4}-\\d\\d-\\d\\d-\\d\\d-\\d\\d-\\d\\d\\.sql\\.gz$`));
  ['2026-01-01-00-00-00', '2026-01-02-00-00-00', '2026-01-03-00-00-00'].forEach((s, i) => {
    write(`backups/dev/shop--mysql--${s}.sql.gz`, 'x');
    const t = new Date(Date.UTC(2026, 0, 1 + i));
    fs.utimesSync(path.join(ROOT, 'backups', 'dev', `shop--mysql--${s}.sql.gz`), t, t);
  });
  const kept = run('PROJECT_NAME=shop ; EXPORT=yes ; plugin_mysql_keep=2 ; mysql_tool');
  assert.strictEqual(fs.readdirSync(path.join(ROOT, 'backups', 'dev')).filter((f) => f.startsWith('shop--mysql--')).length, 2);
  assert.match(kept.out, /Removed an older export \(keep: 2\): shop--mysql--2026-01-01-00-00-00\.sql\.gz/);
  const own = run('PROJECT_NAME=own ; EXPORT=yes ; DOCKER_OUT="-- MySQL dump\\nCREATE TABLE t (id int);\\n" ; mysql_tool');
  assert.strictEqual(own.code, 0, own.out);
  assert.match(own.log[0], /^docker compose -f compose\.yaml exec -T mysql sh -c .*exec "\$dump" "\$@" --single-transaction --routines --triggers --add-drop-table --no-tablespaces "\$d"$/);
  assert.match(run('PROJECT_NAME=own ; EXPORT=yes ; mysql_tool').out, /The export is empty: is own running\?/);
});

test('an import exports the database as it is first, empties it off DDEV, and takes only a dump', () => {
  fs.mkdirSync(path.join(ROOT, 'dumps'), { recursive: true });
  fs.writeFileSync(path.join(ROOT, 'dumps', 'in.sql.gz'), zlib.gzipSync('CREATE TABLE t (id int);\n'));
  const ddev = run(`PROJECT_NAME=shop ; IMPORT='${ROOT}/dumps/in.sql.gz' ; mysql_tool`);
  assert.strictEqual(ddev.code, 0, ddev.out);
  assert.match(ddev.log[0], /^ddev export-db --file=.*\/backups\/dev\/shop--mysql--before-import--.*\.sql\.gz$/);
  assert.strictEqual(ddev.log[1], `ddev import-db --file=${ROOT}/dumps/in.sql.gz`);
  const own = run(`PROJECT_NAME=own ; IMPORT='dumps/in.sql.gz' ; NO_SAFETY_EXPORT=yes ; mysql_tool`);
  assert.strictEqual(own.code, 0, own.out);
  assert.match(own.log[0], /"\$c" "\$@" -e "DROP DATABASE IF EXISTS \\`\$d\\`; CREATE DATABASE \\`\$d\\`\$extra"$/);
  assert.match(own.log[1], /^docker compose -f compose\.yaml exec -T mysql sh -c .*exec "\$c" "\$@" "\$d"$/);
  assert.match(run(`PROJECT_NAME=shop ; IMPORT='${ROOT}/dev/shop/.ddev/config.yaml' ; mysql_tool`).out, /A MySQL dump is a \.sql or \.sql\.gz file/);
});

test('the console: DDEV\'s own client; docker compose for a file of its own', () => {
  assert.deepStrictEqual(run('PROJECT_NAME=shop ; CONSOLE=yes ; mysql_tool').log, ['ddev mysql']);
  assert.match(run('PROJECT_NAME=own ; CONSOLE=yes ; mysql_tool').log[0], /^docker compose -f compose\.yaml exec -T mysql sh -c .*--table --unbuffered "\$d"$/, 'no terminal here, so -T');
  const layer = run('PROJECT_NAME=layered ; CONSOLE=yes ; mysql_tool');
  assert.match(layer.out, /The runtime gives the client no terminal of its own, so it shows no prompt/);
});

test('a web admin: the official add-on on DDEV, its last release for a DDEV older than 1.24.10, and a restart; refused elsewhere', () => {
  const old = run('PROJECT_NAME=shop ; ADMIN=adminer ; mysql_tool');
  assert.strictEqual(old.code, 0, old.out);
  assert.deepStrictEqual(old.log.slice(0, 3), ['ddev --version', 'ddev add-on get ddev/ddev-adminer --version v1.1.4', 'ddev restart']);
  assert.strictEqual(fs.readFileSync(path.join(ROOT, 'dev', 'shop', '.ddev', '.env'), 'utf8'), 'ADMINER_DOCKER_IMAGE=adminer:4.8.1-standalone\n');
  const fresh = run('PROJECT_NAME=shop ; ADMIN=phpmyadmin ; mysql_tool', {}, { ddevVersion: '1.25.4' });
  assert.deepStrictEqual(fresh.log.slice(0, 3), ['ddev --version', 'ddev add-on get ddev/ddev-phpmyadmin', 'ddev restart']);
  write('dev/shop/.ddev/docker-compose.adminer.yaml', 'services: {}\n');
  assert.deepStrictEqual(run('PROJECT_NAME=shop ; ADMIN_REMOVE=adminer ; mysql_tool').log, ['ddev add-on remove adminer', 'ddev restart']);
  assert.ok(!fs.existsSync(path.join(ROOT, 'dev', 'shop', '.ddev', '.env')));
  const own = run('PROJECT_NAME=own ; ADMIN=adminer ; mysql_tool');
  assert.strictEqual(own.code, 1);
  assert.match(own.out, /on a compose file of the project's own the Workspace cannot add one yet/);
});

test('the client\'s login in the database\'s container: the container\'s user, root with its password, or its own option file', () => {
  const bin = path.join(ROOT, 'bin');
  fs.mkdirSync(bin, { recursive: true });
  fs.writeFileSync(path.join(bin, 'mysql'), '#!/bin/sh\ncase "$*" in *schema_name*) echo firstdb ;; *) echo "ARGS $* PWD=${MYSQL_PWD:-}" ;; esac\n', { mode: 0o755 });
  const login = (env: Record<string, string>) => {
    const r = spawnSync('bash', ['-c', `source '${FUN}' ; sh -c "\${MYSQL_DB_LOGIN} \\"\\$c\\" \\"\\$@\\" -N -B \\"\\$d\\" -e 'SELECT 1'"`], { encoding: 'utf8', env: { PATH: `${bin}:/usr/bin:/bin`, HOME: path.join(ROOT, env.WITH_MY_CNF ? 'home-cnf' : 'home'), ...env } });
    return r.stdout.trim();
  };
  fs.mkdirSync(path.join(ROOT, 'home-cnf'), { recursive: true });
  fs.writeFileSync(path.join(ROOT, 'home-cnf', '.my.cnf'), '[client]\nuser=root\n');
  assert.strictEqual(login({ MYSQL_USER: 'app', MYSQL_PASSWORD: 'secret', MYSQL_DATABASE: 'shop' }), 'ARGS -uapp -N -B shop -e SELECT 1 PWD=secret', 'the password in MYSQL_PWD, not on the command line');
  assert.strictEqual(login({ MYSQL_ROOT_PASSWORD: 'root-pass' }), 'ARGS -uroot -N -B firstdb -e SELECT 1 PWD=root-pass');
  assert.strictEqual(login({ MYSQL_USER: 'app', MYSQL_PASSWORD: 'secret', MYSQL_DATABASE: 'shop', WITH_MY_CNF: '1' }), 'ARGS -uapp --password=secret -N -B shop -e SELECT 1 PWD=', 'an option file of the container\'s own would win over MYSQL_PWD');
  assert.strictEqual(login({}), 'ARGS -N -B firstdb -e SELECT 1 PWD=', 'DDEV\'s database: its own option file logs in');
});
