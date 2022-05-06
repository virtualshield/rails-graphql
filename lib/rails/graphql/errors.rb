# frozen_string_literal: true

module Rails
  module GraphQL
    # Error class tha wrappes all the other error classes
    StandardError = Class.new(::StandardError)

    # Error class related to problems during the definition process
    DefinitionError = Class.new(StandardError)

    # Error class related to validation of a value
    ValidationError = Class.new(StandardError)

    # Errors that can happen related to the arguments given to a method
    ArgumentError = Class.new(DefinitionError)

    # Errors that can happen when locking for definition objects, like fields
    NotFoundError = Class.new(DefinitionError)

    # Errors related to the name of the objects
    NameError = Class.new(DefinitionError)

    # Errors related to duplciated objects
    DuplicatedError = Class.new(NameError)

    # Error class related to problems during the execution process
    ExecutionError = Class.new(StandardError)

    # Error related to the parsing process
    ParseError = Class.new(ExecutionError)

    # Error class related to problems that happened during execution of fields
    FieldError = Class.new(ExecutionError)

    # Error class related to when a field was not found on the requested object
    MissingFieldError = Class.new(FieldError)

    # Error class related to when a field was found but is marked as disabled
    DisabledFieldError = Class.new(FieldError)

    # Error class related to when the captured output value is invalid due to
    # type checking
    InvalidValueError = Class.new(FieldError)

    # Error class related to when a field is unauthorized and can not be used,
    # similar to disabled fields
    UnauthorizedFieldError = Class.new(FieldError)
  end
end
