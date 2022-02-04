---
title: RESTORE
summary: Restore your CockroachDB cluster to a cloud storage services such as AWS S3, Google Cloud Storage, or other NFS.
toc: true
---

The `RESTORE` [statement](sql-statements.html) restores your cluster's schemas and data from [a `BACKUP`](backup.html) stored on services such as AWS S3, Google Cloud Storage, NFS, or HTTP storage.

Because CockroachDB is designed with high fault tolerance, restores are designed primarily for disaster recovery, i.e., restarting your cluster if it loses a majority of its nodes. Isolated issues (such as small-scale node outages) do not require any intervention.

You can restore:

- [A full cluster](#full-cluster)
- [Databases](#databases)
- [Tables](#tables)

## Considerations

- `RESTORE` cannot restore backups made by newer versions of CockroachDB.
- `RESTORE` is a blocking statement. To run a restore job asynchronously, use the `DETACHED` option. See [Options](#options) for more usage detail.
- `RESTORE` no longer requires an Enterprise license, regardless of the options passed to it or to the backup it is restoring.

## Required privileges

- [Full cluster restores](#full-cluster) can only be run by members of the [`ADMIN` role](authorization.html#admin-role). By default, the `root` user belongs to the `admin` role.
- For all other restores, the user must have [write access](authorization.html#assign-privileges) (`CREATE` or `INSERT`) on all objects affected.

### Source privileges

{%  include {{  page.version.version  }}/misc/source-privileges.md %}

## Synopsis

<div>
{%  include {{  page.version.version  }}/sql/generated/diagrams/restore.html %}
</div>

## Parameters

 Parameter | Description
-----------|-------------
 `table_pattern` | The table or [view](views.html) you want to restore.
 `database_name` | The name of the database you want to restore (i.e., restore all tables and views in the database). You can restore an entire database only if you had backed up the entire database.
 `destination` | The URL where the [full backup](take-full-and-incremental-backups.html#full-backups) (and appended [incremental backups](take-full-and-incremental-backups.html#incremental-backups), if applicable) is stored. <br/><br/>For information about this URL structure, see [Backup File URLs](#backup-file-urls).
 `partitioned_backup_location` | The URL where a [locality-aware backup](take-and-restore-locality-aware-backups.html) is stored. When restoring from an incremental locality-aware backup, you need to include _every_ locality ever used, even if it was only used once.<br/><br/>For information about this URL structure, see [Backup File URLs](#backup-file-urls).
 `AS OF SYSTEM TIME timestamp` | Restore data as it existed as of [`timestamp`](as-of-system-time.html). You can restore point-in-time data only if you had taken full or incremental backup [with revision history](take-backups-with-revision-history-and-restore-from-a-point-in-time.html).
 `restore_options_list` | Control your backup's behavior with [these options](#options).

### Options

You can control `RESTORE` behavior using any of the following in the `restore_options_list`. To set multiple `RESTORE` options, use a comma-separated list:

 Option                                                             | <div style="width:75px">Value</div>         | Description
 -------------------------------------------------------------------+---------------+-------------------------------------------------------
<a name="into_db"></a>`into_db`                                     | Database name                               | Use to [change the target database](#restore-tables-into-a-different-database) for table restores. (Does not apply to database or cluster restores.)<br><br>Example: `WITH into_db = 'newdb'`
<a name="skip_missing_foreign_keys"></a>`skip_missing_foreign_keys` | N/A                                         | Use to remove the missing [foreign key](foreign-key.html) constraints before restoring.<br><br>Example: `WITH skip_missing_foreign_keys`
<a name="skip_missing_sequences"></a>`skip_missing_sequences`       | N/A                                         | Use to ignore [sequence](show-sequences.html) dependencies (i.e., the `DEFAULT` expression that uses the sequence).<br><br>Example: `WITH skip_missing_sequences`
`skip_missing_sequence_owners`                                      | N/A                                         | Must be used when restoring either a table that was previously a [sequence owner](create-sequence.html#owned-by) or a sequence that was previously owned by a table.<br><br>Example: `WITH skip_missing_sequence_owners`
`skip_missing_views`                                                | N/A                                         | Use to skip restoring [views](views.html) that cannot be restored because their dependencies are not being restored at the same time.<br><br>Example: `WITH skip_missing_views`
`encryption_passphrase`                                             | Passphrase used to create the [encrypted backup](take-and-restore-encrypted-backups.html) |  The passphrase used to decrypt the file(s) that were encrypted by the [`BACKUP`](take-and-restore-encrypted-backups.html) statement.
`DETACHED`                                                          | N/A                                         |  When `RESTORE` runs with `DETACHED`, the job will execute asynchronously and the job ID will be returned immediately without waiting for the job to finish. Note that with `DETACHED` specified, further job information and the job completion status will not be returned. For more on the differences between the returned job data, see the [example](restore.html#restore-a-backup-asynchronously) below. To check on the job status, use the [`SHOW JOBS`](show-jobs.html) statement. <br><br>To run a restore within a [transaction](transactions.html), use the `DETACHED` option.

### Backup file URLs

CockroachDB uses the URL provided to construct a secure API call to the service you specify. The URL structure depends on the type of file storage you are using. For more information, see the following:

- [Use Cloud Storage for Bulk Operations](use-cloud-storage-for-bulk-operations.html)
- [Use a Local File Server for Bulk Operations](use-a-local-file-server-for-bulk-operations.html)

## Functional details

You can restore:

- [A full cluster](#full-cluster)
- [Databases](#databases)
- [Tables](#tables)

#### Full cluster

 A full cluster restore can only be run on a target cluster with no user-created databases or tables. Restoring a full cluster includes:

- All user tables
- Relevant system tables
- All [databases](create-database.html)
- All [tables](create-table.html) (which automatically includes their [indexes](indexes.html))
- All [views](views.html)

{{ site.data.alerts.callout_info }}
When you restore a full cluster with an Enterprise license, it will restore the [Enterprise license](enterprise-licensing.html) of the cluster you are restoring from. If you want to use a different license in the new cluster, make sure to [update the license](licensing-faqs.html#set-a-license) _after_ the restore is complete.
{{ site.data.alerts.end }}

#### Databases

**The database cannot already exist in the target cluster.** Restoring a database will create a new database and restore all of its tables and views. The created database will have the name of the database in the backup.

~~~ sql
RESTORE DATABASE backup_database_name FROM 'subdirectory' IN 'your_backup_location';
~~~

{{ site.data.alerts.callout_success }}
If [dropping](drop-database.html) or [renaming](rename-database.html) an existing database is not an option, you can use [_table_ restore](#restore-a-table) to restore all tables into the existing database by using the [`WITH into_db` option](#options).
{{ site.data.alerts.end }}

#### Tables

You can also restore individual tables (which automatically includes their indexes) or [views](views.html) from a backup. This process uses the data stored in the backup to create entirely new tables or views in the target database.

By default, tables and views are restored into a target database matching the name of the database from which they were backed up. If the target database does not exist, you must [create it](create-database.html). You can choose to change the target database with the [`into_db` option](#into_db).

The target database must not have tables or views with the same name as the tables or views you're restoring. If any of the restore target's names are being used, you can:

- [`DROP TABLE`](drop-table.html), [`DROP VIEW`](drop-view.html), or [`DROP SEQUENCE`](drop-sequence.html) and then restore them. Note that a sequence cannot be dropped while it is being used in a column's `DEFAULT` expression, so those expressions must be dropped before the sequence is dropped, and recreated after the sequence is recreated. The `setval` [function](functions-and-operators.html#sequence-functions) can be used to set the value of the sequence to what it was previously.
- [Restore the table or view into a different database](#into_db).

{{ site.data.alerts.callout_info }}
`RESTORE` only offers table-level granularity; it _does not_ support restoring subsets of a table.
{{ site.data.alerts.end }}

When restoring an individual table that references a user-defined type (e.g., [`ENUM`](enum.html)), CockroachDB will first check to see if the type already exists. The restore will attempt the following for each user-defined type within a table backup:

- If there is _not_ an existing type in the cluster with the same name, CockroachDB will create the user-defined type as it exists in the backup.
- If there is an existing type in the cluster with the same name that is compatible with the type in the backup, CockroachDB will map the type in the backup to the type in the cluster.
- If there is an existing type in the cluster with the same name but it is _not_ compatible with the type in the backup, the restore will not succeed and you will be asked to resolve the naming conflict. You can do this by either [dropping](drop-type.html) or [renaming](alter-type.html) the existing user-defined type.

In general, two types are compatible if they are the same kind (e.g., an enum is only compatible with other enums). Additionally, enums are only compatible if they have the same ordered set of elements that have also been [created in the same way](https://github.com/cockroachdb/cockroach/blob/master/docs/RFCS/20200331_enums.md#physical-layout). For example:

- `CREATE TYPE t1 AS ENUM ('yes', 'no')` and `CREATE TYPE t2 AS ENUM ('yes', 'no')` are compatible.
- `CREATE TYPE t1 AS ENUM ('yes', 'no')` and `CREATE TYPE t2 AS ENUM ('no', 'yes')` are not compatible.
- `CREATE TYPE t1 AS ENUM ('yes', 'no')` and `CREATE TYPE t2 AS ENUM ('yes'); ALTER TYPE t2 ADD VALUE ('no')` are not compatible because they were not created in the same way.

### Object dependencies

Dependent objects must be restored at the same time as the objects they depend on.

Object | Depends On
-------|-----------
Table with [foreign key](foreign-key.html) constraints | The table it `REFERENCES` (however, this dependency can be [removed during the restore](#skip_missing_foreign_keys)).
Table with a [sequence](create-sequence.html) | The sequence.
[Views](views.html) | The tables used in the view's `SELECT` statement.
[Interleaved tables](interleave-in-parent.html) | The parent table in the [interleaved hierarchy](interleave-in-parent.html).

### Users and privileges

To restore your users and privilege [grants](grant.html), you can do a cluster backup and restore the cluster to a fresh cluster with no user data.

If you are not doing a full cluster restore, the table-level privileges need to be granted to the users after the restore is complete. (By default, the user restoring will become the owner of the restored objects.) To grant table-level privileges after a restore, backup the `system.users` table, [restore users and their passwords](restore.html#restoring-users-from-system-users-backup), and then [grant](grant.html) the table-level privileges.

### Restore types

You can either restore from a full backup or from a full backup with incremental backups, based on the backup files you include:

Restore Type | Parameters
-------------|----------
Full backup | Include the path to the full backup destination and the [subdirectory](#view-the-backup-subdirectories) of the backup. See the [Examples](#examples) section for syntax of [cluster](#restore-a-cluster), [database](#restore-a-database), and [table](#restore-a-table) restores.
Full backup + <br>incremental backups | Include the path that contains the backup collection and the [subdirectory](#view-the-backup-subdirectories) containing the incremental backup. See [Restore from incremental backups](#restore-from-incremental-backups) for an example.

## Performance

The `RESTORE` process minimizes its impact to the cluster's performance by distributing work to all nodes. Subsets of the restored data (known as ranges) are evenly distributed among randomly selected nodes, with each range initially restored to only one node. Once the range is restored, the node begins replicating it others.

{{ site.data.alerts.callout_info }}
When a `RESTORE` fails or is canceled, partially restored data is properly cleaned up. This can have a minor, temporary impact on cluster performance.
{{ site.data.alerts.end }}

## Viewing and controlling restore jobs

After CockroachDB successfully initiates a restore, it registers the restore as a job, which you can view with [`SHOW JOBS`](show-jobs.html).

After the restore has been initiated, you can control it with [`PAUSE JOB`](pause-job.html), [`RESUME JOB`](resume-job.html), and [`CANCEL JOB`](cancel-job.html).

{{ site.data.alerts.callout_info }}
If initiated correctly, the statement returns when the restore is finished or if it encounters an error. In some cases, the restore can continue after an error has been returned (the error message will tell you that the restore has resumed in background).
{{ site.data.alerts.end }}

## Known limitations

{%  include {{  page.version.version  }}/known-limitations/restore-aost.md %}

## Examples

{%  include {{  page.version.version  }}/backups/bulk-auth-options.md %}

<div class="filters clearfix">
  <button class="filter-button" data-scope="s3">Amazon S3</button>
  <button class="filter-button" data-scope="azure">Azure Storage</button>
  <button class="filter-button" data-scope="gcs">Google Cloud Storage</button>
</div>

<section class="filter-content" markdown="1" data-scope="s3">

{{ site.data.alerts.callout_info }}
The examples in this section use the **default** `AUTH=specified` parameter. For more detail on how to use `implicit` authentication with Amazon S3 buckets, read [Use Cloud Storage for Bulk Operations — Authentication](use-cloud-storage-for-bulk-operations.html#authentication).
{{ site.data.alerts.end }}

### View the backup subdirectories

<span class="version-tag">New in v21.1:</span> `BACKUP ... INTO` adds a backup to a collection within the backup destination. The path to the backup is created using a date-based naming scheme. To view the backup paths in a given destination, use [`SHOW BACKUPS`](show-backup.html):

{%  include_cached copy-clipboard.html %}
~~~ sql
> SHOW BACKUPS IN 's3://{bucket_name}/{path/to/backup}?AWS_ACCESS_KEY_ID={key_id}&AWS_SECRET_ACCESS_KEY={access_key}';
~~~

~~~
       path
-------------------------
/2021/12/14-190909.83
/2021/12/20-155249.37
/2021/12/21-142943.73
(3 rows)
~~~

When you restore a backup, add the backup's subdirectory path (e.g. `/2021/12/21-142943.73`) to the `RESTORE` statement.

Incremental backups will be appended to the full backup with `BACKUP ... INTO LATEST IN {destination}`. Your storage location will contain the incremental as a date-based subdirectory within the full backup.

In the following example `/2021/12/21-142943.73` contains the full backup. The incremental backups (`144748.08/` and `144639.97/`) are appended as subdirectories to the full backup:

~~~
2021
|—— 12
   |—— 21-142943.73/
       |—— 20211221/
           |—— 144748.08/
           |—— 144639.97/
~~~

To output more detail about the backups contained within a directory, see [View a list of the full and incremental backups in a specific full backup subdirectory](show-backup.html#view-a-list-of-the-full-and-incremental-backups-in-a-specific-full-backup-subdirectory)

See [Incremental backups with explicitly specified destinations](take-full-and-incremental-backups.html#incremental-backups-with-explicitly-specified-destinations) to control where your backups go.

### Restore a cluster

To restore a full cluster:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE FROM '2021/03/23-213101.37' IN 's3://{bucket_name}/{path/to/backup}?AWS_ACCESS_KEY_ID={key_id}&AWS_SECRET_ACCESS_KEY={access_key}';
~~~

To view the available subdirectories, use [`SHOW BACKUPS`](#view-the-backup-subdirectories).

### Restore a database

To restore a database:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE DATABASE bank FROM '2021/03/23-213101.37' IN 's3://{bucket_name}/{path/to/backup}?AWS_ACCESS_KEY_ID={key_id}&AWS_SECRET_ACCESS_KEY={access_key}';
~~~

To view the available subdirectories, use [`SHOW BACKUPS`](#view-the-backup-subdirectories).

{{ site.data.alerts.callout_info }}
`RESTORE DATABASE` can only be used if the entire database was backed up.
{{ site.data.alerts.end }}

### Restore a table

To restore a single table:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE TABLE bank.customers FROM '2021/03/23-213101.37' IN 's3://{bucket_name}/{path/to/backup}?AWS_ACCESS_KEY_ID={key_id}&AWS_SECRET_ACCESS_KEY={access_key}';
~~~

To restore multiple tables:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE TABLE bank.customers, bank.accounts FROM '2021/03/23-213101.37' IN 's3://{bucket_name}/{path/to/backup}?AWS_ACCESS_KEY_ID={key_id}&AWS_SECRET_ACCESS_KEY={access_key}';
~~~

To view the available subdirectories, use [`SHOW BACKUPS`](#view-the-backup-subdirectories).

### Restore from incremental backups

Restoring from [incremental backups](take-full-and-incremental-backups.html#incremental-backups) requires full and incremental backups to be in the same subdirectory:

{%  include_cached copy-clipboard.html %}
~~~ sql
RESTORE DATABASE bank FROM '2021/03/23-213101.37' IN 's3://{bucket_name}/{path/to/backup-collection}?AWS_ACCESS_KEY_ID={key_id}&AWS_SECRET_ACCESS_KEY={access_key}';
~~~

{{ site.data.alerts.callout_info }}
<span class="version-tag">New in v21.1:</span> `RESTORE` will re-validate [indexes](indexes.html) when [incremental backups](take-full-and-incremental-backups.html) are created from an older version (v20.2.2 and earlier or v20.1.4 and earlier), but restored by a newer version (v21.1.0+). These earlier releases may have included incomplete data for indexes that were in the process of being created.
{{ site.data.alerts.end }}

### Restore a backup asynchronously

Use the `DETACHED` [option](#options) to execute the restore [job](show-jobs.html) asynchronously:

{%  include_cached copy-clipboard.html %}
~~~ sql
RESTORE TABLE bank.customers FROM '2021/03/23-213101.37' IN 's3://{bucket_name}/{path/to/backup}?AWS_ACCESS_KEY_ID={key_id}&AWS_SECRET_ACCESS_KEY={access_key}' WITH DETACHED;
~~~

The job ID is returned immediately without waiting for the job to finish:

~~~
        job_id
----------------------
  592786066399264769
(1 row)
~~~

**Without** the `DETACHED` option, `RESTORE` will block the SQL connection until the job completes. Once finished, the job status and more detailed job data is returned:

~~~
job_id             |  status   | fraction_completed | rows | index_entries | bytes
---------------------+-----------+--------------------+------+---------------+--------
652471804772712449 | succeeded |                  1 |   50 |             0 |  4911
(1 row)
~~~

### Other restore usages

#### Restore tables into a different database

By default, tables and views are restored to the database they originally belonged to. However, using the [`into_db` option](#into_db), you can control the target database.

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE bank.customers \
FROM '2021/09/29-153014.47' IN 's3://{bucket_name}/{path/to/backup}?AWS_ACCESS_KEY_ID={key_id}&AWS_SECRET_ACCESS_KEY={access_key}' \
WITH into_db = 'newdb';
~~~

#### Remove the foreign key before restore

By default, tables with [foreign key](foreign-key.html) constraints must be restored at the same time as the tables they reference. However, using the [`skip_missing_foreign_keys`](restore.html#skip_missing_foreign_keys) option you can remove the foreign key constraint from the table and then restore it.

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE bank.accounts \
FROM '2021/09/29-153014.47' IN 's3://{bucket_name}/{path/to/backup}?AWS_ACCESS_KEY_ID={key_id}&AWS_SECRET_ACCESS_KEY={access_key}' \
WITH skip_missing_foreign_keys;
~~~

#### Restoring users from `system.users` backup

The `system.users` table stores your cluster's usernames and their hashed passwords. To restore them, you must restore the `system.users` table into a new database because you cannot drop the existing `system.users` table.

After it's restored into a new database, you can write the restored `users` table data to the cluster's existing `system.users` table.

First, create the new database that you'll restore the `system.users` table into:

{%  include_cached copy-clipboard.html %}
~~~ sql
> CREATE DATABASE newdb;
~~~

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE system.users \
FROM '2021/09/29-153014.47' IN 's3://{bucket_name}/{path/to/backup}?AWS_ACCESS_KEY_ID={key_id}&AWS_SECRET_ACCESS_KEY={access_key}' \
WITH into_db = 'newdb';
~~~

After the restore completes, add the `users` to the existing `system.users` table:

{%  include_cached copy-clipboard.html %}
~~~ sql
> INSERT INTO system.users SELECT * FROM newdb.users;
~~~

{%  include_cached copy-clipboard.html %}
~~~ sql
> DROP TABLE newdb.users;
~~~

</section>

<section class="filter-content" markdown="1" data-scope="azure">

### View the backup subdirectories

<span class="version-tag">New in v21.1:</span> `BACKUP ... INTO` adds a backup to a collection within the backup destination. The path to the backup is created using a date-based naming scheme. To view the backup paths in a given destination, use [`SHOW BACKUPS`](show-backup.html):

{%  include_cached copy-clipboard.html %}
~~~ sql
> SHOW BACKUPS IN 'azure://{container name}/{path/to/backup}?AZURE_ACCOUNT_NAME={account name}&AZURE_ACCOUNT_KEY={url-encoded key}';
~~~

~~~
       path
-------------------------
/2021/12/14-190909.83
/2021/12/20-155249.37
/2021/12/21-142943.73
(3 rows)
~~~

When you restore a backup, add the backup's subdirectory path (e.g. `/2021/12/21-142943.73`) to the `RESTORE` statement.

Incremental backups will be appended to the full backup with `BACKUP ... INTO LATEST IN {destination}`. Your storage location will contain the incremental as a date-based subdirectory within the full backup.

In the following example `/2021/12/21-142943.73` contains the full backup. The incremental backups (`144748.08/` and `144639.97/`) are appended as subdirectories to the full backup:

~~~
2021
|—— 12
   |—— 21-142943.73/
       |—— 20211221/
           |—— 144748.08/
           |—— 144639.97/
~~~

To output more detail about the backups contained within a directory, see [View a list of the full and incremental backups in a specific full backup subdirectory](show-backup.html#view-a-list-of-the-full-and-incremental-backups-in-a-specific-full-backup-subdirectory)

See [Incremental backups with explicitly specified destinations](take-full-and-incremental-backups.html#incremental-backups-with-explicitly-specified-destinations) to control where your backups go.

### Restore a cluster

To restore a full cluster:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE FROM '2021/03/23-213101.37' IN 'azure://{container name}/{path/to/backup}?AZURE_ACCOUNT_NAME={account name}&AZURE_ACCOUNT_KEY={url-encoded key}';
~~~

To view the available subdirectories, use [`SHOW BACKUPS`](#view-the-backup-subdirectories).

### Restore a database

To restore a database:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE DATABASE bank FROM '2021/03/23-213101.37' IN 'azure://{container name}/{path/to/backup}?AZURE_ACCOUNT_NAME={account name}&AZURE_ACCOUNT_KEY={url-encoded key}';
~~~

To view the available subdirectories, use [`SHOW BACKUPS`](#view-the-backup-subdirectories).

{{ site.data.alerts.callout_info }}
`RESTORE DATABASE` can only be used if the entire database was backed up.
{{ site.data.alerts.end }}

### Restore a table

To restore a single table:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE TABLE bank.customers FROM '2021/03/23-213101.37' IN 'azure://{container name}/{path/to/backup}?AZURE_ACCOUNT_NAME={account name}&AZURE_ACCOUNT_KEY={url-encoded key}';
~~~

To restore multiple tables:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE TABLE bank.customers, bank.accounts FROM '2021/03/23-213101.37' IN 'azure://{container name}/{path/to/backup}?AZURE_ACCOUNT_NAME={account name}&AZURE_ACCOUNT_KEY={url-encoded key}';
~~~

To view the available subdirectories, use [`SHOW BACKUPS`](#view-the-backup-subdirectories).

### Restore from incremental backups

Restoring from [incremental backups](take-full-and-incremental-backups.html#incremental-backups) requires full and incremental backups to be in the same subdirectory:

{%  include_cached copy-clipboard.html %}
~~~ sql
RESTORE DATABASE bank FROM '2021/03/23-213101.37' IN 'azure://{container name}/{path/to/backup-collection}?AZURE_ACCOUNT_NAME={account name}&AZURE_ACCOUNT_KEY={url-encoded key}';
~~~

{{ site.data.alerts.callout_info }}
<span class="version-tag">New in v21.1:</span> `RESTORE` will re-validate [indexes](indexes.html) when [incremental backups](take-full-and-incremental-backups.html) are created from an older version (v20.2.2 and earlier or v20.1.4 and earlier), but restored by a newer version (v21.1.0+). These earlier releases may have included incomplete data for indexes that were in the process of being created.
{{ site.data.alerts.end }}

### Restore a backup asynchronously

Use the `DETACHED` [option](#options) to execute the restore [job](show-jobs.html) asynchronously:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE FROM '2021/03/23-213101.37' IN 'azure://{container name}/{path/to/backup}?AZURE_ACCOUNT_NAME={account name}&AZURE_ACCOUNT_KEY={url-encoded key}' WITH DETACHED;
~~~

The job ID is returned immediately without waiting for the job to finish:

~~~
        job_id
----------------------
  592786066399264769
(1 row)
~~~

**Without** the `DETACHED` option, `RESTORE` will block the SQL connection until the job completes. Once finished, the job status and more detailed job data is returned:

~~~
job_id             |  status   | fraction_completed | rows | index_entries | bytes
---------------------+-----------+--------------------+------+---------------+--------
652471804772712449 | succeeded |                  1 |   50 |             0 |  4911
(1 row)
~~~

### Other restore usages

#### Restore tables into a different database

By default, tables and views are restored to the database they originally belonged to. However, using the [`into_db` option](#into_db), you can control the target database.

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE bank.customers \
FROM '2021/03/23-213101.37' IN 'azure://{container name}/{path/to/backup}?AZURE_ACCOUNT_NAME={account name}&AZURE_ACCOUNT_KEY={url-encoded key}' \
WITH into_db = 'newdb';
~~~

#### Remove the foreign key before restore

By default, tables with [foreign key](foreign-key.html) constraints must be restored at the same time as the tables they reference. However, using the [`skip_missing_foreign_keys`](restore.html#skip_missing_foreign_keys) option you can remove the foreign key constraint from the table and then restore it.

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE bank.accounts \
FROM '2021/03/23-213101.37' IN 'azure://{container name}/{path/to/backup}?AZURE_ACCOUNT_NAME={account name}&AZURE_ACCOUNT_KEY={url-encoded key}' \
WITH skip_missing_foreign_keys;
~~~

#### Restoring users from `system.users` backup

The `system.users` table stores your cluster's usernames and their hashed passwords. To restore them, you must restore the `system.users` table into a new database because you cannot drop the existing `system.users` table.

After it's restored into a new database, you can write the restored `users` table data to the cluster's existing `system.users` table.

First, create the new database that you'll restore the `system.users` table into:

{%  include_cached copy-clipboard.html %}
~~~ sql
> CREATE DATABASE newdb;
~~~

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE system.users \
FROM '2021/03/23-213101.37' IN 'azure://{container name}/{path/to/backup}?AZURE_ACCOUNT_NAME={account name}&AZURE_ACCOUNT_KEY={url-encoded key}' \
WITH into_db = 'newdb';
~~~

After the restore completes, add the `users` to the existing `system.users` table:

{%  include_cached copy-clipboard.html %}
~~~ sql
> INSERT INTO system.users SELECT * FROM newdb.users;
~~~

{%  include_cached copy-clipboard.html %}
~~~ sql
> DROP TABLE newdb.users;
~~~

</section>

<section class="filter-content" markdown="1" data-scope="gcs">

{{ site.data.alerts.callout_info }}
The examples in this section use the `AUTH=specified` parameter, which will be the default behavior in v21.2 and beyond for connecting to Google Cloud Storage. For more detail on how to pass your Google Cloud Storage credentials with this parameter, or, how to use `implicit` authentication, read [Use Cloud Storage for Bulk Operations — Authentication](use-cloud-storage-for-bulk-operations.html#authentication).
{{ site.data.alerts.end }}

### View the backup subdirectories

<span class="version-tag">New in v21.1:</span> `BACKUP ... INTO` adds a backup to a collection within the backup destination. The path to the backup is created using a date-based naming scheme. To view the backup paths in a given destination, use [`SHOW BACKUPS`](show-backup.html):

{%  include_cached copy-clipboard.html %}
~~~ sql
> SHOW BACKUPS IN 'gs://{bucket name}/{path/to/backup}?AUTH=specified&CREDENTIALS={encoded key}';
~~~

~~~
       path
-------------------------
/2021/12/14-190909.83
/2021/12/20-155249.37
/2021/12/21-142943.73
(3 rows)
~~~

When you restore a backup, add the backup's subdirectory path (e.g. `/2021/12/21-142943.73`) to the `RESTORE` statement.

Incremental backups will be appended to the full backup with `BACKUP ... INTO LATEST IN {destination}`. Your storage location will contain the incremental as a date-based subdirectory within the full backup.

In the following example `/2021/12/21-142943.73` contains the full backup. The incremental backups (`144748.08/` and `144639.97/`) are appended as subdirectories to the full backup:

~~~
2021
|—— 12
   |—— 21-142943.73/
       |—— 20211221/
           |—— 144748.08/
           |—— 144639.97/
~~~

To output more detail about the backups contained within a directory, see [View a list of the full and incremental backups in a specific full backup subdirectory](show-backup.html#view-a-list-of-the-full-and-incremental-backups-in-a-specific-full-backup-subdirectory)

See [Incremental backups with explicitly specified destinations](take-full-and-incremental-backups.html#incremental-backups-with-explicitly-specified-destinations) to control where your backups go.

### Restore a cluster

To restore a full cluster:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE FROM '2021/03/23-213101.37' IN 'gs://{bucket name}/{path/to/backup}?AUTH=specified&CREDENTIALS={encoded key}';
~~~

To view the available subdirectories, use [`SHOW BACKUPS`](#view-the-backup-subdirectories).

### Restore a database

To restore a database:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE DATABASE bank FROM '2021/03/23-213101.37' IN 'gs://{bucket name}/{path/to/backup}?AUTH=specified&CREDENTIALS={encoded key}';
~~~

To view the available subdirectories, use [`SHOW BACKUPS`](#view-the-backup-subdirectories).

{{ site.data.alerts.callout_info }}
`RESTORE DATABASE` can only be used if the entire database was backed up.
{{ site.data.alerts.end }}

### Restore a table

To restore a single table:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE TABLE bank.customers FROM '2021/03/23-213101.37' IN 'gs://{bucket name}/{path/to/backup}?AUTH=specified&CREDENTIALS={encoded key}';
~~~

To restore multiple tables:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE TABLE bank.customers, bank.accounts FROM '2021/03/23-213101.37' IN 'gs://{bucket name}/{path/to/backup}?AUTH=specified&CREDENTIALS={encoded key}';
~~~

To view the available subdirectories, use [`SHOW BACKUPS`](#view-the-backup-subdirectories).

### Restore from incremental backups

Restoring from [incremental backups](take-full-and-incremental-backups.html#incremental-backups) requires full and incremental backups to be in the same subdirectory:

{%  include_cached copy-clipboard.html %}
~~~ sql
RESTORE DATABASE bank FROM '2021/03/23-213101.37' IN 'gs://{bucket name}/{path/to/backup-collection}?AUTH=specified&CREDENTIALS={encoded key}';
~~~

{{ site.data.alerts.callout_info }}
<span class="version-tag">New in v21.1:</span> `RESTORE` will re-validate [indexes](indexes.html) when [incremental backups](take-full-and-incremental-backups.html) are created from an older version (v20.2.2 and earlier or v20.1.4 and earlier), but restored by a newer version (v21.1.0+). These earlier releases may have included incomplete data for indexes that were in the process of being created.
{{ site.data.alerts.end }}

### Restore a backup asynchronously

Use the `DETACHED` [option](#options) to execute the restore [job](show-jobs.html) asynchronously:

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE FROM '2021/03/23-213101.37' IN 'gs://{bucket name}/{path/to/backup}?AUTH=specified&CREDENTIALS={encoded key}'
WITH DETACHED;
~~~

The job ID is returned immediately without waiting for the job to finish:

~~~
        job_id
----------------------
  592786066399264769
(1 row)
~~~

**Without** the `DETACHED` option, `RESTORE` will block the SQL connection until the job completes. Once finished, the job status and more detailed job data is returned:

~~~
job_id             |  status   | fraction_completed | rows | index_entries | bytes
---------------------+-----------+--------------------+------+---------------+--------
652471804772712449 | succeeded |                  1 |   50 |             0 |  4911
(1 row)
~~~

### Other restore usages

#### Restore tables into a different database

By default, tables and views are restored to the database they originally belonged to. However, using the [`into_db` option](#into_db), you can control the target database.

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE bank.customers FROM '2021/03/23-213101.37' IN 'gs://{bucket name}/{path/to/backup}?AUTH=specified&CREDENTIALS={encoded key}' \
WITH into_db = 'newdb';
~~~

#### Remove the foreign key before restore

By default, tables with [foreign key](foreign-key.html) constraints must be restored at the same time as the tables they reference. However, using the [`skip_missing_foreign_keys`](restore.html#skip_missing_foreign_keys) option you can remove the foreign key constraint from the table and then restore it.

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE bank.accounts FROM '2021/03/23-213101.37' IN 'gs://{bucket name}/{path/to/backup}?AUTH=specified&CREDENTIALS={encoded key}' \
WITH skip_missing_foreign_keys;
~~~

#### Restoring users from `system.users` backup

The `system.users` table stores your cluster's usernames and their hashed passwords. To restore them, you must restore the `system.users` table into a new database because you cannot drop the existing `system.users` table.

After it's restored into a new database, you can write the restored `users` table data to the cluster's existing `system.users` table.

First, create the new database that you'll restore the `system.users` table into:

{%  include_cached copy-clipboard.html %}
~~~ sql
> CREATE DATABASE newdb;
~~~

{%  include_cached copy-clipboard.html %}
~~~ sql
> RESTORE system.users FROM '2021/03/23-213101.37' IN 'gs://{bucket name}/{path/to/backup}?AUTH=specified&CREDENTIALS={encoded key}' \
WITH into_db = 'newdb';
~~~

After the restore completes, add the `users` to the existing `system.users` table:

{%  include_cached copy-clipboard.html %}
~~~ sql
> INSERT INTO system.users SELECT * FROM newdb.users;
~~~

{%  include_cached copy-clipboard.html %}
~~~ sql
> DROP TABLE newdb.users;
~~~

</section>

## See also

- [`BACKUP`](backup.html)
- [Take Full and Incremental Backups](take-full-and-incremental-backups.html)
- [Take and Restore Encrypted Backups](take-and-restore-encrypted-backups.html)
- [Take and Restore Locality-aware Backups](take-and-restore-locality-aware-backups.html)
- [Take Backups with Revision History and Restore from a Point-in-time](take-backups-with-revision-history-and-restore-from-a-point-in-time.html)
- [Manage a Backup Schedule](manage-a-backup-schedule.html)
- [Configure Replication Zones](configure-replication-zones.html)
- [`ENUM`](enum.html)
- [`CREATE TYPE`](create-type.html)
- [`DROP TYPE`](drop-type.html)