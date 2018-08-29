module Effective
  module Resources
    module Controller

      # Used by effective_form_submit
      # The actions we would use to commit. For link_to
      # { 'Save': { action: :save }, 'Continue': { action: :save }, 'Add New': { action: :save }, 'Approve': { action: :approve } }
      # Saves a list of commit actions...
      def submits
        @submits ||= {}.tap do |submits|
          if (actions.find { |a| a == :create } || actions.find { |a| a == :update })
            submits['Save'] = { action: :save }
          end

          if actions.find { |a| a == :index }
            submits['Continue'] = { action: :save, redirect: :index }
          end

          if actions.find { |a| a == :new }
            submits['Add New'] = { action: :save, redirect: :new }
          end
        end
      end

      def buttons
        @buttons ||= {}.tap do |buttons|
          member_get_actions.each do |action| # default true means it will be overwritten by dsl methods
            buttons[action.to_s.titleize] = { action: action }
          end

          (member_post_actions - crud_actions).each do |action| # default true means it will be overwritten by dsl methods
            buttons[action.to_s.titleize] = { action: action }
          end

          member_delete_actions.each do |action|
            buttons[action == :destroy ? 'Delete' : action.to_s.titleize] = { action: action }
          end
        end
      end

      # This is the fallback for render_resource_actions when no actions are specified
      # It is used by datatables
      def resource_actions
        @resource_actions ||= {}.tap do |actions|
          (member_get_actions & crud_actions).each do |action|
            actions[action.to_s.titleize] = { action: action }
          end

          (member_get_actions - crud_actions).each do |action|
            actions[action.to_s.titleize] = { action: action }
          end

          (member_post_actions - crud_actions).each do |action|
            actions[action.to_s.titleize] = { action: action }
          end

          member_delete_actions.each do |action|
            actions[action == :destroy ? 'Delete' : action.to_s.titleize] = { action: action }
          end
        end
      end

      def ons
        @ons ||= {}
      end

    end
  end
end
