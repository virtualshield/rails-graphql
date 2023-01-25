---
layout: default
banner: true
toc: false
image: "/assets/images/logo.png"
---

# The Basics

> `rails-graphql` is a fresh new implementation of a GraphQL server, designed to be
> as close as possible to Rails architecture and interfaces, which implies that it has
> shortcuts, lots of syntax sugar, and direct connection with Rails features like
> <a href="https://guides.rubyonrails.org/active_record_basics.html" target="_blank" rel="external nofollow">ActiveRecord</a>
> and <a href="https://guides.rubyonrails.org/action_cable_overview.html" target="_blank" rel="external nofollow">ActionCable</a>.

This gem has its [own parser](/guides/parser), written from scratch, using
<a href="http://silverhammermba.github.io/emberb/c/" target="_blank" rel="external nofollow">Ruby C API</a>,
which empowers it with an outstanding performance. Plus, all the features
provided were carefully developed so that everyone will feel comfortable and
able to apply in all application sizes and patterns.

## Installation

{% include installation.md %}

## Features

Here is a quick list of all the available features, a short description, and a
link to read more about each one of them:

{% include features.md %}

## Upcoming Features

Here is a quick list of all features that are planned for this version. Some of them may be
release during the beta or after.

Pagination
: A custom implementation of pagination using a directive

Compilation
: Save your GraphQL documents in the cache to improve performance
: Force the application to only accept documents that have been compiled

Rake tasks
: Tasks to clean up cache, list subscriptions, and many others

Generators
: More generators than just the ones for schema and controller that are available right now

Rubocop COPs
: Additional Rubocop cops to guarantee code quality

RSpec integration
: Better integration with RSpec to simply the tests even more

Relay
: All the necessary objects and basic structure plus source support to <a href="https://relay.dev/graphql/connections.htm" target="_blank" rel="external nofollow">Relay<a>

## Collaborate

To start, simply fork the project.

Run local tests using:
```bash
$ bundle install
$ bundle exec rake compile
$ bundle exec rake test
```
Finally, change the code and submit a pull request.

## License

Copyright © 2020-2023 VirtualShield. See
<a href="https://github.com/virtualshield/rails-graphql/blob/master/MIT-LICENSE" target="_blank" rel="external nofollow">
  The MIT License
</a>
for further details.
