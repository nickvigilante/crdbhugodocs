---
title: SHOW USERS
summary: The SHOW USERS statement lists the users for all databases.
toc: true
---

The `SHOW USERS` [statement](sql-statements.html) lists the users for all databases.

## Synopsis

<div>
  {{ partial "{{ page.version.version }}/sql/diagrams/show_users.html" . }}
</div>

## Required privileges

The user must have the [`SELECT`](select-clause.html) [privilege](authorization.html#assign-privileges) on the system table.

## Example

{{ partial "copy-clipboard.html" . }}
~~~ sql
> SHOW USERS;
~~~

~~~
  user_name
+------------+
  jpointsman
  maxroach
  root
(3 rows)
~~~

<span class="version-tag">New in v19.2:</span> Alternatively, within the built-in SQL shell, you can use the `\du` [shell command](cockroach-sql.html#commands):

{{ partial "copy-clipboard.html" . }}
~~~ sql
> \du
~~~

~~~
  user_name
+------------+
  jpointsman
  maxroach
  root
(3 rows)
~~~

## See also

- [`CREATE USER`](create-user.html)
- [Manage Users](authorization.html#create-and-manage-users)
