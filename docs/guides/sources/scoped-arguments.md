---
layout: default
title: Scoped Arguments - Sources - Guides
description: Share behaviors between source fields using arguments in common
---

# Scoped Arguments

Sources like [Active Record Source](/guides/sources/active-record) use a special
feature that allows you to define shared arguments that implement shared behaviors
between your fields.

This feature's original intention is to expose models' scopes to several fields.
Due to [proxy fields](/guides/advanced/fields#proxies), you can easily share
scope-based arguments to query fields and association fields ([see here](/guides/sources/active-record#proxy-field)).

## How to Use

You can define scoped arguments at the source-class level, as in:

```ruby
# app/graphql/sources/user_source.rb
scoped_argument(:active, :boolean) { |value| where(active: value) }
                                 # ↳ Running under the current object

# OR, which intends to call the `active` scope on the current object
scoped_argument(:active, :boolean, true)
# The above is designed to work with
scope :active, -> { where(active: true) }

# OR, using a different scope name and with the argument value
scoped_argument(:active, :boolean, :enabled)
# The above is designed to work with
scope :enabled, ->(value) { where(active: value) }
```

## Considerations

{: .highlight }
> **Important**
> This is an experimental feature and may change in the future.

It's recommended to pass an `on` named argument to limit to which fields that
argument will be added.

```ruby
scoped_argument(:active, :boolean, true, on: :users)
# OR
scoped_argument(:active, :boolean, true, on: 'users')
```

Read more about [names](/guides/names).

A block or method that returns nil won't affect the current value, which will
move forward to the following argument or finish by returning its result.
