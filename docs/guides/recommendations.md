---
layout: default
title: Recommendations - Guides
description: All the recommendations for making best of this gem
---

# Recommendations

Here you will find all the recommendations for making best of this gem.

{: .important }
> **Important**
> In the future, items from this list may become
> <a href="https://rubocop.org/" target="_blank" rel="external nofollow">RuboCop</a>
> cops.<br/>
> This section is under construction.

## General

1. **Never reference a type by their class!**{: .fw-900 }
1. Always provide a type for fields and arguments, even if it will be resolved properly to `:id` or `:string`;
1. Use symbol names for scalars and string gql names for anything else;
1. Do not set arguments using the `arguments` named argument. Open a block and set them up inside of it instead;
1. Do not define fields on the schema. Use [alternatives](/guides/alternatives) instead;
1. Provide description for everything, either directly or using [`I18n`](/guides/i18n);
1. Do not use fields [chaining definition](/guides/fields#chaining-definition);
1. Avoid using [inline types](/guides/advanced/types#inline-creation), except for unions and enums;

## Types

1. If a type requires nested fields to be fully qualified, then don't create a scalar;
1. Always assign a type to a class by its name, not its constant value;
1. Register all database aliases on the [Type Map](/guides/type-map#aliases) to avoid warnings;

## Request

1. **Never load data during the resolve stage!**{: .fw-900 }
1. Use the `prepare` event stage of requests to load data;

## Callbacks

1. Prefer using `current.something` or `current_value.something` than just calling `something`. You may get some unexpected results.
