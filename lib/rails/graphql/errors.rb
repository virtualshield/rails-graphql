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

    # Error class related to parsing the argumens
    ArgumentsError = Class.new(ParseError)

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

    # Error class related to execution responses that don't require processing
    StaticResponse = Class.new(Interrupt)

    # Error class related to cached responses, which doesn't need processing
    CachedResponse = Class.new(StaticResponse)

    # Error class related to a persisted query that has't been persisted yet
    PersistedQueryNotFound = Class.new(StaticResponse)

    # A simple module and way to extend errors with extra information
    ExtendedError = Module.new do
      delegate_missing_to :@extension

      def self.extend(error, extension)
        error.instance_variable_set(:@extension, extension)
        error.extend(self)
        error
      end
    end
  end
end
