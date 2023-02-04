---
layout: default
title: Memory Store - Stores - Subscriptions - Guides
description: Stores all the subscriptions in memory
---

# Memory Store

The Memory Store will keep all the active subscriptions in the memory of your Rails instance.
It still works with multiple instances because it just forces the instance that added the
subscription to be responsible for delivering updates.

The subscription objects are indexed in two ways: by their `sid` and by the combination of
`field`, `scope`, and `arguments`. The second helps the memory store to fetch objects for an update easily.

## Fingerprint

This store uses
<a href="https://ruby-doc.org/core-3.0.0/Object.html#method-i-hash" target="_blank" rel="external nofollow">`#hash`</a>
to keep the memory fingerprint as small as possible. This is fully compatible with
all features provided by this gem and Rails as well, especially ActiveRecord.

You can take advantage of that when triggering updates. For example, if you don't actually
need to load a record to trigger an update where this record is part of the scope, you can
use the following approach:

```ruby
field = GraphQL::AppSchema[:subscription][:user]
field.trigger(scope: { User => 1 })
# This is the same as
field.trigger(scope: User.find(1))
# OR
field.trigger(scope: User.find(1).hash)
# They all use the same approach towards `#hash`
User.hash ^ 1.hash
```
