# @webship.co/workspace-mysql

MySQL for the [Webship Workspace](https://github.com/webship/workspace), the container-based development workspace
(DDEV by default): the **DATABASE** menu on every project row whose database is MySQL, and its tool,
`cmd-tools-mysql.sh`, on DDEV and on a compose file of the project's own. An engine of
[`@webship.co/workspace-database`](https://github.com/webship/workspace-database), which draws the menu.

A project's database is MySQL when its DDEV config says so (`ddev config --database=mysql:8.0`, or 5.7, 8.4), or
when a compose file it carries runs MySQL (`mysql`, `mysql/mysql-server`, Percona Server). Percona Server is MySQL
here.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require github:webship/workspace-mysql
bash core/scripts/plugins.sh --activate mysql --with-needs
bash core/scripts/plugins.sh --install mysql
```

The install places `cmd-tools-mysql.sh` into every sites folder (dev, test, demos, sandboxes, projects, …), its
bash functions and arguments under `core/scripts/plugins/mysql/`, its settings file, its AI items and its webship-js
feature. Restart the dashboard to load it.

## The DATABASE menu

On a row whose database is MySQL, the caption says `MySQL <version>`, and the menu holds:

| Entry | The tool's flag | What it does |
| --- | --- | --- |
| Console (mysql) | `--console` | The client on the database, in a screen: `ddev mysql` on DDEV, the client in the database's container elsewhere |
| Tables and sizes | `--tables` | The tables, largest first, with rows (MySQL's estimate) and size, in the modal. On MySQL 8 the session asks for the statistics as they are now (MySQL keeps them for a day otherwise) |
| Export to the backups folder | `--export` | `<backups>/<folder>/<project>--mysql--<when>.sql.gz` |
| Import a dump… | `--import <file>` | The dumps of the backups folder, this project's first; asks first; checks that the dump is whole, exports the database as it is, then empties it and imports |
| Running statements | `--running` | What runs now, longest first; the slow statements the server counted; whether its slow query log is on |
| Connection details | `--info` | Engine, version, runtime, service, database, user, size, and how a client on this machine connects |
| Add Adminer, Add phpMyAdmin | `--admin adminer`, `--admin phpmyadmin` | DDEV: the official add-on (`ddev/ddev-adminer`, `ddev/ddev-phpmyadmin`), and a restart |
| Open Adminer, Open phpMyAdmin | | The address DDEV gives the add-on |
| Remove Adminer, Remove phpMyAdmin | `--admin-remove <tool>` | The add-on out, and a restart; asks first |

Each entry runs the tool in a screen session from the project's workspace folder: read it on the Screens page.

**Adding or removing a web admin restarts the project.** DDEV starts the add-on's service beside the project, and on
that restart it also recreates its shared router, so every DDEV site of the machine is unreachable for a few seconds.
Add a web admin when you need one, and leave it there rather than adding and removing it often.

## The tool

```bash
cd ~/workspace/dev
bash cmd-tools-mysql.sh mysite                     # --info: what the database is, and how a client connects
bash cmd-tools-mysql.sh mysite --tables            # the tables, largest first (--tsv: name, rows, bytes)
bash cmd-tools-mysql.sh mysite --running           # what runs now
bash cmd-tools-mysql.sh mysite --console
bash cmd-tools-mysql.sh mysite --query "SELECT COUNT(*) FROM users"
bash cmd-tools-mysql.sh mysite --export            # into the backups folder; --file <path.sql.gz> elsewhere
bash cmd-tools-mysql.sh mysite --import <file>     # .sql or .sql.gz; --no-safety-export skips the export first
bash cmd-tools-mysql.sh mysite --admin adminer     # DDEV: the add-on, a restart, the address
bash cmd-tools-mysql.sh mysite --admin-remove adminer
```

For a compose file of the project's own, `--service <name>` names the database's service (the first MySQL one when
it is not given). The client logs in with what the database's container was made with: its `MYSQL_*` user and
password, root with its password when only that is given, or the container's own option file (DDEV's). The password
goes in `MYSQL_PWD`, so MySQL's clients print no warning about a password on the command line; a dump skips the
tablespaces (`--no-tablespaces`), which an application's user may not read.

## Settings

`core/config/plugin.mysql.settings.yml`, also on the plugin's page in Settings:

| Key | Default | What it is |
| --- | --- | --- |
| `admin` | `both` | The web admins the menu offers: `both`, `adminer`, `phpmyadmin` or `none` |
| `keep` | `0` | How many exports of one project the backups folder keeps; the oldest go when a new one is made, never the dump an import is reading. `0` keeps every one |

## Runtimes

| | DDEV | A compose file of its own | Docker Compose, Kubernetes, Podman, Lando, Docksal (built by the Workspace) |
| --- | --- | --- | --- |
| The menu on the row, its caption | Yes | Yes | Not yet: the runtime layer builds MariaDB only |
| Console | Yes, with a prompt | Yes, with a prompt | Not yet |
| Tables and sizes, running statements, connection details | Yes | Yes | Not yet |
| Export, then import (the database emptied first) | Yes | Yes | Not yet |
| Adminer | Yes | No: not yet | No: not yet |
| phpMyAdmin | The same add-on as MariaDB's, not added to a MySQL project here | No: not yet | No: not yet |

"Yes" means it was run on a real project of that runtime: a MySQL 8.0 project on DDEV and a compose file of its own
with a `mysql:8.4` service, each with a shop's tables, from the terminal and from the dashboard.

How each is reached:

| Runtime | The database | The console |
| --- | --- | --- |
| DDEV | The project's `db` service: `ddev mysql`, `ddev exec -s db`, `ddev export-db`, `ddev import-db` | DDEV's own client, with a prompt (in a screen session too: `script` gives it a terminal of its own) |
| A compose file of the project's own | Its MySQL service, with `docker compose exec` | The client, with a prompt (the same way) |
| A project the Workspace built on another runtime | The runtime layer's `db`, once the layer builds MySQL (its block would say `database: "mysql:8.0"`) | |

## What does not fit yet

- **MySQL on Docker Compose, Podman, Kubernetes, Lando and Docksal, built by the Workspace.** The runtime layer's
  `php` stack has one database, MariaDB: a builder run with `--runtime` gets MariaDB, and the MariaDB plugin has its
  menu. The tool already reads a block that names MySQL (`database: "mysql:8.0"`), for the day the layer builds one.
- **A web admin off DDEV.** Adminer and phpMyAdmin are services of their own beside the project. DDEV adds them with
  its official add-ons; for a compose file of the project's own the Workspace cannot declare a service yet, so the
  menu says so in their place.
- **Adminer on a DDEV older than 1.24.10.** The add-ons' newest releases ask for 1.24.10; on an older DDEV the tool
  takes their last release for it (`ddev/ddev-adminer` v1.1.4, `ddev/ddev-phpmyadmin` v1.0.1), and names Adminer 4 in
  the project's `.ddev/.env` (`ADMINER_DOCKER_IMAGE`), the Adminer that release logs in to by itself. Removing Adminer
  takes that line out again.

## What it needs

On the machine: what the core needs (DDEV, and the runtime CLIs of the projects you have). `docker` is suggested
(`suggests.commands`): the tool calls it for a compose file of the project's own. The workspace reports it and never
installs it:

```bash
bash core/scripts/plugins.sh --check mysql
webship-workspace doctor
```

In the workspace (`needs`): a sites folder for the tool (`dev`, `test`, `demos`, `sandboxes` or `projects`; the
first is added when none is there), and the AI folders its items are placed in: `ai-agents`, `ai-skills`,
`ai-commands` and `ai-prompts`. `--with-needs` adds what is missing first.

## The items it carries

Each lands in the folder of its kind, when that folder is an active workspace folder, and is installed into an AI CLI
from there (Claude Code by default):

| What | Lands in | What it is for |
| --- | --- | --- |
| The agent `mysql-helper` | `ai-agents/` | Says what a project's MySQL is, lists its tables and sizes, finds what runs slowly, exports it and checks the dump, and imports only when asked |
| The skill `mysql-database` | `ai-skills/` | Which projects are MySQL's, every entry of the DATABASE menu and its flag, the runtimes, the settings |
| The command `/mysql-sizes` | `ai-commands/` | `/mysql-sizes <folder> <project>`: the size and the largest tables. Reads only |
| The prompt `mysql-dump-and-check` | `ai-prompts/` | The launch command of a session that exports a database and checks the dump |

The item bodies are plain Markdown any AI command-line assistant can follow. How they are laid out and checked:
[docs/plugin-items-pattern.md](docs/plugin-items-pattern.md).

## What the package holds

| Path | What it is |
| --- | --- |
| `src/` | `register(api)`: MySQL's engine for `registerDatabase` (`src/lib/engine.ts`) |
| `commands/cmd-tools-mysql.sh` | The tool, placed into the sites folders (`__WORKSPACE__` filled in) |
| `scripts/functions/fun-mysql.sh`, `scripts/args/arg-mysql.sh` | Its functions and its arguments, placed under `core/scripts/plugins/mysql/` |
| `config/plugin.mysql.settings.yml`, `config/settings.labels.yml` | The settings template and its labels |
| `ai/` | The agent, the skill, the command and the prompt |
| `features/mysql.feature` | The webship-js scenarios, run by the dashboard's suite and in CI |
| `tests/` | The manifest, the engine, the menu, the tool against scaffolded projects, the items |

## What comes later

- MySQL built by the runtime layer, on Docker Compose, Podman, Kubernetes, Lando and Docksal.
- The version new builds get, and a move of a project's database to another MySQL version.
- A web admin for a compose file of the project's own, once the core can declare a service for a project.
- Slow statements over time (the slow query log, `performance_schema`), not only what runs now.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the engine, the menu, the tool's functions against scaffolded projects, the items
```
