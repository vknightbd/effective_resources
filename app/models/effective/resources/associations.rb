module Effective
  module Resources
    module Associations

      def belong_tos
        @belong_tos ||= klass.reflect_on_all_associations(:belongs_to)
      end

      def nested_resources
        @nested ||= klass.reflect_on_all_autosave_associations.inject({}) do |hash, reference|
          hash[reference] = Effective::Resource.new(reference); hash
        end
      end

      def has_manys
      end

      def scopes
      end

    end
  end
end




