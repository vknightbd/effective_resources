module EffectiveResourcesPrivateHelper

  def permitted_resource_actions(resource, actions, effective_resource = nil)
    effective_resource ||= (controller.respond_to?(:effective_resource) ? controller.effective_resource : Effective::Resource.new(controller_path))

    actions.select do |commit, args|
      action = (args[:action] == :save ? (resource.new_record? ? :create : :update) : args[:action])

      (args.key?(:if) ? resource.instance_exec(&args[:if]) : true) &&
      (args.key?(:unless) ? !resource.instance_exec(&args[:unless]) : true) &&
      EffectiveResources.authorized?(controller, action, resource)
    end.transform_values.with_index do |opts, index|
      action = opts[:action]

      # Transform data: { ... } hash into 'data-' keys
      data.each { |k, v| opts["data-#{k}"] ||= v } if (data = opts.delete(:data))

      # Assign data method and confirm
      if effective_resource.member_post_actions.include?(action)
        opts['data-method'] ||= :post
        opts['data-confirm'] ||= "Really #{action} %resource%?"
      elsif effective_resource.member_delete_actions.include?(action)
        opts['data-method'] ||= :delete
        opts['data-confirm'] ||= "Really #{action == :destroy ? 'delete' : action.to_s.titleize} %resource%?"
      end

      # Assign class
      opts[:class] ||= (
        if action == :save && index == 0
          'btn btn-primary'
        elsif opts['data-method'] == :delete
          'btn btn-danger'
        elsif defined?(EffectiveBootstrap)
          'btn btn-secondary'
        else
          'btn btn-default'
        end
      )

      # Replace resource name in any token strings
      opts['data-confirm'].gsub!('%resource%', resource.to_s) if opts['data-confirm']

      opts.except(:if, :unless, :redirect, :default)
    end
  end

end