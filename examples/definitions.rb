class GraphQL::Point2dInput < GraphQL::Input
  desc 'A geometry point with +x+ and +y+ values'

  field :x, :integer, null: false, desc: 'The +x+ value'
  field :y, :integer, null: false, desc: 'The +y+ value'
end

class GraphQL::NamedInterface < GraphQL::Interface
  desc 'Any entity that has first and last name'

  field :first_name, :string, null: false
  field :last_name, :string, null: false
end

class GraphQL::AgedInterface < GraphQL::Interface
  desc 'Any entity that has an age field'

  field :age, :integer, null: false
end

class GraphQL::UserObject < GraphQL::Object
  desc 'Simple informations about an user'

  implements :named, :aged

  field :first_name, :string, null: false, desc: "The user's first name"
  field :last_name, :string, null: false, desc: "The user's last name"
  field :age, :integer, null: false, desc: "The user's age"
  field :birthdate, :date, null: false, desc: "The user's birthdate"
end

class GraphQL::SampleClass < GraphQL::Object
  desc 'Test for use with symbol'

  field :old_ids, :id, full: true do
    desc 'The old list of ids'

    use :deprecated, reason: 'Use the +newIds+ instead, it is faster'

    argument :odd_only, :bool, default: false
    argument :even_only, :bool, default: false
  end

  field :new_ids, :id, full: true do
    desc 'The new list of ids'

    argument :odd_only, :bool, default: false
    argument :even_only, :bool, default: false
  end
end
