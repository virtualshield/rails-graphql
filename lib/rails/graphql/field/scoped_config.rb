# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    # Helper class to be used while configuring a field using a block. An
    # instance of this class works as proxy for changes to the actual field.
    Field::ScopedConfig = Struct.new(:field, :receiver) do
      delegate :argument, :ref_argument, :id_argument, :use, :internal?, :disabled?,
        :enabled?, :disable!, :enable!, :authorize, to: :field

      delegate_missing_to :receiver

      def method_name(value)
        field.instance_variable_set(:@method_name, value.to_sym)
      end

      def desc(value)
        field.instance_variable_set(:@desc, value.strip_heredoc.chomp)
      end
    end
  end
end
