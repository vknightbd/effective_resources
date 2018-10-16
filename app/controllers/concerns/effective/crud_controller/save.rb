module Effective
  module CrudController
    module Save

      # Based on the incoming params[:commit] or passed action. Merges all options.
      def commit_action(action = nil)
        config = (['create', 'update'].include?(params[:action]) ? self.class.submits : self.class.buttons)
        ons = self.class.ons

        case action
        when nil
          commit = config[params[:commit].to_s] || config.find { |_, v| v[:action] == :save }.try(:last) || { action: :save }
          on = ons[params[:commit].to_s] || ons[commit[:action]]
        when [:create, :update]
          commit = config[action.to_s] || config.find { |_, v| v[:action] == action }.try(:last) || config.find { |_, v| v[:action] == :save }.try(:last) || { action: action }
          on = ons[action] || ons[action.to_s] || ons[commit[:action]]
        else
          commit = config[action.to_s] || config.find { |_, v| v[:action] == action }.try(:last) || { action: action }
          on = ons[action] || ons[action.to_s] || ons[commit[:action]]
        end

        commit.reverse_merge(on || {})
      end

      # This calls the appropriate member action, probably save!, on the resource.
      def save_resource(resource, action = :save, &block)
        save_action = ([:create, :update].include?(action) ? :save : action)

        raise "expected @#{resource_name} to respond to #{save_action}!" unless resource.respond_to?("#{save_action}!")

        resource.current_user ||= current_user if resource.respond_to?(:current_user=)

        ActiveRecord::Base.transaction do
          begin
            run_callbacks(:resource_before_save)

            if resource.public_send("#{save_action}!") == false
              raise("failed to #{action} #{resource}")
            end

            yield if block_given?

            run_callbacks(:resource_after_save)

            return true
          rescue => e
            Rails.logger.info "Failed to #{action}: #{e.message}" if Rails.env.development?

            if resource.respond_to?(:restore_attributes) && resource.persisted?
              resource.restore_attributes(['status', 'state'])
            end

            flash.delete(:success)
            flash.now[:danger] = flash_danger(resource, action, e: e)
            raise ActiveRecord::Rollback
          end
        end

        run_callbacks(:resource_error)
        false
      end

      def resource_flash(status, resource, action)
        submit = commit_action(action)
        message = submit[status].respond_to?(:call) ? instance_exec(&submit[status]) : submit[status]
        return message if message.present?

        case status
        when :success then flash_success(resource, action)
        when :danger then flash_danger(resource, action)
        else
          raise "unknown resource flash status: #{status}"
        end
      end

      def reload_resource
        self.resource.reload if resource.respond_to?(:reload)
      end

      # Should return a new resource based on the passed one
      def duplicate_resource(resource)
        resource.dup
      end

    end
  end
end
