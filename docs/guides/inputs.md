---
layout: default
title: Inputs - Guides
description: Organize fields for receiving data
---

# Inputs

```graphql
type UserInput {
  name
  email
}
```

Inputs allow you to organize fields to receive data. Besides [scalars](/guide/scalars) and
[enums](/guide/enums), inputs are the other type accepted by arguments. You should use
them when you have several attributes to receive from your front end.

## Creating an Input

You can define inputs on a file or using the shortcut on the schema.

```ruby
# app/graphql/inputs/user_input.rb
module GraphQL
  class UserInput < GraphQL::Input
    field :name
    field :email
  end
end

# OR

# app/graphql/app_schema.rb
input 'UserInput' do
  field :name
  field :email
end
```

Read more about [field lists](/guides/field-lists).

{% include type-description.md type="input" name="UserInput" file="user_input" %}

## Using Inputs

Once they are defined, you can set them as the type of any field's [arguments](/guides/arguments).
Then, in your execution document, you can pass the values directly or through variables.

```ruby
field(:create_user, 'User', null: false) do
  argument :user, 'UserInput', null: false
end
```

```graphql
# Directly
mutation {
  createUser(user: { name: "John Doe", email: "john+doe@test.com" }) { id }
}

# Using variables
mutation($user: UserInput!) {
  createUser(user: $user) { id }
}
```

### The Instance

The inputs' instances have several methods to facilitate handling them. For example,
all the fields will be automatically converted from camel case to snake case. You can
think of inputs as
<a href="https://edgeapi.rubyonrails.org/classes/ActionController/StrongParameters.html" target="_blank" rel="external nofollow">StrongParameters</a>,
because the combination of fields and their respective types have the same purpose of
protecting attributes from end-user assignment.

```ruby
# app/graphql/app_schema.rb
input 'UserInput' do
  field :first_name
  field :last_name
  field :email
end

add_mutation_field(:create_user, :bool, null: false) do
  argument :user, 'UserInput', null: false
end

def create_user(user:)
  puts user.args.first_name
end
```

```graphql
mutation {
  createUser(user: {
    firstName: "John",
    lastName: "Doe",
    email: "john+doe@test.com"
  })
}
```

### Params

You can collect a sanitized Hash by calling the `params` method.

```ruby
# app/graphql/app_schema.rb
def create_user(user:)
  puts user.params.inspect
  # { first_name: "John", last_name: "Doe", email: "john+doe@test.com" }
end
```

### Type Assignment

Inputs are one of the several types that allow being assigned to a specific class.
When inputs are assigned, you can take advantage of the `resource` method, which will
instantiate the assignment with the parameters. You can also provide extra parameters
to this method to extend the instance.

```ruby
# app/graphql/app_schema.rb
input 'UserInput' do
  # Assigned to ::User model
  self.assigned_to = 'User'
  # ...
end

def create_user(user:)
  puts user.resource(id: 1)
  # #<User id: 1, first_name: "John", ...>
end
```

The `resource` is the method delegated to receive any method that the input doesn't have.
This is a syntax sugar for dealing with the inputs as
<a href="https://api.rubyonrails.org/classes/ActiveRecord/Base.html" target="_blank" rel="external nofollow">Models</a>.

```ruby
def create_user(user:)
  user.save! # Same as user.resource.save!
end
```

Read more about [type assignment](/guides/advanced/type-assignment) and [sources](/guides/sources).
