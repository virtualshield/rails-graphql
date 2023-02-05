---
layout: default
title: Controller - Customizing - Guides
description: All the available methods that you can override to customize the controller
---

# Controller

This gem provides the `GraphQL::Controller` concern that has everything you may need
to run your requests through `ActionController`. You can also use the `GraphQL::BaseController`
as your superclass (which just implements the concern).

## Settings

{: title="gql_schema" id="settings-gql-schema" }
### `gql_schema`

This setting allows defining which schema will be used by default.

```ruby
# app/controllers/my_controller.rb
self.gql_schema = 'GraphQL::MySchema'
# OR
self.gql_schema = GraphQL::MySchema
```

{: .note }
> The [namespace](/guides/advanced/namespaces) is not supported because the class
must be loaded before the schema can be found.

## Actions

Here is the list of actions that are implemented by the concern:

{: title="execute" id="execute" }
### `POST execute`

It will use the helpers provided to execute a request for the [`gql_query`](#gql_query).

{: title="describe" id="describe" }
### `GET describe`

It will print a plain GraphQL document that represents everything that
is defined in the schema.

{: title="graphiql" id="graphiql" }
### `GET graphiql`

It will render a
<a href="https://github.com/graphql/graphiql" target="_blank" rel="external nofollow">GraphiQL</a>
console for the underlying schema.

## Helpers

{: title="gql_compiled_request" id="gql_compiled_request" }
### `gql_compiled_request?(document)`

Identifies if the request should be threated as a compiled request.<br/>Default: `false`.

{: title="gql_request_response" id="gql_request_response" }
### `gql_request_response(*args, **xargs)`

It will render a JSON with the response of the [`gql_request`](#gql_request) helper.

{: title="gql_request" id="gql_request" }
### `gql_request(document, **xargs)`

It will collect the necessary pieces using other helpers and then execute the
[request](/guides/request) for the provided `document`. You can provide
the following named arguments: `operation_name`, `variables`, `context`, `schema`,
and `query_cache_key`.

{: title="gql_schema" id="gql_schema" }
### `gql_schema`

It will resolve the underlying schema from [`self.class.gql_schema`](#settings-gql-schema)
or by attempting to find a schema with the same name as your application.

{: title="gql_query" id="gql_query" }
### `gql_query`

It returns the GraphQL document as `params[:query]`.

{: title="gql_query_cache_key" id="gql_query_cache_key" }
### `gql_query_cache_key(key = nil, version = nil)`

Attempt to build build a cache key for [cached requests](/guides/advanced/request#caching).
You can provide the `key`, or it will be fetched from `params[:query_cache_key]`, and
the `version`, or it will be fetched from `params[:query_cache_version]`.

{: title="gql_operation_name" id="gql_operation_name" }
### `gql_operation_name`

It returns the name for the GraphQL operation as `params[:operationName] || params[:operation_name]`.

{: title="gql_context" id="gql_context" }
### `gql_context`

It returns the context for the GraphQL request. You should override this method to
add your own keys to it.

{: title="gql_variables" id="gql_variables" }
### `gql_variables(variables = params[:variables])`

It will properly parse the provided `variables`, so it is a usable `Hash`. For example,
if the value is a string, it will `JSON.parse(variables)`, and if it is
controller parameters, it will `variables.permit!.to_h`.

{: title="gql_describe_schema" id="gql_describe_schema" }
### `gql_describe_schema(schema = gql_schema)`

It will generate the GraphQL string document of the provided `schema`.

{: title="gql_schema_header" id="gql_schema_header" }
### `gql_schema_header`

It will provide a nice header for the [`gql_describe_schema`](#gql_describe_schema).

{: title="gql_schema_footer" id="gql_schema_footer" }
### `gql_schema_footer`

It will provide a nice footer for the [`gql_describe_schema`](#gql_describe_schema).

{: title="gql_version" id="gql_version" }
### `gql_version`

It returns the version of the [Type Map](/guides/type-map).

{: title="graphiql_settings" id="graphiql_settings" }
### `graphiql_settings(mode = nil)`

It will return the proper settings for the GraphiQL console. It supports the `:fetch` and `:cable`.
You can override this method to change the `:url` and `:channel` settings.

