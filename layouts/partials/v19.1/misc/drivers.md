{{ site.data.alerts.callout_info }}
This page features drivers that we have tested enough to claim **beta-level** support. This means that applications using advanced or obscure features of a driver may encounter incompatibilities. If you encounter problems, please [open an issue](https://github.com/cockroachdb/cockroach/issues/new) with details to help us make progress toward full support.
{{ site.data.alerts.end }}

| App Language | Driver                                                                                                                                                                                                                                  | ORM                                                                 |
|--------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+---------------------------------------------------------------------|
| Go           | [pq](build-a-go-app-with-cockroachdb.html)                                                                                                                                                                                              | [GORM](build-a-go-app-with-cockroachdb-gorm.html)                   |
| Python       | [psycopg2](build-a-python-app-with-cockroachdb.html)                                                                                                                                                                                    | [SQLAlchemy](build-a-python-app-with-cockroachdb-sqlalchemy.html)   |
| Ruby         | [pg](build-a-ruby-app-with-cockroachdb.html)                                                                                                                                                                                            | [ActiveRecord](build-a-ruby-app-with-cockroachdb-activerecord.html) |
| Java         | [JDBC](build-a-java-app-with-cockroachdb.html)                                                                                                                                                                                          | [Hibernate](build-a-java-app-with-cockroachdb-hibernate.html)       |
| Node.js      | [pg](build-a-nodejs-app-with-cockroachdb.html)                                                                                                                                                                                          | [Sequelize](build-a-nodejs-app-with-cockroachdb-sequelize.html)     |
| C            | [libpq](http://www.postgresql.org/docs/9.5/static/libpq.html)                                                                                                                                                                           | No ORMs tested                                                      |
| C++          | [libpqxx](build-a-c++-app-with-cockroachdb.html)                                                                                                                                                                                        | No ORMs tested                                                      |
| C# (.NET)    | [Npgsql](build-a-csharp-app-with-cockroachdb.html)                                                                                                                                                                                      | No ORMs tested                                                      |
| Clojure      | [java.jdbc](build-a-clojure-app-with-cockroachdb.html)                                                                                                                                                                                  | No ORMs tested                                                      |
| PHP          | [php-pgsql](build-a-php-app-with-cockroachdb.html)                                                                                                                                                                                      | No ORMs tested                                                      |
| Rust         | <a href="https://crates.io/crates/postgres/" data-proofer-ignore>postgres</a> {%  comment %} This link is in HTML instead of Markdown because HTML proofer dies bc of https://github.com/rust-lang/crates.io/issues/163 {%  endcomment %} | No ORMs tested                                                      |
| TypeScript   | No drivers tested                                                                                                                                                                                                                       | [TypeORM](https://typeorm.io/#/)                                    |