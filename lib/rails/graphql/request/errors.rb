# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    class Request # :nodoc:
      # = GraphQL Request Errors
      #
      # This class is inspired by +ActiveModel::Erros+. The idea is to hold all
      # the errors that happened during the execution of a request. It also
      # helps to export such information to the result object.
      class Errors
        include Enumerable

        delegate :empty?, :size, :each, :to_json, :last, :first, to: :@items

        def initialize(request)
          @request = request
          @items   = []
        end

        def reset!
          @items = []
        end

        # Return a deep duplicated version of the items
        def to_a
          @items.deep_dup
        end

        # Add +message+ to the list of errors. Any other keywork argument will
        # be used on set on the +:extensions+ part.
        #
        # ==== Options
        #
        # * <tt>:line</tt> - The line associated with the error.
        # * <tt>:col</tt> - The column associated with the error.
        # * <tt>:path</tt> - The path of the field that generated the error.
        def add(message, line: nil, col: nil, path: nil, **extra)
          item = { message: message }

          item[:locations] = [{ line: line.to_i, column: col.to_i }] \
            if line.present? && col.present?

          item[:path] = path if path.present? && path.is_a?(Array)
          item[:extensions] = extra if extra.present?

          @items << item
        end
      end
    end
  end
end