---
title: SHOW TRACE FOR SESSION
summary: The SHOW TRACE FOR SESSION statement returns details about how CockroachDB executed a statement or series of statements recorded during a session.
toc: true
---

The `SHOW TRACE FOR SESSION` [statement](sql-statements.html) returns details about how CockroachDB executed a statement or series of statements recorded during a session. These details include messages and timing information from all nodes involved in the execution, providing visibility into the actions taken by CockroachDB across all of its software layers.

You can use `SHOW TRACE FOR SESSION` to debug why a query is not performing as expected, to add more information to bug reports, or to generally learn more about how CockroachDB works.

## Usage overview

`SHOW TRACE FOR SESSION` returns messages and timing information for all statements recorded during a session. It's important to note the following:

- `SHOW TRACE FOR SESSION` only returns the most recently recorded traces, or for a currently active recording of traces.
    - To start recording traces during a session, enable the `tracing` session variable via [`SET tracing = on;`](set-vars.html#set-tracing).
    - To stop recording traces during a session, disable the `tracing` session variable via [`SET tracing = off;`](set-vars.html#set-tracing).

- Recording traces during a session does not effect the execution of any statements traced. This means that errors encountered by statements during a recording are returned to clients. CockroachDB will [automatically retry](transactions.html#automatic-retries) individual statements (considered implicit transactions) and multi-statement transactions sent as a single batch when [retry errors](transactions.html#error-handling) are encountered due to contention. Also, clients will receive retry errors required to handle [client-side retries](transactions.html#client-side-intervention). As a result, traces of all transaction retries will be captured during a recording.


## Required privileges

For `SHOW TRACE FOR SESSION`, no privileges are required.

## Syntax

<div>
{% include {{ page.version.version }}/sql/diagrams/show_trace.html %}
</div>

## Parameters

Parameter | Description
----------|------------
`COMPACT` | If specified, fewer columns are returned by the statement. See [Response](#response) for more details.
`KV` | If specified, the returned messages are restricted to those describing requests to and responses from the underlying key-value [storage layer](architecture/storage-layer.html), including per-result-row messages.<br><br>For `SHOW KV TRACE FOR SESSION`, per-result-row messages are included only if the session was/is recording with `SET tracing = kv;`.

## Trace description

CockroachDB's definition of a "trace" is a specialization of [OpenTracing's](https://opentracing.io/docs/overview/what-is-tracing/#what-is-opentracing) definition. Internally, CockroachDB uses OpenTracing libraries for tracing, which also means that
it can be easily integrated with OpenTracing-compatible trace collectors; for example, Lightstep and Zipkin are already supported.

Concept | Description
--------|------------
**trace** | Information about the sub-operations performed as part of a high-level operation (a query or a transaction). This information is internally represented as a tree of "spans", with a special "root span" representing a whole SQL transaction in the case of `SHOW TRACE FOR SESSION`.
**span** | A named, timed operation that describes a contiguous segment of work in a trace. Each span links to "child spans", representing sub-operations; their children would be sub-sub-operations of the grandparent span, etc.<br><br>Different spans can represent (sub-)operations that executed either sequentially or in parallel with respect to each other. (This possibly-parallel nature of execution is one of the important things that a trace is supposed to describe.) The operations described by a trace may be _distributed_, that is, different spans may describe operations executed by different nodes.
**message** | A string with timing information. Each span can contain a list of these. They are produced by CockroachDB's logging infrastructure and are the same messages that can be found in node [log files](debug-and-error-logs.html) except that a trace contains message across all severity levels, whereas log files, by default, do not. Thus, a trace is much more verbose than logs but only contains messages produced in the context of one particular traced operation.

To further clarify these concepts, let's look at a visualization of a trace for one statement. This particular trace is visualized by [Lightstep](http://lightstep.com/) (docs on integrating Lightstep with CockroachDB coming soon). The image only shows spans, but in the tool, it would be possible drill down to messages. You can see names of operations and sub-operations, along with parent-child relationships and timing information, and it's easy to see which operations are executed in parallel.

<div style="text-align: center;"><img src="{{ 'images/v19.1/trace.png' | relative_url }}" alt="Lightstep example" style="border:1px solid #eee;max-width:100%" /></div>

## Response

{{site.data.alerts.callout_info}}The format of the <code>SHOW TRACE FOR SESSION</code> response may change in future versions.{{site.data.alerts.end}}

CockroachDB outputs traces in linear tabular format. Each result row represents either a span start (identified by the `=== SPAN START: <operation> ===` message) or a log message from a span. Rows are generally listed in their timestamp order (i.e., the order in which the events they represent occurred) with the exception that messages from child spans are interleaved in the parent span according to their timing. Messages from sibling spans, however, are not interleaved with respect to one another.

The following diagram shows the order in which messages from different spans would be interleaved in an example trace. Each box is a span; inner-boxes are child spans. The numbers indicate the order in which the log messages would appear in the virtual table.

~~~
 +-----------------------+
 |           1           |
 | +-------------------+ |
 | |         2         | |
 | |  +----+           | |
 | |  |    | +----+    | |
 | |  | 3  | | 4  |    | |
 | |  |    | |    |  5 | |
 | |  |    | |    | ++ | |
 | |  +----+ |    |    | |
 | |         +----+    | |
 | |          6        | |
 | +-------------------+ |
 |            7          |
 +-----------------------+
~~~

Each row contains the following columns:

Column | Type | Description
-------|------|------------
`timestamp` | timestamptz | The absolute time when the message occurred.
`age` | interval | The age of the message relative to the beginning of the trace (i.e., the beginning of the statement execution in the case of `SHOW TRACE FOR <stmt>` and the beginning of the recording in the case of `SHOW TRACE FOR SESSION`.
`message` | string | The log message.
`tag` | string | Meta-information about the message's context. This is the same information that appears in the beginning of log file messages in between square brackets (e.g, `[client=[::1]:49985,user=root,n1]`).
`location` | string | The file:line location of the line of code that produced the message. Only some of the messages have this field set; it depends on specifically how the message was logged. The `--vmodule` flag passed to the node producing the message also affects what rows get this field populated. Generally, if `--vmodule=<file>=<level>` is specified, messages produced by that file will have the field populated.
`operation` | string | The name of the operation (or sub-operation) on whose behalf the message was logged.
`span` | int | The index of the span within the virtual list of all spans if they were ordered by the span's start time.

{{site.data.alerts.callout_info}}If the <code>COMPACT</code> keyword was specified, only the <code>age</code>, <code>message</code>, <code>tag</code> and <code>operation</code> columns are returned. In addition, the value of the <code>location</code> columns is prepended to <code>message</code>.{{site.data.alerts.end}}

## Examples

### Trace a session

{% include copy-clipboard.html %}
~~~ sql
> SET tracing = on;
~~~

~~~
SET TRACING
~~~

{% include copy-clipboard.html %}
~~~ sql
> SHOW TRACE FOR SESSION;
~~~

~~~
+----------------------------------+---------------+-------------------------------------------------------+------------------------------------------------+----------+-----------------------------------+------+
|            timestamp             |      age      |                        message                        |                      tag                       | location |             operation             | span |
+----------------------------------+---------------+-------------------------------------------------------+------------------------------------------------+----------+-----------------------------------+------+
| 2018-03-08 21:22:18.266373+00:00 | 0s            | === SPAN START: sql txn ===                           |                                                |          | sql txn                           |    0 |
| 2018-03-08 21:22:18.267341+00:00 | 967??s713ns    | === SPAN START: session recording ===                 |                                                |          | session recording                 |    5 |
| 2018-03-08 21:22:18.267343+00:00 | 969??s760ns    | === SPAN START: starting plan ===                     |                                                |          | starting plan                     |    1 |
| 2018-03-08 21:22:18.267367+00:00 | 993??s551ns    | === SPAN START: consuming rows ===                    |                                                |          | consuming rows                    |    2 |
| 2018-03-08 21:22:18.267384+00:00 | 1ms10??s504ns  | Scan /Table/51/{1-2}                                  | [n1,client=[::1]:58264,user=root]              |          | sql txn                           |    0 |
| 2018-03-08 21:22:18.267434+00:00 | 1ms60??s392ns  | === SPAN START: dist sender ===                       |                                                |          | dist sender                       |    3 |
| 2018-03-08 21:22:18.267444+00:00 | 1ms71??s136ns  | querying next range at /Table/51/1                    | [client=[::1]:58264,user=root,txn=76d25cda,n1] |          | dist sender                       |    3 |
| 2018-03-08 21:22:18.267462+00:00 | 1ms88??s421ns  | r20: sending batch 1 Scan to (n1,s1):1                | [client=[::1]:58264,user=root,txn=76d25cda,n1] |          | dist sender                       |    3 |
| 2018-03-08 21:22:18.267465+00:00 | 1ms91??s570ns  | sending request to local server                       | [client=[::1]:58264,user=root,txn=76d25cda,n1] |          | dist sender                       |    3 |
| 2018-03-08 21:22:18.267467+00:00 | 1ms93??s707ns  | === SPAN START: /cockroach.roachpb.Internal/Batch === |                                                |          | /cockroach.roachpb.Internal/Batch |    4 |
| 2018-03-08 21:22:18.267469+00:00 | 1ms96??s103ns  | 1 Scan                                                | [n1]                                           |          | /cockroach.roachpb.Internal/Batch |    4 |
| 2018-03-08 21:22:18.267471+00:00 | 1ms97??s437ns  | read has no clock uncertainty                         | [n1]                                           |          | /cockroach.roachpb.Internal/Batch |    4 |
| 2018-03-08 21:22:18.267474+00:00 | 1ms101??s60ns  | executing 1 requests                                  | [n1,s1]                                        |          | /cockroach.roachpb.Internal/Batch |    4 |
| 2018-03-08 21:22:18.267479+00:00 | 1ms105??s912ns | read-only path                                        | [n1,s1,r20/1:/Table/5{1-2}]                    |          | /cockroach.roachpb.Internal/Batch |    4 |
| 2018-03-08 21:22:18.267483+00:00 | 1ms110??s94ns  | command queue                                         | [n1,s1,r20/1:/Table/5{1-2}]                    |          | /cockroach.roachpb.Internal/Batch |    4 |
| 2018-03-08 21:22:18.267487+00:00 | 1ms114??s240ns | waiting for read lock                                 | [n1,s1,r20/1:/Table/5{1-2}]                    |          | /cockroach.roachpb.Internal/Batch |    4 |
| 2018-03-08 21:22:18.26752+00:00  | 1ms146??s596ns | read completed                                        | [n1,s1,r20/1:/Table/5{1-2}]                    |          | /cockroach.roachpb.Internal/Batch |    4 |
| 2018-03-08 21:22:18.267566+00:00 | 1ms192??s724ns | plan completed execution                              | [n1,client=[::1]:58264,user=root]              |          | consuming rows                    |    2 |
| 2018-03-08 21:22:18.267568+00:00 | 1ms195??s60ns  | resources released, stopping trace                    | [n1,client=[::1]:58264,user=root]              |          | consuming rows                    |    2 |
+----------------------------------+---------------+-------------------------------------------------------+------------------------------------------------+----------+-----------------------------------+------+
(19 rows)
~~~

### Trace conflicting transactions

In this example, we use two terminals concurrently to generate conflicting transactions.

1. In terminal 1, create a table:

    {% include copy-clipboard.html %}
    ~~~ sql
    > CREATE TABLE t (k INT);
    ~~~

2. Still in terminal 1, open a transaction and perform a write without closing the transaction:

    {% include copy-clipboard.html %}
    ~~~ sql
    > BEGIN;
    ~~~

    {% include copy-clipboard.html %}
    ~~~ sql
    > INSERT INTO t VALUES (1);
    ~~~

    Press enter one more time to send these statements to the server.

3. In terminal 2, turn tracing on:

    ~~~
    > SET tracing = on;
    ~~~

4.  Still in terminal 2, execute a conflicting read:

    {% include copy-clipboard.html %}
    ~~~ sql
    > SELECT * FROM t;
    ~~~

    You'll see that this statement is blocked until the transaction in terminal 1 finishes.

4. Back in terminal 1, finish the transaction:

    {% include copy-clipboard.html %}
    ~~~ sql
    > COMMIT;
    ~~~

5. In terminal 2, you'll see the completed read:

    ~~~
    +---+
    | k |
    +---+
    | 1 |
    +---+
    ~~~

6. Still in terminal 2, stop tracing and then view the completed trace:

    {{site.data.alerts.callout_success}}Check the lines starting with <code>#Annotation</code> for insights into how the conflict is traced.{{site.data.alerts.end}}

    ~~~
    +--------------------+------+--------------------------------------------------------------------------+
    |        age         | span |                                 message                                  |
    +--------------------+------+--------------------------------------------------------------------------+
    | 0s                 |    0 | === SPAN START: session recording ===                                    |
    | 26??s841ns          |    0 | [NoTxn pos:25] executing Sync                                            |
    | 214??s31ns          |    0 | [NoTxn pos:26] executing ExecStmt: SHOW TRANSACTION STATUS               |
    ...
    | 6s289ms100??s820ns  |    3 | === SPAN START: sql txn ===                                              |
    | 6s289ms136??s804ns  |    3 | [Open pos:34] executing ExecStmt: SELECT * FROM t                        |
    | 6s289ms147??s236ns  |    3 | executing: SELECT * FROM t in state: Open                                |
    | 6s289ms169??s623ns  |    3 | planning starts: SELECT                                                  |
    | 6s289ms171??s400ns  |    3 | generating optimizer plan                                                |
    | 6s289ms203??s35ns   |    3 | added table 'defaultdb.public.t' to table collection                     |
    | 6s289ms300??s796ns  |    3 | optimizer plan succeeded                                                 |
    | 6s289ms301??s851ns  |    3 | planning ends                                                            |
    | 6s289ms305??s338ns  |    3 | checking distributability                                                |
    | 6s289ms308??s608ns  |    3 | distributable plan: true                                                 |
    | 6s289ms314??s399ns  |    3 | execution starts: distributed                                            |
    | 6s289ms315??s380ns  |    4 | === SPAN START: consuming rows ===                                       |
    | 6s289ms327??s736ns  |    3 | creating DistSQL plan                                                    |
    | 6s289ms360??s73ns   |    3 | querying next range at /Table/52/1                                       |
    | 6s289ms397??s745ns  |    3 | running DistSQL plan                                                     |
    | 6s289ms411??s676ns  |    5 | === SPAN START: flow ===                                                 |
    | 6s289ms459??s347ns  |    5 | starting (1 processors, 0 startables)                                    |
    | 6s289ms476??s196ns  |    8 | === SPAN START: table reader ===                                         |
    |                    |      |                                                                          |
    |                    |      | cockroach.stat.tablereader.stalltime: 7??s                                |
    |                    |      |                                                                          |
    |                    |      | cockroach.processorid: 0                                                 |
    |                    |      |                                                                          |
    |                    |      | cockroach.stat.tablereader.input.rows: 2                                 |
    | 6s290ms23??s213ns   |    8 | Scan /Table/52/{1-2}                                                     |
    | 6s290ms39??s563ns   |    9 | === SPAN START: dist sender ===                                          |
    | 6s290ms82??s250ns   |    9 | querying next range at /Table/52/1                                       |
    | 6s290ms106??s319ns  |    9 | r23: sending batch 1 Scan to (n1,s1):1                                   |
    | 6s290ms112??s72ns   |    9 | sending request to local server                                          |
    | 6s290ms156??s75ns   |   10 | === SPAN START: /cockroach.roachpb.Internal/Batch ===                    |
    | 6s290ms160??s422ns  |   10 | 1 Scan                                                                   |
    | 6s290ms166??s984ns  |   10 | executing 1 requests                                                     |
    | 6s290ms175??s94ns   |   10 | read-only path                                                           |
    | 6s290ms179??s708ns  |   10 | read has no clock uncertainty                                            |
    | 6s290ms186??s84ns   |   10 | command queue                                                            |
    | 6s290ms203??s789ns  |   10 | waiting for read lock                                                    |
    | # Annotation: The following line identifies the conflict and describes the conflict resolution.      |
    | 6s290ms318??s839ns  |   10 | conflicting intents on /Table/52/1/372254698480435201/0                  |
    | 6s290ms337??s353ns  |   10 | replica.Send got error: conflicting intents on                           |
    |                    |      | /Table/52/1/372254698480435201/0                                         |
    | 6s290ms352??s992ns  |   10 | adding f4a8193b to contention queue on intent                            |
    |                    |      | /Table/52/1/372254698480435201/0 @c4203a16                               |
    | # Annotation: The read is now going to wait for the writer to finish by executing a PushTxn request. |
    | 6s290ms362??s345ns  |   10 | pushing 1 transaction(s)                                                 |
    | 6s290ms370??s927ns  |   11 | === SPAN START: dist sender ===                                          |
    | 6s290ms378??s722ns  |   11 | querying next range at /Table/52/1/372254698480435201/0                  |
    | 6s290ms389??s560ns  |   11 | r23: sending batch 1 PushTxn to (n1,s1):1                                |
    | 6s290ms392??s349ns  |   11 | sending request to local server                                          |
    | 6s290ms455??s709ns  |   12 | === SPAN START: /cockroach.roachpb.Internal/Batch ===                    |
    | 6s290ms461??s351ns  |   12 | 1 PushTxn                                                                |
    | 6s290ms464??s607ns  |   12 | executing 1 requests                                                     |
    | 6s290ms471??s394ns  |   12 | read-write path                                                          |
    | 6s290ms476??s558ns  |   12 | command queue                                                            |
    | 6s290ms484??s12ns   |   12 | applied timestamp cache                                                  |
    | 6s290ms593??s363ns  |   12 | evaluated request                                                        |
    | 6s290ms606??s183ns  |   12 | replica.Send got error: failed to push "sql txn" id=c4203a16             |
    |                    |      | key=/Table/52/1/372254698480435201/0 rw=true pri=0.03424799              |
    |                    |      | iso=SERIALIZABLE stat=PENDING epo=0 ts=1533673518.429352831,0            |
    |                    |      | orig=1533673518.429352831,0 max=1533673518.429352831,0 wto=false         |
    |                    |      | rop=false seq=1                                                          |
    | 6s290ms617??s794ns  |   12 | f4a8193b pushing c4203a16 (1 pending)                                    |
    | 6s290ms655??s798ns  |   12 | querying pushee                                                          |
    ...
    | 11s777ms251??s907ns |   20 | === SPAN START: /cockroach.roachpb.Internal/Batch ===                    |
    | 11s777ms261??s211ns |   20 | 1 QueryTxn                                                               |
    | 11s777ms286??s672ns |   20 | executing 1 requests                                                     |
    | 11s777ms300??s370ns |   20 | read-only path                                                           |
    | 11s777ms371??s665ns |   20 | command queue                                                            |
    | 11s777ms393??s277ns |   20 | waiting for 1 overlapping requests                                       |
    | 11s779ms520??s651ns |   20 | waited 2.113298ms for overlapping requests                               |
    | 11s779ms543??s461ns |   20 | waiting for read lock                                                    |
    | 11s779ms641??s611ns |   20 | read completed                                                           |
    | 12s440ms469??s377ns |   12 | result of pending push: "sql txn" id=c4203a16                            |
    |                    |      | key=/Table/52/1/372254698480435201/0 rw=true pri=0.03424799              |
    |                    |      | iso=SERIALIZABLE stat=COMMITTED epo=0 ts=1533673518.429352831,0          |
    |                    |      | orig=1533673518.429352831,0 max=1533673518.429352831,0 wto=false         |
    |                    |      | rop=false seq=3                                                          |
    | # Annotation: The writer is detected to have finished.                                               |
    | 12s440ms473??s127ns |   12 | push request is satisfied                                                |
    | 12s440ms546??s916ns |   10 | c4203a16-78c5-4841-92f3-9a0c966ba9db is now COMMITTED                    |
    | # Annotation: The write has committed. Some cleanup follows.                                         |
    | 12s440ms551??s686ns |   10 | resolving intents [wait=false]                                           |
    | 12s440ms603??s878ns |   21 | === SPAN START: dist sender ===                                          |
    | 12s440ms648??s131ns |   21 | querying next range at /Table/52/1/372254698480435201/0                  |
    | 12s440ms692??s427ns |   21 | r23: sending batch 1 ResolveIntent to (n1,s1):1                          |
    | 12s440ms699??s732ns |   21 | sending request to local server                                          |
    | 12s440ms703??s670ns |   22 | === SPAN START: /cockroach.roachpb.Internal/Batch ===                    |
    | 12s440ms708??s476ns |   22 | 1 ResolveIntent                                                          |
    | 12s440ms714??s221ns |   22 | executing 1 requests                                                     |
    | 12s440ms720??s853ns |   22 | read-write path                                                          |
    | 12s440ms733??s90ns  |   22 | command queue                                                            |
    | 12s440ms742??s916ns |   22 | applied timestamp cache                                                  |
    | 12s440ms831??s18ns  |   22 | evaluated request                                                        |
    | 12s440ms857??s118ns |   10 | read-only path                                                           |
    | 12s440ms860??s848ns |   10 | read has no clock uncertainty                                            |
    | 12s440ms867??s261ns |   10 | command queue                                                            |
    | 12s440ms873??s171ns |   10 | waiting for read lock                                                    |
    | # Annotation: This is where we would have been if there hadn't been a conflict.                      |
    | 12s440ms913??s370ns |   10 | read completed                                                           |
    | 12s440ms961??s323ns |   10 | f4a8193b finished, leaving intent? false (owned by <nil>)                |
    | 12s441ms989??s325ns |    3 | execution ends                                                           |
    | 12s441ms991??s398ns |    3 | rows affected: 2                                                         |
    | 12s442ms22??s953ns  |    3 | AutoCommit. err: <nil>                                                   |
    | 12s442ms44??s376ns  |    0 | releasing 1 tables                                                       |
    | 12s442ms57??s49ns   |    0 | [NoTxn pos:35] executing Sync                                            |
    | 12s442ms449??s324ns |    0 | [NoTxn pos:36] executing ExecStmt: SHOW TRANSACTION STATUS               |
    | 12s442ms457??s347ns |    0 | executing: SHOW TRANSACTION STATUS in state: NoTxn                       |
    | 12s442ms466??s126ns |    0 | [NoTxn pos:37] executing Sync                                            |
    | 12s442ms586??s65ns  |    0 | [NoTxn pos:38] executing ExecStmt: SHOW database                         |
    | 12s442ms591??s342ns |    0 | executing: SHOW database in state: NoTxn                                 |
    | 12s442ms599??s279ns |    6 | === SPAN START: sql txn ===                                              |
    | 12s442ms621??s543ns |    6 | [Open pos:38] executing ExecStmt: SHOW database                          |
    | 12s442ms624??s632ns |    6 | executing: SHOW database in state: Open                                  |
    | 12s442ms639??s579ns |    6 | planning starts: SHOW                                                    |
    | 12s442ms641??s610ns |    6 | generating optimizer plan                                                |
    | 12s442ms657??s397ns |    6 | optimizer plan failed: unsupported statement: *tree.ShowVar              |
    | 12s442ms659??s345ns |    6 | optimizer falls back on heuristic planner                                |
    | 12s442ms666??s926ns |    6 | query is correlated: false                                               |
    | 12s442ms667??s859ns |    6 | heuristic planner starts                                                 |
    | 12s442ms765??s327ns |    6 | heuristic planner optimizes plan                                         |
    | 12s442ms811??s772ns |    6 | heuristic planner optimizes subqueries                                   |
    | 12s442ms812??s988ns |    6 | planning ends                                                            |
    | 12s442ms815??s950ns |    6 | checking distributability                                                |
    | 12s442ms825??s105ns |    6 | query not supported for distSQL: unsupported node *sql.valuesNode        |
    | 12s442ms826??s599ns |    6 | distributable plan: false                                                |
    | 12s442ms828??s79ns  |    6 | execution starts: local                                                  |
    | 12s442ms832??s803ns |    7 | === SPAN START: consuming rows ===                                       |
    | 12s442ms845??s752ns |    6 | execution ends                                                           |
    | 12s442ms846??s750ns |    6 | rows affected: 1                                                         |
    | 12s442ms860??s278ns |    6 | AutoCommit. err: <nil>                                                   |
    | 12s442ms869??s681ns |    0 | [NoTxn pos:39] executing Sync                                            |
    | 12s442ms975??s847ns |    0 | [NoTxn pos:40] executing ExecStmt: SHOW TRANSACTION STATUS               |
    | 12s442ms979??s816ns |    0 | executing: SHOW TRANSACTION STATUS in state: NoTxn                       |
    | 12s442ms987??s160ns |    0 | [NoTxn pos:41] executing Sync                                            |
    | 21s727ms852??s808ns |    0 | [NoTxn pos:42] executing ExecStmt: SHOW SYNTAX 'set tracing = off;'      |
    | 21s727ms875??s564ns |    0 | executing: SHOW SYNTAX 'set tracing = off;' in state: NoTxn              |
    | 21s727ms955??s982ns |    0 | [NoTxn pos:43] executing Sync                                            |
    | 21s728ms150??s348ns |    0 | [NoTxn pos:44] executing ExecStmt: SET TRACING = off                     |
    | 21s728ms163??s798ns |    0 | executing: SET TRACING = off in state: NoTxn                             |
    +--------------------+------+--------------------------------------------------------------------------+
    ~~~

### Trace a transaction retry

In this example, we use session tracing to show an [automatic transaction retry](transactions.html#automatic-retries). Like in the previous example, we'll have to use two terminals because retries are induced by unfortunate interactions between transactions.

1. In terminal 1, turn on trace recording and then start a transaction:

    {% include copy-clipboard.html %}
    ~~~ sql
    > SET tracing = on;
    ~~~

    {% include copy-clipboard.html %}
    ~~~ sql
    > BEGIN;
    ~~~

    Starting a transaction gets us an early timestamp, i.e., we "lock" the snapshot of the data on which the transaction is going to operate.

2. In terminal 2, perform a read:

    {% include copy-clipboard.html %}
    ~~~ sql
    > SELECT * FROM t;
    ~~~

    This read is performed at a timestamp higher than the timestamp of the transaction running in terminal 1. Because we're running at the [`SERIALIZABLE` transaction isolation level](architecture/transaction-layer.html#isolation-levels), if the system allows terminal 1's transaction to commit, it will have to ensure that ordering terminal 1's transaction *before* terminal 2's transaction is valid; this will become relevant in a second.

3. Back in terminal 1, execute and trace a conflicting write:

    {% include copy-clipboard.html %}
    ~~~ sql
    > INSERT INTO t VALUES (1);
    ~~~

    At this point, the system will detect the conflict and realize that the transaction can no longer commit because allowing it to commit would mean that we have changed history with respect to terminal 2's read. As a result, it will automatically retry the transaction so it can be serialized *after* terminal 2's transaction. The trace will reflect this retry.

4. Turn off trace recording and request the trace:

    {% include copy-clipboard.html %}
  	~~~ sql
  	> SET tracing = off;
  	~~~

    {% include copy-clipboard.html %}
  	~~~ sql
  	> SELECT age, message FROM [SHOW TRACE FOR SESSION];
  	~~~

    {{site.data.alerts.callout_success}}Check the lines starting with <code>#Annotation</code> for insights into how the retry is traced.{{site.data.alerts.end}}

  	~~~ shell
  	+--------------------+---------------------------------------------------------------------------------------------------------------+
  	|        age         |        message                                                                                                |
  	+--------------------+---------------------------------------------------------------------------------------------------------------+
  	| 0s                 | === SPAN START: sql txn implicit ===                                                                          |
  	| 123??s317ns         | AutoCommit. err: <nil>                                                                                        |
  	|                    | txn: "sql txn implicit" id=64d34fbc key=/Min rw=false pri=0.02500536 iso=SERIALIZABLE stat=COMMITTED ...      |
  	| 1s767ms959??s448ns  | === SPAN START: sql txn ===                                                                                   |
  	| 1s767ms989??s448ns  | executing 1/1: BEGIN TRANSACTION                                                                              |
  	| # Annotation: First execution of INSERT.                                                                                           |
  	| 13s536ms79??s67ns   | executing 1/1: INSERT INTO t VALUES (1)                                                                       |
  	| 13s536ms134??s682ns | client.Txn did AutoCommit. err: <nil>                                                                         |
  	|                    | txn: "unnamed" id=329e7307 key=/Min rw=false pri=0.01354772 iso=SERIALIZABLE stat=COMMITTED epo=0 ...         |
  	| 13s536ms143??s145ns | added table 't' to table collection                                                                           |
  	| 13s536ms305??s103ns | query not supported for distSQL: mutations not supported                                                      |
  	| 13s536ms365??s919ns | querying next range at /Table/61/1/285904591228600321/0                                                       |
  	| 13s536ms400??s155ns | r42: sending batch 1 CPut, 1 BeginTxn to (n1,s1):1                                                            |
  	| 13s536ms422??s268ns | sending request to local server                                                                               |
  	| 13s536ms434??s962ns | === SPAN START: /cockroach.roachpb.Internal/Batch ===                                                         |
  	| 13s536ms439??s916ns | 1 CPut, 1 BeginTxn                                                                                            |
  	| 13s536ms442??s413ns | read has no clock uncertainty                                                                                 |
  	| 13s536ms447??s42ns  | executing 2 requests                                                                                          |
  	| 13s536ms454??s413ns | read-write path                                                                                               |
  	| 13s536ms462??s456ns | command queue                                                                                                 |
  	| 13s536ms497??s475ns | applied timestamp cache                                                                                       |
  	| 13s536ms637??s637ns | evaluated request                                                                                             |
  	| 13s536ms646??s468ns | acquired {raft,replica}mu                                                                                     |
  	| 13s536ms947??s970ns | applying command                                                                                              |
  	| 13s537ms34??s667ns  | coordinator spawns                                                                                            |
  	| 13s537ms41??s171ns  | === SPAN START: [async] kv.TxnCoordSender: heartbeat loop ===                                                 |
  	| # Annotation: The conflict is about to be detected in the form of a retriable error.                                               |
  	| 13s537ms77??s356ns  | automatically retrying transaction: sql txn (id: b4bd1f60-30d9-4465-bdb6-6b553aa42a96) because of error:      |
  	|                      HandledRetryableTxnError: serializable transaction timestamp pushed (detected by SQL Executor)                |
  	| # Annotation: Second execution of INSERT.                                                                                          |
  	| 13s537ms83??s369ns  | executing 1/1: INSERT INTO t VALUES (1)                                                                       |
  	| 13s537ms109??s516ns | client.Txn did AutoCommit. err: <nil>                                                                         |
  	|                    | txn: "unnamed" id=1228171b key=/Min rw=false pri=0.02917782 iso=SERIALIZABLE stat=COMMITTED epo=0             |
  	|                      ts=1507321556.991937203,0 orig=1507321556.991937203,0 max=1507321557.491937203,0 wto=false rop=false          |
  	| 13s537ms111??s738ns | releasing 1 tables                                                                                            |
  	| 13s537ms116??s944ns | added table 't' to table collection                                                                           |
  	| 13s537ms163??s155ns | query not supported for distSQL: writing txn                                                                  |
  	| 13s537ms192??s584ns | querying next range at /Table/61/1/285904591231418369/0                                                       |
  	| 13s537ms209??s601ns | r42: sending batch 1 CPut to (n1,s1):1                                                                        |
  	| 13s537ms224??s219ns | sending request to local server                                                                               |
  	| 13s537ms233??s350ns | === SPAN START: /cockroach.roachpb.Internal/Batch ===                                                         |
  	| 13s537ms236??s572ns | 1 CPut                                                                                                        |
  	| 13s537ms238??s39ns  | read has no clock uncertainty                                                                                 |
  	| 13s537ms241??s255ns | executing 1 requests                                                                                          |
  	| 13s537ms245??s473ns | read-write path                                                                                               |
  	| 13s537ms248??s915ns | command queue                                                                                                 |
  	| 13s537ms261??s543ns | applied timestamp cache                                                                                       |
  	| 13s537ms309??s401ns | evaluated request                                                                                             |
  	| 13s537ms315??s302ns | acquired {raft,replica}mu                                                                                     |
  	| 13s537ms580??s149ns | applying command                                                                                              |
  	| 18s378ms239??s968ns | executing 1/1: COMMIT TRANSACTION                                                                             |
  	| 18s378ms291??s929ns | querying next range at /Table/61/1/285904591228600321/0                                                       |
  	| 18s378ms322??s473ns | r42: sending batch 1 EndTxn to (n1,s1):1                                                                      |
  	| 18s378ms348??s650ns | sending request to local server                                                                               |
  	| 18s378ms364??s928ns | === SPAN START: /cockroach.roachpb.Internal/Batch ===                                                         |
  	| 18s378ms370??s772ns | 1 EndTxn                                                                                                      |
  	| 18s378ms373??s902ns | read has no clock uncertainty                                                                                 |
  	| 18s378ms378??s613ns | executing 1 requests                                                                                          |
  	| 18s378ms386??s573ns | read-write path                                                                                               |
  	| 18s378ms394??s316ns | command queue                                                                                                 |
  	| 18s378ms417??s576ns | applied timestamp cache                                                                                       |
  	| 18s378ms588??s396ns | evaluated request                                                                                             |
  	| 18s378ms597??s715ns | acquired {raft,replica}mu                                                                                     |
  	| 18s383ms388??s599ns | applying command                                                                                              |
  	| 18s383ms494??s709ns | coordinator stops                                                                                             |
  	| 23s169ms850??s906ns | === SPAN START: sql txn implicit ===                                                                          |
  	| 23s169ms885??s921ns | executing 1/1: SET tracing = off                                                                              |
  	| 23s169ms919??s90ns  | query not supported for distSQL: SET / SET CLUSTER SETTING should never distribute                            |
  	+--------------------+---------------------------------------------------------------------------------------------------------------+
  	~~~

## See also

- [`EXPLAIN`](explain.html)
- [`SET (session settings)`](set-vars.html)
