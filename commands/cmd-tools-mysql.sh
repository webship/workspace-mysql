#!/usr/bin/env bash

# Installed by the MySQL plugin (plugins.sh --install mysql); __WORKSPACE__ is the workspace it was installed into.
#
# The MySQL database of a project of this folder, on the runtime the project is on: DDEV by default, a compose file of
# the project's own, and the Workspace's runtime layer once it builds MySQL. Its console, its tables and sizes, the
# statements running now, an export into the backups folder, an import of a dump (the database as it is exported
# first), and a web admin on DDEV (the official add-ons).
#
#   bash cmd-tools-mysql.sh <project>                  # what the database is, and how a client connects
#   bash cmd-tools-mysql.sh <project> --tables         # the tables, largest first
#   bash cmd-tools-mysql.sh <project> --console        # the client
#   bash cmd-tools-mysql.sh <project> --export         # a dump into the backups folder
#   bash cmd-tools-mysql.sh <project> --import <file>  # replaces the database
#   bash cmd-tools-mysql.sh <project> --help           # every flag

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings and extra lists.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

ARGPARSE_DESCRIPTION="The MySQL database of a __WORKSPACE__ project: its console, tables and sizes, running statements, an export, an import, and a web admin on DDEV"
# The args file comes with the plugin: core/scripts/plugins/mysql/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/mysql/args/arg-mysql.sh || exit 1 ;

shift $#;

mysql_tool ;
