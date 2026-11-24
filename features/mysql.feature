Feature: The MySQL plugin
  Once the plugin is activated and installed, a project row whose database is MySQL carries the DATABASE menu, the
  plugin has its page in Settings with its settings and its tool, and its AI items are in the folders of their kind.
  (The menu itself needs a MySQL project, which the browser suite's workspace has not: the unit tests draw it, and the
  README says on which real projects it was run.)

  # Settings lists every plugin the workspace has, by family; the package is on the plugin's own page.
  Scenario: Settings lists the plugin, and its own page names its package, its settings and its tool
    Given I am on "/settings"
     Then I should see "MySQL"
     When I go to "/settings/plugin/mysql"
     Then I should see "@webship.co/workspace-mysql"
      And I should see "Web admin"
      And I should see "Exports kept per project"
      And I should see "cmd-tools-mysql.sh"

  # The AI folders are searched by name: with every plugin on, a folder lists more than one page of items.
  Scenario: The AI Agents folder lists the agent the plugin ships
    Given I am on "/ai-agents?q=mysql-helper"
     Then I should see "mysql-helper"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills?q=mysql-database"
     Then I should see "mysql-database"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands?q=mysql-sizes"
     Then I should see "mysql-sizes"

  Scenario: The AI Prompts folder lists the prompt the plugin ships
    Given I am on "/ai-prompts?q=mysql-dump-and-check"
     Then I should see "mysql-dump-and-check"
