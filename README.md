<a href="https://rails-graphql.dev/?utm_source=github">
  <img src="./docs/assets/images/github.png" alt="Rails GraphQL - GraphQL meets RoR with the most Ruby-like DSL" />
</a>

![Gem Version](https://badge.fury.io/rb/rails-graphql.svg)
<!-- [![Code Climate](https://codeclimate.com/github/virtualshield/rails-graphql/badges/gpa.svg)](https://codeclimate.com/github/virtualshield/rails-graphql) -->
<!--([![Test Coverage](https://codeclimate.com/github/virtualshield/rails-graphql/badges/coverage.svg)](https://codeclimate.com/github/virtualshield/rails-graphql/coverage))-->
<!--([![Dependency Status](https://gemnasium.com/badges/github.com/virtualshield/rails-graphql.svg)](https://gemnasium.com/github.com/virtualshield/rails-graphql))-->

[Wiki](https://rails-graphql.dev/?utm_source=github) |
[Bugs](https://github.com/virtualshield/rails-graphql/issues)

# Description

`rails-graphql` is a fresh new implementation of a GraphQL server, designed to be
as close as possible to Rails architecture and interfaces, which implies that it has
shortcuts, lots of syntax sugar, and direct connection with Rails features like
**ActiveRecord** and **ActionCable**.

This gem has its **own parser**, written from scratch, using the
**C-API of Ruby**, which empowers it with an outstanding performance.
Plus, all the features provided were carefully developed so that everyone will feel
comfortable and able to apply in all application sizes and patterns.

# 3 Simple Steps

## Install

```bash
# Add the gem to your Gemfile
$ bundle add rails-graphql
# Then run the Rails generator
$ rails g graphql:install
```

## Define

```ruby
# app/graphql/app_schema.rb
class GraphQL::AppSchema < GraphQL::Schema
  field(:welcome).resolve { 'Hello World!' }
end
```

## Run

```bash
$ curl -d '{"query":"{ welcome }"}' \
       -H "Content-Type: application/json" \
       -X POST http://localhost:3000/graphql
# {"data":{"welcome":"Hello World!"}}
```

# Features

[GraphQL Parser](https://rails-graphql.dev/guides/parser?utm_source=github)
: Supporting the <a href="https://spec.graphql.org/October2021/" target="_blank" rel="external nofollow">October 2021</a> spec

[Schemas](https://rails-graphql.dev/guides/schemas?utm_source=github)
: One or multiple under the same application or across multiple engines

[Queries](https://rails-graphql.dev/guides/queries?utm_source=github)
: 3 different ways to defined your queries, besides sources

[Mutations](https://rails-graphql.dev/guides/mutations?utm_source=github)
: 3 different ways to defined your mutations, besides sources

[Subscriptions](https://rails-graphql.dev/guides/subscriptions?utm_source=github)
: 3 different ways to defined your subscriptions, besides sources

[Directives](https://rails-graphql.dev/guides/directives?utm_source=github)
: 4 directives provided: `@deprecated`, `@skip`, `@include`, and `@specifiedBy`
: Event-driven interface to facilitate new directives

[Scalars](https://rails-graphql.dev/guides/scalars?utm_source=github)
: All the spec scalars plus: `any`, `bigint`, `binary`, `date`, `date_time`, `decimal`, `json`, and `time`

[Sources](https://rails-graphql.dev/guides/sources?utm_source=github)
: A bridge between classes and GraphQL types and fields
: Fully implemented for [ActiveRecord](https://rails-graphql.dev/guides/sources/active-record?utm_source=github) for `PostgreSQL`, `MySQL`, and `SQLite` databases.

[Generators](https://rails-graphql.dev/guides/generators?utm_source=github)
: Rails generators for you to get start quickly

[Shortcuts](https://rails-graphql.dev/guides/architecture#shortcuts?utm_source=github)
: Several shortcuts through `::GraphQL` module to access classes within the gem

[Type Map](https://rails-graphql.dev/guides/type-map?utm_source=github)
: A centralized place where all the types are stored and can be resolved

[Global ID](https://rails-graphql.dev/guides/global-id?utm_source=github)
: All objects defined supports `.to_global_id`, or simply `.to_gid`

[Subscriptions Provider](https://rails-graphql.dev/guides/subscriptions/providers?utm_source=github)
: Current supporting only [ActionCable](https://rails-graphql.dev/guides/subscriptions/action-cable-provider?utm_source=github) provider and [Memory](https://rails-graphql.dev/guides/subscriptions/memory-store?utm_source=github) store

[Introspection](https://rails-graphql.dev/guides/introspection?utm_source=github)
: All necessary types for introspection with proper descriptions
: Plain text display of the schemas

[Testing](https://rails-graphql.dev/guides/testing?utm_source=github)
: Support to validate GraphQL documents and stub values before requests

[Error Handling](https://rails-graphql.dev/guides/error-handling?utm_source=github)
: Full support to `rescue_from` within schemas
: A gracefully backtrace display

# How to contribute

To start, simply fork the project.

Run local tests using:
```
$ bundle install
$ bundle exec rake compile
$ bundle exec rake test
```
Finally, change the code and submit a pull request.

## License

Copyright © 2020-2023 VirtualShield LLC. See [The MIT License](MIT-LICENSE) for further
details.
