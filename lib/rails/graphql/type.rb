# frozen_string_literal: true

require 'concurrent/map'

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Type
    #
    # This is the most pure object from GraphQL. Anything that a schema can
    # define will be an extension of this class
    # See: http://spec.graphql.org/June2018/#sec-Types
    class Type
      extend ActiveSupport::Autoload
      extend GraphQL::NamedDefinition
      extend Helpers::WithDirectives

      # A direct representation of the spec types
      KINDS = %w[Scalar Object Interface Union Enum Input].freeze
      eager_autoload { KINDS.each { |kind| autoload kind.to_sym } }

      # :singleton-method:
      # A list of ActiveRecord adapters and their specific internal naming used
      # to compound the accessors for direct query serialization
      mattr_accessor :type_alias, instance_accessor: false, default: Concurrent::Map.new

      # :singleton-method:
      # A list of all available input types as symbol => class index
      mattr_accessor :input_types, instance_accessor: false, default: Concurrent::Map.new

      # :singleton-method:
      # A list of all available output types as symbol => class index
      mattr_accessor :output_types, instance_accessor: false, default: Concurrent::Map.new

      # If a type is marked as abstract, it's then used as a base and it won't
      # appear in the introspection
      class_attribute :abstract, instance_writer: false, default: false

      # Marks if the object is one of those defined on the spec, which marks the
      # object as part of the introspection system
      class_attribute :spec_object, instance_writer: false, default: false

      # The given description of the type
      class_attribute :description, instance_writer: false

      class << self
        # Reset some class attributes, meaning that they are not cascade
        def inherited(subclass)
          subclass.spec_object = false
          subclass.abstract = false

          if subclass.superclass.eql?(GraphQL::Type)
            subclass.define_singleton_method(:base_type) { subclass }
            subclass.delegate(:base_type, to: :class)
          end
        end

        # An alias for +description = value+ that can be used as method
        def desc(value)
          self.description = value.squish
        end

        # Find an input type using the given symbol as reference
        #
        # ==== Examples
        #
        #   GraphQL.find_input(:boolean)         # => Rails::GraphQL::Type::Scalar::BooleanScalar
        #   GraphQL.find_input(:integer)         # => Rails::GraphQL::Type::Scalar::IntScalar
        #   GraphQL.find_input(:other)           # => GraphQL::OtherScalar - User defined
        def find_input(thing)
          return thing.input_type? && thing if thing.is_a?(Module) && thing < GraphQL::Type

          type = normalize_type(thing)
          return input_types[type] if input_types.key?(type)

          reload_input_types!
          input_types[type]
        end

        # Similar to find input, but now for output types
        def find_output(thing)
          return thing.output_type? && thing if thing.is_a?(Module) && thing < GraphQL::Type

          type = normalize_type(thing)
          return output_types[type] if output_types.key?(type)

          reload_output_types!
          output_types[type]
        end

        # Fetch the list of all available types
        def all(lazy = false)
          if lazy
            ObjectSpace.each_object(singleton_class).lazy.select do |k|
              k != self && !k.singleton_class? && !k.abstract?
            end
          else
            descendants.reject { |klass| klass.abstract? }
          end
        end

        # Return the specific value for the __TypeKind of this class
        def kind_enum
          kind.to_s.upcase
        end

        # Defines if the current type is a valid input type
        def input_type?
          true
        end

        # Defines if the current type is a valid output type
        def output_type?
          true
        end

        # Defines if the current type is a leaf output type
        def leaf_type?
          false
        end

        # Checks if the current type is an extension of another type
        # TODO: Think in a way to make this work, since the types must have the
        # same name. Maybe add a method +as_extension+ and use the superclass to
        # get the type name
        def extension?
          false
        end

        # Defines a serie of question methods based on the kind
        KINDS.each { |kind| define_method("#{kind.downcase}?") { false } }

        def eager_load! # :nodoc:
          super

          if self.eql?(GraphQL::Type)
            Type::Scalar.eager_load!
            Type::Enum.eager_load!
          end
        end

        private

          def normalize_type(thing)
            thing = thing.to_sym
            thing = type_alias[thing] if type_alias.key?(thing)
            thing
          end

          def reload_input_types!
            eager_load!
            all(true).select do |type|
              type.input_type? && !input_types.value?(type)
            end.each do |type|
              input_types[type.to_sym] = type
            end
          end

          def reload_output_types!
            eager_load!
            all(true).select do |type|
              type.output_type? && !output_types.value?(type)
            end.each do |type|
              output_types[type.to_sym] = type
            end
          end
      end
    end

    Type.type_alias[:integer] = :int
    Type.type_alias[:file] = :binary
  end
end
