---
layout: default
title: Action Cable Provider - Providers - Subscriptions - Guides
description: Deliver GraphQL requests, including subscriptions, through Action Cable
---

# Action Cable Provider

The Action Cable Provider uses a channel to communicate with your front end using a web socket.
First, you must ensure that you have properly set up
<a href="https://guides.rubyonrails.org/action_cable_overview.html#configuration" target="_blank" rel="external nofollow">Action Cable</a>.
Then you can use the provided
<a href="https://github.com/virtualshield/rails-graphql/blob/master/app/channels/graphql/base_channel.rb" target="_blank" rel="external nofollow">`GraphQL::BaseChannel`</a>
or implement your own, taking advantage of the
<a href="https://github.com/virtualshield/rails-graphql/blob/master/lib/rails/graphql/railties/channel.rb" target="_blank" rel="external nofollow">`Rails::GraphQL::Channel`</a>
concern.

The concern was designed to be easily overridden, allowing you to decide which parts
you want to use and which ones you need to add or change the settings. For example, here is
how you can add your own context:

```ruby
# app/channels/graphql_channel.rb
class GraphQLChannel < ApplicationCable::Channel
  include GraphQL::Channel

  protected

    def gql_context(*)
      super.merge(current_user: current_user)
    end
end
```

Read more about [customizing the Channel](/guides/customizing/channel).

## How it Works

The provider uses the Action Cable server and its underlying pub-sub mechanism
to stream subsequent results from subscriptions. It will create one stream per
subscription plus an internal asynchronous callback.

Here is everything that you can configure for this provider:

`cable`
: `::ActionCable` the Action Cable class

`prefix`
: `rails-graphql` the streams prefix

`store`
: [`Rails::GraphQL::Subscription::Store::Memory.new`](/guides/subscriptions/memory-store) the store of the subscriptions

`logger`
: `Rails::GraphQL.logger` the logger
