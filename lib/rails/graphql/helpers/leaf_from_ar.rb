# frozen_string_literal: true

module Rails
  module GraphQL
    module Helpers
      # Helper module allowing leaf values to be collected direct from
      # ActiveRecord. It also helps AR Adapters to define the necessary
      # methods and settings to operate with this extractor.
      #
      # TODO: Implement ActiveRecord serialization
      module LeafFromAr
        def self.extended(other)
          # Defines which type exactly represents the scalar type on the
          # ActiveRecord adapter for casting purposes
          other.class_attribute :ar_adapter_type, instance_writer: false, default: {}

          # A list of ActiveRecord aliases per adapter to skip casting
          other.class_attribute :ar_adapter_aliases, instance_writer: false,
            default: (Hash.new { |h, k| h[k] = Set.new })
        end

        # Identifies the ActiveRecord type (actually it uses the
        # ActiveModel::Type#type method, but ActiveRecord uses the same
        # reference) of this object. When mismatching, the query must cast the
        # value.
        def ar_type
          :string
        end

        # If a class extend this module, we assume that it can serialize
        # attributes direct from the query point of view
        def from_ar?(ar_object, attribute)
          ar_object&.has_attribute?(attribute)
        end

        # Returns an Arel object that represents how this object is serialized
        # direct from the query
        #
        # This happens in 3 parts
        #
        # 1. It finds a method to get the arel representation of the
        #    accessor of the given attribute
        # 2. If the attribute type mismatch the ar type or any of its aliases,
        #    then invoke a adapter-specific cast
        # 3. If necessary, adapters can describe a specific way to serialize
        #    the arel attribute to ensure equivalency
        #
        # ==== Example
        #
        # Lets imagine a scenario where the adapter is the +PostgreSQL+, the
        # attribute is a +data+ field with +enum+ type from a +sample+ table and
        # the result must be a binary base64 data:
        #
        # 1. Sample.arel_attribute(:data)
        #    # => "samples"."data"
        # 2. Arel::Nodes::NamedFunction.new('CAST', [arel_object, Arel.sql('text')])
        #    # => CAST("samples"."data" AS text)
        # 3. Arel::Nodes::NamedFunction.new('ENCODE', [arel_object, Arel.sql("'base64")])
        #    # => ENCODE(CAST("samples"."data" AS text), 'base64')
        def from_ar(ar_object, attribute)
          key = adapter_key(ar_object)
          method_name = "from_#{key}_adapter"
          method_name = 'from_abstract_adapter' unless respond_to?(method_name, true)

          arel_object = send(method_name, ar_object, attribute)
          return if arel_object.nil?

          arel_object = try("cast_#{key}_attribute", arel_object, ar_adapter_type[key]) \
            unless match_ar_type?(ar_object, attribute, key)
          return if arel_object.nil?

          method_name = "#{key}_serialize"
          respond_to?(method_name, true) ? try(method_name, arel_object) : arel_object
        end

        # Helper method that should be used for ActiveRecord adapters in order
        # to provide the correct methods and settings for retrieving the given
        # value direct from a query.
        #
        # ==== Options
        #
        # * <tt>:fetch</tt> - A specific function to build the arel for fetching the attribute
        # * <tt>:cast</tt> - A function to cast an attribute to the correct value
        # * <tt>:type</tt> - A symbol that represents the exactly database type that matches
        #   the ActiveRecord type (ie. :varchar for :string)
        # * <tt>:aliases</tt> - An array of AR aliases that for the adapter they are
        #   equivalent
        def define_for(adapter, **settings)
          adapter = ar_adapters[adapter] if ar_adapters.key?(adapter)
          raise ArgumentError, <<~MSG.squish unless ar_adapters.values.include?(adapter)
            The given #{adapter.inspect} adapter is not a valid option.
            The valid options are: #{ar_adapters.to_a.flatten.map(&:inspect).to_sentence}.
          MSG

          define_singleton_method("from_#{adapter}_adapter", &settings[:fetch]) \
            if settings.key?(:fetch)

          define_singleton_method("cast_#{adapter}_attribute", &settings[:cast]) \
            if settings.key?(:cast)

          ar_adapter_type[adapter] = settings[:type] if settings.key?(:type)
          ar_adapter_aliases[adapter] += Array.wrap(settings[:aliases]) \
            if settings.key?(:aliases)
        end

        protected

          # A pretty abstract way to access an attribute from an ActiveRecord
          # object using arel
          def from_abstract_adapter(ar_object, attribute)
            ar_object.arel_attribute(attribute)
          end

          # Change the ActiveRecord type of the given object
          def set_ar_type!(type)
            redefine_singleton_method(:ar_type) { type }
          end

        private

          # Return the list of defined ActiveRecord Adapters
          def ar_adapters
            GraphQL.config.ar_adapters
          end

          # Given the ActiveRecord Object, find the key to compound the method
          # name for the specific attribute accessor
          def adapter_key(ar_object)
            ar_adapters[ar_object.connection.adapter_name]
          end

          # Check if the GraphQL ar type of this object matches the
          # ActiveRecord type or any alias for the specific adapter
          def match_ar_type?(ar_object, attribute, adapter_key)
            attr_type = ar_object.columns_hash[attribute.to_s].type
            ar_type.eql?(attr_type) || ar_adapter_aliases[adapter_key].include?(attr_type)
          end
      end
    end
  end
end
