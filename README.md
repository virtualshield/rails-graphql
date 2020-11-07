# Rails GraphQL

![Build Status](https://github.com/virtualshield/rails-graphql/workflows/Tests/badge.svg)
<!-- [![Code Climate](https://codeclimate.com/github/virtualshield/rails-graphql/badges/gpa.svg)](https://codeclimate.com/github/virtualshield/rails-graphql) -->
![Gem Version](https://badge.fury.io/rb/rails-graphql.svg)
<!--([![Test Coverage](https://codeclimate.com/github/virtualshield/rails-graphql/badges/coverage.svg)](https://codeclimate.com/github/virtualshield/rails-graphql/coverage))-->
<!--([![Dependency Status](https://gemnasium.com/badges/github.com/virtualshield/rails-graphql.svg)](https://gemnasium.com/github.com/virtualshield/rails-graphql))-->

* [Wiki](https://github.com/virtualshield/rails-graphql/wiki)
* [Bugs](https://github.com/virtualshield/rails-graphql/issues)

# Description
`rails-graphql` is another implementation of GraphQL server that works really
close to Rails architecture, creating shortcuts to define schemes and connecting
directly with ActiveRecord.

# Installation
To install rails-graphql you need to add the following to your Gemfile:
```ruby
gem 'rails-graphql', '~> 0.1'
```

Also, run:

```
$ bundle
```

Or, for non-Gemfile related usage, simply:

```
gem install rails-graphql
```

# Usage
This gem is intended to be used alongside Rails. It has shortcuts on working
with ActiveRecord as well as providing the C implementation of the GraphQL
parser.

Another great emphasis on reusability and directive was put in place, allowing
robust systems to be built using it without too much boilerplate code. At the
same time, providing all needed levels of customization.

## Folder structure
All the files should live under `app/graphql`, which supports any files
structure (this will probably change in the future). The recommended structure
would have folders like `enums`, `inputs`, `interfaces`, `objects`, `scalars`,
and `unions`, leaving the schema on the base folder.

## Execution sample
If your schema is short, you can define all your elements straightforward from
the schema definition:

```ruby
class ApplicationSchema < GraphQL::Schema
  object 'Hello' do
    field :name, :string, null: false
  end

  query_fields do
    field :welcome, :hello, null: false do
      resolve { OpenStruct.new(name: 'World') }
    end
  end
end
```

Then executing the following will produce the expected behavior:
```ruby
GraphQL.execute('{ welcome { name } }')
# {"data":{"welcome":{"name":"World"}}}
```

## Type mapping
This gem uses the same [TypeMap](lib/rails/graphql/type_map.rb) concept used on
ActiveRecord, meaning that when referencing to any name or type is possible
through ruby symbol notation (`:string`), GraphQL real name of the object
(`'String'`), or the actual class or object (`GraphQL::Scalar::StringScalar`).

In the previous example, the object create `Hello` can then be used in
arguments, fields, or any place that receives a type as the folling options:
`:hello`, `'Hello'`, `GraphQL::HelloObject`.

Several additional types are provided by default from the gem, so it can comply
with database most commonly used types. Those are: `Bigint`, `Binary` for files
(that are Base64 encoded), `Date`, `DateTime`, `Decimal`, and `Time`.

## ActiveRecord sources
To facilitate the mapping of information from ActiveRecord Models into a GraphQL
Scheme, a specific type named source was added that will read all the
meta-information from a model (attributes, validations, and associations) and
build several items gaining instant access to all CRUD operations.

The easiest way to initialize a source is defining them straight on the scheme:
```ruby
class ApplicationSchema < GraphQL::Schema
  #...
  source User # assuming that we have a User model
  sources Company, Project # faster way to define multiple sources
  source Team do
    #... can be further improved
  end
end
```

Another way to define them is to have a file/class per source, which allows
further changes to the objects created by the sourcing process:
```ruby
# app/graphql/sources/user_source.rb
module GraphQL
  class UserSource < ActiveRecordSource # Or just class UserSource < ARSource
    #... same extensions as from the block method
  end
end
```

## Exposing GraphQL
This gem includes a controller concern that allows any controller to answer to
GraphQL requests. Once a controler includes the
[`GraphQL::Controller`](lib/rails/graphql/railties/controller.rb) concern,
several things are provided, like the ability to customize the context by
overriding the `gql_context` method.

On top of providing the `execute` action, which will execute the
`params[:query]` using the `params[:variables]`, there is another action called
`describe`, which will print a GraphQL description of the scheme being served.
`?without_descriptions` will disable the descriptions, and `?without_spec` will
disable spec default elements.

# How to contribute

To start, simply fork the project.

Run local tests using:
```
$ bundle install
$ bundle exec rake compile
$ bundle exec rake test
```
Finally, fix and send a pull request.

## License

Copyright © 2020- VirtualShield. See [The MIT License](MIT-LICENSE) for further
details.
