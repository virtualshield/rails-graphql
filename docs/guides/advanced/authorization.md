---
layout: default
title: Authorization - Advanced - Guides
description: How to implement authorization in your schema
---

# Authorization

{: .warning }
> **Unavailable**
> This feature is yet to be published. Give it a
> <a href="https://github.com/virtualshield/rails-graphql/issues/24" target="_blank" rel="external nofollow">thumbs up</a>.
> <br/>An old version is available, but it should not be used.

This gem has an authorization feature implemented using a hidden [directive](/guides/directives).
It leverages the ability of directives to have [events](/guides/events)
triggered during [requests](/guides/request), the ability to add directives
to both fields and types (which embeds the events),
and the ability to use shared directives.

## Setting Up

The [hidden directive](/guides/directives#hidden) [`@authorize`](#) is responsible
for dealing with the `authorize` events and holding the possible settings as its arguments.
It is the component that you will set up for controlling the authorization.

### Parameters

You can add parameters (aka [arguments](/guides/arguments)) to the
directive by calling `parameter`. It works just as any
[argument addition](/guides/arguments#adding-arguments), including the
[`one_of`](/guides/advanced/fields#one-of) special type.

```ruby
GraphQL::Authorization.parameter(:reading, :boolean)
# Same as
GraphQL::Directive::AuthorizeDirective.argument(...)

LEVELS = %w[guest support admin]
GraphQL::Authorization.parameter(:level, :one_of, LEVELS)
```

### Rules

You can add rules (aka [event listeners](/guides/events#using-events)) to the
directive by calling `rule`. It works just like adding an `authorize`
[event listeners](/guides/events#directive-events) to directives,
including the [`filters`](/guides/events#directive-filters).

```ruby
GraphQL::Authorization.rule do |context|
  accept! if context.current_user.admin?
end
# Same as
GraphQL::Directive::AuthorizeDirective.on(:authorize) { ... }

GraphQL::Authorization.rule(on: 'User') { ... }
```

## Using

You have some options for attaching the directive to fields:

### Directly

You can use the `use` method on the fields where you want to attach a directive,
where you can also set up the values for parameters.

```ruby
use :authorize, reading: true
```

### Field List

You can use the [directive attacher](/guides/field-lists#attaching-directives)
method for any field list.

```ruby
attach :authorize, reading: true, to: %i[users user]
```

### Creator

You can use the `create` method to initialize an instance and attach it to fields
provided in the `for` named argument, which works with any [field list](/guides/field-list).

```ruby
GraphQL::Authorization.create(reading: true, for: [
  GraphQL::AppSchema[:query][:users],
  GraphQL::AppSchema[:query][:user],
  # OR
  GraphQL::AppSchema[:query],
  # OR
  GraphQL::UserSource[:query],
])
```

## Especial Methods

The directive has some special instance methods that can be used to control the
result of the authorization process.

### `accept!`

It will approve the authorization and prevent any other callback from being invoked.

### `reject!`

It will disapprove the authorization and prevent any other callback from being invoked.

### `apply!(value)`

It will conditionally approve, disapprove, or move to the next callback based on
the provided `value` (`true`, `false`, and `nil`, respectively).

## CanCanCan Implementation

Here is an example of how you can implement this feature when combined with [sources](/guides/sources)
and the famous authorization gem
<a href="https://github.com/CanCanCommunity/cancancan" target="_blank" rel="external nofollow">CanCanCan</a>.

```ruby
# app/graphql/authorization.rb
module GraphQL
  # Add the action parameter for the fields
  Authorization.parameter(:action, :string, null: false)

  # Add the rule based on the ability
  Authorization.rule do |context, field, event|
    reject! unless context.current_user

    # Get the model from the return type
    model = field.type_class.assigned_class
    # If the field has an id argument, get it as part of the check
    args = { id: event.argument(:id) } if field.has_argument?(:id)

    # Apply the result of the ability
    apply! context.current_user.ability.can?(args.action, model, *args)
  end

  # Create shared instances for common actions
  index_action   = Authorization.new(action: 'index')
  show_action    = Authorization.new(action: 'show')
  create_action  = Authorization.new(action: 'create')
  update_action  = Authorization.new(action: 'update')
  destroy_action = Authorization.new(action: 'destroy')

  # Create a new prepare callback to use the accessible_by
  before_index = -> do
    model = field.type_class.assigned_class
    model.accessible_by(context.current_user.ability)
  end

  # Force the Type Map to load all the dependencies so classes are defined
  type_map.load_dependencies!

  # We create a module to hook into the attach fields process of sources
  ActiveRecordSource.extend Module.new do
    # Call a helper based on the type being attached
    def attach_fields!(type, fields)
      helper = "add_#{type}_authorization"
      send(helper, fields) if respond_to?(helper)
      super
    end

    # helper for query fields
    def add_query_authorization(fields)
      fields[singular.to_sym]&.use(show_action)
      fields[plural.to_sym]&.use(show_action)
      fields[plural.to_sym]&.prepare(&before_index)
    end

    # helper for mutation fields
    def add_mutation_authorization(fields)
      fields[:"create_#{singular}"]&.use(create_action)
      fields[:"update_#{singular}"]&.use(update_action)
      fields[:"destroy_#{singular}"]&.use(destroy_action)
    end
  end
end

# app/graphql/app_schema.rb
module GraphQL
  class AppSchema < GraphQL::Schema
    load_scalars %i[bigint date_time]

    load_directory 'sources'

    require_relative 'authorization'
  end
end
```

The above will also work with custom fields and custom actions.

```ruby
field(:friends, 'User') do
  use :authorize, action: 'index'
end
# OR
field(:approve_user, 'User') do
  argument :id, null: false
  use :authorize, action: 'approve'
end
```
