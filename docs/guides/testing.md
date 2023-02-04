---
layout: default
title: Testing - Guides
description: The built-in features to facilitate testing your GraphQL API
---

# Testing

This gem provides some features that facilitate testing your GraphQL API.
Here is the list of these facilitators:

{: .important }
> **Important**
> More features will soon be added to both RSpec and Rubocop.

## Validating

You can run a [request](/guides/request) in validation mode, which will go
over the whole `organize` step and return true if the given document, including
context and variables, is valid.

{: .rails-console }
```ruby
:001 > GraphQL.valid?('{ welcome }')
    => true
```

## Stubbing Values

You can easily stub the values received by fields by using
[prepared data](/guides/advanced/request#prepared-data). This feature is not
exclusively for testing, but it was created with this intention. Here are
some examples on how you can use that:

```ruby
# Using a simple named argument
GraphQL.execute('{ users { id name } }', data_for: {
  'query.users' => [User.new]
})

# Using a more complex setting from the request instance
request = GraphQL.request
request.prepare_data_for('User.id', [1, 2], repeat: :cycle)
request.execute('{ users { id name } }')
```

{: .note }
> The format is always `gql_name.field` or `{query,mutation,subscription}.field` for
> schema fields.

Read more about [prepared data](/guides/advanced/request#prepared-data).
