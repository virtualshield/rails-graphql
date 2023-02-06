---
layout: default
title: Handbook
description: Quick references and other important things to remember
---

# Handbook

## Links

* [Exceptions](/handbook/exceptions)
* [Settings](/handbook/settings)
* [Snippets](/handbook/snippets)

## Directory Structure

{: .directory }
```
/ app
  / graphql
    / directives
    / enums
    / fields
    / inputs
    / interfaces
    / mutations
    / object
    / queries
    / scalars
    / sources
    / subscriptions
    / unions
    - app_schema.rb
```

## GraphQL Module Shortcuts

{% include shortcuts.html open=true %}

## Introspection Query

{% include introspection-query.html open=true %}

## Fresh Schema

{% include introspection-schema.html open=true %}

## Available Scalars

```ruby
# Class                                 # Name and aliases
GraphQL::Scalar::IdScalar               [:id, 'ID']
GraphQL::Scalar::IntScalar              [:int, :integer, 'Int']
GraphQL::Scalar::FloatScalar            [:float, 'Float']
GraphQL::Scalar::StringScalar           [:string, 'String']
GraphQL::Scalar::BooleanScalar          [:boolean, :bool, 'Boolean']
# Needs to be loaded as dependencies
GraphQL::Scalar::AnyScalar              [:any, 'Any']
GraphQL::Scalar::BigintScalar           [:bigint, 'Bigint']
GraphQL::Scalar::BinaryScalar           [:binary, :file, 'Binary']
GraphQL::Scalar::DateScalar             [:date, 'Date']
GraphQL::Scalar::DateTimeScalar         [:date_time, :datetime, 'DateTime']
GraphQL::Scalar::DecimalScalar          [:decimal, 'Decimal']
GraphQL::Scalar::JsonScalar             [:json, 'Json', 'JSON']
GraphQL::Scalar::TimeScalar             [:time, 'Time']
```

## Loading Dependencies

```ruby
# Known dependencies
load_scalars :bigint, :date_time

# Local dependencies
load_directory 'sources'
load_current_directory

# Importing Fields
import_into :query, GraphQL::Queries::Sample
import_all GraphQL::Queries
```

## Schema Fields

```ruby
# Adding fields            # Typename
query_fields do            # _Query
end
mutation_fields do         # _Mutation
end
subscription_fields do     # _Subscription
end
```

## Field List Methods

```ruby
# Single form                      Multi form
# The List
#   Accessing
fields                             fields_for(:query)
#   Checking
fields?                            fields_for?(:query)
# Adding Fields
#   Regular
field(:name, :string)              add_field(:query, :name, :string)
#   Safe
safe_field(:name, :string)         safe_add_field(:query, :name, :string)
#   Proxy
proxy_field(other)                 add_proxy_field(:query, other)
#   Importing
#     From Class
import(GraphQL::WithName)          import_into(:query, GraphQL::Queries::Users)
#     From Module
import_all(GraphQL::UserFields)    import_all_into(:query, GraphQL::Queries)
                                   import_all(GraphQL::Queries)
# Changing
#   Simple
change_field(:name, null: true)    change_field(:query, :name, null: true)
#   Block Only
configure_field(:name) { }         configure_field(:query, :name) { }
#   Disable Fields
disable_fields(:field1, :field2)   disable_fields(:query, :field1, :field2)
#   Enable Fields
enable_fields(:field1, :field2)    enable_fields(:query, :field1, :field2)
# Searching
#   Checking
has_field?(:first_name)            has_field?(:query, :first_name)
has_field?('firstName')            has_field?(:query, 'firstName')
#   Finding
find_field(:first_name)            find_field(:query, :first_name)
find_field('firstName')            find_field(:query, 'firstName')
self[:first_name]                  self[:query, :first_name]
self['firstName']                  self[:query, 'firstName']
#   Force Finding
find_field!(:first_name)           find_field!(:query, :first_name)
find_field!('firstName')           find_field!(:query, 'firstName')
```

## Event Accessors

```ruby
data                      # Any additional data provided to trigger
event                     # The instance of the event
event_name                # The name of the event
last_result               # The last result of the event chain
object                    # The object calling the trigger
source                    # The source of the event

parameter(name)           # Same as try(name) || data[name]
[name]                    # Same as above
parameter?(name)          # Same as respond_to?(name) || data.key?(name)
key?(name)                # Same as above
stop(*result)             # Stop running the event and return *result
```

## Request Event Accessors

```ruby
context                   # The request context
current                   # The current value in the data stack
current_value             # Same as above
errors                    # The request errors
extensions                # The request extensions
field                     # The current field being resolved
index                     # The index of the current array element
memo                      # The operation memo
operation                 # The operation component being resolved
prepared_data             # The prepared data of a field, when provided
request                   # The request itself
resolver                  # The request data stack
schema                    # The schema of the request
strategy                  # The strategy of the request
subscription_provider     # The subscription provider of the schema

argument(name)            # Get the value of an argument sent to the field
arg(name)                 # Same as above
```
