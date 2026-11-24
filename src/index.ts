/**
 * MySQL for Webship Workspace.
 *
 * The DATABASE menu on every project whose database is MySQL: its console in a screen, tables and sizes, an export
 * into the backups folder, an import of a dump that folder holds, the statements running now, the connection
 * details, and Adminer and phpMyAdmin on DDEV. All of it is the database family's surface
 * (@webship.co/workspace-database); this package is MySQL's engine, its tool (cmd-tools-mysql.sh, placed into
 * the sites folders) and its AI items.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';
import { registerDatabase } from '@webship.co/workspace-database';

import { mysqlEngine } from './lib/engine';

export { mysqlEngine };

/** The AI items the installer places: agents in ai-agents/, skills in ai-skills/, commands in ai-commands/, prompts in ai-prompts/. */
export const AGENTS: string[] = ['mysql-helper'];
export const SKILLS: string[] = ['mysql-database'];
export const AI_COMMANDS: string[] = ['mysql-sizes'];
export const PROMPTS: string[] = ['mysql-dump-and-check'];

export function register(api: PluginApi): void {
  registerDatabase(api, mysqlEngine);
}
