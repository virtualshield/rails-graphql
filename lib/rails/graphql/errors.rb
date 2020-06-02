# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # Error class related to problems during the definition process
    # It can sometimes happen during the execution process, if the definition
    # of what is being executed is wrong
    DefinitionError = Class.new(::ArgumentError)

    # Errors that can happen related to the arguments given to a method
    ArgumentError = Class.new(DefinitionError)

    # Errors related to the name of the objects
    NameError = Class.new(DefinitionError)
  end
end
