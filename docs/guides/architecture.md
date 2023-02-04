---
layout: default
title: Architecture - Guides
description: All you need to know about how this gem was designed and how it works
---

# Architecture

Here you will find basic information about how this gem was designed,
its essential pieces, and how they connect with each other. It will also guide
you through how to use that in your application.

## Basic concepts

A common way to use this gem is: set up a schema, set up a controller,
create some objects, add query and mutation fields, and start doing requests.

With that in mind, here are some essential concepts:

### Directory Structure

The folder structure within the `graphql` folder differs from what Rails expects
from regular folders. However, you just need to understand 2 rules: Everything must be
inside of the `GraphQL` module, and that it behaves similarly to the `app` folder.

{: .highlight }
> This is 100% intentional and fully compatible with
> <a href="https://github.com/fxn/zeitwerk" target="_blank" rel="external nofollow">Zeitwerk</a>.

#### GraphQL Module

Everything must be encapsulated using the `GraphQL` module so that classes do not collide
with your applications classes. It's also a hint that you are dealing with a GraphQL-specific
object, not a regular one. Plus, it delivers a better naming architecture than throwing
everything on the `Object` module.

Here is some examples:

```ruby
# app/graphql/app_schema.rb
class GraphQL::AppSchema < GraphQL::Schema
# Normally Rails would expect something like AppSchemaGraphQL
```

#### Acting as an `app` folder

This structure can seem weird at first, but it will feel natural when you start using it.
The sole purpose is to ensure that you end up with a directory tree that makes sense,
is Rails-like, and encapsulates things correctly.

Here is some examples:

```ruby
# app/graphql/objects/sample.rb
class GraphQL::Sample < GraphQL::Object
# Normally Rails would expect something like Objects::SampleGraphQL

# app/graphql/inputs/sample_input.rb
class GraphQL::SampleInput < GraphQL::Input
# Normally Rails would expect something like Inputs::SampleInputGraphQL

# app/graphql/inputs/person_input.rb
class GraphQL::PersonInput < GraphQL::Input
# Normally Rails would expect something like Inputs::PersonInputGraphQL

# app/graphql/queries/users.rb
class GraphQL::Queries::Users < GraphQL::Query
# Normally Rails would expect something like Queries::UsersGraphQL
```

With this example, you can notice 2 behaviors: one where the folder name is not required to
appear as a module and the other where it must. This is intentional, so that natural feeling
is kept. `objects` and `interfaces` work like `controllers` and `jobs` in an `app` folder,
whereas others behave as regular folders.

This also works with nested directories, as one would expect for engines:

```ruby
# app/graphql/admin/objects/sample.rb
class GraphQL::Admin::Sample < GraphQL::Object

# app/graphql/admin/queries/users.rb
class GraphQL::Admin::Queries::User < GraphQL::Query
```

