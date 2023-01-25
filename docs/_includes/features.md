[GraphQL Parser](/guides/parser)
: Supporting the <a href="https://spec.graphql.org/October2021/" target="_blank" rel="external nofollow">October 2021</a> spec

[Schemas](/guides/schemas)
: One or multiple under the same application or across multiple engines

[Queries](/guides/queries)
: 3 different ways to defined your queries, besides sources

[Mutations](/guides/mutations)
: 3 different ways to defined your mutations, besides sources

[Subscriptions](/guides/subscriptions)
: 3 different ways to defined your subscriptions, besides sources

[Directives](/guides/directives)
: 3 directives provided: `@deprecated`, `@skip`, `@include`
: Event-driven interface to facilitate new directives

[Scalars](/guides/scalars)
: All the spec scalars plus: `any`, `bigint`, `binary`, `date`, `date_time`, `decimal`, `json`, and `time`

[Sources](/guides/sources)
: A bridge between struct-like classes and GraphQL types and fields
: Fully implemented for [ActiveRecord](/guides/sources/active-record) for `PostgreSQL`, `MySQL`, and `SQLite` databases.

[Shortcuts](/guides/architecture#shortcuts)
: Several shortcuts through `::GraphQL` module to access classes within the gem

[Type Map](/guides/type-map)
: A centralized place where all the types are stored and can be resolved

[Global ID](/guides/global-id)
: All objects defined supports `.to_global_id`, or simply `.to_gid`

[Subscriptions Provider](/guides/subscriptions/providers)
: Current supporting only [ActionCable](/guides/subscriptions/providers/action-cable-provider) provider and [Memory](/guides/subscriptions/providers/memory-store) store

[Introspection](/guides/introspection)
: All necessary types for introspection with proper descriptions
: Plain text display of the schemas

[Testing](/guides/testing)
: Support to validate GraphQL documents and stub values before requests

[Error Handling](/guides/error-handling)
: Full support to `rescue_from` within schemas
: A gracefully backtrace display
