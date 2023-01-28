---
layout: default
title: Exceptions - Handbook
description: An easy to use guide of all the exceptions provided by this gem
---

# Exceptions

Here is the list with the meaning of all exceptions added by this gem.

```
Interrupt
↳ Rails::GraphQL::StaticResponse
  ↳ CachedResponse
  ↳ PersistedQueryNotFound

StandardError
↳ Rails::GraphQL::StandardError
  ↳ DefinitionError
    ↳ ArgumentError
    ↳ NameError
      ↳ DuplicatedError
    ↳ NotFoundError
  ↳ ValidationError
  ↳ ExecutionError
    ↳ FieldError
      ↳ DisabledFieldError
      ↳ InvalidValueError
      ↳ MissingFieldError
      ↳ SubscriptionError
      ↳ UnauthorizedFieldError
    ↳ ParseError
      ↳ ArgumentsError
```
{% include hierarchy-sub.md %}

## ArgumentError

Errors that can happen related to the arguments given to a method.

## ArgumentsError

Error class related to parsing the arguments.

## CachedResponse

Error class related to cached responses, which doesn't need processing.

## DefinitionError

Error class related to problems during the definition process.

## DisabledFieldError

Error class related to when a field was found but is marked as disabled.

## DuplicatedError

Errors related to duplicated objects.

## ExecutionError

Error class related to problems during the execution process.

## FieldError

Error class related to problems that happened during execution of fields.

## InvalidValueError

Error class related to when the captured output value is invalid due to
type checking.

## MissingFieldError

Error class related to when a field was not found on the requested object.

## NameError

Errors related to the name of the objects.

## NotFoundError

Errors that can happen when locking for definition objects, like fields.

## ParseError

Error related to the parsing process.

## PersistedQueryNotFound

Error class related to a persisted query that has't been persisted yet.

## StandardError

Error class tha wraps all the other error classes.

## StaticResponse

Error class related to execution responses that don't require processing.

## SubscriptionError

Error class related to problems that happened while subscribing to a field.

## UnauthorizedFieldError

Error class related to when a field is unauthorized and can not be used,
similar to disabled fields.

## ValidationError

Error class related to validation of a value.
