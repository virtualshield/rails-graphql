# frozen_string_literal: true

module Rails # :nodoc:
  module GraphQL # :nodoc:
    module Native # :nodoc:
      class Visitor < FFI::Struct
        CALLBACK_LAYOUT = %i[pointer pointer].freeze

        macros = Pathname.new(__dir__).join('../../../../')
        macros = macros.join('ext/graphqlparser/c/GraphQLAstForEachConcreteType.h')
        MACROS = File.foreach(macros.to_s).map do |line|
          line.match(/MACRO\(\w+, (\w+)\)/).try(:[], 1)
        end.compact.freeze

        macros = MACROS.map do |key|
          [
            [    "visit_#{key}", callback(CALLBACK_LAYOUT, :bool)],
            ["end_visit_#{key}", callback(CALLBACK_LAYOUT, :void)],
          ]
        end.flatten(1).to_h
        layout(macros)

        def testing!
          MACROS.each do |key|
            self[    :"visit_#{key}"] = ->(_, _) { puts "visit_#{key}"; true }
            self[:"end_visit_#{key}"] = ->(_, _) { puts "end_visit_#{key}" }
          end
        end
      end
    end
  end
end
