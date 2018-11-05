# ActsAsArchived
#
# Implements the archived pattern
# An archived object should not be present on any index screens or in any new record collections
# Works with effective_select (from the effective_bootstrap gem) to have .unarchived and .archived called appropriately
#
# class Thing < ApplicationRecord
#   has_many :comments
#   acts_as_archivable cascade: :comments

# To use the routes concern, In your routes.rb:
#
# Rails.application.routes.draw do
#   acts_as_archivable
#   resource :things, concern: :archivable
# end

module ActsAsArchived
  extend ActiveSupport::Concern

  module ActiveRecord
    def acts_as_archived(cascade: [])
      resource = new()

      # Make sure we respond to archived attribute
      raise 'must respond to archived' unless resource.respond_to?(:archived)

      # Parse options
      cascade = Array(cascade).compact
      raise 'expected cascade to be an Array of has_many symbols' if cascade.any? { |obj| !resource.respond_to?(obj) }

      @acts_as_archived_options = { cascade: cascade }

      include ::ActsAsArchived
    end
  end

  module RoutesConcern
    def acts_as_archived
      concern :acts_as_archived do
        post :archive, on: :member
        post :unarchive, on: :member
      end
    end
  end

  included do
    scope :archived, -> { where(archived: true) }
    scope :unarchived, -> { where(archived: false) }

    effective_resource do
      archived :boolean, permitted: false
    end

    acts_as_archived_options = @acts_as_archived_options
    self.send(:define_method, :acts_as_archived_options) { acts_as_archived_options }
  end

  module ClassMethods
    def acts_as_archived?; true; end
  end

  # Instance methods
  def archive!
    transaction do
      update!(archived: true) # Runs validations
      acts_as_archived_options[:cascade].each { |obj| public_send(obj).update_all(archived: true) }
    end
  end

  def unarchive!
    transaction do
      update_column(:archived, false) # Does not run validations
      acts_as_archived_options[:cascade].each { |obj| public_send(obj).update_all(archived: false) }
    end
  end

  def destroy
    archive!
  end

  def readonly?
    (archived? && archived_was)
  end

end

