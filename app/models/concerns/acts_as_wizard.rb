# ActsAsWizard
# Works alongside wicked gem to build a wizard
# https://github.com/zombocom/wicked

# acts_as_wizard(start: 'Start Step', select: 'Select Step', finish: 'Finished')

module ActsAsWizard
  extend ActiveSupport::Concern

  module Base
    def acts_as_wizard(steps)
      raise 'acts_as_wizard expected a Hash of steps' unless steps.kind_of?(Hash)

      unless steps.all? { |k, v| k.kind_of?(Symbol) && v.kind_of?(String) }
        raise 'acts_as_wizard expected a Hash of symbol => String steps'
      end

      @acts_as_wizard_options = {steps: steps}

      include ::ActsAsWizard
    end
  end

  included do
    acts_as_wizard_options = @acts_as_wizard_options

    attr_accessor :current_step
    attr_accessor :skip_to_step

    attr_accessor :current_user

    if Rails.env.test? # So our tests can override the required_steps method
      cattr_accessor :test_required_steps
    end

    const_set(:WIZARD_STEPS, acts_as_wizard_options[:steps])

    effective_resource do
      wizard_steps           :text, permitted: false
    end

    serialize :wizard_steps, Hash

    before_save(if: -> { current_step.present? }) do
      wizard_steps[current_step.to_sym] ||= Time.zone.now
    end

    # Use can_visit_step? required_steps and wizard_step_title(step) to control the wizard behaviour
    def can_visit_step?(step)
      can_revisit_completed_steps(step)
    end

    def wizard_step_keys
      self.class.const_get(:WIZARD_STEPS).keys
    end

    def required_steps
      return self.class.test_required_steps if Rails.env.test? && self.class.test_required_steps.present?

      steps = wizard_step_keys()

      # Give the caller class a mechanism to change these.
      # Used more in effective memberships
      steps = change_wizard_steps(steps)

      unless steps.kind_of?(Array) && steps.all? { |step| step.kind_of?(Symbol) }
        raise('expected change_wizard_steps to return an Array of steps with no nils')
      end

      steps
    end

    # Intended for use by calling class
    def change_wizard_steps(steps)
      steps
    end

    # For use in the summary partials. Does not include summary.
    def render_steps
      blacklist = [:start, :billing, :checkout, :submitted, :summary]
      (required_steps - blacklist).select { |step| has_completed_step?(step) }
    end

    def wizard_step_title(step)
      self.class.const_get(:WIZARD_STEPS).fetch(step)
    end

    def first_completed_step
      required_steps.find { |step| has_completed_step?(step) }
    end

    def last_completed_step
      required_steps.reverse.find { |step| has_completed_step?(step) }
    end

    def first_uncompleted_step
      required_steps.find { |step| has_completed_step?(step) == false }
    end

    def has_completed_step?(step)
      (errors.present? ? wizard_steps_was : wizard_steps)[step].present?
    end

    def next_step
      first_uncompleted_step ||
      last_completed_step ||
      required_steps.reverse.find { |step| can_visit_step?(step) } ||
      required_steps.first ||
      :start
    end

    def previous_step(step)
      index = required_steps.index(step)
      required_steps[index-1] unless index == 0 || index.nil?
    end

    def has_completed_previous_step?(step)
      previous = previous_step(step)
      previous.blank? || has_completed_step?(previous)
    end

    def has_completed_all_previous_steps?(step)
      index = required_steps.index(step).to_i
      previous = required_steps[0...index]

      previous.blank? || previous.all? { |step| has_completed_step?(step) }
    end

    def has_completed_last_step?
      has_completed_step?(required_steps.last)
    end

    def without_current_step(&block)
      existing = current_step

      begin
        self.current_step = nil; yield
      ensure
        self.current_step = existing
      end
    end

    private

    def can_revisit_completed_steps(step)
      return (step == required_steps.last) if has_completed_last_step?
      has_completed_all_previous_steps?(step)
    end

    def cannot_revisit_completed_steps(step)
      return (step == required_steps.last) if has_completed_last_step?
      has_completed_all_previous_steps?(step) && !has_completed_step?(step)
    end

  end

  module ClassMethods
    def acts_as_wizard?; true; end

    def wizard_steps_hash
      const_get(:WIZARD_STEPS)
    end

    def all_wizard_steps
      const_get(:WIZARD_STEPS).keys
    end

  end

end
