---
layout: default
title: Request - Advanced - Guides
description: All about the advanced features of requests
---

# Request

This page will explore more advanced features of [requests](/guides/request).
It would be best if you started from there before reading this content.

## Strategies

Request strategies are the actual classes responsible for handling the last three
phases of a request: `organize`, `prepare`, and `resolve`. They all inherit from
the base `Strategy` class, and the request will go over all the available
strategies to rank the best one to execute a document.

As of now, there are only two strategies:

`MultiQueryStrategy`<br/>Rank `10`
: Will run each phase once per operation, but only if there are no
[mutation operations](/guides/mutations).

`SequencedStrategy`<br/>Rank `1`
: Will perform one operation at a time, which is the default behavior.

You can implement your own strategy and override any of the existing methods
to fulfill your application's needs. Just remember to add them to the
[`request_strategies`](/handbook/settings#request_strategies) setting.

## Prepared Data

Prepared data allows you to inject data into any field before a request is
kicked off. With prepared data, you can stub results for [testing](/guides/testing)
and deliver fast [subscriptions](/guides/subscriptions/#trigger_for).

To prepare data for a field, you need the field instance or a reference to it,
the prepared value, and a conditional indicator for repetition.

```ruby
def prepare_data_for(field, value, repeat: 1)
```

### Field

You can use any [searching method](/guides/field-lists#searching-fields)
to grab the instance of the field you are preparing the data for. But, you can
also pass a reference as `"type"."field"`, for example:

```ruby
# Using the Type Map
'User.id'          # => GraphQL::User[:id]
# Using the schema
'query.users'      # => GraphQL::AppSchema[:query][:users]
```

### Value

The value has some special behaviors depending if it was provided an array and
if the field resolves to an array. The table below shows the prepared value
each time the field is resolved:

| value \ field | array? | !array? |
| array? | next array | next value |
| !array? | array with value | same value |

The example below shows a case where `addresses` can be resolved twice,
each time with a different list of values.

```ruby
prepare_data_for('User.addresses', [[
  Addresses.new(id: 1),
  Addresses.new(id: 2),
], [
  Addresses.new(id: 3),
  Addresses.new(id: 4),
]])
```

{: .note }
> **Note**
> Calling `prepare_data_for` subsequent times with the same field will append
> the `value` to the prepared data value.

### Repeat

The `repeat` argument indicates how many times the field can be resolved till
it exhausts the prepared data. The example below will result in a cycle between
`1` and `2`.

```ruby
prepare_data_for('User.id', [1, 2], repeat: true)
```

It accepts a number for the number of repetitions, `true` to always repeat, or `false` to
never repeat. Here is some alias values:

`false`
: `1`

`:once`
: `1`

`:cycle`
: `true`

`always`
: `true`

## Data Stack

The data stack is similar to the field stack when traversing the document, but it
refers to the data assigned to each field during the `prepare` and `resolve` phases.

You can access it via the `strategy.context` or `event.resolver`.

### Reading

There are several different ways to access the data in the stack:

`current_value`
: Returns the last item of the stack.

`parent`
: Returns the second to last item of the stack.

`ancestors`
: Returns all the values from the `parent` downwards.

`at`
: Returns a value at a specific position<br/>`0` is the last.

Now, by calling `resolver.current`, you will get an extraordinary object. You can
think of it as a loose reference to the last value of the stack. This means that
if the value changed to something else, every other place that called `current`
will now have the updated reference to the new value.

This ability is crucial for events and request processing because they need
a "value by reference" for the result of resolved fields. It is implemented
in a way that you probably won't ever notice it.

### Writing

The data stack allows changing only the current value, never any of the
ancestors. To perform such change, you can call either `resolver.override_value(value)`
or `resolver.current_value = value`.

### Shortcuts

[Events](/guides/events) provide a couple of shortcuts to access data stack:

`event.current_value`
: Read the current value

`event.current`
: Same as above

`event.current_value = value`
: Write the current value

Read more about [request events](/guides/request#event).

## Caching

This gem supports caching documents after they have been organized. Any subsequent
request using a cached document will recover the state where it was after that
phase was completed and move forward with the next two phases.

This is an implementation based on Apollo's
<a href="https://www.apollographql.com/docs/apollo-server/performance/apq/" target="_blank" rel="external nofollow">Persisted Queries</a>.
You can use the [`query_cache_key`](/guides/customizing/controller#gql_query_cache_key) controller method
or the [`gql_query_cache_key`](/guides/customizing/channel#gql_query_cache_key) channel method to correctly
set up the incoming cache key and version and leave the request to do the rest.

Everything cached by a request will be saved using the [schema `cache` configuration](/guides/schemas#configuring).

{: .important }
> If the [Type Map](/guides/type-map) version changed, then the document will be reorganized.

## Compiling

{: .highlight }
> **Important**
> This is an experimental feature. More will be added to it soon.

Compiling is almost the same as [caching](#caching). The difference lies in the fact that
the request will return the cache string instead of saving it somewhere.

This is part of a future feature named `strict mode`, where you would compile
all the documents that your application accepts, store them as files, or on a database,
or even on the cache, and only use a unique identifier to reference such documents.

As of now, requests can compile a document, and even compress it, and run a compiled document
when it is informed that the provided document is `compiled: true`.
