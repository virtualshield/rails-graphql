---
layout: default
title: Request - Guides
description: Everything you need to know about dealing with GraphQL requests
---

# Request

A request is where everything comes together to deliver responses for GraphQL documents.
The `Request` class and its children classes perform a series of steps to fulfill
your document, which are:

1. [Initializing](#initializing) - Before a response is started
1. [Organizing](#organizing) - Collecting fields and event listeners
1. [Preparing](#preparing) - Preparing the data and performing mutations
1. [Resolving](#resolving) - Formatting the response

{: id="initializing" }
## 1. Initializing

This is the only step that is not protected against exceptions. Any errors that
may occur during the initialization will be raised, and they are probably related
to a wrong setup of the request, like not being able to find a schema.

We can divide this process into four parts:

{: title="1. Instantiating" }
### 1. 1. Instantiating

When a request is instantiated, it requires a schema, either the class or its
namespace.

```ruby
request = Rails::GraphQL.request(GraphQL::AppSchema)
# OR
request = Rails::GraphQL.request(namespace: :base)
# OR, same as above
request = Rails::GraphQL.request
# OR
request = GraphQL::AppSchema.request
```

{: title="2. Setting Up" }
### 1. 2. Setting Up

This step is where you can prepare the ground for your request to be executed smoothly.
Here is when you can add a [context](#context) or [prepare data](#prepared-data).

#### Context

Context is a way for you to provide external information to the internal processing
of the requests. The context is also important for [subscriptions](/guides/subscriptions/#scope) because it
provides the values to their scope. Once set, the context is turned into an
<a href="https://ruby-doc.org/stdlib-3.0.0/libdoc/ostruct/rdoc/OpenStruct.html" target="_blank" rel="external nofollow">`OpenStruct`</a>,
facilitating reading.

```ruby
request.context = { current_user: current_user }
# THEN
request.context.current_user
```

{: .important }
> **Important**
> The context is **immutable**{: .fw-900 }! If you need to store any data during the request, you
> should use the [operation memo](#memo).

#### Prepared Data

Preparing data allows you to override what data the field will be using. This is useful
for [testing](/guides/testing) and [triggering subscriptions](/guides/subscriptions/#trigger_for).

```ruby
request.prepare_data_for('query.users', User.all)
```

Read more about [prepared data](/guides/advanced/request#prepared-data).

{: title="3. Kick Off" }
### 1. 3. Kick Off

This step is where we choose what kind of request we want to run. Here are the
three available options:

{: title="valid?" }
#### `valid?(document)`

It checks if the given `document` is valid by running only the [Organizing](#organizing) step.
If no errors were added, then the document is considered valid.

{: title="compile" }
#### `compile(document, compress: true)`

It is similar to the above, but it generates a cached version of the request, which
could be used to run multiple requests that skip the [Organizing](#organizing) step.

Arguments:
: <span></span>

`compress`
: `true` - Marks if the return value should be compressed using
<a href="https://ruby-doc.org/stdlib-3.0.0/libdoc/zlib/rdoc/Zlib.html#method-c-deflate" target="_blank" rel="external nofollow">`Zlib#deflate`</a>.

{: .important }
> This is an experimental feature. More will be added to it soon.

{: title="execute" }
#### `execute(document, **settings)`

It will run the request completely till it returns the result.

Arguments:
: <span></span>

`operation_name`
: `nil` - The name of the operation for logging purposes.

`args` / `variables`
: `{}` - The list of [varaibles](#variables) of the request.

`origin`
: `nil` - An optional object from where the request originated. Usually mapped
to a [Controller](/guides/customizing/controller) or [Channel](/guides/customizing/channel).

`as`
: [`default_response_format`](/handbook/settings#default_response_format) - The expected output format.
<br/>One of: `string`, `object`, `json`, `hash`.

`hash`
: `nil` - The cache key of a [cached request](/guides/advanced/request#caching).

`compiled`
: `false` - Indicates whether the incoming document is compiled.

`data_for`
: `nil` - A shortcut for defining a series of [prepared data](#prepared-data).

{: title="4. Parse and Run" }
### 1. 4. Parse and Run

This step is where the document will be parsed by the [`GQLParser#parse_execution`](`/guides/parser`),
or fetched from the cache, and the proper runner will be called.

{: .note }
> **Note**
> During this step, the schema will be validated (if it hasn’t been yet),
> which causes the first request to be slower than the others.

#### Variables

Variables, as defined by the
<a href="http://spec.graphql.org/October2021/#sec-Language.Variables" target="_blank" rel="external nofollow">GraphQL Spec</a>,
allow operations to be parameterized, maximize reuse, and avoid costly string building in clients.
Here is an example on how to use variables:

```graphql
query($active: Boolean!, $order: [SortingInput!]!) {
  users(active: $active, order: $order) { id email }
}
```

```ruby
request.execute('↑', variables: { active: true, order: [
  { field: 'email', direction: 'ASC' },
]})
```

#### Origin

The origin allows you to access the external world from where the request began
without passing that into the context. This is preferable because the
request will know how to deal with it in special cases properly.

You can also use the aliases `request.controller` and `request.channel`.

#### Strategy

A `Strategy` class is actually the one responsible for running the following steps.
The request will look for the highest-ranked strategy from
[`request_strategies`](/handbook/settings#request_strategies) that `can_resolve?` itself.

Read more about [strategies](/guides/advanced/request#strategioes).

{: id="organizing" }
## 2. Organizing

This step will traverse through the parsed document and ensure everything that can
actually be resolved from it.

Exceptions that may happen in this phase will be added to the `errors`
and properly tagged with `extensions: { stage: "organize" }`.

This process involves:

### Componentizing

Each operation ([query](/guides/queries), [mutation](/guides/mutations),
and [subscription](/guides/subscriptions)), [field](/guides/fields#output-fields),
[fragment](/guides/fragments), and [spread](/guides/spreads) in your documents will
be assigned to its own request component.

### Validating

Check if the component is valid, which means different things for different components.
Some examples: Does the spread point to an existing fragment? Does the type
of the fragment exist in the schema? Does the return type has the request fields?
Do the provided variables and fields' arguments are equivalent?

If validation fails, the field will be marked as `unresolvable`, and you will
be able to resolve the problem by addressing the issue reported.

Read more about [components](#components).

### Listeners and Events

Collect all the events from the fields and keep track of what type of events are
being listened to within the document.

{: id="preparing" }
## 3. Preparing

This step is the one-and-only opportunity for fields to collect data before they
are actually resolved. This stage is the best middle ground where we know everything
about what has been requested, and it can gather resources to fulfill the response.
This is also the phase where [mutations](/guide/mutations) perform their actions.

Exceptions that may happen in this phase will be added to the `errors`
and properly tagged with `extensions: { stage: "prepare" }`.

### Data Stack

This step initializes an internal request context which represents a stack of the
underlying data of each field. Such s stack is called `resolver`, and you can do
things like getting the `current`, the `parent`, and `ancestors`.

Read more about the [request data stack](/guides/advanced/request#data-stack).

### Data

In this step, we properly assign data to fields by either [prepared data](#prepared-data)
or by the result of the `prepare`(`before_resolve`) [event](#events-prepare).

### Performing

After getting the data above, a [mutation field](/guides/fields#mutation-fields)
will have its opportunity to be performed, which triggers a `perform` [event](#events-perform).

The returning value of the mutation will replace the one collected before.

{: id="resolving" }
## 4. Resolving

This is the final step of the process, where the document is traversed one last
time, and values are added to the response in their proper format.

Exceptions that may happen in this phase will be added to the `errors`
and properly tagged with `extensions: { stage: "resolve" }`.

Here is the list of ways a field can be resolved by order of precedence:

{: .important }
> Array results will be resolved per field per item of the array in a `items` * `fields` form.

{: title="1. Resolver Callback" }
### 4. 1. Resolver Callback

If the field has a `resolve` [callback](/guides/events#callbacks), it will be called.
Inside the callback, you can access `prepared_data` to get any prepared data assigned
to the field.

{: title="2. Next Prepared Data" }
### 4. 2. Next Prepared Data

If data has been prepared for the field using the request's [prepared data](#prepared-data),
then it will return the next value.

{: .note }
> The following options are ignored when the field is an entry point.

{: title="3. Read from Hash" }
### 4. 3. Read from Hash

If the current value in the [data stack](##data-stack) is a `Hash`, then it will attempt
to get a key with the [`method_name`](/guides/fields#resolving-fields) or with the field's
`gql_name`.

{: title="4. Call Method" }
### 4. 4. Call Method

As its last resource, it will try to call the [`method_name`](/guides/fields#resolving-fields)
from the current value in the [data stack](##data-stack).

### Quick Reference

Here is a quick reference for the resolve precedence:

```ruby
# 1. Resolver Callback
field.resolver     # Proc or Method

# 2. Prepared Data
request.prepared_data_for('User.id').next

# 3. Read from Hash
if resolver.current_value.is_a?(Hash)
  resolver.current_value[:id] || resolver.current_value['id']
end

# 4. Call Method
resolver.current_value.id
```

## Extras

Here is some extra information about requests:

### Extensions

You can use the `request.extensions` `Hash` object to add data to the response
as you see fit. No restrictions nor validations will be applied to this portion
of the response.

```ruby
request.extensions[:something] = 'Any value'
```

```json
{
  "data": { "..." },
  "extensions": { "something": "Any value" }
}
```

### Memo

If you need to keep data between fields and resolvers, you can add it to the operation's memo.
The memo is a mutable `Hash` that is isolated by operation, and any data added to it will
be discarded after the request has been completed.

```ruby
operation.memo[:counter] ||= 0
operation.memo[:counter] += 1
```

### Event

The `Request::Event` instance is the object that is assigned to all classes after
they have been instantiated for resolving method-based [callbacks](/guides/events#callbacks).

Here is a quick reference of all the request-specific things you can get from the events:

```ruby
# app/graphql/app_schema.rb
# Works with delegate_missing_to :event
def welcome
  context                   # The request context
  current                   # The current value in the data stack
  current_value             # Same as above
  errors                    # The request errors
  extensions                # The request extensions
  field                     # The current field being resolved
  index                     # The index of the current array element
  memo                      # The operation memo
  operation                 # The operation component being resolved
  prepared_data             # The prepared data of a field, when provided
  request                   # The request itself
  resolver                  # The request data stack
  schema                    # The schema of the request
  strategy                  # The strategy of the request
  subscription_provider     # The subscription provider of the schema

  argument(name)            # Get the value of an argument sent to the field
  arg(name)                 # Same as above

  # Anything else will be attempted to be called from the `current_value`
  something_else
end
```

Read more about [events](/guides/events#quick-reference).

### Events

Here is a list of all events that can happen during a request and when they will
be triggered:

`request`
: When a `Strategy` is initiated to resolve a request.

`query`
: When a `query` operation started to be organized.

`mutation`
: When a `mutation` operation started to be organized.

`subscription`
: When a `subscription` operation started to be organized.

`attach`
: When a [directive](/guides/directives) has been attached to a component.

`authorize`
: When a field is being organized, to check for [authorization](/guides/advanced/authorization).

`organized`
: When a component has been successfully organized.

`prepare` / `before_resolve`
: When a field is preparing data.<br/>**Runs in reverse order**{: .fw-900 }.

`perform`
: When a mutation is performing its actions.

`prepared`
: When a component has been successfully prepared, and also performed in case of a mutation.

`resolve`
: When the value of a field is being resolved.

`subscribed`
: When a subscription was resolved and successfully added to the provider.

`finalize` / `after_resolve`
: When a component has been successfully resolved.

Read more about [events](/guides/events).

### Components

All request components inherit from the `Component` class, which has some useful
methods that you can use during your callbacks:

`invalid?`
: Checks if the component was marked as invalid.

`skipped?`
: Checks if the component should be skipped.

`unresolvable?`
: Same as `invalid? || skipped?`.

`broadcastable?`
: Checks if the component has no broadcasting restrictions.

`invalidate!(type = true)`
: Marks the component as invalid, providing an optional type for the reason of the invalidation.

`skip!`
: Marks that the component should be skipped.

Here is a list of request components and their respective purposes:

#### `Field`

It represents each of the requested fields in the request. You can check things like
`entry_point?` and `mutation?`. You can also get the `gql_name`, which
is either the alias or the field name.

Read more about [fields](/guides/fields#output-fields).

#### `Fragment`

It represents a fragment added to the document which was actually initiated because a
spread is associated with it. It stores things like the `used_variables` and `used_fragments`.

Since fragments do not belong to a specific operation, their `operation` value will be
dynamically associated with the one from the spread that is using itself.

Read more about [fragments](/guides/fragments).

#### `Operation`

The base class for all types of operations. It stores things like the [`memo`](#memo),
the `used_variables`, and the `used_fragments`.

Each operation is a child class of this component, as in: `Operation::Query < Operation`,
`Operation::Mutation < Operation`, and `Operation::Subscription < Operation`

Calling `kind` will always return `operation`, but you can call `query?` or similar methods
to identify the right type.

```ruby
operation.used_variables     # A set of used variables
operation.query?             # Checks if it is a query operation
```

#### `Spread`

It represents a spread added to the document. You can check things like `inline?` and
you can also access the `fragment` associated with the spread, if any.

Read more about [spreads](/guides/spreads).

#### `Typename`

The typename is a special type of [field](#field). Its only purpose is to return
a plain string with the current GraphQL type within the scope to which it was requested.
For example:

{: .rails-console }
```ruby
:001 > GraphQL::AppSchema.execute('{ __typename }')
    => # { "data" => { "__typename" => "_Query" } }
```

It is handy when working with [interfaces](/guides/interfaces) and
[unions](/guides/unions) because it returns the actual type instead of these
intermediate types.

Read more about the [typename](/guides/queries#typename).
