---
layout: default
title: Objects - Guides
description: The principal type of GraphQL to organize fields
---

# Objects

```graphql
type User {
  id
  name
}
```

Objects are the principal type of GraphQL. In contrast with [Scalars](/guides/scalars), objects
create branches in the GraphQL tree. It is always through them that you will be able to organize
and access your data.

## Creating an Object

You can define objects on a file or using the shortcut on the schema.

```ruby
# app/graphql/objects/user.rb
module GraphQL
  class User < GraphQL::Object
    field :id
    field :name
  end
end

# OR

# app/graphql/app_schema.rb
object 'User' do
  field :id
  field :name
end
```

Read more about the [Field Lists](/guides/field-lists).

{% include type-description.md type="object" name="User" %}

### Implementing Interfaces

Objects can implement interfaces, meaning they will receive a series of imported
fields or comply with what is configured in the interface.

```ruby
# app/graphql/objects/user.rb
implements 'Person'
```

Read more about the [Interfaces](/guides/interfaces).

{% include type-creators.md type="object" %}

## Using Objects

Once they are defined, you can set them as the type of [output fields](/guides/fields#output-fields).
Then, in your execution document, you can use query any of the fields that were defined.

```ruby
field(:recipient, 'User')
```

```graphql
{ recipient { id name } }
```

{: .note }
> Objects is the best place for you to set up your
> <a href="https://api.rubyonrails.org/classes/ActiveRecord/Base.html" target="_blank" rel="external nofollow">Models</a>.
