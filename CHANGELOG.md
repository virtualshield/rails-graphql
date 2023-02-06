### Unreleased

### 1.0.0.rc1 - 2023-02-05

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
