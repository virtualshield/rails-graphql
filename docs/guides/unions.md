---
layout: default
title: Unions - Guides
description: Group object types into one single type
---

# Unions

```graphql
union User | Admin
```

Unions allow you to group different [objects](/guides/objects) into one single type. You can
think of unions as a sort of composition. They work great with [Spreads](/guides/spreads). Unlike
[interfaces](/guides/interfaces), unions can't have fields.

## Creating a Union

You can define unions on a file or using the shortcut on the schema.

```ruby
# app/graphql/unions/person.rb
module GraphQL
  class Person < GraphQL::Union
    # This is a union of User and Admin object types
    append User, Admin
  end
end

# OR

# app/graphql/app_schema.rb
union 'Person' do
  append User, Admin
end

# OR even
union 'Person', of_types: %w[User Admin]
```

The last one is preferable because, for now, the only thing you can do with
unions besides appending the types is using [directives](/guides/directives). Plus, it
follows the rule of not referencing types by their actual classes.

Read more about [recommendations](/guides/recommendations).

{% include type-description.md type="union" name="Person" %}

### Type Resolution

Unions have a special `type_for(value, request)` class-level method, which is
responsible for finding an [object](/guides/objects) for the given `value`.

The default behavior is to go over the list of members in reverse and find the
first one that is a `valid_member?` of `value`.

If for some reason, that is not compatible with your application, you can override this method.
For example, this relies on ActiveRecord
<a href="https://edgeapi.rubyonrails.org/classes/ActiveRecord/ModelSchema.html#method-c-inheritance_column" target="_blank" rel="external nofollow">single table inheritance column</a>.

```ruby
# app/graphql/unions/person.rb
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

{% include type-creators.md type="union" %}

## Using Unions

Once they are defined, you can set them as the type of [output fields](/guides/fields#output-fields).
Then, in your execution document, you can use [spreads](/guides/spreads) to properly
capture unique information of the respective types.

{: .important }
> Since unions do not contain a [list of fields](/guides/field-lists), you can never request
> fields directly from them besides [`__typename`](/guides/requests#typename).

```ruby
field(:recipient, 'Person')
```

```graphql
{
  recipient {
    # Gets the name of the type
    __typename
    ... on User {
      # Email is a common attribute, but unions don't hold fields
      email
      # Slug is a field only available on User
      slug
    }
    ... on Admin {
      # Email is a common attribute, but unions don't hold fields
      email
      # Role is a field only available on Admin
      role
    }
  }
}
```

{: .note }
> Unions is the best place for you to set up your `belongs_to`
> <a href="https://guides.rubyonrails.org/association_basics.html#polymorphic-associations" target="_blank" rel="external nofollow">Polymorphic Associations</a>.
