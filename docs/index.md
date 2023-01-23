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
> **ActiveRecord**{: .text-red-200} and **ActionCable**{: .text-red-200}.

This gem has its **own parser**{: .text-red-200}, written from scratch, using the
**C-API of Ruby**{: .text-red-200}, which empowers it with an outstanding performance.
Plus, all the features provided were carefully developed so that everyone will feel
comfortable and able to apply in all application sizes and patterns.

## Installation

To install rails-graphql you need to add the following to your **Gemfile**:
```ruby
gem 'rails-graphql', '~> 1.0'
```

Also, run:

```bash
$ bundle
```

Or, for non-Gemfile related usage, simply:

```bash
gem install rails-graphql
```
