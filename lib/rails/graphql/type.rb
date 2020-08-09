# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # = GraphQL Type
    #
    # This is the most pure object from GraphQL. Anything that a schema can
    # define will be an extension of this class
    # See: http://spec.graphql.org/June2018/#sec-Types
    class Type
      extend ActiveSupport::Autoload
      extend Helpers::WithDirectives
      extend Helpers::Registerable

      # A direct representation of the spec types
      KINDS = %w[Scalar Object Interface Union Enum Input].freeze
      eager_autoload { KINDS.each { |kind| autoload kind.to_sym } }

      delegate :base_type, :kind, :kind_enum, :input_type?, :output_type?,
        :leaf_type?, :extension?, to: :class

      # A +base_object+ helps to identify what methods are actually available
      # to work as resolvers
      class_attribute :base_object, instance_writer: false, default: false

      self.abstract = true

      class << self
        # Returns the base type of the class. It will be one of the classes
        # defined on +Type::KINDS+
        def base_type
          nil
        end

        # Check if the other type is equivalent
        def =~(other)
          (other.is_a?(Module) ? other : other.class) <= self
        end

        # Return the base type in a symbolized way
        def kind
          base_type.name.demodulize.underscore.to_sym
        end

        # Return the specific value for the __TypeKind of this class
        def kind_enum
          kind.to_s.upcase
        end

        # Defines if the current type is a valid input type
        def input_type?
          false
        end

        # Defines if the current type is a valid output type
        def output_type?
          false
        end

        # Defines if the current type is a leaf output type
        def leaf_type?
          false
        end

        # A little helper to instanteate the type if necessary
        def decorate(value)
          value
        end

        # Checks if a given method can act as resolver
        def gql_resolver?(method_name)
          ref_object = self
          ref_object = ref_object.superclass until ref_object.base_object
          (instance_methods - ref_object.instance_methods).include?(method_name)
        end

        # Defines a series of question methods based on the kind
        KINDS.each { |kind| define_method("#{kind.downcase}?") { false } }

        def eager_load! # :nodoc:
          super

          # Due to inheritance
          if self.eql?(GraphQL::Type)
            Type::Enum.eager_load!
            Type::Input.eager_load!
            Type::Object.eager_load!
            Type::Scalar.eager_load!

            Source.eager_load!
            TypeMap.loaded! :Type
          end
        end

        protected

          # Provide a list of settings to setup the current child class
          def setup!(**options)
            return unless superclass.eql?(GraphQL::Type)

            redefine_singleton_method(:kind) { options[:kind] } if options.key?(:kind)
            self.directive_location = kind

            redefine_singleton_method(:leaf_type?)   { true } if options[:leaf]
            redefine_singleton_method(:input_type?)  { true } if options[:input]
            redefine_singleton_method(:output_type?) { true } if options[:output]
          end

        private

          # Reset some class attributes, meaning that they are not cascade
          def inherited(subclass)
            if subclass.superclass.eql?(GraphQL::Type)
              subclass.redefine_singleton_method(:base_type) { subclass }

              question_method = "#{subclass.name.demodulize.underscore}?"
              subclass.redefine_singleton_method(question_method) { true }

              subclass.spec_object = true
              subclass.base_object = true
              subclass.abstract = true
            else
              subclass.spec_object = false
              subclass.base_object = false
              subclass.abstract = false
            end

            super if defined? super
          end
      end
    end
  end
end
