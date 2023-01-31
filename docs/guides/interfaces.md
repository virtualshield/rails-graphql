---
layout: default
title: Interfaces - Guides
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
    field :email
  end
end

# OR

# app/graphql/app_schema.rb
interface 'Person' do
  field :email
end
```

Read more about the [Field Lists](/guides/field-lists).

{% include type-description.md type="interface" name="Person" %}

### Type Resolution

Interfaces have a special `type_for(value, request)` class-level method, which is
responsible for finding an [object](/guides/objects) for the given `value`.

The default behavior is to go over the list of types in reverse and find the
first one that is a `valid_member?` of `value`.

If for some reason, that is not compatible with your application, you can override this method.
For example, this relies on ActiveRecord
<a href="https://edgeapi.rubyonrails.org/classes/ActiveRecord/ModelSchema.html#method-c-inheritance_column" target="_blank" rel="external nofollow">single table inheritance column</a>.

```ruby
# app/graphql/interfaces/person.rb
def self.type_for(value, request)
  request.find_type(value.type)
end
```

{: .important }
> **Important**
> It's recommended to use `request.find_type` with either the symbol or string [name](/guides/names) because
> the resolution is cached during the request and complies with [namespaces](/guides/advanced/namespaces).

{: .note }
> Such translation is possible because object names match type names when using [sources](/guides/sources).
> An even more accurate version would be<br/>`value.type.tr(':', '')`.

{% include type-creators.md type="interface" %}

## Implementing Interfaces

There are two ways to implement your interfaces:

### Importing Fields

By default, when an [object](/guides/objects) says it implements an interface, all of the fields
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

## Using Interfaces

You can use the interface types as the return type of your fields. However, the
underlying data will always have to match one of the objects implemented by that interface.
You can use a combination of the fields declared by the interface, and unique fields
of each object by using [spreads](/guides/spreads).

```ruby
field(:recipient, 'Person')
```

```graphql
{
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
}
```

{: .note }
> Interfaces is the best place for you to set up your
> <a href="https://edgeapi.rubyonrails.org/classes/ActiveRecord/Inheritance.html" target="_blank" rel="external nofollow">Single table inheritances</a>.
