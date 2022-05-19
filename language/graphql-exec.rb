# This file was generated from graphql-exec.peg
# See https://canopy.jcoglan.com/ for documentation

module Rails::GraphQL::Parser
  class TreeNode
    include Enumerable
    attr_reader :text, :offset, :elements

    def initialize(text, offset, elements)
      @text = text
      @offset = offset
      @elements = elements
    end

    def each(&block)
      @elements.each(&block)
    end
  end

  class TreeNode1 < TreeNode
    attr_reader :definitions

    def initialize(text, offset, elements)
      super
      @definitions = elements[0]
    end
  end

  class TreeNode2 < TreeNode
    attr_reader :selection

    def initialize(text, offset, elements)
      super
      @selection = elements[4]
    end
  end

  class TreeNode3 < TreeNode
    attr_reader :type, :operation_type

    def initialize(text, offset, elements)
      super
      @type = elements[0]
      @operation_type = elements[0]
    end
  end

  class TreeNode4 < TreeNode
    attr_reader :name

    def initialize(text, offset, elements)
      super
      @name = elements[0]
    end
  end

  class TreeNode5 < TreeNode
    attr_reader :type, :name, :selection

    def initialize(text, offset, elements)
      super
      @type = elements[3]
      @name = elements[3]
      @selection = elements[5]
    end
  end

  class TreeNode6 < TreeNode
    attr_reader :name

    def initialize(text, offset, elements)
      super
      @name = elements[1]
    end
  end

  class TreeNode7 < TreeNode
    attr_reader :items

    def initialize(text, offset, elements)
      super
      @items = elements[0]
    end
  end

  class TreeNode8 < TreeNode
    attr_reader :name

    def initialize(text, offset, elements)
      super
      @name = elements[1]
    end
  end

  class TreeNode9 < TreeNode
    attr_reader :alias, :name

    def initialize(text, offset, elements)
      super
      @alias = elements[0]
      @name = elements[0]
    end
  end

  class TreeNode10 < TreeNode
    attr_reader :name

    def initialize(text, offset, elements)
      super
      @name = elements[1]
    end
  end

  class TreeNode11 < TreeNode
    attr_reader :selection

    def initialize(text, offset, elements)
      super
      @selection = elements[3]
    end
  end

  class TreeNode12 < TreeNode
    attr_reader :type, :name

    def initialize(text, offset, elements)
      super
      @type = elements[2]
      @name = elements[2]
    end
  end

  class TreeNode13 < TreeNode
    attr_reader :name

    def initialize(text, offset, elements)
      super
      @name = elements[1]
    end
  end

  class TreeNode14 < TreeNode
    attr_reader :name

    def initialize(text, offset, elements)
      super
      @name = elements[1]
    end
  end

  class TreeNode15 < TreeNode
    attr_reader :op_parent, :cl_parent

    def initialize(text, offset, elements)
      super
      @op_parent = elements[0]
      @cl_parent = elements[2]
    end
  end

  class TreeNode16 < TreeNode
    attr_reader :op_parent, :cl_parent

    def initialize(text, offset, elements)
      super
      @op_parent = elements[0]
      @cl_parent = elements[2]
    end
  end

  class TreeNode17 < TreeNode
    attr_reader :name, :type, :generic_type

    def initialize(text, offset, elements)
      super
      @name = elements[1]
      @type = elements[2]
      @generic_type = elements[2]
    end
  end

  class TreeNode18 < TreeNode
    attr_reader :eql_sep, :value

    def initialize(text, offset, elements)
      super
      @eql_sep = elements[0]
      @value = elements[1]
    end
  end

  class TreeNode19 < TreeNode
    attr_reader :name

    def initialize(text, offset, elements)
      super
      @name = elements[0]
    end
  end

  class TreeNode20 < TreeNode
    attr_reader :var_name, :name

    def initialize(text, offset, elements)
      super
      @var_name = elements[1]
      @name = elements[1]
    end
  end

  class TreeNode21 < TreeNode
    attr_reader :op_list, :generic_type, :cl_list

    def initialize(text, offset, elements)
      super
      @op_list = elements[0]
      @generic_type = elements[1]
      @cl_list = elements[2]
    end
  end

  class TreeNode22 < TreeNode
    attr_reader :int

    def initialize(text, offset, elements)
      super
      @int = elements[1]
    end
  end

  class TreeNode23 < TreeNode
    attr_reader :int_number

    def initialize(text, offset, elements)
      super
      @int_number = elements[0]
    end
  end

  class TreeNode24 < TreeNode
    attr_reader :items

    def initialize(text, offset, elements)
      super
      @items = elements[0]
    end
  end

  class TreeNode25 < TreeNode
    attr_reader :value

    def initialize(text, offset, elements)
      super
      @value = elements[0]
    end
  end

  class TreeNode26 < TreeNode
    attr_reader :value

    def initialize(text, offset, elements)
      super
      @value = elements[0]
    end
  end

  class TreeNode27 < TreeNode
    attr_reader :items

    def initialize(text, offset, elements)
      super
      @items = elements[0]
    end
  end

  class TreeNode28 < TreeNode
    attr_reader :object_field

    def initialize(text, offset, elements)
      super
      @object_field = elements[0]
    end
  end

  class TreeNode29 < TreeNode
    attr_reader :object_field

    def initialize(text, offset, elements)
      super
      @object_field = elements[0]
    end
  end

  class TreeNode30 < TreeNode
    attr_reader :value

    def initialize(text, offset, elements)
      super
      @value = elements[0]
    end
  end

  class TreeNode31 < TreeNode
    attr_reader :value

    def initialize(text, offset, elements)
      super
      @value = elements[1]
    end
  end

  class TreeNode32 < TreeNode
    attr_reader :code

    def initialize(text, offset, elements)
      super
      @code = elements[1]
    end
  end

  class TreeNode33 < TreeNode
    attr_reader :name, :value

    def initialize(text, offset, elements)
      super
      @name = elements[0]
      @value = elements[1]
    end
  end

  FAILURE = Object.new

  module Grammar
    def _read_document
      address0, index0 = FAILURE, @offset
      cached = @cache[:document][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_ows
      unless address1 == FAILURE
        address2 = FAILURE
        index2, elements1, address3 = @offset, [], nil
        loop do
          address3 = _read_definition
          unless address3 == FAILURE
            elements1 << address3
          else
            break
          end
        end
        if elements1.size >= 1
          address2 = TreeNode.new(@input[index2...@offset], index2, elements1)
          @offset = @offset
        else
          address2 = FAILURE
        end
        unless address2 == FAILURE
          elements0 << address2
          address4 = FAILURE
          address4 = _read_ows
          unless address4 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode1.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:document][index0] = [address0, @offset]
      return address0
    end

    def _read_definition
      address0, index0 = FAILURE, @offset
      cached = @cache[:definition][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1 = @offset
      address0 = _read_operation
      if address0 == FAILURE
        @offset = index1
        address0 = _read_fragment
        if address0 == FAILURE
          @offset = index1
        end
      end
      @cache[:definition][index0] = [address0, @offset]
      return address0
    end

    def _read_operation
      address0, index0 = FAILURE, @offset
      cached = @cache[:operation][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      index2 = @offset
      index3, elements1 = @offset, []
      address2 = FAILURE
      address2 = _read_operation_type
      unless address2 == FAILURE
        elements1 << address2
        address3 = FAILURE
        address3 = _read_rws
        unless address3 == FAILURE
        else
          elements1 = nil
          @offset = index3
        end
      else
        elements1 = nil
        @offset = index3
      end
      if elements1.nil?
        address1 = FAILURE
      else
        address1 = TreeNode3.new(@input[index3...@offset], index3, elements1)
        @offset = @offset
      end
      if address1 == FAILURE
        address1 = TreeNode.new(@input[index2...index2], index2, [])
        @offset = index2
      end
      unless address1 == FAILURE
        elements0 << address1
        address4 = FAILURE
        index4 = @offset
        index5, elements2 = @offset, []
        address5 = FAILURE
        address5 = _read_name
        unless address5 == FAILURE
          elements2 << address5
          address6 = FAILURE
          address6 = _read_rws
          unless address6 == FAILURE
          else
            elements2 = nil
            @offset = index5
          end
        else
          elements2 = nil
          @offset = index5
        end
        if elements2.nil?
          address4 = FAILURE
        else
          address4 = TreeNode4.new(@input[index5...@offset], index5, elements2)
          @offset = @offset
        end
        if address4 == FAILURE
          address4 = TreeNode.new(@input[index4...index4], index4, [])
          @offset = index4
        end
        unless address4 == FAILURE
          elements0 << address4
          address7 = FAILURE
          index6 = @offset
          address7 = _read_variables
          if address7 == FAILURE
            address7 = TreeNode.new(@input[index6...index6], index6, [])
            @offset = index6
          end
          unless address7 == FAILURE
            elements0 << address7
            address8 = FAILURE
            index7 = @offset
            address8 = _read_directives
            if address8 == FAILURE
              address8 = TreeNode.new(@input[index7...index7], index7, [])
              @offset = index7
            end
            unless address8 == FAILURE
              elements0 << address8
              address9 = FAILURE
              address9 = _read_selection
              unless address9 == FAILURE
                elements0 << address9
              else
                elements0 = nil
                @offset = index1
              end
            else
              elements0 = nil
              @offset = index1
            end
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode2.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:operation][index0] = [address0, @offset]
      return address0
    end

    def _read_fragment
      address0, index0 = FAILURE, @offset
      cached = @cache[:fragment][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      chunk0, max0 = nil, @offset + 8
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "fragment"
        address1 = TreeNode.new(@input[@offset...@offset + 8], @offset, [])
        @offset = @offset + 8
      else
        address1 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::fragment", "\"fragment\""]
        end
      end
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        address2 = _read_rws
        unless address2 == FAILURE
          address3 = FAILURE
          index2, elements1 = @offset, []
          address4 = FAILURE
          index3 = @offset
          chunk1, max1 = nil, @offset + 2
          if max1 <= @input_size
            chunk1 = @input[@offset...max1]
          end
          if chunk1 == "on"
            address4 = TreeNode.new(@input[@offset...@offset + 2], @offset, [])
            @offset = @offset + 2
          else
            address4 = FAILURE
            if @offset > @failure
              @failure = @offset
              @expected = []
            end
            if @offset == @failure
              @expected << ["Rails.GraphQL.Parser::fragment", "\"on\""]
            end
          end
          @offset = index3
          if address4 == FAILURE
            address4 = TreeNode.new(@input[@offset...@offset], @offset, [])
            @offset = @offset
          else
            address4 = FAILURE
          end
          unless address4 == FAILURE
            elements1 << address4
            address5 = FAILURE
            address5 = _read_name
            unless address5 == FAILURE
              elements1 << address5
            else
              elements1 = nil
              @offset = index2
            end
          else
            elements1 = nil
            @offset = index2
          end
          if elements1.nil?
            address3 = FAILURE
          else
            address3 = TreeNode6.new(@input[index2...@offset], index2, elements1)
            @offset = @offset
          end
          unless address3 == FAILURE
            elements0 << address3
            address6 = FAILURE
            address6 = _read_rws
            unless address6 == FAILURE
              address7 = FAILURE
              chunk2, max2 = nil, @offset + 2
              if max2 <= @input_size
                chunk2 = @input[@offset...max2]
              end
              if chunk2 == "on"
                address7 = TreeNode.new(@input[@offset...@offset + 2], @offset, [])
                @offset = @offset + 2
              else
                address7 = FAILURE
                if @offset > @failure
                  @failure = @offset
                  @expected = []
                end
                if @offset == @failure
                  @expected << ["Rails.GraphQL.Parser::fragment", "\"on\""]
                end
              end
              unless address7 == FAILURE
                elements0 << address7
                address8 = FAILURE
                address8 = _read_rws
                unless address8 == FAILURE
                  address9 = FAILURE
                  address9 = _read_name
                  unless address9 == FAILURE
                    elements0 << address9
                    address10 = FAILURE
                    index4 = @offset
                    address10 = _read_directives
                    if address10 == FAILURE
                      address10 = TreeNode.new(@input[index4...index4], index4, [])
                      @offset = index4
                    end
                    unless address10 == FAILURE
                      elements0 << address10
                      address11 = FAILURE
                      address11 = _read_rws
                      unless address11 == FAILURE
                        address12 = FAILURE
                        address12 = _read_selection
                        unless address12 == FAILURE
                          elements0 << address12
                        else
                          elements0 = nil
                          @offset = index1
                        end
                      else
                        elements0 = nil
                        @offset = index1
                      end
                    else
                      elements0 = nil
                      @offset = index1
                    end
                  else
                    elements0 = nil
                    @offset = index1
                  end
                else
                  elements0 = nil
                  @offset = index1
                end
              else
                elements0 = nil
                @offset = index1
              end
            else
              elements0 = nil
              @offset = index1
            end
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode5.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:fragment][index0] = [address0, @offset]
      return address0
    end

    def _read_operation_type
      address0, index0 = FAILURE, @offset
      cached = @cache[:operation_type][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1 = @offset
      chunk0, max0 = nil, @offset + 5
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "query"
        address0 = TreeNode.new(@input[@offset...@offset + 5], @offset, [])
        @offset = @offset + 5
      else
        address0 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::operation_type", "\"query\""]
        end
      end
      if address0 == FAILURE
        @offset = index1
        chunk1, max1 = nil, @offset + 8
        if max1 <= @input_size
          chunk1 = @input[@offset...max1]
        end
        if chunk1 == "mutation"
          address0 = TreeNode.new(@input[@offset...@offset + 8], @offset, [])
          @offset = @offset + 8
        else
          address0 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::operation_type", "\"mutation\""]
          end
        end
        if address0 == FAILURE
          @offset = index1
          chunk2, max2 = nil, @offset + 12
          if max2 <= @input_size
            chunk2 = @input[@offset...max2]
          end
          if chunk2 == "subscription"
            address0 = TreeNode.new(@input[@offset...@offset + 12], @offset, [])
            @offset = @offset + 12
          else
            address0 = FAILURE
            if @offset > @failure
              @failure = @offset
              @expected = []
            end
            if @offset == @failure
              @expected << ["Rails.GraphQL.Parser::operation_type", "\"subscription\""]
            end
          end
          if address0 == FAILURE
            @offset = index1
          end
        end
      end
      @cache[:operation_type][index0] = [address0, @offset]
      return address0
    end

    def _read_selection
      address0, index0 = FAILURE, @offset
      cached = @cache[:selection][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_op_object
      unless address1 == FAILURE
        address2 = FAILURE
        index2, elements1, address3 = @offset, [], nil
        loop do
          address3 = _read_selection_item
          unless address3 == FAILURE
            elements1 << address3
          else
            break
          end
        end
        if elements1.size >= 0
          address2 = TreeNode.new(@input[index2...@offset], index2, elements1)
          @offset = @offset
        else
          address2 = FAILURE
        end
        unless address2 == FAILURE
          elements0 << address2
          address4 = FAILURE
          address4 = _read_cl_object
          unless address4 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode7.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:selection][index0] = [address0, @offset]
      return address0
    end

    def _read_selection_item
      address0, index0 = FAILURE, @offset
      cached = @cache[:selection_item][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      index2 = @offset
      address1 = _read_field
      if address1 == FAILURE
        @offset = index2
        address1 = _read_fragment_spread
        if address1 == FAILURE
          @offset = index2
          address1 = _read_inline_fragment
          if address1 == FAILURE
            @offset = index2
          end
        end
      end
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        address2 = _read_field_sep
        unless address2 == FAILURE
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:selection_item][index0] = [address0, @offset]
      return address0
    end

    def _read_field
      address0, index0 = FAILURE, @offset
      cached = @cache[:field][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      index2 = @offset
      index3, elements1 = @offset, []
      address2 = FAILURE
      address2 = _read_name
      unless address2 == FAILURE
        elements1 << address2
        address3 = FAILURE
        address3 = _read_key_sep
        unless address3 == FAILURE
        else
          elements1 = nil
          @offset = index3
        end
      else
        elements1 = nil
        @offset = index3
      end
      if elements1.nil?
        address1 = FAILURE
      else
        address1 = TreeNode9.new(@input[index3...@offset], index3, elements1)
        @offset = @offset
      end
      if address1 == FAILURE
        address1 = TreeNode.new(@input[index2...index2], index2, [])
        @offset = index2
      end
      unless address1 == FAILURE
        elements0 << address1
        address4 = FAILURE
        address4 = _read_name
        unless address4 == FAILURE
          elements0 << address4
          address5 = FAILURE
          index4 = @offset
          address5 = _read_arguments
          if address5 == FAILURE
            address5 = TreeNode.new(@input[index4...index4], index4, [])
            @offset = index4
          end
          unless address5 == FAILURE
            elements0 << address5
            address6 = FAILURE
            index5 = @offset
            address6 = _read_directives
            if address6 == FAILURE
              address6 = TreeNode.new(@input[index5...index5], index5, [])
              @offset = index5
            end
            unless address6 == FAILURE
              elements0 << address6
              address7 = FAILURE
              index6 = @offset
              address7 = _read_selection
              if address7 == FAILURE
                address7 = TreeNode.new(@input[index6...index6], index6, [])
                @offset = index6
              end
              unless address7 == FAILURE
                elements0 << address7
              else
                elements0 = nil
                @offset = index1
              end
            else
              elements0 = nil
              @offset = index1
            end
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode8.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:field][index0] = [address0, @offset]
      return address0
    end

    def _read_fragment_spread
      address0, index0 = FAILURE, @offset
      cached = @cache[:fragment_spread][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      chunk0, max0 = nil, @offset + 3
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "..."
        address1 = TreeNode.new(@input[@offset...@offset + 3], @offset, [])
        @offset = @offset + 3
      else
        address1 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::fragment_spread", "\"...\""]
        end
      end
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        address2 = _read_ows
        unless address2 == FAILURE
          address3 = FAILURE
          address3 = _read_name
          unless address3 == FAILURE
            elements0 << address3
            address4 = FAILURE
            index2 = @offset
            address4 = _read_directives
            if address4 == FAILURE
              address4 = TreeNode.new(@input[index2...index2], index2, [])
              @offset = index2
            end
            unless address4 == FAILURE
              elements0 << address4
            else
              elements0 = nil
              @offset = index1
            end
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode10.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:fragment_spread][index0] = [address0, @offset]
      return address0
    end

    def _read_inline_fragment
      address0, index0 = FAILURE, @offset
      cached = @cache[:inline_fragment][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      chunk0, max0 = nil, @offset + 3
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "..."
        address1 = TreeNode.new(@input[@offset...@offset + 3], @offset, [])
        @offset = @offset + 3
      else
        address1 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::inline_fragment", "\"...\""]
        end
      end
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        address2 = _read_ows
        unless address2 == FAILURE
          address3 = FAILURE
          index2 = @offset
          index3, elements1 = @offset, []
          address4 = FAILURE
          index4, elements2 = @offset, []
          address5 = FAILURE
          index5 = @offset
          chunk1, max1 = nil, @offset + 2
          if max1 <= @input_size
            chunk1 = @input[@offset...max1]
          end
          if chunk1 == "on"
            address5 = TreeNode.new(@input[@offset...@offset + 2], @offset, [])
            @offset = @offset + 2
          else
            address5 = FAILURE
            if @offset > @failure
              @failure = @offset
              @expected = []
            end
            if @offset == @failure
              @expected << ["Rails.GraphQL.Parser::inline_fragment", "\"on\""]
            end
          end
          @offset = index5
          if address5 == FAILURE
            address5 = TreeNode.new(@input[@offset...@offset], @offset, [])
            @offset = @offset
          else
            address5 = FAILURE
          end
          unless address5 == FAILURE
            elements2 << address5
            address6 = FAILURE
            address6 = _read_name
            unless address6 == FAILURE
              elements2 << address6
            else
              elements2 = nil
              @offset = index4
            end
          else
            elements2 = nil
            @offset = index4
          end
          if elements2.nil?
            address4 = FAILURE
          else
            address4 = TreeNode13.new(@input[index4...@offset], index4, elements2)
            @offset = @offset
          end
          unless address4 == FAILURE
            elements1 << address4
            address7 = FAILURE
            address7 = _read_rws
            unless address7 == FAILURE
              address8 = FAILURE
              chunk2, max2 = nil, @offset + 2
              if max2 <= @input_size
                chunk2 = @input[@offset...max2]
              end
              if chunk2 == "on"
                address8 = TreeNode.new(@input[@offset...@offset + 2], @offset, [])
                @offset = @offset + 2
              else
                address8 = FAILURE
                if @offset > @failure
                  @failure = @offset
                  @expected = []
                end
                if @offset == @failure
                  @expected << ["Rails.GraphQL.Parser::inline_fragment", "\"on\""]
                end
              end
              unless address8 == FAILURE
                elements1 << address8
                address9 = FAILURE
                address9 = _read_rws
                unless address9 == FAILURE
                  address10 = FAILURE
                  address10 = _read_name
                  unless address10 == FAILURE
                    elements1 << address10
                  else
                    elements1 = nil
                    @offset = index3
                  end
                else
                  elements1 = nil
                  @offset = index3
                end
              else
                elements1 = nil
                @offset = index3
              end
            else
              elements1 = nil
              @offset = index3
            end
          else
            elements1 = nil
            @offset = index3
          end
          if elements1.nil?
            address3 = FAILURE
          else
            address3 = TreeNode12.new(@input[index3...@offset], index3, elements1)
            @offset = @offset
          end
          if address3 == FAILURE
            address3 = TreeNode.new(@input[index2...index2], index2, [])
            @offset = index2
          end
          unless address3 == FAILURE
            elements0 << address3
            address11 = FAILURE
            index6 = @offset
            address11 = _read_directives
            if address11 == FAILURE
              address11 = TreeNode.new(@input[index6...index6], index6, [])
              @offset = index6
            end
            unless address11 == FAILURE
              elements0 << address11
              address12 = FAILURE
              address12 = _read_selection
              unless address12 == FAILURE
                elements0 << address12
              else
                elements0 = nil
                @offset = index1
              end
            else
              elements0 = nil
              @offset = index1
            end
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode11.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:inline_fragment][index0] = [address0, @offset]
      return address0
    end

    def _read_directives
      address0, index0 = FAILURE, @offset
      cached = @cache[:directives][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_rws
      unless address1 == FAILURE
        address2 = FAILURE
        chunk0, max0 = nil, @offset + 1
        if max0 <= @input_size
          chunk0 = @input[@offset...max0]
        end
        if chunk0 == "@"
          address2 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address2 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::directives", "\"@\""]
          end
        end
        unless address2 == FAILURE
          elements0 << address2
          address3 = FAILURE
          address3 = _read_name
          unless address3 == FAILURE
            elements0 << address3
            address4 = FAILURE
            index2 = @offset
            address4 = _read_arguments
            if address4 == FAILURE
              address4 = TreeNode.new(@input[index2...index2], index2, [])
              @offset = index2
            end
            unless address4 == FAILURE
              elements0 << address4
            else
              elements0 = nil
              @offset = index1
            end
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode14.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:directives][index0] = [address0, @offset]
      return address0
    end

    def _read_variables
      address0, index0 = FAILURE, @offset
      cached = @cache[:variables][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_op_parent
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        index2, elements1, address3 = @offset, [], nil
        loop do
          address3 = _read_variable
          unless address3 == FAILURE
            elements1 << address3
          else
            break
          end
        end
        if elements1.size >= 0
          address2 = TreeNode.new(@input[index2...@offset], index2, elements1)
          @offset = @offset
        else
          address2 = FAILURE
        end
        unless address2 == FAILURE
          elements0 << address2
          address4 = FAILURE
          address4 = _read_cl_parent
          unless address4 == FAILURE
            elements0 << address4
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode15.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:variables][index0] = [address0, @offset]
      return address0
    end

    def _read_arguments
      address0, index0 = FAILURE, @offset
      cached = @cache[:arguments][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_op_parent
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        index2, elements1, address3 = @offset, [], nil
        loop do
          address3 = _read_argument
          unless address3 == FAILURE
            elements1 << address3
          else
            break
          end
        end
        if elements1.size >= 0
          address2 = TreeNode.new(@input[index2...@offset], index2, elements1)
          @offset = @offset
        else
          address2 = FAILURE
        end
        unless address2 == FAILURE
          elements0 << address2
          address4 = FAILURE
          address4 = _read_cl_parent
          unless address4 == FAILURE
            elements0 << address4
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode16.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:arguments][index0] = [address0, @offset]
      return address0
    end

    def _read_variable
      address0, index0 = FAILURE, @offset
      cached = @cache[:variable][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      chunk0, max0 = nil, @offset + 1
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "$"
        address1 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
        @offset = @offset + 1
      else
        address1 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::variable", "\"$\""]
        end
      end
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        address2 = _read_name
        unless address2 == FAILURE
          elements0 << address2
          address3 = FAILURE
          address3 = _read_key_sep
          unless address3 == FAILURE
            address4 = FAILURE
            address4 = _read_generic_type
            unless address4 == FAILURE
              elements0 << address4
              address5 = FAILURE
              index2 = @offset
              index3, elements1 = @offset, []
              address6 = FAILURE
              address6 = _read_eql_sep
              unless address6 == FAILURE
                elements1 << address6
                address7 = FAILURE
                address7 = _read_value
                unless address7 == FAILURE
                  elements1 << address7
                else
                  elements1 = nil
                  @offset = index3
                end
              else
                elements1 = nil
                @offset = index3
              end
              if elements1.nil?
                address5 = FAILURE
              else
                address5 = TreeNode18.new(@input[index3...@offset], index3, elements1)
                @offset = @offset
              end
              if address5 == FAILURE
                address5 = TreeNode.new(@input[index2...index2], index2, [])
                @offset = index2
              end
              unless address5 == FAILURE
                elements0 << address5
                address8 = FAILURE
                index4 = @offset
                address8 = _read_directives
                if address8 == FAILURE
                  address8 = TreeNode.new(@input[index4...index4], index4, [])
                  @offset = index4
                end
                unless address8 == FAILURE
                  elements0 << address8
                else
                  elements0 = nil
                  @offset = index1
                end
              else
                elements0 = nil
                @offset = index1
              end
            else
              elements0 = nil
              @offset = index1
            end
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode17.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:variable][index0] = [address0, @offset]
      return address0
    end

    def _read_argument
      address0, index0 = FAILURE, @offset
      cached = @cache[:argument][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_name
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        address2 = _read_key_sep
        unless address2 == FAILURE
          address3 = FAILURE
          index2 = @offset
          address3 = _read_value
          if address3 == FAILURE
            @offset = index2
            index3, elements1 = @offset, []
            address4 = FAILURE
            chunk0, max0 = nil, @offset + 1
            if max0 <= @input_size
              chunk0 = @input[@offset...max0]
            end
            if chunk0 == "$"
              address4 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
              @offset = @offset + 1
            else
              address4 = FAILURE
              if @offset > @failure
                @failure = @offset
                @expected = []
              end
              if @offset == @failure
                @expected << ["Rails.GraphQL.Parser::argument", "\"$\""]
              end
            end
            unless address4 == FAILURE
              elements1 << address4
              address5 = FAILURE
              address5 = _read_name
              unless address5 == FAILURE
                elements1 << address5
              else
                elements1 = nil
                @offset = index3
              end
            else
              elements1 = nil
              @offset = index3
            end
            if elements1.nil?
              address3 = FAILURE
            else
              address3 = TreeNode20.new(@input[index3...@offset], index3, elements1)
              @offset = @offset
            end
            if address3 == FAILURE
              @offset = index2
            end
          end
          unless address3 == FAILURE
            elements0 << address3
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode19.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:argument][index0] = [address0, @offset]
      return address0
    end

    def _read_generic_type
      address0, index0 = FAILURE, @offset
      cached = @cache[:generic_type][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1 = @offset
      address0 = _read_name
      if address0 == FAILURE
        @offset = index1
        address0 = _read_not_null_type
        if address0 == FAILURE
          @offset = index1
          address0 = _read_list_type
          if address0 == FAILURE
            @offset = index1
          end
        end
      end
      @cache[:generic_type][index0] = [address0, @offset]
      return address0
    end

    def _read_not_null_type
      address0, index0 = FAILURE, @offset
      cached = @cache[:not_null_type][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      index2 = @offset
      address1 = _read_name
      if address1 == FAILURE
        @offset = index2
        address1 = _read_list_type
        if address1 == FAILURE
          @offset = index2
        end
      end
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        chunk0, max0 = nil, @offset + 1
        if max0 <= @input_size
          chunk0 = @input[@offset...max0]
        end
        if chunk0 == "!"
          address2 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address2 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::not_null_type", "\"!\""]
          end
        end
        unless address2 == FAILURE
          elements0 << address2
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:not_null_type][index0] = [address0, @offset]
      return address0
    end

    def _read_list_type
      address0, index0 = FAILURE, @offset
      cached = @cache[:list_type][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_op_list
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        address2 = _read_generic_type
        unless address2 == FAILURE
          elements0 << address2
          address3 = FAILURE
          address3 = _read_cl_list
          unless address3 == FAILURE
            elements0 << address3
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode21.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:list_type][index0] = [address0, @offset]
      return address0
    end

    def _read_ws
      address0, index0 = FAILURE, @offset
      cached = @cache[:ws][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1 = @offset
      chunk0, max0 = nil, @offset + 1
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 =~ /\A[ \t\n\r]/
        address0 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
        @offset = @offset + 1
      else
        address0 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::ws", "[ \\t\\n\\r]"]
        end
      end
      if address0 == FAILURE
        @offset = index1
        address0 = _read_comment
        if address0 == FAILURE
          @offset = index1
        end
      end
      @cache[:ws][index0] = [address0, @offset]
      return address0
    end

    def _read_comment
      address0, index0 = FAILURE, @offset
      cached = @cache[:comment][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      chunk0, max0 = nil, @offset + 1
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "#"
        address1 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
        @offset = @offset + 1
      else
        address1 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::comment", "\"#\""]
        end
      end
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        index2, elements1, address3 = @offset, [], nil
        loop do
          chunk1, max1 = nil, @offset + 1
          if max1 <= @input_size
            chunk1 = @input[@offset...max1]
          end
          if chunk1 =~ /\A[^\n]/
            address3 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
            @offset = @offset + 1
          else
            address3 = FAILURE
            if @offset > @failure
              @failure = @offset
              @expected = []
            end
            if @offset == @failure
              @expected << ["Rails.GraphQL.Parser::comment", "[^\\n]"]
            end
          end
          unless address3 == FAILURE
            elements1 << address3
          else
            break
          end
        end
        if elements1.size >= 0
          address2 = TreeNode.new(@input[index2...@offset], index2, elements1)
          @offset = @offset
        else
          address2 = FAILURE
        end
        unless address2 == FAILURE
          elements0 << address2
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:comment][index0] = [address0, @offset]
      return address0
    end

    def _read_ows
      address0, index0 = FAILURE, @offset
      cached = @cache[:ows][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0, address1 = @offset, [], nil
      loop do
        address1 = _read_ws
        unless address1 == FAILURE
          elements0 << address1
        else
          break
        end
      end
      if elements0.size >= 0
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      else
        address0 = FAILURE
      end
      @cache[:ows][index0] = [address0, @offset]
      return address0
    end

    def _read_rws
      address0, index0 = FAILURE, @offset
      cached = @cache[:rws][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0, address1 = @offset, [], nil
      loop do
        address1 = _read_ws
        unless address1 == FAILURE
          elements0 << address1
        else
          break
        end
      end
      if elements0.size >= 1
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      else
        address0 = FAILURE
      end
      @cache[:rws][index0] = [address0, @offset]
      return address0
    end

    def _read_op_object
      address0, index0 = FAILURE, @offset
      cached = @cache[:op_object][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_ows
      unless address1 == FAILURE
        address2 = FAILURE
        chunk0, max0 = nil, @offset + 1
        if max0 <= @input_size
          chunk0 = @input[@offset...max0]
        end
        if chunk0 == "{"
          address2 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address2 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::op_object", "\"{\""]
          end
        end
        unless address2 == FAILURE
          address3 = FAILURE
          address3 = _read_ows
          unless address3 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:op_object][index0] = [address0, @offset]
      return address0
    end

    def _read_cl_object
      address0, index0 = FAILURE, @offset
      cached = @cache[:cl_object][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_ows
      unless address1 == FAILURE
        address2 = FAILURE
        chunk0, max0 = nil, @offset + 1
        if max0 <= @input_size
          chunk0 = @input[@offset...max0]
        end
        if chunk0 == "}"
          address2 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address2 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::cl_object", "\"}\""]
          end
        end
        unless address2 == FAILURE
          address3 = FAILURE
          address3 = _read_ows
          unless address3 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:cl_object][index0] = [address0, @offset]
      return address0
    end

    def _read_op_parent
      address0, index0 = FAILURE, @offset
      cached = @cache[:op_parent][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_ows
      unless address1 == FAILURE
        address2 = FAILURE
        chunk0, max0 = nil, @offset + 1
        if max0 <= @input_size
          chunk0 = @input[@offset...max0]
        end
        if chunk0 == "("
          address2 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address2 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::op_parent", "\"(\""]
          end
        end
        unless address2 == FAILURE
          address3 = FAILURE
          address3 = _read_ows
          unless address3 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:op_parent][index0] = [address0, @offset]
      return address0
    end

    def _read_cl_parent
      address0, index0 = FAILURE, @offset
      cached = @cache[:cl_parent][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_ows
      unless address1 == FAILURE
        address2 = FAILURE
        chunk0, max0 = nil, @offset + 1
        if max0 <= @input_size
          chunk0 = @input[@offset...max0]
        end
        if chunk0 == ")"
          address2 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address2 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::cl_parent", "\")\""]
          end
        end
        unless address2 == FAILURE
          address3 = FAILURE
          address3 = _read_ows
          unless address3 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:cl_parent][index0] = [address0, @offset]
      return address0
    end

    def _read_op_list
      address0, index0 = FAILURE, @offset
      cached = @cache[:op_list][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_ows
      unless address1 == FAILURE
        address2 = FAILURE
        chunk0, max0 = nil, @offset + 1
        if max0 <= @input_size
          chunk0 = @input[@offset...max0]
        end
        if chunk0 == "["
          address2 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address2 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::op_list", "\"[\""]
          end
        end
        unless address2 == FAILURE
          address3 = FAILURE
          address3 = _read_ows
          unless address3 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:op_list][index0] = [address0, @offset]
      return address0
    end

    def _read_cl_list
      address0, index0 = FAILURE, @offset
      cached = @cache[:cl_list][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_ows
      unless address1 == FAILURE
        address2 = FAILURE
        chunk0, max0 = nil, @offset + 1
        if max0 <= @input_size
          chunk0 = @input[@offset...max0]
        end
        if chunk0 == "]"
          address2 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address2 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::cl_list", "\"]\""]
          end
        end
        unless address2 == FAILURE
          address3 = FAILURE
          address3 = _read_ows
          unless address3 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:cl_list][index0] = [address0, @offset]
      return address0
    end

    def _read_key_sep
      address0, index0 = FAILURE, @offset
      cached = @cache[:key_sep][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_ows
      unless address1 == FAILURE
        address2 = FAILURE
        chunk0, max0 = nil, @offset + 1
        if max0 <= @input_size
          chunk0 = @input[@offset...max0]
        end
        if chunk0 == ":"
          address2 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address2 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::key_sep", "\":\""]
          end
        end
        unless address2 == FAILURE
          address3 = FAILURE
          address3 = _read_ows
          unless address3 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:key_sep][index0] = [address0, @offset]
      return address0
    end

    def _read_eql_sep
      address0, index0 = FAILURE, @offset
      cached = @cache[:eql_sep][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_ows
      unless address1 == FAILURE
        address2 = FAILURE
        chunk0, max0 = nil, @offset + 1
        if max0 <= @input_size
          chunk0 = @input[@offset...max0]
        end
        if chunk0 == "="
          address2 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address2 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::eql_sep", "\"=\""]
          end
        end
        unless address2 == FAILURE
          address3 = FAILURE
          address3 = _read_ows
          unless address3 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:eql_sep][index0] = [address0, @offset]
      return address0
    end

    def _read_item_sep
      address0, index0 = FAILURE, @offset
      cached = @cache[:item_sep][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_ows
      unless address1 == FAILURE
        address2 = FAILURE
        chunk0, max0 = nil, @offset + 1
        if max0 <= @input_size
          chunk0 = @input[@offset...max0]
        end
        if chunk0 == ","
          address2 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address2 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::item_sep", "\",\""]
          end
        end
        unless address2 == FAILURE
          address3 = FAILURE
          address3 = _read_ows
          unless address3 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:item_sep][index0] = [address0, @offset]
      return address0
    end

    def _read_field_sep
      address0, index0 = FAILURE, @offset
      cached = @cache[:field_sep][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_ows
      unless address1 == FAILURE
        address2 = FAILURE
        index2, elements1, address3 = @offset, [], nil
        loop do
          chunk0, max0 = nil, @offset + 1
          if max0 <= @input_size
            chunk0 = @input[@offset...max0]
          end
          if chunk0 == ","
            address3 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
            @offset = @offset + 1
          else
            address3 = FAILURE
            if @offset > @failure
              @failure = @offset
              @expected = []
            end
            if @offset == @failure
              @expected << ["Rails.GraphQL.Parser::field_sep", "\",\""]
            end
          end
          unless address3 == FAILURE
            elements1 << address3
          else
            break
          end
        end
        if elements1.size >= 0
          address2 = TreeNode.new(@input[index2...@offset], index2, elements1)
          @offset = @offset
        else
          address2 = FAILURE
        end
        unless address2 == FAILURE
          address4 = FAILURE
          address4 = _read_ows
          unless address4 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:field_sep][index0] = [address0, @offset]
      return address0
    end

    def _read_name
      address0, index0 = FAILURE, @offset
      cached = @cache[:name][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      chunk0, max0 = nil, @offset + 1
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 =~ /\A[a-zA-Z_]/
        address1 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
        @offset = @offset + 1
      else
        address1 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::name", "[a-zA-Z_]"]
        end
      end
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        index2, elements1, address3 = @offset, [], nil
        loop do
          chunk1, max1 = nil, @offset + 1
          if max1 <= @input_size
            chunk1 = @input[@offset...max1]
          end
          if chunk1 =~ /\A[0-9a-zA-Z_]/
            address3 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
            @offset = @offset + 1
          else
            address3 = FAILURE
            if @offset > @failure
              @failure = @offset
              @expected = []
            end
            if @offset == @failure
              @expected << ["Rails.GraphQL.Parser::name", "[0-9a-zA-Z_]"]
            end
          end
          unless address3 == FAILURE
            elements1 << address3
          else
            break
          end
        end
        if elements1.size >= 0
          address2 = TreeNode.new(@input[index2...@offset], index2, elements1)
          @offset = @offset
        else
          address2 = FAILURE
        end
        unless address2 == FAILURE
          elements0 << address2
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:name][index0] = [address0, @offset]
      return address0
    end

    def _read_value
      address0, index0 = FAILURE, @offset
      cached = @cache[:value][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1 = @offset
      address0 = _read_int_number
      if address0 == FAILURE
        @offset = index1
        address0 = _read_float_number
        if address0 == FAILURE
          @offset = index1
          address0 = _read_string
          if address0 == FAILURE
            @offset = index1
            address0 = _read_boolean
            if address0 == FAILURE
              @offset = index1
              address0 = _read_null
              if address0 == FAILURE
                @offset = index1
                address0 = _read_enum
                if address0 == FAILURE
                  @offset = index1
                  address0 = _read_list_value
                  if address0 == FAILURE
                    @offset = index1
                    address0 = _read_object_value
                    if address0 == FAILURE
                      @offset = index1
                    end
                  end
                end
              end
            end
          end
        end
      end
      @cache[:value][index0] = [address0, @offset]
      return address0
    end

    def _read_int_number
      address0, index0 = FAILURE, @offset
      cached = @cache[:int_number][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      index2 = @offset
      chunk0, max0 = nil, @offset + 1
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "-"
        address1 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
        @offset = @offset + 1
      else
        address1 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::int_number", "\"-\""]
        end
      end
      if address1 == FAILURE
        address1 = TreeNode.new(@input[index2...index2], index2, [])
        @offset = index2
      end
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        address2 = _read_int
        unless address2 == FAILURE
          elements0 << address2
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode22.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:int_number][index0] = [address0, @offset]
      return address0
    end

    def _read_float_number
      address0, index0 = FAILURE, @offset
      cached = @cache[:float_number][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_int_number
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        index2 = @offset
        address2 = _read_fraction
        if address2 == FAILURE
          address2 = TreeNode.new(@input[index2...index2], index2, [])
          @offset = index2
        end
        unless address2 == FAILURE
          elements0 << address2
          address3 = FAILURE
          index3 = @offset
          address3 = _read_exponent
          if address3 == FAILURE
            address3 = TreeNode.new(@input[index3...index3], index3, [])
            @offset = index3
          end
          unless address3 == FAILURE
            elements0 << address3
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode23.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:float_number][index0] = [address0, @offset]
      return address0
    end

    def _read_string
      address0, index0 = FAILURE, @offset
      cached = @cache[:string][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1 = @offset
      address0 = _read_inline_string
      if address0 == FAILURE
        @offset = index1
        address0 = _read_multiline_string
        if address0 == FAILURE
          @offset = index1
        end
      end
      @cache[:string][index0] = [address0, @offset]
      return address0
    end

    def _read_boolean
      address0, index0 = FAILURE, @offset
      cached = @cache[:boolean][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1 = @offset
      chunk0, max0 = nil, @offset + 4
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "true"
        address0 = TreeNode.new(@input[@offset...@offset + 4], @offset, [])
        @offset = @offset + 4
      else
        address0 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::boolean", "\"true\""]
        end
      end
      if address0 == FAILURE
        @offset = index1
        chunk1, max1 = nil, @offset + 5
        if max1 <= @input_size
          chunk1 = @input[@offset...max1]
        end
        if chunk1 == "false"
          address0 = TreeNode.new(@input[@offset...@offset + 5], @offset, [])
          @offset = @offset + 5
        else
          address0 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::boolean", "\"false\""]
          end
        end
        if address0 == FAILURE
          @offset = index1
        end
      end
      @cache[:boolean][index0] = [address0, @offset]
      return address0
    end

    def _read_null
      address0, index0 = FAILURE, @offset
      cached = @cache[:null][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      chunk0, max0 = nil, @offset + 4
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "null"
        address0 = TreeNode.new(@input[@offset...@offset + 4], @offset, [])
        @offset = @offset + 4
      else
        address0 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::null", "\"null\""]
        end
      end
      @cache[:null][index0] = [address0, @offset]
      return address0
    end

    def _read_enum
      address0, index0 = FAILURE, @offset
      cached = @cache[:enum][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      address0 = _read_name
      @cache[:enum][index0] = [address0, @offset]
      return address0
    end

    def _read_list_value
      address0, index0 = FAILURE, @offset
      cached = @cache[:list_value][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_op_list
      unless address1 == FAILURE
        address2 = FAILURE
        index2 = @offset
        index3, elements1 = @offset, []
        address3 = FAILURE
        address3 = _read_value
        unless address3 == FAILURE
          elements1 << address3
          address4 = FAILURE
          index4, elements2, address5 = @offset, [], nil
          loop do
            index5, elements3 = @offset, []
            address6 = FAILURE
            address6 = _read_item_sep
            unless address6 == FAILURE
              address7 = FAILURE
              address7 = _read_value
              unless address7 == FAILURE
                elements3 << address7
              else
                elements3 = nil
                @offset = index5
              end
            else
              elements3 = nil
              @offset = index5
            end
            if elements3.nil?
              address5 = FAILURE
            else
              address5 = TreeNode26.new(@input[index5...@offset], index5, elements3)
              @offset = @offset
            end
            unless address5 == FAILURE
              elements2 << address5
            else
              break
            end
          end
          if elements2.size >= 0
            address4 = TreeNode.new(@input[index4...@offset], index4, elements2)
            @offset = @offset
          else
            address4 = FAILURE
          end
          unless address4 == FAILURE
            elements1 << address4
          else
            elements1 = nil
            @offset = index3
          end
        else
          elements1 = nil
          @offset = index3
        end
        if elements1.nil?
          address2 = FAILURE
        else
          address2 = TreeNode25.new(@input[index3...@offset], index3, elements1)
          @offset = @offset
        end
        if address2 == FAILURE
          address2 = TreeNode.new(@input[index2...index2], index2, [])
          @offset = index2
        end
        unless address2 == FAILURE
          elements0 << address2
          address8 = FAILURE
          address8 = _read_cl_list
          unless address8 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode24.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:list_value][index0] = [address0, @offset]
      return address0
    end

    def _read_object_value
      address0, index0 = FAILURE, @offset
      cached = @cache[:object_value][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_op_object
      unless address1 == FAILURE
        address2 = FAILURE
        index2 = @offset
        index3, elements1 = @offset, []
        address3 = FAILURE
        address3 = _read_object_field
        unless address3 == FAILURE
          elements1 << address3
          address4 = FAILURE
          index4, elements2, address5 = @offset, [], nil
          loop do
            index5, elements3 = @offset, []
            address6 = FAILURE
            address6 = _read_item_sep
            unless address6 == FAILURE
              address7 = FAILURE
              address7 = _read_object_field
              unless address7 == FAILURE
                elements3 << address7
              else
                elements3 = nil
                @offset = index5
              end
            else
              elements3 = nil
              @offset = index5
            end
            if elements3.nil?
              address5 = FAILURE
            else
              address5 = TreeNode29.new(@input[index5...@offset], index5, elements3)
              @offset = @offset
            end
            unless address5 == FAILURE
              elements2 << address5
            else
              break
            end
          end
          if elements2.size >= 0
            address4 = TreeNode.new(@input[index4...@offset], index4, elements2)
            @offset = @offset
          else
            address4 = FAILURE
          end
          unless address4 == FAILURE
            elements1 << address4
          else
            elements1 = nil
            @offset = index3
          end
        else
          elements1 = nil
          @offset = index3
        end
        if elements1.nil?
          address2 = FAILURE
        else
          address2 = TreeNode28.new(@input[index3...@offset], index3, elements1)
          @offset = @offset
        end
        if address2 == FAILURE
          address2 = TreeNode.new(@input[index2...index2], index2, [])
          @offset = index2
        end
        unless address2 == FAILURE
          elements0 << address2
          address8 = FAILURE
          address8 = _read_cl_object
          unless address8 == FAILURE
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode27.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:object_value][index0] = [address0, @offset]
      return address0
    end

    def _read_digit
      address0, index0 = FAILURE, @offset
      cached = @cache[:digit][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      chunk0, max0 = nil, @offset + 1
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 =~ /\A[0-9]/
        address0 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
        @offset = @offset + 1
      else
        address0 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::digit", "[0-9]"]
        end
      end
      @cache[:digit][index0] = [address0, @offset]
      return address0
    end

    def _read_int
      address0, index0 = FAILURE, @offset
      cached = @cache[:int][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1 = @offset
      chunk0, max0 = nil, @offset + 1
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "0"
        address0 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
        @offset = @offset + 1
      else
        address0 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::int", "\"0\""]
        end
      end
      if address0 == FAILURE
        @offset = index1
        index2, elements0 = @offset, []
        address1 = FAILURE
        chunk1, max1 = nil, @offset + 1
        if max1 <= @input_size
          chunk1 = @input[@offset...max1]
        end
        if chunk1 =~ /\A[1-9]/
          address1 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address1 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::int", "[1-9]"]
          end
        end
        unless address1 == FAILURE
          elements0 << address1
          address2 = FAILURE
          index3, elements1, address3 = @offset, [], nil
          loop do
            address3 = _read_digit
            unless address3 == FAILURE
              elements1 << address3
            else
              break
            end
          end
          if elements1.size >= 0
            address2 = TreeNode.new(@input[index3...@offset], index3, elements1)
            @offset = @offset
          else
            address2 = FAILURE
          end
          unless address2 == FAILURE
            elements0 << address2
          else
            elements0 = nil
            @offset = index2
          end
        else
          elements0 = nil
          @offset = index2
        end
        if elements0.nil?
          address0 = FAILURE
        else
          address0 = TreeNode.new(@input[index2...@offset], index2, elements0)
          @offset = @offset
        end
        if address0 == FAILURE
          @offset = index1
        end
      end
      @cache[:int][index0] = [address0, @offset]
      return address0
    end

    def _read_fraction
      address0, index0 = FAILURE, @offset
      cached = @cache[:fraction][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      chunk0, max0 = nil, @offset + 1
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "."
        address1 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
        @offset = @offset + 1
      else
        address1 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::fraction", "\".\""]
        end
      end
      unless address1 == FAILURE
        address2 = FAILURE
        index2, elements1, address3 = @offset, [], nil
        loop do
          address3 = _read_digit
          unless address3 == FAILURE
            elements1 << address3
          else
            break
          end
        end
        if elements1.size >= 1
          address2 = TreeNode.new(@input[index2...@offset], index2, elements1)
          @offset = @offset
        else
          address2 = FAILURE
        end
        unless address2 == FAILURE
          elements0 << address2
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode30.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:fraction][index0] = [address0, @offset]
      return address0
    end

    def _read_exponent
      address0, index0 = FAILURE, @offset
      cached = @cache[:exponent][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      chunk0, max0 = nil, @offset + 1
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 =~ /\A[eE]/
        address1 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
        @offset = @offset + 1
      else
        address1 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::exponent", "[eE]"]
        end
      end
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        index2, elements1 = @offset, []
        address3 = FAILURE
        index3 = @offset
        index4 = @offset
        chunk1, max1 = nil, @offset + 1
        if max1 <= @input_size
          chunk1 = @input[@offset...max1]
        end
        if chunk1 == "+"
          address3 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address3 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::exponent", "\"+\""]
          end
        end
        if address3 == FAILURE
          @offset = index4
          chunk2, max2 = nil, @offset + 1
          if max2 <= @input_size
            chunk2 = @input[@offset...max2]
          end
          if chunk2 == "-"
            address3 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
            @offset = @offset + 1
          else
            address3 = FAILURE
            if @offset > @failure
              @failure = @offset
              @expected = []
            end
            if @offset == @failure
              @expected << ["Rails.GraphQL.Parser::exponent", "\"-\""]
            end
          end
          if address3 == FAILURE
            @offset = index4
          end
        end
        if address3 == FAILURE
          address3 = TreeNode.new(@input[index3...index3], index3, [])
          @offset = index3
        end
        unless address3 == FAILURE
          elements1 << address3
          address4 = FAILURE
          index5, elements2, address5 = @offset, [], nil
          loop do
            address5 = _read_digit
            unless address5 == FAILURE
              elements2 << address5
            else
              break
            end
          end
          if elements2.size >= 1
            address4 = TreeNode.new(@input[index5...@offset], index5, elements2)
            @offset = @offset
          else
            address4 = FAILURE
          end
          unless address4 == FAILURE
            elements1 << address4
          else
            elements1 = nil
            @offset = index2
          end
        else
          elements1 = nil
          @offset = index2
        end
        if elements1.nil?
          address2 = FAILURE
        else
          address2 = TreeNode.new(@input[index2...@offset], index2, elements1)
          @offset = @offset
        end
        unless address2 == FAILURE
          elements0 << address2
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode31.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:exponent][index0] = [address0, @offset]
      return address0
    end

    def _read_char
      address0, index0 = FAILURE, @offset
      cached = @cache[:char][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1 = @offset
      chunk0, max0 = nil, @offset + 1
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 =~ /\A[\u0009\u000A\u000D\u0020-\uFFFF]/
        address0 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
        @offset = @offset + 1
      else
        address0 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::char", "[\\u0009\\u000A\\u000D\\u0020-\\uFFFF]"]
        end
      end
      if address0 == FAILURE
        @offset = index1
        address0 = _read_escaped_char
        if address0 == FAILURE
          @offset = index1
        end
      end
      @cache[:char][index0] = [address0, @offset]
      return address0
    end

    def _read_escaped_char
      address0, index0 = FAILURE, @offset
      cached = @cache[:escaped_char][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      chunk0, max0 = nil, @offset + 1
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "\\"
        address1 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
        @offset = @offset + 1
      else
        address1 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::escaped_char", "\"\\\\\""]
        end
      end
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        index2 = @offset
        chunk1, max1 = nil, @offset + 1
        if max1 <= @input_size
          chunk1 = @input[@offset...max1]
        end
        if chunk1 =~ /\A[\u0056\u002F\u0062\u0066\u006E\u0072\u0074]/
          address2 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
          @offset = @offset + 1
        else
          address2 = FAILURE
          if @offset > @failure
            @failure = @offset
            @expected = []
          end
          if @offset == @failure
            @expected << ["Rails.GraphQL.Parser::escaped_char", "[\\u0056\\u002F\\u0062\\u0066\\u006E\\u0072\\u0074]"]
          end
        end
        if address2 == FAILURE
          @offset = index2
          index3, elements1 = @offset, []
          address3 = FAILURE
          chunk2, max2 = nil, @offset + 1
          if max2 <= @input_size
            chunk2 = @input[@offset...max2]
          end
          if chunk2 == "u"
            address3 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
            @offset = @offset + 1
          else
            address3 = FAILURE
            if @offset > @failure
              @failure = @offset
              @expected = []
            end
            if @offset == @failure
              @expected << ["Rails.GraphQL.Parser::escaped_char", "\"u\""]
            end
          end
          unless address3 == FAILURE
            elements1 << address3
            address4 = FAILURE
            index4, elements2, address5 = @offset, [], nil
            loop do
              chunk3, max3 = nil, @offset + 1
              if max3 <= @input_size
                chunk3 = @input[@offset...max3]
              end
              if chunk3 =~ /\A[0-9a-fA-F]/
                address5 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
                @offset = @offset + 1
              else
                address5 = FAILURE
                if @offset > @failure
                  @failure = @offset
                  @expected = []
                end
                if @offset == @failure
                  @expected << ["Rails.GraphQL.Parser::escaped_char", "[0-9a-fA-F]"]
                end
              end
              unless address5 == FAILURE
                elements2 << address5
              else
                break
              end
            end
            if elements2.size == 4
              address4 = TreeNode.new(@input[index4...@offset], index4, elements2)
              @offset = @offset
            else
              address4 = FAILURE
            end
            unless address4 == FAILURE
              elements1 << address4
            else
              elements1 = nil
              @offset = index3
            end
          else
            elements1 = nil
            @offset = index3
          end
          if elements1.nil?
            address2 = FAILURE
          else
            address2 = TreeNode32.new(@input[index3...@offset], index3, elements1)
            @offset = @offset
          end
          if address2 == FAILURE
            @offset = index2
          end
        end
        unless address2 == FAILURE
          elements0 << address2
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:escaped_char][index0] = [address0, @offset]
      return address0
    end

    def _read_inline_string
      address0, index0 = FAILURE, @offset
      cached = @cache[:inline_string][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      chunk0, max0 = nil, @offset + 1
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "\""
        address1 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
        @offset = @offset + 1
      else
        address1 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::inline_string", "'\"'"]
        end
      end
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        index2, elements1, address3 = @offset, [], nil
        loop do
          address3 = _read_char
          unless address3 == FAILURE
            elements1 << address3
          else
            break
          end
        end
        if elements1.size >= 0
          address2 = TreeNode.new(@input[index2...@offset], index2, elements1)
          @offset = @offset
        else
          address2 = FAILURE
        end
        unless address2 == FAILURE
          elements0 << address2
          address4 = FAILURE
          chunk1, max1 = nil, @offset + 1
          if max1 <= @input_size
            chunk1 = @input[@offset...max1]
          end
          if chunk1 == "\""
            address4 = TreeNode.new(@input[@offset...@offset + 1], @offset, [])
            @offset = @offset + 1
          else
            address4 = FAILURE
            if @offset > @failure
              @failure = @offset
              @expected = []
            end
            if @offset == @failure
              @expected << ["Rails.GraphQL.Parser::inline_string", "'\"'"]
            end
          end
          unless address4 == FAILURE
            elements0 << address4
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:inline_string][index0] = [address0, @offset]
      return address0
    end

    def _read_multiline_string
      address0, index0 = FAILURE, @offset
      cached = @cache[:multiline_string][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      chunk0, max0 = nil, @offset + 3
      if max0 <= @input_size
        chunk0 = @input[@offset...max0]
      end
      if chunk0 == "\"\"\""
        address1 = TreeNode.new(@input[@offset...@offset + 3], @offset, [])
        @offset = @offset + 3
      else
        address1 = FAILURE
        if @offset > @failure
          @failure = @offset
          @expected = []
        end
        if @offset == @failure
          @expected << ["Rails.GraphQL.Parser::multiline_string", "'\"\"\"'"]
        end
      end
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        index2, elements1, address3 = @offset, [], nil
        loop do
          address3 = _read_char
          unless address3 == FAILURE
            elements1 << address3
          else
            break
          end
        end
        if elements1.size >= 0
          address2 = TreeNode.new(@input[index2...@offset], index2, elements1)
          @offset = @offset
        else
          address2 = FAILURE
        end
        unless address2 == FAILURE
          elements0 << address2
          address4 = FAILURE
          chunk1, max1 = nil, @offset + 3
          if max1 <= @input_size
            chunk1 = @input[@offset...max1]
          end
          if chunk1 == "\"\"\""
            address4 = TreeNode.new(@input[@offset...@offset + 3], @offset, [])
            @offset = @offset + 3
          else
            address4 = FAILURE
            if @offset > @failure
              @failure = @offset
              @expected = []
            end
            if @offset == @failure
              @expected << ["Rails.GraphQL.Parser::multiline_string", "'\"\"\"'"]
            end
          end
          unless address4 == FAILURE
            elements0 << address4
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:multiline_string][index0] = [address0, @offset]
      return address0
    end

    def _read_object_field
      address0, index0 = FAILURE, @offset
      cached = @cache[:object_field][index0]
      if cached
        @offset = cached[1]
        return cached[0]
      end
      index1, elements0 = @offset, []
      address1 = FAILURE
      address1 = _read_name
      unless address1 == FAILURE
        elements0 << address1
        address2 = FAILURE
        address2 = _read_key_sep
        unless address2 == FAILURE
          address3 = FAILURE
          address3 = _read_value
          unless address3 == FAILURE
            elements0 << address3
          else
            elements0 = nil
            @offset = index1
          end
        else
          elements0 = nil
          @offset = index1
        end
      else
        elements0 = nil
        @offset = index1
      end
      if elements0.nil?
        address0 = FAILURE
      else
        address0 = TreeNode33.new(@input[index1...@offset], index1, elements0)
        @offset = @offset
      end
      @cache[:object_field][index0] = [address0, @offset]
      return address0
    end
  end

  class Parser
    include Grammar

    def initialize(input, actions, types)
      @input = input
      @input_size = input.size
      @actions = actions
      @types = types
      @offset = 0
      @cache = Hash.new { |h,k| h[k] = {} }
      @failure = 0
      @expected = []
    end

    def parse
      tree = _read_document
      if tree != FAILURE and @offset == @input_size
        return tree
      end
      if @expected.empty?
        @failure = @offset
        @expected << ["Rails.GraphQL.Parser", "<EOF>"]
      end
      raise ParseError, Parser.format_error(@input, @failure, @expected)
    end

    def self.format_error(input, offset, expected)
      lines = input.split(/\n/)
      line_no, position = 0, 0

      while position <= offset
        position += lines[line_no].size + 1
        line_no += 1
      end

      line = lines[line_no - 1]
      message = "Line #{line_no}: expected one of:\n\n"

      expected.each do |rule, term|
        message += "    - #{term} from #{rule}\n"
      end

      number = line_no.to_s
      number = " " + number until number.size == 6

      message += "\n#{number} | #{line}\n"
      message += " " * (line.size + 10 + offset - position)
      return message + "^"
    end
  end

  ParseError = Class.new(StandardError)

  def self.parse(input, options = {})
    parser = Parser.new(input, options[:actions], options[:types])
    parser.parse
  end
end
