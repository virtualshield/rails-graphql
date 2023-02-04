---
layout: default
title: Error Handling - Guides
description: Everything you need to know about how errors are handled
---

# Error Handling

This gem provides several resources for handling errors. Per the
<a href="http://spec.graphql.org/October2021/#sec-Handling-Field-Errors" target="_blank" rel="external nofollow">GraphQL Spec</a>,
errors during the processing of fields, therefore the processing of requests, should produce
partial responses, with further explanation under the `errors` key of the response.

With that in mind, be aware that **exceptions will always be captured and added to the errors**{: .fw-900 },
unless you return a `false` from a `rescue_from`.

## Additional Errors

The [request](/guides/request) provides some methods that facilitate adding errors to the response.
In normal circumstances, they work collaboratively, one calling the other in this order. But, you
can choose which one to use:

{: title="exception_to_error" id="exception_to_error" }
### `exception_to_error(exception, node, **extra)`

Turn an exception into an item in the errors of the response. This step adds the
`exception` key to the `extensions` of the error and gets the message from the exception
if one hasn't been provided using the `message` named argument.

{: title="report_node_error" id="report_node_error" }
### `report_node_error(message, node, **extra)`

Report an error message that occurred in the given node. This step properly adds the location
of the node where the error occurred if one hasn't been provided.
The node can be any of the [request components](/guides/request#components).

{: title="report_error" id="report_error" }
### `report_error(message, **extra)`

Simply add an error message to the response. This step adds the `path` of the error as the
current stack of the request if one hasn't been provided. This is the last step of the chain.

{: .new }
> **Shortcut**
> The method above returns `nil` so that you can easily make it the last result of
> your resolvers, making the result of the field `nil`. See below:

```ruby
# Instead of doing this
def welcome
  request.report_error('Something went wrong.')
  nil # Resolving the field to nil
end

# Simply do this
def welcome
  request.report_error('Something went wrong.')
  # The return of the above is already nil
end
```

## Using Rescue From

Schemas implement
<a href="https://edgeapi.rubyonrails.org/classes/ActiveSupport/Rescuable/ClassMethods.html" target="_blank" rel="external nofollow">ActiveSupport::Rescuable</a>,
which allows you to capture specific exceptions and handle them differently.
The exception received during the rescue has the necessary information to interact
with the request:

`args`
: The arguments passed to the request

`source`
: The component where the error happened

`request`
: The request instance

`response`
: The response instance

`document`
: The document of the request

## Console Display

If the exception was not skipped by a `rescue_from`, then on top of adding the
error to the response, a nice table and backtrace will be displayed in the server
console. Here is an example:

```ruby
# app/graphql/app_schema.rb
field(:welcome).resolve { raise 'Something went wrong.' }
```

```
   | Loc | Field          | Object | Arguments | Result
---+-----+----------------+--------+-----------+--------------------
 1 | GQL | schema         | :base  |           | GraphQL::AppSchema
 2 | 1:1 | query          | nil    | {}        | _Query
 3 | 1:3 | _Query.welcome | nil    | {}        | ↓

Something went wrong. (RuntimeError) [resolve]
/home/app/graphql/app_schema.rb:3:in `block in <class:AppSchema>'
```

{: .note }
> Some internal errors that may appear in the `errors` portion of the response
> will not produce a console display.
