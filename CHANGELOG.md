### Unreleased

* A source built before the schema of its namespace is loaded now attaches its query, mutation, and subscription fields to that schema when the schema registers
* Importing a field that a schema already holds as a proxy of that same field is now a no-op instead of an error, and a field name taken by both a schema and a source loaded later is reported by the schema's validation, on every request, after the other fields of that source are attached
* `trigger_for` and `unsubscribe_from` on a subscription field now read an argument's value from a hash or hash-like object under a string key, and read a `false` or `null` value under a symbol key as that value, instead of yielding the argument's name; a hash or a struct given directly is read as one object instead of being iterated, and a hash-like object (one that answers `[]`, `key?`, and `each_pair`) is read only by its keys, never through a method of the same name
* A directive argument whose value is `false` is now printed by `to_gql`, a `null` argument before a printed one no longer leaves a leading comma, a directive with nothing to print no longer prints empty parentheses, and a directive instance can be compiled on its own
* A `null` written in a document for an argument, a directive argument, or a variable default is now the value `null`, and an argument that does not accept `null` still refuses it
* A list value written inline in a document (an argument, or a variable default) now parses
* The integer `0`, and a float starting with `0`, now parse as a value in a document
* A `null` inside a list, written in a document or given as a variable, is now the value `null` for every item type, and is refused by an argument whose list items cannot be null; a lone `-` or a number followed by a name character is no longer read as a number; a list given to an input object argument, or an invalid list given as a variable default, is refused; and the error for an invalid value shows a list as written and a string quoted
* Fix an input object field, or a directive argument given to `build`, being read as `null` (so its default applied) when `false` is given under its GraphQL name and that name differs from its Ruby name
* Stricter handling of the end of a document in the parser
* A list value that cannot be read is now a parser error
* A comment no longer moves the end position of the token before it
* Fix the token after a list of directives being skipped (the next field, its alias or arguments, or the next definition); a stray token there is now a parser error
* A token that ends with directives no longer extends past them
* Listeners of directives attached to a schema are now triggered during a request (those declared with `exclusive_callback: false`, for an event whose source is not the schema)
* The `query`, `mutation`, and `subscription` events now have the operation as their source, and are also triggered for an operation loaded from the cache
* A component loaded from the cache now goes through the same steps, under the same stack, as when it is organized, so the listeners of its `organized` event run, its authorization is checked before its selection, and the errors have the same path
* An exception from a listener or from an authorization check is now reported as an error of the component when it is loaded from the cache
* A request in which a component was invalid or refused, or that could not be parsed, or that did not complete, is no longer written to the request cache, since a component was left unorganized or its error was for that request only; such a document cannot be compiled either
* A request with a persisted query key that is not in the cache now gets the `PersistedQueryNotFound` response, and a document is only persisted under a persisted query key that is its SHA-256 digest
* Fix a cache key object being changed by the schema when it is used, which made a persisted query never be found again through a cache store

### 1.0.0

* Allow ENUM inputs to receive strings (needs to be enabled through config)
* Set up the project's CI

### 1.0.0.rc2 - 2023-02-28

* Fixes for inputs
* Fixes for callbacks and field ownership
* Fixes for the inline type creator and sources
* Fixes to folder structure and constant management
* Provide a better URL for the ISO 8601 specification
* Make some constants private

### 1.0.0.rc1 - 2023-02-06

* Added the `@specifiedBy` directive
* Added request extensions
* Base controller and base channel
* An easy-to-use [GraphiQL](https://github.com/graphql/graphiql) view
* A brand new inline type creator
* Organized several method names to follow one single pattern
* Several fixes to events and callbacks
* Fixes for source hooks
* Fixes for scoped arguments
* Docs now available on the [website](https://rails-graphql.dev/)

### 1.0.0.beta - 2023-01-23

* Brand new parser, way faster than the previous one and 12x faster than the original gem
* Subscriptions are now available using ActionCable
* Sources are now built on demand
* A nice backtrace display for when things go wrong
* Methods to validate and compile queries for tests and in preparation for a strict mode feature
* Simple way to provide data to requests for both testing and reuse
* Alternatives are now available: fields can be defined in a standalone class, or in groups, apart from where they will actually live
* Support for persisted queries and several caching features
* Support for ActiveRecord running MySQL
* Field descriptions can now be defined on I18n
* Way better integration with Zeitwerk. Now the `graphql` folder is 100% compliant with the reloader, even though it has its particular structure
* Everything now is compliant with GlobalID, which means that GraphQL objects like fields and directives can be sent to ActiveJob and other places in a serializable way
* TypeMap versioning, so that the application can be updated without tearing down GraphQL
* Lots of performance improvements
