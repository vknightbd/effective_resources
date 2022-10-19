module Admin
  class Select2AjaxController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)
    before_action { EffectiveResources.authorize!(self, :admin, :effective_resources) }

    include Effective::Select2AjaxController

    def users
      collection = current_user.class.all

      if collection.respond_to?(:to_select2)
        collection = collection.to_select2
      elsif collection.respond_to?(:sorted)
        collection = collection.sorted
      end

      respond_with_select2_ajax(collection) do |user|
        { id: user.to_param, text: user.try(:to_select2) || to_select2(user) }
      end
    end

    private

    def to_select2(user)
      "<span>#{user}</span> <small>#{user.email}</small>"
    end

  end

end
