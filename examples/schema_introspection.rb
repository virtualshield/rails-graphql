# This reproduces the same result as
# http://spec.graphql.org/June2018/#sec-Schema-Introspection

[
  GraphQL::Object::SchemaObject,
  GraphQL::Object::TypeObject,
  GraphQL::Object::FieldObject,
  GraphQL::Object::InputValueObject,
  GraphQL::Object::EnumValueObject,
  GraphQL::Enum::TypeKindEnum,
  GraphQL::Object::DirectiveObject,
  GraphQL::Enum::DirectiveLocationEnum,
].each_with_index do |klass, i|
  puts if i > 0
  puts GraphQL.to_gql(klass, with_descriptions: false)
end