The full list of collapsed directories comes from [`config.paths`](/handbook/settings#paths) setting.

### Naming

The gem assumes you are following the ruby naming conventions. On top of that, there are
some additional concepts related to how things are translated to GraphQL names. Here is
a quick list of the naming conventions:

`class SampleInput`
: Class names should be in Pascal Case

`class Sample < GraphQL::Object`
: Objects are recommended to not have the `Object` suffix

`'SampleObject'`
: Types in GraphQL follows the same pattern

`:sample_object`
: Keys as symbol are always in snake case

`'sampleField'`
: Fields in GraphQL are always in camel case

`:sample_field`
: Field names are always symbols in snake case

This is extremely important when referencing types in fields return type and argument types:

```ruby
# Each one of these blocks produces the same result
field(:name, :string)
field(:name, 'String')
field(:name, GraphQL::Scalar::StringScalar)
# For scalars it is recommended the first or the second options

field(:sample, :sample)
field(:sample, 'Sample')
field(:sample, GraphQL::Sample)
# For objects and other things it is recommended the second option

field(:other_sample, :sample_interface)
field(:other_sample, 'SampleInterface')
field(:other_sample, GraphQL::SampleInterface)
# For any other types it is also recommended the second option
# Field names and argument names should always be symbols in snake case
```

{: .highlight }
> As a rule of thumb: class name in Pascal Case, symbol always in snake case, string in
> either Pascal Case for types or camel Case for fields.

Read more about [names](/guides/names) and [recommendations](/guides/recommendations).

### Namespaces

You can skip this part if you run a single schema in your application.
The purpose of namespaces is to allow a single Rails application to have multiple
schemas so that they are isolated and yet allowed to share types.

In short, schemas can only have one single namespace, whereas other types can have multiple
namespaces. The default namespace is `:base`.

**This is an advanced feature.** Read more about [namespaces](/guides/advanced/namespaces).

### Shortcuts

The default module of this gem is `::Rails::GraphQL`. However, a `::GraphQL` module is provided.
to simplify accessing standard methods and classes you might inherit from.

{% include shortcuts.html %}

### Instantiating types

Types are usually dealt with at their module level, similar to Rails models when handling
the whole collection. When an instance is created, it is because a request will process
something using that type. This implies that such an instance will have an instance variable
`@event`, and everything that is not found as instance methods will be automatically redirected
to the reader of this variable.

This is how you can access all the information about the request that brought you to that
instance. For example:

```ruby
# app/graphql/app_schema.rb
module GraphQL
  class AppSchema < GraphQL::Schema
    query_fields do
      field(:welcome, :string, null: false)
    end

    # The instance method of the schema,
    # which is instantiated during a request
    def welcome
      # This is the same as event.context
      context.inspect

      # This is the same as event.source.field,
      # which returns the declaration of the welcome field
      field.inspect
    end
  end
end
```

Read more about [events](/guides/events).

### Request

Typically, what we want from a request is its result. That is why `execute` will
only deliver the plain result and disappear with the request instance. However,
you can navigate through a request if you coordinate the execution independently.

{: .rails-console }
```ruby
:001 > # The common use case
:002 > GraphQL::AppSchema.execute('{ welcome }')
    => {"data"=>{"welcome"=>"Hello World!"}}
:003 > # The self coordinated approach
:004 > request = GraphQL::AppSchema.request
    => #<Rails::GraphQL::Request:0x00
       #  @extensions={},
       #  @namespace=:base,
       #  @prepared_data={},
       #  @schema=GraphQL::AppSchema>
:005 > request.execute('{ welcome }')
    => {"data"=>{"welcome"=>"Hello World!"}}
```

You may also find some other ways to start and execute a request:

{: .rails-console }
```ruby
:001 > # Using the shortcut method
:002 > GraphQL.execute('{ welcome }', schema: GraphQL::AppSchema)
:003 > # Manually instantiating the request
:004 > GraphQL::Request.new(GraphQL::AppSchema).execute('{ welcome }')
:005 > # They are all the same, and returns the same result
:006 > GraphQL.execute('{ welcome }')
:007 > # Also works because the schema is from :base namespace
:008 > # However, GraphQL::AppSchema must be loaded first
```

Read more about [requests](/guides/request).

### Logs

You will notice that the Rails application logs are enhanced by GraphQL in both
the server and the console, and they have quite the same behavior as how
<a href="https://edgeapi.rubyonrails.org/classes/ActiveSupport/LogSubscriber.html" target="_blank" rel="external nofollow">ActiveRecord</a>
enhances the logs.

{: .rails-console }
```ruby
:001 > GraphQL::AppSchema.execute('{ welcome }')
     # GraphQL (0.4ms)  { welcome }
     # ↳ (irb):1:in `<main>'
    => {"data"=>{"welcome"=>"Hello World!"}}
```

The log will show the GraphQL header, the operation name, if any, how long it took to process
the request, the document executed, and the variables, if any.

Another place you can see log information is in the summary of a request.

```
| Started POST "/graphql" for 127.0.0.1 at ...
| Processing by GraphQLController#execute as */*
|   GraphQL (0.4ms)  { welcome }
| Completed 200 OK in 2ms ... | GraphQL: 0.4ms | ...
```

Read more about [request logs](/guides/request#logs).

## Components

This gem contains 9 crucial parts for its operation. Some are one-to-one
with the GraphQL spec, while others connect things and make it happen.

### Type

This is the hearth of GraphQL. Almost everything in GraphQL is a Type, like `Object`, `Input`,
`Scalar`, and all its descendants. Some are called `leaf` types, like `Scalar` and `Enum` because
the only produce a value. Others are more complex because they can hold a list of fields, like
`Object` and `Interface`.

Read more about it in the
<a href="http://spec.graphql.org/October2021/#sec-Types" target="_blank" rel="external nofollow">GraphQL Spec</a>
and [here](/guides#type-system).

### Schema

A schema is where types meet and organize themselves to tell all the capabilities
a user can access and do.

A good way to think about schemas is as if they were their own Rails application.
The fields in it are its routing system, and the types are everything it can respond to.

Read more about it in the
<a href="http://spec.graphql.org/October2021/#sec-Schema" target="_blank" rel="external nofollow">GraphQL Spec</a>
and [here](/guides/schemas).

### Field

The field is the most important thing to understand in GraphQL. Everything you can access
and collect from any GraphQL operation is based on fields. Schema and some types can have
a list of fields.

It's important to know that names **cannot be duplicated** within a list of fields.

In that Rails application analogy, you can think of fields as individual routes when they are
inside of a schema and individual pieces of output in the responses.

Read more about it in the
<a href="http://spec.graphql.org/October2021/#sec-Language.Fields" target="_blank" rel="external nofollow">GraphQL Spec</a>
and [here](/guides/fields).

### Argument

Fields can typically have their behavior changed based on arguments.
Arguments can be as simple as a String or as complex as a custom Input type.
It is through arguments that you usually will exchange parameters with your request.
The only fields that don’t support arguments are those found in Input types.

A list of arguments within a particular field **cannot be duplicated** as well.

Following that Rails analogy, think of arguments as the parameters that you send on each request.

Read more about it in the
<a href="http://spec.graphql.org/October2021/#sec-Language.Arguments" target="_blank" rel="external nofollow">GraphQL Spec</a>
and [here](/guides/arguments).

### Directive

Directives are similar to arguments. However, its purpose is to change output as a whole.
There are several other usages for directives, making it an advanced feature of GraphQL and the gem.

Directives are available during a request and while setting up your schema and types.
A schema **cannot have duplicated** directive names.
However, there is no rule for using the same directive multiple times.

In that Rails analogy, think of directives settings and configurations on your setup or headers in your requests.

Read more about it in the
<a href="http://spec.graphql.org/October2021/#sec-Language.Directives" target="_blank" rel="external nofollow">GraphQL Spec</a>
and [here](/guides/directives).

{: .highlight }
> This section now is exclusive for this gem

### Type Map

The type map is central to the operations of the gem. It knows all the schemas available,
all the types each schema has access to, aliases to other types, and many more mapping
between values and their underlying object.

You can think of the type map as an index of your application in GraphQL.

Read more about the [Type Map](/guides/type-map).

### Request

The request is the one responsible for making things happen. It is within its content
that a document is received, executed, and thrown a response. Requests are somewhat complicated
because there are too many possibilities, and it has to serve it all.

A great thing to keep in mind is that requests are divided into a 3-steps process: `organize`,
`prepare`, and `resolve`.

Read more about [requests](/guides/request).

### Event

During the requests' lifecycle, several events may happen. Events are how the request interacts
with the code outside of the gem. There is a considerable amount of events that you can use
to adapt the gem to your needs.

This event-driven architecture is primarily present in fields and directives.

Read more about [events](/guides/events).

### Callback

The callback is the counterpart of the event. Methods and Procs are turned into callbacks so
that they can coordinate with the event if they will actually be executed and what kind of
information it will provide straightaway to the associated process.

Read more about [callbacks](/guides/events#callbacks).
