---
layout: default
title: Events - Guides
description: Everything you need to know about events and callbacks
---

# Events

{: .important }
> **Important**
> This gem uses a lot of
> <a href="https://ruby-doc.org/stdlib-3.0.0/libdoc/delegate/rdoc/SimpleDelegator.html" target="_blank" rel="external nofollow">SimpleDelegator</a>
> and custom delegators. If you are not familiar with such a pattern, it's recommended
> that you read about it first.

This gem uses a series of events to deal with [requests](/guides/request) and
[directives](/guides/directives). Events are divided into two types (also called
phase): `definition` and `execution`.

* [`definition`](#definition) - Events that happens when components are being defined;
* [`execution`](#execution) - Events that happens during a [request](/guides/request).

It is not a coincidence that this division is similar to the
[directive restrictions](/guides/directives#restrictions).

{: .important }
> More events will be added as the gem evolves, especially during the definition
> stage.

## Phases

### Definition

As of now, the only event that can happen during the definition is the `attach`
one, which occurs when a directive is attached to a component. You can use
this event to manipulate the component where the directive is being attached to.

### Execution

On the other hand, the execution has a large list of [available events](/guides/request#events).
Any field, directive, or type (through directives) can listen to any of those events
and perform proper manipulation of the request and response. For example:

```ruby
# app/graphql/objects/user.rb
field(:id).on(:finalize) do
  # This will multiply the id by 10 before it is added to the response
  self.current_value = current_value * 10
end
```

Read more about the [request event](/guides/request#event).

## Using Events

You can add an event listener by calling the `on` method. This will set up a
[callback](#callback), which can be either a method to be called or a block to
be run. You can also pass extra arguments that will be properly transferred.

```ruby
field(:id).on(:organized) { do_something }
# OR
field(:id).on(:organized, :do_something)
#                         ↳ the method to be called
```

### Shortcuts

Fields allow setting up some event listeners using a method with the same name
as the event. These are: `organized`, `prepared`, `prepare` (`before_resolve`),
`finalize` (`after_resolve`), `resolve`, `perform`, and `authorize`.

The `resolve` and `perform` are unique events because fields can only have one
of them, you cannot set them up using `on`, and directives cannot listen to them.
Therefore, you should use their respective next events `finalize` and `prepared`
to accomplish the same.

### Exclusiveness

By default, events will only be triggered when the source of the event is the
same as where the listener was added (or on a directive of the source). However,
setting up a listener with `exclusive_callback: false` will trigger if the
source is in the current stack.

In the above example, when anything has been resolved for the schema, the block
on the directive will be called.

```ruby
# app/graphql/directives/awesome_directive.rb
on(:finalize, exclusive_callback: false) do |source|
  puts "#{source.gql_name} has been resolved!"
end

# app/graphql/app_schema.rb
use :awesome
```

### Arguments

Arguments that an event listener can receive work differently. You
can think about them as a list of things you need to perform the callback.
This feature is controlled by the [callback_inject_arguments](/handbook/settings#callback_inject_arguments)
and [callback_inject_named_arguments](/handbook/settings#callback_inject_named_arguments) settings.

Assuming that both settings are enabled, see the following examples:

```ruby
on(:finalize) { |event| event.inspect }
#                ↳ The event will be inject here

on(:finalize) { |request| request.inspect }
#                ↳ The request will be inject here

on(:finalize) { |field, memo| (memo[field] ||= []) << 1 }
#                ↳ Both elements will be injected here

on(:finalize) { |request:| request.inspect }
#                ↳ It works with named arguments too

on(:prepare) { |id:| User.find(id) }
#               ↳ With named arguments you can capture arguments

on(:prepare, :load_record)
def load_record(id:)
#               ↳ It works with methods too

argument(:direction, null: false, default: 'asc')
on(:finalize) do |current, direction:|
#                          ↳ It will inject the default value too
```

Now, when you set up the listener with extra arguments, they will have higher
precedence than the injected ones. See the examples:

```ruby
on(:finalize, 123) { |event| event.inspect }
#                     ↳ This will be 123

on(:finalize, 123) { |value, event| event.inspect }
#                            ↳ This will reive the injected event

on(:finalize, format: :string) do |direction:|
#                                  ↳ It works the same for named arguments

on(:prepare, :sort_records, :name)
def sort_records(field)
#                ↳ Same with methods
```

What can be injected is equal to everything you can call from the event. You can
find the list of available ones in the [quick reference](#quick-reference) and
some extra ones [here](/guides/request#event) for the request events.

### Calling Next

You can capture the next value of a chain of events, manipulate it, and then
return a different value to the next event to work with it. Think of it as
calling `super` from a method in a child class. See the example:

```ruby
on(:finalize) { 1 }                                                 # 1
on(:finalize) { |event| event.last_result * 10 }                    # 1 * 10
on(:finalize) { |event| event.last_result + 4 }                     # 10 + 4
on(:finalize) { |event| event.current_value = event.last_result }   # 14
# This will result in 14

on(:finalize) { 1 }                                                 # 1
on(:finalize) { |event| event.call_next * 10 }                      # 5 * 10
on(:finalize) { |event| event.last_result + 4 }                     # 1 + 4
on(:finalize) { |event| event.current_value = event.last_result }   # 50
# This will result in 50
```

This ability is extremely valuable. For example, when Active Record sources are
[loading associations](/guides/sources/active-record#build_association_scope)
because you can capture the built value, extend it, and leave the rest to the
next event. See the example:

```ruby
# Assuming that this field was created
field = field(:addresses, 'Address', full: true) do
  before_resolve(:preload_association, :addresses)
  before_resolve(:build_association_scope, :addresses)
  resolve(:parent_owned_records, true)
end

# We can simply do the following
field.before_resolve do
  call_next.where(deleted_at: nil)
end
```

That is why the `prepare` (`before_resolve`) event runs in reverse order. Following
the example above, we can see that the last one added will be called first. So we can capture
the next event result, change the query's condition, and leave the `preload_association`
to do its job.

### Directive Events

Event listeners added to directives have some special characteristics: the binding
will always be the instance of the directive, and you can use special filters
to narrow down the source of the event.

{: id="directive-arguments" }
#### Arguments

Since the binding inside an event listener will always be the instance of the directive,
you will need to use [injected arguments](#arguments). If such a feature is disabled, you
can receive an extra argument with the event instance. See the example:

```ruby
# Assuming injected arguments is disabled
# app/graphql/directives/awesome_directive.rb
on(:finalize) { self.inspect }
#               ↳ Nothing will be injected

on(:finalize) { |event| event.inspect }
#                ↳ One extra argument receives the event instance

on(:finalize) { |event, request| event.inspect }
#                       ↳ This will fail

on(:finalize, Rails.env) { |env, event| event.inspect }
#                                ↳ Always the last argument

on(:finalize, :inspect_event)
def inspect_event
  event.inspect
# ↳ For methods, you can use the reader of @event
end
```

{: .important }
> Directives do not automatically delegate missing methods to `@event`.

{: id="directive-filters" }
#### Filters

Filters can be added to event listeners by using named arguments. All filters
accept one or multiple values to check if the conditions event matches any
of its options.

`during`
: A filter for the [event phase](#phases)
: `on :attach, during: :definition`

{: .important }
> More filters will be added in future versions.

## Callbacks

All event listeners are turned into `Callback`s, which are extra powerful Procs.
Not only can they be passed as `&block`, but you can also check their `source_location`
and `call` them, as long as you provide an event.

{: .rails-console }
```ruby
:001 > GraphQL::AppSchema[:query][:welcome].resolver.inspect
    => #<Rails::GraphQL::Callback ...
:002 > GraphQL::AppSchema[:query][:welcome].resolver.source_location[0]
    => "(symbolized-callback/#<... AppSchema[:query] welcome: String>)"
:003 > GraphQL::AppSchema[:query][:welcome].resolver.source_location[1]
    => :welcome
```

Callbacks are the ones responsible for doing the [injection of arguments](#arguments) and
coordinating the instantiation of classes, which is when the `@event` variable
is injected.

## Quick Reference

Here is a quick reference of all the things you can get from the events:

```ruby
# app/graphql/app_schema.rb
# Works with delegate_missing_to :event
def welcome
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
end
```
