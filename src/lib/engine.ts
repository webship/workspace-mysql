/**
 * MySQL, as a database engine: the facts the family's DATABASE menu draws from.
 *
 * A project's MySQL is DDEV's `db` service (`ddev config --database=mysql:<version>`), a MySQL service of a compose file
 * of the project's own, or the runtime layer's `db` once the layer builds MySQL (its block's `database: "mysql:8.0"`).
 * Every entry of the menu runs cmd-tools-mysql.sh, which the plugin installs into the sites folders.
 */

import { serverDetect } from '@webship.co/workspace-database';
import type { DatabaseEngine } from '@webship.co/workspace-database';

export const mysqlEngine: DatabaseEngine = {
  id: 'mysql',
  title: 'MySQL',
  script: 'cmd-tools-mysql.sh',
  client: 'mysql',
  detect: serverDetect('mysql'),
  admins: [
    { id: 'adminer', label: 'Adminer', ddevAddon: { repo: 'ddev/ddev-adminer', service: 'adminer' } },
    { id: 'phpmyadmin', label: 'phpMyAdmin', ddevAddon: { repo: 'ddev/ddev-phpmyadmin', service: 'phpmyadmin' } },
  ],
  dumpExt: '.sql.gz',
  rowsAre: 'as MySQL estimates them',
};
