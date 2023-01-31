---
layout: default
title: Alternatives - Guides
description: All the alternative ways you can declare your schema fields
---

# Alternatives

Here you will see all the possible ways you can define your schema fields. Keep in mind
that this was developed to provide
<a href="https://en.wikipedia.org/wiki/Single-responsibility_principle" target="_blank" rel="external nofollow">SRP</a>
and
<a href="https://en.wikipedia.org/wiki/Don%27t_repeat_yourself" target="_blank" rel="external nofollow">DRY</a>
principles gracefully.

{: .highlight }
> The examples will focus on queries, but you can do the same with mutations and subscriptions.

## Direct Definition

Directly defining your fields means that you will add them directly into your schema.
This is the simplest way, but the one you should use as less as possible.

```ruby
# app/graphql/app_schema.rb
query_fields do
  field(:rails_version, :string).resolve { Rails.version }
end
```

This is a great example of a direct definition of a field. The value is immutable, and
there is no reason to add a method. A direct resolve block is enough.

```ruby
# app/graphql/app_schema.rb
query_fields do
  field(:me, 'User').resolve { context.current_user }
end
```

This is also an excellent example because there is no logic involved in resolving the
field's value, and there is no need to add more code than this.

{: .important }
> This approach is not recommended for mutations in any case.

Read more about [fields](/guides/fields) and [recommendations](/guides/recommendations).

## Set Definition

This is one level higher. When a set of fields share a common ground, you can define a
class where they will all live. Then you can add shared methods and the list of fields.
Just remember to import this as a dependency in your schema.

```ruby
# app/graphql/queries/migrations_set.rb
class GraphQL::Queries::MigrationsSet < GraphQL::QuerySet
  field :last_migration, :int, null: false
  field :all_migrations, :int, null: false, array: true
  field :needs_migration, :boolean, null: false

  def last_migration
    context.current_version
  end

  def all_migrations
    context.get_all_versions
  end

  def needs_migration
    context.needs_migration?
  end

  private

  def context
    ActiveRecord::Base.connection.migration_context
  end
end
```

Read more about [local dependencies](/guides/schemas#local-dependencies).

## Standalone Definition

This is one level even higher. When the complexity of a field is so significant that it requires
several methods and several parts to get its resolution, you can define a single class for
a single field. If you are used to using
<a href="https://www.honeybadger.io/blog/refactor-ruby-rails-service-object/" target="_blank" rel="external nofollow">Rails Services</a>,
you might feel at home here.

```ruby
# app/graphql/queries/migrations_set.rb
class GraphQL::Queries::Permissions < GraphQL::Query
  desc <<~DESC
    Returns all the actions that the current can do
    in the given section provided as an argument.
  DESC

  argument :section, null: false
  returns :string, array: true

  delegate :current_user, to: :context

  def resolve
    # ...
  end

  # ...
end
```

You will also need to import these kinds of classes into your schema.

{: .note }
> **Quick Note**
> For mutations, besides the `resolve` method, you also have the `perform` method
> as entry point. Read more about it [here](/guides/mutations).

## Source Definition

This is the highest level you can get. This approach combines several things into one place.
Think of it as the abstraction level of the definition process. Instead of defining each
query field, plus mutations, plus object type, plus input type, sources can translate
other classes into several GraphQL things.

This is the highest level because instead of writing each individual element, you would
write a translator. Once you have the translator, then all the objects that fall into
the same patterns can all be threaded the same way.

One great example is [ActiveRecord](/guides/sources/active-record), which already has
its source implemented in this gem. All your models can be easily turned into all
their counterparts in GraphQL.

```ruby
# app/graphql/sources/user_source.rb
class GraphQL::UserSource < GraphQL::ActiveRecordSource
  build_all
end

# OR

# app/graphql/app_schema.rb
module GraphQL
  class AppSchema < GraphQL::Schema
    source User
  end
end
```

The above will produce something like:

```graphql
schema {
  query: _Query
  mutation: _Mutation
}

type _Query {
  users: [User!]!
  user(id: ID!): User!
}

type _Mutation {
  createUser(user: UserInput!): User!
  updateUser(id: ID!, user: UserInput!): User!
  deleteUser(id: ID!): Boolean!
}

type User {
  # ... All user fields
}

input UserInput {
  # ... All user fields as input
}
```

{: .new }
> Sources are one the most powerful features of this gem.

Read more about [sources](/guides/sources).
