module TimesheetsAppCustomFieldPatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable
      before_destroy :prevent_destroy

      alias_method_chain :validate_custom_field, :timelogs
    end

  end

  module InstanceMethods

    def validate_custom_field_with_timelogs
      if self.id == Setting.plugin_redmine_app_timesheets["field"] and
         self.is_required == false
        errors.add :is_required, l(:error_timesheet_required_custom_field)
      end
      validate_custom_field_without_timelogs
    end

    def prevent_destroy
      if self.name == TS_FIELD_NAME
        errors.add :destroy, l(:error_timesheet_cannot_delete_field)
        false
      else
        true
      end
    end
  end

end


unless CustomField.included_modules.include?(TimesheetsAppCustomFieldPatch)
  CustomField.send(:include, TimesheetsAppCustomFieldPatch)
end
