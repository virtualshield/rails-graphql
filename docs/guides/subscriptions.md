---
layout: default
title: Subscriptions - Guides
description: The GraphQL operation responsible for constantly fetching data from your API
---

# Subscription Operations

```graphql
subscription { user { id status } }
```

Subscription is one of the three operations that you can run on GraphQL. Subscriptions' purpose
is to fetch an initial installment of data and keep the result up-to-date with your API.
Subscriptions are handled by [requests](/guides/request) for the first fetch
and a [provider](/guides/subscriptions/providers) for subsequent updates.

## Definition

Subscriptions can be composed of 5 different elements:

`type`
: `subscription`

`[name]`
: An optional name

`[variables]`
: An optional set of [variables](/guides/request#variables)

`[directives]`
: An optional set of [directives](/guides/directives)

`selection`
: One field from the<br/>schema [query fields](/guides/schemas#fields)

```graphql
#     type            name         variables    directives  selection
  subscription FirstSubscription($var: String!) @directive { welcome }
```

## Fields

The top-level fields in the selection of your subscriptions are called `entry points`,
and they must exist in the [subscription fields](/guides/schemas#fields) of your schema.
Subscription work similarly to [queries](/guides/queries), but you can only request a
single entry point. Subsequent results will have the same structure.

```graphql
subscription {
  user         # entry point GraphQL::AppSchema[:subscription][:user]
  {            # one GraphQL::User < GraphQL::Object
    id         # GraphQL::User[:id]
    status     # GraphQL::User[:status]
  }
}
```

Here is an example of a response from the above:

```json
{ "data": { "user": { "id": 1, "status": "PENDING" } } }
```

Read more about [fields subscription](/guides/request#subscribing).

### Extra Definitions

Subscription [fields](/guides/fields) accept some additional settings when they are being defined.

#### `scope`

A scope allows you to define an internal condition before delivering subsequent results.
You can set this up using a named argument or the [chaining definition](/guides/fields#chaining-definition),
giving one or more values to it. Symbols and Procs receive special treatment, for example:

* `:current_user` - A symbol indicates that such value should be taken from the [request context](/guides/request#context);
* `->(subscription) { }` - A proc will be called with the subscription object, and its result will be added to the scope.

You will have full access to the request and operation installing the subscription using a Proc.

```ruby
# app/graphql/app_schema.rb
field(:user, 'User', scope: :current_user)
field(:user, 'User').scope(System.version, :current_user)
field(:user, 'User') do
  scope ->(subscription) { subscription.operation.name }
end
```

#### `subscribed`

You can set a [callback](/guides/events#callbacks) for when a subscription is successfully
installed for that given field. This can be done using the
[chaining definition](/guides/fields#chaining-definition) or inside the block definition.

```ruby
# app/graphql/app_schema.rb
field(:user, 'User').subscribed { puts subscription.inspect }
field(:user, 'User') do
  subscribed { puts subscription.inspect }
end
```

## Broadcasting

By default, if there are several subscriptions to the same field, with the same document,
same scope, and same arguments, only one payload will be generated and then transmitted to
every subscriber.

The [`default_subscription_broadcastable`](/handbook/settings#default_subscription_broadcastable)
setting and the fields' [broadcastable](/guides/fields#output-fields) option control this behavior,
and if a `false` value is encountered, then a request per subscriber will be executed.

In this example, we are subscribing to updates to a user, constantly checking if the current
user is following the other one. We mark the `isFollowing` as not broadcastable because
different users can receive different results, which prevents subscriptions from
being broadcasted.

```ruby
# app/graphql/objects/user.rb
field(:is_following, :boolean, broadcastable: false)

# app/graphql/app_schema.rb
field(:user, 'User', arguments: id_argument)
```

```graphql
subscription { user(id: 2) { name isFollowing } }
```

## Triggering

To trigger an update, you need to call one of the following methods from the field. If you
are using a [standalone definition](/guides/alternatives#standalone-definition), you can call
using the class instead.

{: .important }
> This process will happen asynchronously.

{: title="trigger" id="trigger" }
### `trigger(args: nil, scope: nil, **)`

This method will search for all the subscriptions with matching arguments and scope, then
trigger an update on all of them. You can pass an array of arguments and an array of scopes
to update multiples at once.

```ruby
field = GraphQL::AppSchema[:subscription][:user]

# A regular trigger
field.trigger
# Will update subscriptions that `user(id: 1)`
field.trigger(args: { id: 1 })
# Will update subscriptions `user(id: 1)` and `user(id: 2)`
field.trigger(args: [{ id: 1 }, { id: 2 }])
# Will update subscriptions of the current user
field.trigger(scope: current_user)
```

{: title="trigger_for" id="trigger_for" }
### `trigger_for(object, and_prepare: true, **)`

This method does two things before calling the method above:

1. It attempts to extract arguments values from the provided object;
2. Set up a [prepared data](/guides/advanced/request#prepared-data) as the given object
unless `and_prepare` is false.

In this example, we can trigger one or several updates fairly easily using this method.
Plus, the GraphQL request won't have to load the users because that will be
prepared for it directly:

```ruby
# app/graphql/app_schema.rb
field(:user, 'User') { argument(:id, null: false) }

# somewhere else
field = GraphQL::AppSchema[:subscription][:user]
field.trigger_for(User.all)       # Produces args: [{ id: 1 }, { id: 2 }]
field.trigger_for(User.first)     # Produces args: [{ id: 1 }]

# The above is the same as
field.trigger(args: [{ id: 1 }], data_for: {
  "subscription.user" => User.first,
})
```

Read more about [prepared data](/guides/advanced/request#prepared-data).

## Unsubscribing

You can force subscriptions from being removed by calling `unsubscribe` or `unsubscribe_from`,
which works similarly to [`trigger`](#trigger) and [`trigger_for`](#trigger_for), respectively.
Clients will receive one last update informing them that there won't be any more updates.

## Subsequent Results

There are two parts involved in the process of providing the subsequent results.

### Store

Stores are the places where all subscriptions are saved, and they are responsible
for handling the addition, removal, and search of subscriptions. These subscription
objects are like receipts, holding the necessary information for it to be re-evaluated.

During a request, you can access that object from the [`subscribed`](#subscribed) callback
or any other place by calling `operation.subscription`. Here is a list of things that are
stored in these objects:

`id`/`sid`
: The unique identifier of the subscription

`schema`
: The [namespace](/guides/advanced/namespaces) of the schema

`context`
: The [context](/guides/request#context) of the request when the subscription was created

`scope`
: The scope of the subscription

`operation_id`
: The id of the operation, which points to a cached document

`origin`
: The origin of the subscription

`field`
: The field of the subscription

`args`
: A hash of the arguments provided to the field

`broadcastable`
: An indicator of whether the subscription can be broadcasted

`created_at`
: The timestamp of when the subscription was created

`updated_at`
: The timestamp of when the subscription was last updated

{: .important }
> **Important**
> Different stores may manipulate these attributes so that they can be serialized and
> deserialized.

{: .no_toc }
#### Available Stores

* [Memory](/guides/subscriptions/memory-store)

### Provider

Providers are the ones capable of running asynchronously, executing subscriptions,
and streaming subsequent results. They are the ones with the "Pub-Sub" architecture.

Providers can share the same store or have one of their own. Regardless, it is important
to keep these two parts separated so that you can choose which combination best fits your
application.

{: .no_toc }
#### Available Providers

* [ActionCable](/guides/subscriptions/action-cable-provider)
