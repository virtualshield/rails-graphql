# frozen_string_literal: true

module Rails
  module GraphQL
    class Type
      # = GraphQL Type Creator
      #
      # This class helps to dynamically create types using a large set of
      # settings that are provided through the named arguments. There are
      # setting that are general to all types, and some are specific per base
      # type of the superclass
      class Creator
        NESTED_MODULE = :NestedTypes
        SUPPORTED_KINDS = %i[scalar object interface union enum input_object source].freeze

        attr_reader :name, :superclass, :klass, :settings

        delegate :type_map, to: '::Rails::GraphQL'
        delegate :kind, to: :superclass

        # Simply instantiate the creator and run the process
        def self.create!(*args, **xargs, &block)
          new(*args, **xargs).create!(&block)
        end

        def initialize(from, name_or_object, superclass, **settings)
          @from = from
          @settings = settings
          @object = name_or_object if name_or_object.is_a?(Class)

          @superclass = sanitize_superclass(superclass)
          @name = sanitize_name(name_or_object)
        end

        # Go over the create process
        def create!(&block)
          @klass = find_or_create_class
          klass.instance_variable_set(:@gql_name, gql_name)

          apply_general_settings
          after_block = apply_specific_settings

          klass.module_exec(&block) if block.present?
          after_block.call if after_block.is_a?(Proc)
          klass
        end

        protected

          # Use the type map to look for a type from the same namespace
          def find_type!(value)
            type_map.fetch!(value, namespaces: namespaces, base_class: :Type)
          end

          # Same as above, but mapping the list
          def find_all_types!(*list)
            list.map { |item| item.is_a?(Class) ? item : find_type!(item) }
          end

          # Apply settings that is common for any possible type created
          def apply_general_settings
            klass.abstract = settings[:abstract] if settings.key?(:abstract)
            klass.set_namespace(*namespaces)

            klass.use(*settings[:directives]) if settings.key?(:directives) &&
              klass.is_a?(Helpers::WithDirectives)

            if klass.is_a?(Helpers::WithAssignment)
              assignment = settings.fetch(:assigned_to, @object)
              klass.assigned_to = assignment unless assignment.nil?
            end

            if settings.key?(:owner)
              klass.include(Helpers::WithOwner) unless klass.is_a?(Helpers::WithOwner)
              klass.owner = settings[:owner] == true ? @from : settings[:owner]
            end
          end

          # Using the kind, call of a specific method to further configure the
          # created class
          def apply_specific_settings
            method_name = +"apply_#{kind}_settings"
            send(method_name) if respond_to?(method_name, true)
          end

          # Specific settings when creating an enum
          def apply_enum_settings
            klass.indexed! if settings[:indexed]
            return if (values = settings[:values]).nil?
            GraphQL.enumerate(values).each(&klass.method(:add))
          end

          # Specific settings when creating an union
          def apply_union_settings
            types = settings[:of_types]
            klass.append(*find_all_types!(*types)) unless types.nil?
          end

          # Specific settings when creating a source
          def apply_source_settings
            build = settings[:build]

            -> do
              return klass.build_all if build == true
              GraphQL.enumerate(build).each do |step|
                klass.public_send(+"build_#{step}")
              end
            end if build
          end

        private

          # Either get the gql name from settings or properly resolve one from
          # the name
          def gql_name
            settings[:gql_name].presence || begin
              gql_name = name.dup
              gql_name = gql_name.chomp(name_suffix) unless kind == :input_object
              gql_name.tr('_', '')
            end
          end

          # Add the nested module to the source of the creating and create the
          # class. If any of those exist, return the constant instead
          def find_or_create_class
            base = base_module

            # Create the class under the nested module
            return base.const_set(name, Class.new(superclass)) \
              unless base.const_defined?(name)

            # Get the existing class and check for the once setting
            klass = base.const_get(name)
            return klass unless !once? && klass < superclass

            # Created once or not from the same superclass
            raise DuplicatedError, (+<<~MSG).squish
              A type named "#{name}" already exists for the "#{base.name}" module.
            MSG
          end

          # Make sure to properly get the superclass
          def sanitize_superclass(value)
            value = Type.const_get(value.to_s.classify) unless value.is_a?(Class)

            valid_class = value.is_a?(Class) && value.respond_to?(:kind)
            valid_class &= SUPPORTED_KINDS.include?(value.kind)
            return value if valid_class

            raise ::ArgumentError, +"The \"#{value.inspect}\" is not a valid superclass."
          rescue ::NameError
            raise ::ArgumentError, +"Unable to find a \"#{value}\" superclass."
          end

          # Let's clean up the name
          def sanitize_name(name_or_object)
            name = name_or_object.is_a?(Module) ? name_or_object.name : name_or_object.to_s
            name = name.classify.gsub(/::/, '_')
            name.end_with?(name_suffix) ? name : name + name_suffix
          end

          # Figure out the suffix that is supposed to be used for the name
          def name_suffix
            @name_suffix ||= @settings[:suffix] || begin
              if kind == :input_object
                GraphQL.config.auto_suffix_input_objects
              else
                superclass.kind.to_s.classify
              end
            end
          end

          # Get or set the base module using the from argument
          def base_module
            base = @from.is_a?(Module) ? @from : @from.class
            if base.const_defined?(NESTED_MODULE, false)
              base.const_get(NESTED_MODULE)
            else
              base.const_set(NESTED_MODULE, Module.new)
            end
          end

          # Get the namespaces from the settings or from the source
          def namespaces
            @namespaces ||= settings[:namespace] || settings[:namespaces] || @from.namespace
          end

          # Check if the type should be create only once, meaning that returning
          # an existing one is not an option
          def once?
            settings.fetch(:once, true)
          end
      end
    end
  end
end
