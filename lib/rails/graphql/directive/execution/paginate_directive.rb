# frozen_string_literal: true

module Rails
  module GraphQL
    # = GraphQL Execution Paginate Directive
    #
    # A directive that allows any array-based field to be paginated. The paging
    # information will be added to the extensions of the response, unless if
    # it has been explicitly queried.
    class Directive::PaginateDirective < Directive
      MODE_TYPE = Type::Enum::PaginationModeEnum
      CACHE_KEY = Object.new

      PageInfo = Struct.new(:previous, :next, :count, :pages)

      placed_on :field

      desc 'Paginates the result of the field. The field must return an array.'

      argument :limit, :int, null: false, desc: <<~DESC
        The maximum number of items to return.
      DESC

      argument :current, :id, desc: <<~DESC
        The identifier of the current page, according to the mode.
      DESC

      argument :id, desc: <<~DESC
        If provided, then the pagination information will become available to
        a queryable field.
      DESC

      argument :mode, MODE_TYPE, null: false, default: 'PAGES', desc: <<~DESC
        The type if pagination that should be used.
      DESC

      argument :totals, :bool, default: true, desc: <<~DESC
        Indicates of the pagination should calculate the total number of items,
        before paginating.
      DESC

      attr_accessor :calculate_totals

      delegate :previous, :next, :count, :pages, to: :page_info
      delegate :id, :mode, :limit, to: :args

      on(:prepared) do |event|
        event.request.cache(CACHE_KEY)[args.id] = self if args.id

        by_event = event.source.all_listeners.include?(:paginate)
        result = by_event ? trigger_paginate(event) : handle_array(event)
        event.prepared_data = result

        append_extensions(event) unless queried?
      end

      # A helper method to find a pagination by its id
      def self.find(source, id)
        source = source.request unless source.is_a?(Request)
        source.cache(CACHE_KEY)[id]
      end

      # Get the identifier of the current page. Since the argument can be null,
      # we have extra condition here
      def current
        return args.current if args.mode == :keyset

        args.current&.to_i || 0
      end

      # Get the pagination information
      def page_info
        @page_info ||= PageInfo.new
      end

      # Figure out the path using the owner and parent process
      def field_path
        @field_path ||= [@owner.gql_name].tap do |path|
          current = @owner
          until (current = current.parent).is_a?(Request::Component::Operation)
            path << current.try(:gql_name)
          end

          path << current.gql_name if current.stacked_selection?
          path.reverse!
        end
      end

      # Mark that the pagination has been queried and doesn't need to append
      # information to extensions
      def queried!
        @queried = true
      end

      # Check if the pagination has been queried
      def queried?
        defined?(@queried) && @queried
      end

      # Check if count and pages should be calculated
      def totals?
        defined?(@calculate_totals) ? @calculate_totals : args.totals
      end

      # Make sure that the pagination can be properly configured
      def validate!
        super

        setups = @owner.request.cache(CACHE_KEY)
        raise DirectiveError, (+<<~MSG).squish unless @owner.array?
          Field is not an array and can't be paginated.
        MSG

        if args.id
          raise DirectiveError, (+<<~MSG).squish if args.id.blank?
            Pagination id cannot be blank.
          MSG

          raise DirectiveError, (+<<~MSG).squish if setups.key?(args.id)
            Id "#{args.id}" has already been taken by another pagination.
          MSG

          # Add the id to the setups just for validation purposes
          setups[args.id] = nil
        end

        raise DirectiveError, (+<<~MSG).squish if nested?
          A pagination cannot be defined inside the array field "#{other_array.gql_name}".
        MSG
      end

      protected

        # Since the field has a paginate event, then we defer to the proper
        # event handler
        def trigger_paginate(event)
          args_source = args.to_h.merge(current: current, totals: totals?)
          Request::Event.trigger(:paginate, event.source, event.strategy,
            object?: true,
            entries: event.prepared_data,
            args_source: args_source,
            page_info: page_info,
            totals?: args_source[:totals],
          )
        end

        # Here we paginate the entries as a pure array, depending on the mode
        def handle_array(event, data = event.prepared_data.to_a)
          return empty_paging(event) if data.blank?

          assign_totals(data)
          case args.mode.to_sym
          when :pages  then paginate_by_pages(data)
          when :offset then paginate_by_offset(data)
          when :keyset then paginate_by_keyset(data)
          end.presence || EMPTY_ARRAY.tap do
            page_info.previous = page_info.next = nil
          end
        end

        # Just translate page into offset and then redirect
        def paginate_by_pages(data)
          paginate_by_offset(data, args.limit * current).tap do
            page_info.previous &&= current - 1
            page_info.next &&= current + 1
          end
        end

        # Paginate the array by offset
        def paginate_by_offset(data, offset = current)
          page_info.previous = offset - args.limit if offset > 0
          page_info.previous = 0 if page_info.previous&.negative?
          page_info.next = offset + args.limit if offset < data.size - args.limit
          data.slice(offset, args.limit)
        end

        # Paginate the array by keyset, which is nothing more than the hash
        # of the elements (it works with AR, regardless)
        def paginate_by_keyset(data)
          key = current&.to_i
          data = data.drop_while { |item| item.hash != key }.drop(1) if key
          data.take(args.limit).tap do |result|
            page_info.next = result.last.hash.to_s if result.last != data.last
          end
        end

        # Just assign proper totals
        def assign_totals(data)
          page_info.pages = (page_info.count = data.size).fdiv(args.limit).ceil
        end

        # Just assign empty values to the paging information
        def empty_paging(event)
          page_info.pages = page_info.count = 0
          EMPTY_ARRAY
        end

        # This will add the pagination information into the extensions
        def append_extensions(event)
          key = args.id || field_path.join('.')
          entry = (event.extensions['pagination'] ||= {})[key] = {}
          page_info.each_pair { |k, v| entry[k.to_s] = v unless v.nil? }
          entry.freeze
        end

        # Check if the field is nested under another array
        def nested?(field = @owner)
          until (field = field.parent).is_a?(Request::Component::Operation)
            return true if field.try(:array?)
          end
        end

    end
  end
end
