---
layout: default
title: Sources - Guides
description: Translate common business objects into GraphQL elements
---

# Sources

Sources are a powerful feature that allows you to translate business objects that
have common structures into GraphQL elements. You can think about sources as
a portion of a schema that is deeply connected to another class in your ruby application.
Therefore, if such a class follows a pattern, you can create a source for such a pattern
and translate all similar classes to GraphQL.

## Available Sources

{: .important }
> More sources will be added, like some for direct DB connection (without Active Record).

This gem provides the following sources:

* [ActiveRecord](/guides/sources/active-record)

## Creating a new Source

There are 4 important steps that you should follow to have a good experience with sources:

### 1. Create the File and set Assignment

Since sources are designed to map features of other classes, you must set the base class to
which the source will translate. This ensures that the underlying class is right when resolving the
[type assignment](/guides/type-assignment). You should also set the base class of your source as `abstract`.

```ruby
# app/graphql/sources/awesome_source.rb
module GraphQL
  class AwesomeSource < GraphQL::Source::Base
    self.abstract = true

    validate_assignment('Awesome::Base')
  end
end
```

Read more about [abstraction](/guides/advanced/abstract).

### 2. Setup Hooks

Sources work with hooks. Hooks represent steps that the source may take to generate
specific GraphQL components. Hooks are always applied in reverse order, meaning that the
outermost class will have its hooks run first.

Hooks are ensured to run only once per build of a source. The `start` hook is special because
it will always run before any other hook is executed. Here is the list of available hooks:

`start`, `object`, `input`, `query`, `mutation`, and `subscription`.

{: .important }
> The order is somewhat important because using `build_all` will run hooks in that specific order.

You can always add your own hooks. If to change the hooks list, make sure to use a `Set`.

```ruby
# A total rewrite
self.hook_names = %i[start object query].to_set.freeze

# A partial change
self.hook_names = hook_names.to_a.insert(1, :enums).to_set.freeze
```

