---
layout: default
title: Scalars - Guides
description: The most important type in GraphQL
---

# Scalars

```graphql
scalar String
```

Scalars are the most important type in GraphQL.
While other types exist to organize the information in a way that makes sense,
scalars deliver the data.

This gem comes with all the 5
<a href="http://spec.graphql.org/October2021/#sec-Scalars" target="_blank" rel="external nofollow">Spec Scalars</a>,
plus 8 other ones you can use whenever you need.

You can use any of the options displayed after "Names" when referencing the type in fields and
arguments.

Read more about the [Type Map](/guides/type-map).

## Spec Scalars

### ID

The ID scalar type represents a unique identifier and it is serialized in the same
way as a String but it accepts both numeric and string based values as input.

**Names**: `:id`, `'ID'`

### Int

The Int scalar type represents a signed 32-bit numeric non-fractional value.

**Names**: `:int`, `:integer`, `'Int'`

### Float

The Float scalar type represents signed double-precision fractional values.

**Names**: `:float`, `'Float'`

### String

The String scalar type represents textual data, represented as UTF-8 character
sequences.

**Names**: `:string`, `'String'`

### Boolean

The Boolean scalar type represents true or false.

**Names**: `:boolean`, `:bool`, `'Boolean'`

## Additional Scalars

{: .highlight }
> Remember to [add a dependency](/guides/schemas#known-dependencies) to any of these ones you gonna use.

### Any

The Any scalar type allows anything for both input and output.

**Names**: `:any`, `'Any'`

### Bigint

The Bigint scalar type represents a signed numeric non-fractional value.
It can go beyond the Int 32-bit limit, but it's exchanged as a string.

**Names**: `:bigint`, `'Bigint'`

### Binary

The Binary scalar type represents a Base64 string. Normally used to share files and uploads.

**Names**: `:binary`, `:file`, `'Binary'`

### Date

The Date scalar type represents a ISO 8601 string value.

**Names**: `:date`, `'Date'`

### DateTime

The DateTime scalar type represents a ISO 8601 string value.

**Names**: `:date_time`, `:datetime`, `'DateTime'`

### Decimal

The Decimal scalar type represents signed fractional values with extra precision.
The values are exchange as string.

**Names**: `:decimal`, `'Decimal'`

### JSON

The JSON scalar type represents an unstructured JSON data with all its available keys and values.

**Names**: `:json`, `'Json'`, `'JSON'`

{: .important }
> **Careful**
> GraphQL won't handle its structure either for input or output.

### Time

The Time scalar type that represents a distance in time using hours, minutes, seconds, and milliseconds.

**Names**: `:time`, `'Time'`

## Creating your own Scalar

Scalars were inspired by
<a href="https://edgeapi.rubyonrails.org/classes/ActiveModel/Type/Value.html" target="_blank" rel="external nofollow">ActiveModel::Type::Value</a>.
To create your own scalars, you just have to define some class-level methods.

```ruby
# app/graphql/scalars/yes_no_scalar.rb
class GraphQL::YesNoScalar < GraphQL::Scalar
  # It's always good to add a description
  desc 'Exchange boolean values using Yes or No string values'

  class << self
    # Check if a given value is a valid non-deserialized input
    def valid_input?(value)
      value.is_a?(String) && (value == 'Yes' || value == 'No')
    end

    # Check if a given value is a valid non-serialized output
    def valid_output?(value)
      value === true || value === false
    end

    # Transforms the given value to its representation in a JSON string
    def to_json(value)
      value ? '"Yes"' : '"No"'
    end

    # Transforms the given value to its representation in a Hash object
    def as_json(value)
      value ? 'Yes' : 'No'
    end

    # Turn a user input of this given type into a Ruby object
    def deserialize(value)
      value == 'Yes'
    end
  end
end
```

You can check the
<a href="https://github.com/virtualshield/rails-graphql/blob/master/lib/rails/graphql/type/scalar.rb#L38" target="_blank" rel="external nofollow">source code</a>
of the base scalar to seize some of the default behaviors.

You can also add aliases for your type, as in:

```ruby
# app/graphql/scalars/yes_no_scalar.rb
class GraphQL::YesNoScalar < GraphQL::Scalar
  aliases :yesno, 'YESNO'
end
```

The inheritance triggers a process of informing the Type Map of a new type. The values
registered will be based on the class name and the aliases, precisely as they were provided.

**Names**: `:yes_no`, `:yesno`, `'YesNo'`, `'YESNO'`

Read more about the [Type Map](/guides/type-map).

### For gem Creators

Once you have created your scalars in your gem, remember to add them into
[`config.known_dependencies`](/handbook/settings#known_dependencies).

```ruby
Rails::GraphQL.config.known_dependencies[:scalar].update(
  my_gem_scalar: "#{__dir__}/scalars/my_gem_scalar",
)
```
