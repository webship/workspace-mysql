---
name: mysql-database
description: The MySQL database of a Webship Workspace project, as the MySQL plugin (`@webship.co/workspace-mysql`) gives it — which project's database is MySQL and where it runs (DDEV, a compose file of the project's own), every entry of the DATABASE menu and the `cmd-tools-mysql.sh` flag it runs, the exports and imports in the backups folder, the web admins on DDEV, and the plugin's settings. Use when a person asks about a project's MySQL, its console, its size, its tables, an export or an import, Adminer or phpMyAdmin, or what the DATABASE menu does.
---

# MySQL in a Webship Workspace

The Webship Workspace is container-based (DDEV by default). The MySQL plugin (`@webship.co/workspace-mysql`, an
engine of `@webship.co/workspace-database`) puts a **DATABASE** menu on every project row whose database is MySQL,
and places its tool, `cmd-tools-mysql.sh`, into every sites folder (dev, test, demos, sandboxes, projects, …).
Every entry of the menu runs that tool in a screen session, from the project's workspace folder.

## Which projects

| The project carries | Its MySQL |
| --- | --- |
| `.ddev/config.yaml` | `database.type: mysql` (`ddev config --database=mysql:8.0`) |
| A compose file of its own | A service whose image is `mysql`, `mysql/mysql-server` or Percona Server (or their Bitnami or Docksal builds) |
| An `x-webship:` block (a builder run with `--runtime`) | The block's `database` value naming MySQL (`mysql:8.0`), once the runtime layer builds MySQL: today it builds MariaDB only |

The row's caption says it: `MySQL 8.0`. A project whose database is MariaDB or PostgreSQL gets that plugin's
section in the same menu, with that plugin installed.

## The DATABASE menu

| Entry | The tool's flag | What it does |
| --- | --- | --- |
| Console (mysql) | `--console` | The client on the database: `ddev mysql` on DDEV; elsewhere the client in the database's container |
| Tables and sizes | `--tables` (the modal reads `--tables --tsv`) | The tables, largest first, with rows (MySQL's estimate) and size. Reads only |
| Export to the backups folder | `--export` | `<backups>/<folder>/<project>--mysql--<when>.sql.gz`, beside the dumps the row's own Export writes |
| Import a dump… | `--import <file>` | Lists the dumps of the backups folder; asks first; exports the database as it is, then replaces it |
| Running statements | `--running` | What runs now, longest first; the server's count of slow statements; whether the slow query log is on. Reads only |
| Connection details | `--info` | Engine, version, runtime, service, database, user, size, and how a client on this machine connects |
| Add Adminer, Add phpMyAdmin | `--admin adminer`, `--admin phpmyadmin` | DDEV only: the official add-on (ddev/ddev-adminer, ddev/ddev-phpmyadmin), and a restart |
| Open Adminer, Open phpMyAdmin | | The address DDEV gives the add-on |
| Remove Adminer, Remove phpMyAdmin | `--admin-remove <tool>` | Takes the add-on out and restarts the project; asks first |

The tool also takes `--query "<statement>"` (prints what it answers), `--file <path>` with `--export`,
`--no-safety-export` with `--import`, and `--service <name>` for a compose file of the project's own. Run
`bash cmd-tools-mysql.sh <project> --help` for every flag.

```bash
cd ~/workspace/<folder>
bash cmd-tools-mysql.sh <project>                    # --info
bash cmd-tools-mysql.sh <project> --tables
bash cmd-tools-mysql.sh <project> --export
bash cmd-tools-mysql.sh <project> --import ~/workspace/backups/<folder>/<project>--mysql--<when>.sql.gz
```

## Runtimes

| | DDEV | A compose file of the project's own | Docker Compose, Podman, Kubernetes, Lando, Docksal built by the Workspace |
| --- | --- | --- | --- |
| Reached through | DDEV's verbs | `docker compose exec` on the service | Not yet: the runtime layer builds MariaDB only |
| The console | DDEV's own client, with a prompt | The client, with a prompt | |
| A web admin | Adminer, phpMyAdmin (add-ons) | Not yet: the Workspace cannot add a service to a project there | |

An import empties the database first everywhere (DDEV's import-db does it on DDEV), so a table the dump does not have
does not stay.

## The settings

`core/config/plugin.mysql.settings.yml`, also on the plugin's page in Settings:

| Key | What it is |
| --- | --- |
| `admin:` | The web admins the menu offers: `both` (the default), `adminer`, `phpmyadmin`, or `none` |
| `keep:` | How many exports of one project the backups folder keeps; the oldest go when a new one is made. `0` keeps every one |

## Good to know

- The exports carry the engine in their name, so the Import list of a PostgreSQL project never offers a MySQL dump.
- A project that is stopped has no database to ask: the tool says so. Start it first.
- The tool never prints a password other than the project's own `db` one, and never copies a dump out of the workspace.
