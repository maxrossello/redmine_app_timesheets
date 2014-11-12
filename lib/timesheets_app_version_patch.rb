module TimesheetsAppVersionPatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable

      validate :validate_order

      has_many :time_entries, :class_name => 'TsTimeEntry', :foreign_key => 'order_id', :dependent => :destroy

    end
  end

  module InstanceMethods

    def validate_order
      custom_field_values.each do |cv|
        if cv.custom_field_id == Setting.plugin_redmine_app_timesheets["field"]
          if TimeEntry.where(:order_id => self.id).any?  # timelogs associated
            self.is_order = true
            self.in_timesheet = cv.value
          else
            self.is_order = cv.value
          end

          return false if (self.project_id == Setting.plugin_redmine_app_timesheets['project'].to_i and self.is_order == false)
        end
      end
      if self.is_order and changed_attributes['in_timesheet'].nil?
        self.in_timesheet = true
      end
      true
    end

  end

end


unless Version.included_modules.include?(TimesheetsAppVersionPatch)
  Version.send(:include, TimesheetsAppVersionPatch)
end
