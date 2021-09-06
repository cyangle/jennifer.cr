require "./scoping"
require "./translation"
require "./relation_definition"
require "../macros"

module Jennifer
  module Model
    # Base abstract class for a database entity.
    abstract class Resource
      module AbstractClassMethods
        abstract def build(values : Hash | NamedTuple, new_record : Bool)
        abstract def build

        # Returns relation instance by given name.
        abstract def relation(name)

        # Returns table column counts grepped from the database.
        abstract def actual_table_field_count

        # Returns primary field name.
        abstract def primary_field_name

        # Returns `Jennifer::QueryBuilder::ModelQuery(T)`.
        #
        # This method is an entry point for writing query to your resource.
        #
        # ```
        # Address.all
        #   .where { _street.like("%St. Paul%") }
        #   .union(
        #     Profile.all
        #       .where { _login.in(["login1", "login2"]) }
        #       .select(:contact_id)
        #   )
        #   .select(:contact_id)
        #   .results
        # ```
        abstract def all

        # Returns superclass for the current class.
        #
        # ```
        # class A < Jennifer::Model::Base
        #   # ...
        # end
        #
        # class B < A
        # end
        #
        # B.superclass # => A
        # ```
        abstract def superclass

        # Returns criterion for the resource primary field.
        #
        # Is generated by `.mapping` macro.
        #
        # ```
        # User.primary.inspect # => #<Jennifer::QueryBuilder::Criteria:0x0 @field="id", @table="users">
        # ```
        abstract def primary

        # Returns field count.
        #
        # Is generated by `.mapping` macro.
        abstract def field_count

        # Returns array of field names
        #
        # Is generated by `.mapping` macro.
        abstract def field_names : Array(String)

        # Returns all non virtual field names
        #
        # Is generated by `.mapping` macro.
        abstract def column_names : Array(String)

        # Returns named tuple of column metadata
        #
        # Is generated by `.mapping` macro.
        abstract def columns_tuple

        # Accepts symbol hash or named tuple, stringifies it and calls constructor with string-based keys hash.
        #
        # It calls `after_initialize` callbacks.
        #
        # ```
        # User.new({:name => "John Smith"})
        # User.new({name: "John Smith"})
        # ```
        abstract def new(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)

        # Creates object based on given string hash.
        #
        # It calls `after_initialize` callbacks.
        #
        # ```
        # User.new({"name" => "John Smith"})
        # ```
        abstract def new(values : Hash(String, ::Jennifer::DBAny))

        # Returns table prefix.
        #
        # If `nil` (default) is returned - adds nothing.
        abstract def table_prefix
      end

      extend AbstractClassMethods
      include Translation
      include Scoping
      include RelationDefinition
      include Macros

      # :nodoc:
      def self.superclass; end

      # :nodoc:
      def self.table_prefix
        Inflector.underscore(to_s).split('/')[0...-1].join("_") + "_" if to_s.includes?(':')
      end

      @@expression_builder : QueryBuilder::ExpressionBuilder?
      @@actual_table_field_count : Int32?
      @@has_table : Bool?
      @@table_name : String?

      # Returns a string containing a human-readable representation of object.
      #
      # ```
      # Address.new.inspect
      # # => "#<Address:0x7f532bdd5340 id: nil, street: "Ant st. 69", contact_id: nil, created_at: nil, updated_at: nil>"
      # ```
      def inspect(io) : Nil
        io << "#<" << {{@type.name.id.stringify}} << ":0x"
        object_id.to_s(io, 16)
        io << ' '
        inspect_attributes(io)
        io << '>'
        nil
      end

      # Returns a JSON string representing the resource.
      #
      # Without any argument or block passed in all resource columns are serialized.
      #
      # ```
      # user.to_json
      # # => {"id": 1,"name": "John Smith", "age": 42,"admin":false}
      # ```
      #
      # The `only` argument allows to specify the exact collection of fields to be serialized:
      #
      # ```
      # user.to_json(only: %w[id name])
      # # => {"id": 1,"name": "John Smith"}
      # ```
      #
      # The `except` argument allows to specify which field should not be serialized:
      #
      # ```
      # user.to_json(except: %w[id name])
      # # => {"age": 42,"admin":false}
      # ```
      #
      # Only one argument `only` or `except` can be specified at a time.
      #
      # Also the block can be specified to serialize extra fields. As arguments block receives json builder
      # and resource itself
      #
      # ```
      # user.to_json do |json|
      #   json.field "first_name", user.name.split(" ")[0]
      # end
      # # => {"id": 1,"name": "John Smith", "age": 42,"admin":false, "first_name": "John"}
      # ```
      def to_json(only : Array(String)? = nil, except : Array(String)? = nil)
        JSON.build do |json|
          to_json(json, only, except) { }
        end
      end

      def to_json(only : Array(String)? = nil, except : Array(String)? = nil, &block)
        JSON.build do |json|
          to_json(json, only, except) { yield json, self }
        end
      end

      def to_json(json : JSON::Builder)
        to_json(json) { }
      end

      def to_json(json : JSON::Builder, only : Array(String)? = nil, except : Array(String)? = nil, &block)
        json.object do
          field_names =
            if only
              only
            elsif except
              self.class.column_names - except
            else
              self.class.column_names
            end
          field_names.each do |name|
            json.field name, attribute(name)
          end
          yield json, self
        end
      end

      private def inspect_attributes(io) : Nil
        self.class.field_names.each_with_index do |name, index|
          io << ", " if index > 0
          io << name << ": "
          attribute(name).inspect(io)
        end
        nil
      end

      # Alias for `.new`.
      def self.build(values : Hash(Symbol, ::Jennifer::DBAny) | NamedTuple)
        new(values)
      end

      # :ditto:
      def self.build(values : Hash(String, ::Jennifer::DBAny))
        new(values)
      end

      # :ditto:
      def self.build(**values)
        new(values)
      end

      # Sets custom table name.
      #
      # Specified table name should include table name prefix as it is used "as is".
      def self.table_name(value : String | Symbol)
        @@table_name = value.to_s
        @@actual_table_field_count = nil
        @@has_table = nil
      end

      # Returns resource's table name.
      #
      # ```
      # User.table_name        # "users"
      # Admin::User.table_name # "admin_users"
      #
      # class Admin::Post < Jennifer::Model::Base
      #   # ...
      #
      #   def self.table_prefix; end
      # end
      #
      # Admin::Post.table_name # "posts"
      # ```
      def self.table_name : String
        @@table_name ||=
          begin
            name = ""
            class_name = Inflector.demodulize(to_s)
            prefix = table_prefix
            name = prefix.to_s if prefix
            Inflector.pluralize(name + class_name.underscore)
          end
      end

      # Returns adapter instance.
      def self.adapter
        Adapter.default_adapter
      end

      # Returns adapter used to write resource to the database.
      def self.write_adapter
        adapter
      end

      # Returns adapter used to read resource from the database.
      def self.read_adapter
        adapter
      end

      # Returns `QueryBuilder::ExpressionBuilder` object of this resource's table.
      #
      # ```
      # User.context.sql("ABS(1.2)")
      # ```
      def self.context
        @@expression_builder ||= QueryBuilder::ExpressionBuilder.new(table_name)
      end

      # Implementation of `AbstractClassMethods.all`.
      #
      # ```
      # User.all.where { _name == "John" }
      # ```
      def self.all
        {% begin %}
          QueryBuilder::ModelQuery({{@type}}).build(table_name, adapter)
        {% end %}
      end

      # Is a shortcut for `.all.where` call.
      #
      # ```
      # User.where { _name == "John" }
      # ```
      def self.where(&block)
        ac = all
        tree = with ac.expression_builder yield ac.expression_builder
        ac.set_tree(tree)
        ac
      end

      # :ditto:
      def self.where(conditions : Hash(Symbol, _))
        all.where(conditions)
      end

      # Starts database transaction.
      #
      # For more details see `Jennifer::Adapter::Transactions`.
      #
      # ```
      # User.transaction do
      #   Post.create
      # end
      # ```
      def self.transaction
        write_adapter.transaction do |t|
          yield(t)
        end
      end

      # Returns criterion for column *name* of resource's table.
      #
      # ```
      # User.c(:email) # => users.email
      # ```
      def self.c(name : String | Symbol)
        context.c(name.to_s)
      end

      def self.c(name : String | Symbol, relation)
        QueryBuilder::Criteria.new(name.to_s, table_name, relation)
      end

      # Returns star field statement for current resource's table.
      #
      # ```
      # User.star # => users.*
      # ```
      def self.star
        context.star
      end

      def self.relation(name)
        raise UnknownRelation.new(self, name)
      end

      def append_relation(name : String, hash)
        raise Jennifer::UnknownRelation.new(self.class, name)
      end

      def set_inverse_of(name : String, object)
        raise Jennifer::UnknownRelation.new(self.class, name)
      end

      def get_relation(name : String)
        raise Jennifer::UnknownRelation.new(self.class, name)
      end

      # Returns value of attribute *name*.
      #
      # It method doesn't invoke getter. If no attribute with given name is found - `BaseException`
      # is raised. To prevent this and return `nil` instead - pass `false` for *raise_exception*.
      #
      # ```
      # contact.attribute(:name)          # => Jennifer::DBAny
      # contact.attribute("age")          # => Jennifer::DBAny
      # contact.attribute(:salary)        # => Jennifer::BaseException is raised
      # contact.attribute(:salary, false) # => nil
      # ```
      abstract def attribute(name : String | Symbol, raise_exception : Bool = true)

      # Returns value of primary field
      #
      # Is generated by `.mapping` macro.
      abstract def primary

      # Returns hash with model attributes; keys are symbols.
      #
      # Is generated by `.mapping` macro.
      #
      # ```
      # contact.to_h # => { name: "Jennifer", age: 2 }
      # ```
      abstract def to_h

      # Returns hash with model attributes; keys are strings.
      #
      # Is generated by `.mapping` macro.
      #
      # ```
      # contact.to_h # => { "name" => "Jennifer", "age" => 2 }
      # ```
      abstract def to_str_h
    end
  end
end
