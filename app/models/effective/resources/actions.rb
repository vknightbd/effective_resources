# frozen_string_literal: true

module Effective
  module Resources
    module Actions
      EMPTY_HASH = {}
      POST_VERBS = ['POST', 'PUT', 'PATCH']
      CRUD_ACTIONS = %i(index new create show edit update destroy)

      # This was written for the Edit actions fallback templates and Datatables
      # Effective::Resource.new('admin/posts').routes[:index]
      def routes
        @routes ||= (
          matches = [[namespace, plural_name].compact.join('/'), [namespace, name].compact.join('/')]

          routes_engine.routes.routes.select do |route|
            matches.any? { |match| match == route.defaults[:controller] } && !route.name.to_s.end_with?('root')
          end.inject({}) do |h, route|
            h[route.defaults[:action].to_sym] = route; h
          end
        )
      end

      # Effective::Resource.new('effective/order', namespace: :admin)
      def routes_engine
        case class_name
        when 'Effective::Order'
          EffectiveOrders::Engine
        else
          Rails.application
        end
      end

      # Effective::Resource.new('admin/posts').action_path_helper(:edit) => 'edit_admin_posts_path'
      # This will return empty for create, update and destroy
      def action_path_helper(action)
        return unless routes[action]
        return (routes[action].name + '_path') if routes[action].name.present?
      end

      # Effective::Resource.new('admin/posts').action_path(:edit, Post.last) => '/admin/posts/3/edit'
      # Will work for any action. Returns the real path
      def action_path(action, resource = nil, opts = nil)
        opts ||= EMPTY_HASH

        if klass.nil? && resource.present? && initialized_name.kind_of?(ActiveRecord::Reflection::BelongsToReflection)
          return Effective::Resource.new(resource, namespace: namespace).action_path(action, resource, opts)
        end

        return unless routes[action]

        if resource.kind_of?(Hash)
          opts = resource; resource = nil
        end

        # edge case: Effective::Resource.new('admin/comments').action_path(:new, @post)
        if resource && klass && !resource.kind_of?(klass)
          if (bt = belongs_to(resource)).present? && instance.respond_to?("#{bt.name}=")
            return routes[action].format(klass.new(bt.name => resource)).presence
          end
        end

        # This generates the correct route when an object is overriding to_param
        target = (resource || instance)

        if target.respond_to?(:to_param) && target.respond_to?(:id) && (target.to_param != target.id.to_s)
          formattable = routes[action].parts.inject({}) do |h, part|
            if part == :id
              h[part] = target.to_param
            elsif part == :format
              # Nothing
            else
              h[part] = target.public_send(part) if target.respond_to?(part)
            end; h
          end
        end

        # Generate the path
        path = routes[action].format(formattable || EMPTY_HASH).presence

        if path.present? && opts.present?
          uri = URI.parse(path)
          uri.query = URI.encode_www_form(opts)
          path = uri.to_s
        end

        path
      end

      def actions
        @route_actions ||= routes.keys
      end

      def crud_actions
        @crud_actions ||= (actions & CRUD_ACTIONS)
      end

      # GET actions
      def collection_actions
        @collection_actions ||= (
          routes.map { |_, route| route.defaults[:action].to_sym if is_collection_route?(route) }.tap(&:compact!)
        )
      end

      def collection_get_actions
        @collection_get_actions ||= (
          routes.map { |_, route| route.defaults[:action].to_sym if is_collection_route?(route) && is_get_route?(route) }.tap(&:compact!)
        )
      end

      def collection_post_actions
        @collection_post_actions ||= (
          routes.map { |_, route| route.defaults[:action].to_sym if is_collection_route?(route) && is_post_route?(route) }.tap(&:compact!)
        )
      end

      # All actions
      def member_actions
        @member_actions ||= (
          routes.map { |_, route| route.defaults[:action].to_sym if is_member_route?(route) }.tap(&:compact!)
        )
      end

      # GET actions
      def member_get_actions
        @member_get_actions ||= (
          routes.map { |_, route| route.defaults[:action].to_sym if is_member_route?(route) && is_get_route?(route) }.tap(&:compact!)
        )
      end

      def member_delete_actions
        @member_delete_actions ||= (
          routes.map { |_, route| route.defaults[:action].to_sym if is_member_route?(route) && is_delete_route?(route) }.tap(&:compact!)
        )
      end

      # POST/PUT/PATCH actions
      def member_post_actions
        @member_post_actions ||= (
          routes.map { |_, route| route.defaults[:action].to_sym if is_member_route?(route) && is_post_route?(route) }.tap(&:compact!)
        )
      end

      # Same as controller_path in the view
      def controller_path
        [namespace, plural_name].compact * '/'
      end

      private

      def is_member_route?(route)
        (route.path.required_names || []).include?('id')
      end

      def is_collection_route?(route)
        (route.path.required_names || []).include?('id') == false
      end

      def is_get_route?(route)
        route.verb == 'GET'
      end

      def is_delete_route?(route)
        route.verb == 'DELETE'
      end

      def is_post_route?(route)
        POST_VERBS.include?(route.verb)
      end
    end
  end
end