Read more about [hooks](#hooks).

### 3. Add Shared Methods

Now you can add methods to both the construction of your GraphQL components and the
resolution of fields. All class-level methods added will always be available within hooks
execution. In contrast, instance-level methods are available for fields resolutions and events.

```ruby
# app/graphql/sources/awesome_source.rb
step(:query) do
  safe_field("awesome_#{base_name}", :string, null: false) do
    before_resolve(:load, base_name)
  end
end

# Class-level methods should work with the class that is being translated
def self.base_name
  self.class.name.demodulize.underscore
end

# Instance-level methods describe shared process among classes
def load(name)
  assigned_class.load(name)
end
```

### 4. Inform the Settings

When you have finished your source definition, adding the base class to the list of
available base sources is important. This is controlled by the [`sources`](/handbook/settings#sources)
setting. Its main effect is to support the inline definition of sources within a schema:

```ruby
# app/graphql/app_schema.rb
Rails::GraphQL.config.sources << 'GraphQL::AwesomeSource'

# This will automatically identify the proper source describer and translate
# the provided class. This will create a GraphQL::Awesome::UserSource class.
source Awesome::User
```

Read more about [inline types](/guides/schemas#inline-types).

## Using Sources

Once you have your source defined, you can create additional files or use
the shortcut on the schema. It's extremely important that you choose which
steps you want to build so that you don't overload your GraphQL with unnecessary
objects. However, you can still choose to build them all.

```ruby
# app/graphql/sources/user_source.rb
module GraphQL
  class UserSource < GraphQL::AwesomeSource
    build_all
  end
end

# OR

# app/graphql/app_schema.rb
source Awesome::User do
  build_all
end
```

{: .note }
> Each hook have their respective `build_{name}` method.

### Preventing Fields

There are several ways you can prevent specific fields from being created. If properly
configured, sources should only attempt to create fields that haven't been defined yet.
Apart from that, here are other ways to prevent the creation of fields.

#### General

You can prevent fields from being create in any place by calling `skip_fields!` with the
list of symbolized names.

```ruby
# app/graphql/sources/user_source.rb
skip_fields! :secure_token
```

#### Per Kind

You can also prevent fields from being created per kind (where they are supposed to be added).
For example, the following will prevent any `:one_user` and `:all_users` fields from being created in query fields.

```ruby
# app/graphql/sources/user_source.rb
skip_from :query, :one_user, :all_users
```

#### Before Build

You can call any of the build methods with `:except` and `:only`, which works as a shortcut for
the above plus the build process itself.

```ruby
# app/graphql/sources/user_source.rb
build_query except: %i[one_user all_users]
```

## Hooks

The hooks are the place where you will create the necessary elements as a result of
the translation of your classes. Each hook has its own `self`-binding (on top of the
regular binding of the class itself) and represents an area being described to GraphQL
about your classes.

### Managing Hooks

There are several methods implemented to set up and control the execution of hooks.
Here is the list of available methods:

{: title="step" }
#### `step(hook_name, unshift: false, &block)`

This will add one more step to the given `hook_name`. If `unshift` is true, then the step will
be added to the beginning of the list, making the step the last one to be executed.
If you call this method after the build of that hook, the block will be executed immediately.

{: title="skip" }
#### `skip(*hook_names)`

This prevents hooks from further executing. For example, if you add a `skip` and then a `step`
for a given `hook_name`, only that last step will run, and the ones added previously will be
skipped.

{: title="override" }
#### `override(hook_name, &block)`

This is just a shortcut for the `skip` + `step` combination.

{: title="disable" }
#### `disable(*hook_names)`

Disable one or more hooks. This also prevents new steps from being added to those hooks.

{: title="enable" }
#### `enable(*hook_names)`

Enable one or more hooks. This allows steps to be added to those hooks.

### Using Hooks

{: .important }
> Using `safe_field` instead of `field` is recommended to allow specific source
> classes to define fields differently what they would normally be.

When inside the `step` block, you should use the `self`-scope, the source `class`,
and the underlying class of your source to describe it to GraphQL. You are more
than welcome to use inheritance, composition, concerns, and any other object approach
to execute steps.

### Built-in Hooks

Here is the list of built-in hooks and their respective `self`-scopes.

#### `start`

This hook will always be triggered before any other hook runs. The binding is the
source itself. Use this hook to require dependencies and other things from a top-level,
things that are not related to GraphQL components directly.

```ruby
# app/graphql/sources/awesome_source.rb
step(:start) { Awesome::Base.establish_connection }
```

#### `object`

This hook will set up an [object](/guides/objects) that represents the underlying class.
You should map all readable attributes of your class into fields in this step. The binding is
the `object` class being defined.

```ruby
# app/graphql/sources/awesome_source.rb
step(:object) do
  assigned_class.attributes.each do |attribute, type|
    safe_field(attribute, type)
  end
end
```

#### `input`

This hook will set up an [input](/guides/inputs) that represents the underlying class.
You should map all writeable attributes of your class into fields in this step. The binding is
the `input` class being defined.

```ruby
# app/graphql/sources/awesome_source.rb
step(:input) do
  assigned_class.attributes.each do |attribute, type|
    safe_field(attribute, type, null: false)
  end
end
```

#### `query`

This hook will create one or more fields exposed to schema query operations. Usually, here
you will add a read-all and read-one fields. The binding is the same as the block in `query_fields`
from [field lists](/guides/field-lists).

```ruby
# app/graphql/sources/awesome_source.rb
step(:query) do
  safe_field("all_#{base_name}", :string, array: true)
  safe_field("one_#{base_name}", :string)
end
```

If not skipped, this hook will automatically add all the source's query fields to the schemas
of the same namespace.

**Proxy fields is an advanced feature.** Read more about
[proxy fields](/guides/advanced/fields#proxies) and [namespaces](/guides/advanced/namespaces).

#### `mutation`

This hook is quite similar to the above. Usually, here you will add create, update, and
delete fields. The binding is the same as the block in `mutation_fields`
from [field lists](/guides/field-lists).

```ruby
# app/graphql/sources/awesome_source.rb
step(:mutation) do
  safe_field("create_#{base_name}", :bool)
  safe_field("update_#{base_name}", :bool)
  safe_field("delete_#{base_name}", :bool)
end
```

Fields will also be automatically added by default.

#### `subscription`

This hook is quite similar to the above. The binding is the same as the block in `subscription_fields`
from [field lists](/guides/field-lists).

```ruby
# app/graphql/sources/awesome_source.rb
step(:subscription) do
  safe_field("read_#{base_name}", :string)
end
```

Fields will also be automatically added by default.
