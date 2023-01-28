---
layout: default
title: Interface - Guides
description: GraphQL's abstract type for objects inheritance
---

# Interface

```graphql
interface Person {
  name: String!
}
```

Interfaces allow you to set fields and their respective types and settings that
must be equivalent in all [objects](/guides/objects) that implement these interfaces. You can
think of interfaces as inheritance, where objects can inherit from multiple interfaces.
Unlike [unions](/guides/unions), interfaces can have fields.

## Creating an Interface

You can define interfaces on a file or using the shortcut on the schema.

```ruby
# app/graphql/interfaces/person.rb
module GraphQL
  class Person < GraphQL::Interface
    # Any object that implements this interface must have an equivalent field
    field :email, :string
  end
end

# OR

# app/graphql/app_schema.rb
interface 'Person' do
  field :email, :string
end
```

As a recommendation, use the second approach if your application has a few interfaces
(up to 5, with just a few fields and never event handlers nor resolvers). Otherwise, prefer using
the individual file approach.

Read more about [Recommendations](/guides/recommendations).

### For gem Creators

Once you have created your interfaces in your gem, remember to add them into
[`config.known_dependencies`](/handbook/settings#known_dependencies).

```ruby
Rails::GraphQL.config.known_dependencies[:interface].update(
  my_gem_interface: "#{__dir__}/interfaces/my_gem_interface",
)
```

## Using Interfaces

There are two ways to use your interfaces:

### Importing Fields

By default, when an object says it implements an interface, all of the fields
of the interface that the object still doesn’t have will be automatically
imported as proxies. When such fields are being resolved, the interface will be
instantiated and used to resolve the values, which makes them perfect for sharing
resolution logic among several objects and their common fields.

```ruby
# app/graphql/objects/user.rb
implements 'Person'
# OR
implements GraphQL::Person
# Then any additional fields
```

Proxy fields is an advanced feature. Read more about the [Proxy Fields](/guides/advanced/fields#proxies).

### Not Importing Fields

Now, if the purpose of your interface is to solely define the rules of the fields that
must exist in all the objects that implement that interface, you have a couple of options:

```ruby
# app/graphql/interfaces/person.rb
self.abstract = true
# Abstract interfaces will never have their fields imported
# because they should never be instantiated

# OR

# app/graphql/objects/user.rb
# All fields definition, then
implements 'Person', import_fields: false
# Not importing fields will enforce their existence and equivalency
```

### Validation

As soon as you declare that your object implements an interface,
it will validate the implementation. All fields will be checked by their
[equivalency](/guides/advanced/fields#equivalency). The first field with the
same name that is not equivalent to the one in the interface will raise a
[`ArgumentError`](/handbook/exceptions#ArgumentError) exception.

## In a Request

You can use the interface types as the return type of your fields. However, the
underlying data will always have to match one of the objects implemented by that interface.
You can use a combination of the fields declared by the interface, and unique fields
of each object by using [spreads](/guides/spreads).

```ruby
field(:recipient, 'Person')
```

```graphql
recipient {
  # Gets the name of the type
  __typename
  # Email is a common attribute
  email
  ... on User {
    # Slug is a field only available on User
    slug
  }
  ... on Admin {
    # Role is a field only available on Admin
    role
  }
}
```

{: .note }
> Interfaces is the best place for you to set up your
> <a href="https://edgeapi.rubyonrails.org/classes/ActiveRecord/Inheritance.html" target="_blank" rel="external nofollow">Single table inheritances</a>.
