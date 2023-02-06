### Unreleased

### 1.0.0.rc1 - 2023-02-06

* Added the `@specifiedBy` directive
* Added request extensions
* Base controller and base channel
* An easy to use [GraphiQL](https://github.com/graphql/graphiql) view
* A brand new inline type creator
* Organized several method names to follow one single patter
* Several fixes to events and callbacks
* Fixes for source hooks
* Fixes for scoped arguments
* Docs now available on the [website](https://www.rails-graphql.dev/)

### 1.0.0.beta - 2023-01-23

* Brand new parser, way faster than the previous one and 12x faster than the original gem
* Subscriptions are now available using ActionCable
* Sources are now built on demand
* A nice backtrace display for when things go wrong
* Methods to validate and compile queries for tests and in preparation for a strict mode feature
* Simple way to provide data to requests for both testing and reuse
* Alternatives are now available: fields can be defined in a standalone class, or in groups, apart from where they will actually live
* Support for persisted queries and several caching features
* Support to ActiveRecord running MySQL
* Fields description can now be defined on I18n
* Way better integration with Zeitwrek. Now the `graphql` folder is 100% compliant with reloader, even though it has its particular structure
* Everything now is compliant with GlobalID, which means that GraphQL objects like fields and directives can be sent to ActiveJob and other places in a serializable way
* TypeMap versioning, so that the application can be updated without tearing down GraphQL
* Lots of performance improvements
