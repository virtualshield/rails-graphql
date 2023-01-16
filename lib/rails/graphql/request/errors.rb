# frozen_string_literal: true

module Rails
  module GraphQL
    class Request
      # = GraphQL Request Errors
      #
      # This class is inspired by +ActiveModel::Errors+. The idea is to hold all
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

        # Add +message+ to the list of errors. Any other keyword argument will
        # be used on set on the +:extensions+ part.
        #
        # ==== Options
        #
        # * <tt>:line</tt> - The line associated with the error.
        # * <tt>:col</tt> - The column associated with the error.
        # * <tt>:path</tt> - The path of the field that generated the error.
        def add(message, line: nil, col: nil, path: nil, **extra)
          item = { 'message' => message }

          item['locations'] = extra.delete(:locations)
          item['locations'] ||= [{ line: line.to_i, column: col.to_i }] \
            if line.present? && col.present?

          item['path'] = path if path.present? && path.is_a?(::Array)
          item['extensions'] = extra.deep_stringify_keys if extra.present?
          item['locations']&.map!(&:stringify_keys)

          @items << item.compact
        end

        # Dump the necessary information from errors to a cached operation
        def cache_dump
          @items.select { |item| item.dig('extensions', 'stage') == 'organize' }
        end

        # Load the necessary information from a cached request data
        def cache_load(data)
          @items += data
        end
      end
    end
  end
end
