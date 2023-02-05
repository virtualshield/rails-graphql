---
layout: default
title: Channel - Customizing - Guides
description: All the available methods that you can override to customize the channel
---

# Channel

This gem provides the `GraphQL::Channel` concern that has everything you may need
to run your requests through `ActionCable`. You can also use the `GraphQL::BaseChannel`
as your superclass (which just implements the concern).

## Settings

{: title="gql_schema" id="settings-gql-schema" }
### `gql_schema`

This setting allows defining which schema will be used by default.

```ruby
# app/channels/my_channel.rb
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
### `execute(data)`

It will use the helpers provided to execute a request from the provided `data`.

## Helpers

{: title="gql_compiled_request" id="gql_compiled_request" }
### `gql_compiled_request?(data)`

Identifies if the received request within `data` should be threated as a compiled request.
<br/>Default: `false`.

{: title="gql_request_response" id="gql_request_response" }
### `gql_request_response(data)`

It will return the `Hash` for the response of the [`gql_response`](#gql_response)
generated using the provided `data`. It will also call
[`gql_merge_subscriptions`](#gql_merge_subscriptions) with any subscription
created during the request.

{: title="gql_merge_subscriptions" id="gql_merge_subscriptions" }
### `gql_merge_subscriptions(request)`

It will merge the current subscriptions with any other ones created during the
provided `request`.

{: title="gql_response" id="gql_response" }
### `gql_response(request)`

It will return a `Hash` with the response of the provided `request` in the
`:result` key and an additional `:more` key informing if any subscriptions
were added during the request.

{: title="gql_params" id="gql_params" }
### `gql_params(data)`

It will extract a series of parameters from the provided `data` as a preparation
for a request. You can override this or any of the other helpers this method
will call. **Beware**{: .fw-900 }, the `origin` key is vital for
subscriptions to work correctly.

{: title="gql_request" id="gql_request" }
### `gql_request(schema = gql_schema)`

It initiates a new [request](/guides/request) for the provided `schema`.

{: title="gql_query_cache_key" id="gql_query_cache_key" }
### `gql_query_cache_key(key = nil, version = nil)`

Attempt to build build a cache key for [cached requests](/guides/advanced/request#caching).
You can provide the `key`, or it will be fetched from `data['query_cache_key']`, and
the `version`, or it will be fetched from `data['query_cache_version']`.

{: title="gql_schema" id="gql_schema" }
### `gql_schema(data)`

It will resolve the underlying schema from [`self.class.gql_schema`](#settings-gql-schema)
or by attempting to find a schema with the same name as your application. You can
use the provided `data` in your override to estipulate the proper schema.

{: title="gql_context" id="gql_context" }
### `gql_context`

It returns the context for the GraphQL request. You should override this method to
add your own keys to it. By default, it will add the received `action` name to it.

```ruby
{ action: (data['action'] || :receive).to_sym }
```

{: title="gql_variables" id="gql_variables" }
### `gql_variables(data, variables = data['variables'])`

It will properly parse the provided `variables`, so it is a usable `Hash`. For example,
if the value is a string, it will `JSON.parse(variables)`, and if it is
controller parameters, it will `variables.permit!.to_h`.

{: title="gql_subscriptions" id="gql_subscriptions" }
### `gql_subscriptions`

It stores all the subscriptions current active by the instance of the channel.

{: title="gql_clear_subscriptions" id="gql_clear_subscriptions" }
### `gql_clear_subscriptions`

It will call [`gql_remove_subscriptions`](#gql_remove_subscriptions) for all of the
subscriptions stored in the [`gql_subscriptions`](#gql_subscriptions). An `after_unsubscribe`
callback is automatically added to this method.

{: title="gql_remove_subscriptions" id="gql_remove_subscriptions" }
### `gql_remove_subscriptions(*sids)`

It will use the underlying schema to unsubscribe from one or more provided `sids`
(subscription ids).
