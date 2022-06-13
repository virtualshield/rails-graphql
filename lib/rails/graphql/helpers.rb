# frozen_string_literal: true

module Rails
  module GraphQL
    # All helpers that allow this gem to be flexible and extendable to any other
    # sources of objects and other gems as well
    module Helpers
      extend ActiveSupport::Autoload

      autoload :AttributeDelegator
      autoload :InheritedCollection
      autoload :Instantiable
      autoload :LeafFromAr
      autoload :Registerable

      autoload :WithArguments
      autoload :WithAssignment
      autoload :WithCallbacks
      autoload :WithDirectives
      autoload :WithDescription
      autoload :WithEvents
      autoload :WithFields
      autoload :WithGlobalID
      autoload :WithName
      autoload :WithNamespace
      autoload :WithOwner
      autoload :WithSchemaFields
      autoload :WithValidator

      # Easy way to duplicate objects and set a new owner
      def self.dup_all_with_owner(enumerator, owner)
        enumerator.map { |item| dup_with_owner(item, owner) }.presence
      end

      # Easy way to duplicate a object and set a new owner
      def self.dup_with_owner(item, owner)
        item.dup.tap { |x| x.instance_variable_set(:@owner, owner) }
      end

      # Global helper that merge a hash that contains values as arrays
      def self.merge_hash_array(one, other)
        one.merge(other) { |_, lval, rval| lval + rval }
      end
    end
  end
end
