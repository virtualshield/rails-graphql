---
layout: default
title: Parser - Guides
description: The implementation of the GraphQL parser provided by this gem
---

# GQLParser

This gem includes its own implementation of a GraphQL parser, written using
<a href="http://silverhammermba.github.io/emberb/c/" target="_blank" rel="external nofollow">Ruby C API</a>,
which delivers the best performance possible.

It’s unlikely that you will need to use the parser on its own. However, by
calling the parser independently, you can always check what the gem will
understand from your GraphQL documents.

{: .rails-console }
```ruby
:001 > GQLParser.parse_execution('{ welcome }')
    => [[[nil, nil, nil, nil,
         [["welcome", nil, nil, nil, nil]]
       ]], nil]
```

You can also use it to check the current supporting spec version:

{: .rails-console }
```ruby
:001 > GQLParser::VERSION
    => "October 2021"
```

You can check the full implementation
<a href="https://github.com/virtualshield/rails-graphql/tree/master/ext" target="_blank" rel="external nofollow">here</a>.

## Concepts

The idea of the parser is to turn all the document information into arrays
of predefined sizes where the needed information will always be in a given spot.

On top of that, Arrays and many other objects that may appear as a result will
be wrapped by a
<a href="https://ruby-doc.org/stdlib-3.0.0/libdoc/delegate/rdoc/SimpleDelegator.html" target="_blank" rel="external nofollow">`SimpleDelegator`</a>
named `GQLParser::Token`, so that their value and usage are kept regularly and enhanced with information
about their meaning and place in the document.

## GQLParser::Token

There are several things a token can inform us of besides its underline value.

{: .rails-console }
```ruby
:001 > result = GQLParser.parse_execution('query Sample { welcome }')
    => [[["query", "Sample", nil, nil, [["welcome", nil, nil, nil, nil]]]], nil]
:002 > operation = result.dig(0, 0)
    => ["query", "Sample", nil, nil, [["welcome", nil, nil, nil, nil]]]
:003 > operation.class
    => GQLParser::Token
:004 > operation.type
    => :query
:005 > operation.begin_line
    => 1
:006 > operation.end_column
    => 25
:007 > operation.of_type?(:query)
    => true
```

The available methods are: `type`, `begin_line`, `begin_column`, `end_line`, `end_column`, and `of_type?`.

## Quick reference

Here is a quick reference list of the token types and arrays returned by the parser:

### Execution

`execution`
: `[[*operation], [*fragment]]`

`operation`
: `[type, name, [*variable], [*directive], [*field]]`

`fragment`
: `[name, type, [*directive], [*field]]`

`variable`
: `[name, type, value, [*directive]]`

`directive`
: `[name, [*argument]]`

`field`
: `[name, alias, [*argument], [*directive], [*field]]`

`type`
: `[name, array_dimensions, bitwise_nullability]`

`argument`
: `[name, value, variable_name]`

`spread`
: `[name, type, [*directive], [*field]]`

### Definition

{: .important }
> To be implemented

## The Type token

There are a couple of things important to notice when reading the information
from the Type token. Types can have multiple dimensions of an Array, and each
can have its own identifier of nullability. Those two information were
simplified into 2 values:

`array_dimensions`: A simple integer that shows how many dimensions the array have.

For example:
```graphql
String     # 0 dimensions
[String]   # 1 dimension
[[String]] # 2 dimensions
```

`bitwise_nullability`: An integer that represents the bitwise result of the nullability
of each dimension

For example:
```graphql
String      #  0 as 0
String!     #  1 as 1
[String]    # 00 as 0
[String]!   # 01 as 1
[String!]   # 10 as 2
[String!]!  # 11 as 3
```
