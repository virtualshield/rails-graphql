---
layout: default
title: Arguments - Guides
description: Specialize your directives and fields using arguments
---

# Arguments

```graphql
{ field(argument: String) }
```

Arguments allow you to pass specific instructions to your fields so they can be prepared
and/or resolved accordingly. You can think of arguments the same as Ruby's named arguments.
In fact, you can make it pretty clear in your resolvers that the incoming argument
is from the field's arguments.

## Adding Arguments

You can add arguments to [fields](/guides/fields#arguments) and [directives](/guides/directives#arguments)
in quite the same way you add fields to [field lists](/guides/field-lists#adding-fields), but using the `argument` method.
However, arguments do not support extended block configuration.

Arguments are a light-weight version of [input fields](/guides/fields#input-fields).

{: .new }
> Starting from version *1.1*, type now can be fully descriptive. It means that you can describe
> the nullability and array as a string representation of the type.

```ruby
argument :name, :string, null: false
argument :name, 'String!'
```

{: .important }
> The current version does not support directives for arguments.

{: .no_toc }
### Additional Options

{: .no_toc }
#### `desc:`/`description:` `String` = `nil`

Allows documenting the argument. This value can be retrieved using [introspection](/guides/introspection)
or during a [to_gql](/guides/customizing/controller#describe) output.

{: .no_toc }
#### `null:` `Boolean` = `true`

Marks if the field accepts or can deliver a null value.

{: .no_toc }
#### `array:` `Boolean` = `false`

Marks if the field accepts or can deliver an array of values.

{: .important }
> As of now, arguments only support one-dimensional arrays.

{: .no_toc }
#### `nullable:` `Boolean` = `true`

Marks if the array may contain null values.

{: .no_toc }
#### `full:` `Boolean` = `false`

A shortcut to `null: false, array: true, nullable: false`.

{: .no_toc }
#### `default:` `Any` = `nil`

The default value for the argument, in case it ends up with `nil`.

## Using Arguments

There are several ways you can access the arguments provided to a field. The example
below go over all of them:

```ruby
# Assuming
field(:welcome) do
  argument(:name, null: false)
end

# Using Proc
find_field(:welcome).resolve { argument(:name) }
find_field(:welcome).resolve { |name:| name }

# Using a method
def welcome
  argument(:name)
end

def welcome(name:)
  name
end
```

### Argument Injection

Because of [events' callbacks](/guides/events#callbacks), you can deliberately ask what
elements you need to run that Proc or method. Such feature is controlled by
[`callback_inject_arguments`](/handbook/settings#callback_inject_arguments) and
[`callback_inject_named_arguments`](/handbook/settings#callback_inject_named_arguments) settings.

Read more about [argument injection](/guides/events#argument-injection)
