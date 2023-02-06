---
layout: default
title: Active Record - Sources - Guides
description: Full support to Active Record using Sources
---

# Active Record Source

The gem comes with full support for Active Record, which means that one line can
create all the necessary components for you to perform any CRUD operation on them.

{: .new }
> **N+1 Protected**
> By default, associations will be properly loaded once during the
[`prepare`](/guides/request#preparing) phase of the request.

## Setup

You can define Active Record sources on a file or using the shortcut on the schema.

```ruby
# app/graphql/sources/user_source.rb
module GraphQL
  class UserSource < GraphQL::Source::ActiveRecordSource
  # OR
  class UserSource < GraphQL::ARSource
    build_all
  end
end

# OR

# app/graphql/app_schema.rb
source User
```

This will scaffold the following components:

```graphql
type User {
  id: ID!
  email: String!
  # ... any other attributes and associations
}

input UserInput {
  id: ID
  email: String!
  # ... any other attributes and associations with accepts nested attributes
  _delete: Boolean = false # For the inverted reason of the above
}

type _Mutation {
  createUser(user: UserInput!): User!
  deleteUser(id: ID!): Boolean!
  updateUser(id: ID!, user: UserInput!): User!
}

type _Query {
  user(id: ID!): User!
  users: [User!]!
}
```

Read more about [inline sources](/guides/sources#4-inform-the-settings).

## Settings

Here are all the settings that you can add to your sources:

`with_associations`
: `true` - Marks if fields related to associations should be added.

`errors_to_extensions`
: `false` - Marks if errors should be exported to the `extensions` of the response.
<br/>Possible values: `false`, `:details`, `:messages`

`act_as_interface`
: `false` - Marks if the source should build an interface instead of an object.

## Behaviors

Here are all the behaviors of an Action Record source and how you can take advantage of them:

### Fields

Here is some important information about the fields created automatically and what
events are added to them in what order (examples based on the `UserSource`):

{: title="query all" }
#### `query users: [User!]!`

Uses the `plural` name of the model for the field name and resolves to [`load_records`](#load_records).

{: title="query one" }
#### `query user(id: ID!): User!`

Uses the `singular` name of the model for the field name and resolves to [`load_record`](#load_record).

{: title="mutation create" }
#### `mutation createUser(user: UserInput!): User!`

Uses the `singular` name of the model with `create`, has a `singular` argument with the proper
input type, performs [`create_record`](#create_record), and resolves to the created record.

{: title="mutation update" }
#### `mutation updateUser(id: ID!, user: UserInput!): User!`

Uses the `singular` name of the model with `update`, has an `id` argument and a `singular` argument
with the proper input type, prepares with [`load_record`](#load_record), performs [`update_record`](#update_record),
and resolves to the updated record.

{: title="mutation delete" }
#### `mutation deleteUser(id: ID!, user: UserInput!): Boolean!`

Uses the `singular` name of the model with `delete`, has an `id` argument, prepares with [`load_record`](#load_record),
performs [`destroy_record`](#destroy_record), and resolves to either `true` or `false`.

### Assignment

Sources take a huge advantage of [type assignment](/guides/advanced/type-assignment). That said, the
source will assume that its name is a reference to a model and make an automatic
assignment to that. You can override that and manually set the assignment:

```ruby
# app/graphql/sources/user_source.rb
class GraphQL::UserSource < GraphQL::ARSource
# Thus automatically assign it to User, the same as
self.assigned_to = 'User'
```

### Interface

By default, the source would create an [object](/guides/objects) to represent its values.
However, if you don't set `act_as_interface`, the source can still identify that it should
behave as an interface when it has an inheritance column (aka `type`), and the assigned
class is the base class of such inheritance. This is an automatic support for
<a href="https://edgeapi.rubyonrails.org/classes/ActiveRecord/Inheritance.html" target="_blank" rel="external nofollow">Single table inheritances</a>.

### Enums

The source will attempt to create [enums](/guides/enums) for each attribute on the model that
is marked as an enum. In case of any conflict, it will threaten the attribute as their plain type.
You can skip this process by simply calling `disable :enums`.

### Associations

This source takes advantage of the [Type Map hooks](/guides/type-map#register-hook) to lazy
add fields into both the [object](/guides/objects)/[interface](/guides/interfaces) and the
[input](/guides/inputs) that is related to associations. Here is an example:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_many :addresses
  accepts_nested_attributes_for :addresses, allow_destroy: true
end

# app/models/address.rb
class Address < ApplicationRecord
  belongs_to :user
end

# app/graphql/sources/user_source.rb
class GraphQL::UserSource < GraphQL::ARSource
  build_all
end

# app/graphql/sources/address_source.rb
class GraphQL::AddressSource < GraphQL::ARSource
  build_all
end
```

```graphql
type Address {
  id: ID!
  line1: String!
  userId: ID!
  user: User!
  _delete: Boolean = false
}

type User {
  id: ID!
  email: String!
  addresses: [Address!]
  _delete: Boolean = false
}

type AddressInput {
  id: ID
  line1: String!
  userId: ID!
}

type UserInput {
  id: ID
  email: String!
  addressesAttributes: [AddressInput!]
}
```

{: .warning }
> **Warning**
> Polymorphic associations are ignored.

#### Proxy Field

An interesting thing to notice is that collection associations, those with `has_many`, will attempt
to proxy the collection field from the other source. By doing that, you can share common
arguments and features, like [scoped arguments](/guides/sources/scoped-arguments), between them.
Here is what may happen:

```graphql
type _Query {
  # This is the original field
  addresses(primary: Boolean! = false): [Addresses!]!
}

type User {
  # This is the proxy field, with the same arguments as its companion
  addresses(primary: Boolean! = false): [Addresses!]!
}
```

{: .highlight }
> **Important**
> This is an experimental feature and may change in the future.

**Proxy fields is an advanced feature.** Read more about [proxy fields](/guides/advanced/fields#proxies)
adn [scoped arguments](/guides/sources/scoped-arguments).

### Errors

When you use the `errors_to_extensions` setting, whenever the default mutations
are not successful, it will expose the
<a href="https://edgeapi.rubyonrails.org/classes/ActiveModel/Errors.html" target="_blank" rel="external nofollow">Errors</a>
to the [`extensions`](/guides/request#extensions) portion of the result. It will include
the operation name, if any, and the field name or alias. See an example:

```graphql
mutation SingUp($user: UserInput!) {
  createUser(user: $user) { id }
}
```

When set to `:details`, it uses
<a href="https://edgeapi.rubyonrails.org/classes/ActiveModel/Errors.html#method-i-details" target="_blank" rel="external nofollow">`details`</a>:

```json
{
  "data": {},
  "errors": [
    {
      "message": "Validation failed: Email can't be blank",
      "path": ["SingUp", "createUser"],
      "extensions": {
        "stage": "prepare",
        "exception": "ActiveRecord::RecordInvalid"
      }
    }
  ],
  "extensions": {
    "SingUp": {
      "createUser": { "email": [{ "error": "blank" }] }
    }
  }
}
```

When set to `:messages`, it uses
<a href="https://edgeapi.rubyonrails.org/classes/ActiveModel/Errors.html#method-i-as_json" target="_blank" rel="external nofollow">`as_json`</a>:

```json
{
  // ...
  "extensions": {
    "SingUp": {
      "createUser": { "email": ["can't be blank"] }
    }
  }
}
```

## Methods

Here is a list of methods that you can use and rely on to facilitate the usage
with your models:

{: title="load_records" id="load_records" }
### `load_records(scope = nil)`

Responsible for loading several records from the model during the `prepare` stage.
The `scope` will be either the event's [`last_result`](/guides/events#calling-next) or `default_scoped`.

{: title="load_record" id="load_record" }
### `load_record(scope = nil, find_by: nil)`

Responsible for loading one record from the model during the `prepare` stage.
The `scope` will be either the event's [`last_result`](/guides/events#calling-next) or `default_scoped`.
If `find_by` is not provided, it assumes `{ primary_key => argument(primary_key) }`.

{: title="create_record" id="create_record" }
### `create_record`

It will call `save!` from [`input_argument`](#input_argument).
Read more about [inputs assignment](/guides/inputs#type-assignment).

{: title="update_record" id="update_record" }
### `update_record`

It will call `update!` from the current record with params from [`input_argument`](#input_argument).

{: title="destroy_record" id="destroy_record" }
### `destroy_record`

It will call `destroy!` from the current record.

{: title="build_association_scope" id="build_association_scope" }
### `build_association_scope(association)`

This is the first step to loading an association, which will get the proper scope for the association.
Read more about [events](/guides/events#capturing-values) to see how you can build on top of this method.

{: title="preload_association" id="preload_association" }
### `preload_association(association, scope = nil)`

This is the second step to loading an association, which will use Active Record internal
components to properly load the records and make them available for the next step. If the
`scope` is not provided, it will use the value from the above method.

{: title="parent_owned_records" id="parent_owned_records" }
### `parent_owned_records(collection_result = false)`

This is the last step to loading an association, which will use the preloaded data and
get the relevant records for the current record.

{: title="errors_to_extensions" id="errors_to_extensions" }
### `errors_to_extensions(errors, path = nil, format = nil)`

This method is responsible for delivering the [errors](#errors) behavior. You can still
use it regardless of the `errors_to_extensions` setting by simply passing the `format` you want.
You can also override the `path` to which the errors will be added to.

{: title="input_argument" id="input_argument" }
### `input_argument`

This method gets the proper [input](/guides/inputs) associated with the attributes
of the record from the list of arguments of the field. You can use it to manipulate the
attributes that will be saved.

## Adapters

Here is the list of supported adapters and their respective mapping of types:

### MySQL

<details>
  <summary>Types</summary>
  <div class="language-ruby highlighter-rouge">
{% highlight ruby %}
'mysql:varchar'       => :string
'mysql:bit'           => :bool
'mysql:int'           => :int
'mysql:bigint'        => :bigint
'mysql:json'          => :json
'mysql:date'          => :date
'mysql:timestamp'     => :date_time
'mysql:binary'        => :binary
'mysql:float'         => :float
'mysql:decimal'       => :decimal
'mysql:time'          => :time

'mysql:set'           => 'mysql:varchar'
'mysql:text'          => 'mysql:varchar'
'mysql:enum'          => 'mysql:varchar'
'mysql:char'          => 'mysql:varchar'
'mysql:tinytext'      => 'mysql:text'
'mysql:mediumtext'    => 'mysql:text'
'mysql:longtext'      => 'mysql:text'
'mysql:datetime'      => 'mysql:timestamp'
'mysql:varbinary'     => 'mysql:binary'
'mysql:blob'          => 'mysql:binary'
'mysql:tinyblob'      => 'mysql:blob'
'mysql:mediumblob'    => 'mysql:blob'
'mysql:longblob'      => 'mysql:blob'
'mysql:tinyint'       => 'mysql:int'
'mysql:smallint'      => 'mysql:int'
'mysql:mediumint'     => 'mysql:int'
'mysql:double'        => 'mysql:float'
{% endhighlight %}
  </div>
</details>

### PostgreSQL

<details>
  <summary>Types</summary>
  <div class="language-ruby highlighter-rouge">
{% highlight ruby %}
'pg:bigint'                       => :bigint
'pg:boolean'                      => :boolean
'pg:text'                         => :string
'pg:date'                         => :date
'pg:integer'                      => :int
'pg:json'                         => :json
'pg:numeric'                      => :decimal
'pg:real'                         => :float
'pg:time without time zone'       => :time
'pg:timestamp'                    => :date_time

'pg:char'                         => 'pg:text'
'pg:smallint'                     => 'pg:integer'
'pg:oid'                          => 'pg:integer'
'pg:double precision'             => 'pg:real'
'pg:money'                        => 'pg:numeric'
'pg:character'                    => 'pg:text'
'pg:character varying'            => 'pg:text'
'pg:timestamp without time zone'  => 'pg:timestamp'
'pg:timestamp with time zone'     => 'pg:timestamp'
'pg:time with time zone'          => 'pg:time without time zone'
'pg:jsonb'                        => 'pg:json'
{% endhighlight %}
  </div>
</details>

### SQLite

<details>
  <summary>Types</summary>
  <div class="language-ruby highlighter-rouge">
{% highlight ruby %}
'sqlite:binary'       => :binary
'sqlite:boolean'      => :boolean
'sqlite:date'         => :date
'sqlite:datetime'     => :date_time
'sqlite:decimal'      => :decimal
'sqlite:float'        => :float
'sqlite:integer'      => :int
'sqlite:json'         => :json
'sqlite:primary_key'  => :id
'sqlite:string'       => :string
'sqlite:time'         => :time

'sqlite:varchar'      => 'sqlite:string'
'sqlite:text'         => 'sqlite:string'
{% endhighlight %}
  </div>
</details>
