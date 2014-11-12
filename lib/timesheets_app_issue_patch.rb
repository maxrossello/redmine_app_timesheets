module TimesheetsAppIssuePatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable

      alias_method_chain :assignable_versions, :timelogs
      alias_method_chain :validate_issue, :timelogs
    end

  end

  module InstanceMethods

    def assignable_versions_with_timelogs
      assignable_versions_without_timelogs
      @assignable_versions.reject! { |version| version.project_id == Setting.plugin_redmine_app_timesheets['project'].to_i ?
                              TsPermission.permission(User.current, version) <= TsPermission::NONE :
                              !User.current.allowed_to?(:view_issues, version.project)
      } if Setting.plugin_redmine_app_timesheets["public_versions"].nil?
      @assignable_versions
    end

    # while validating an issue anybody should be able to save it with current foreign version, unless changed
    def validate_issue_with_timelogs
      if Setting.plugin_redmine_app_timesheets["public_versions"].nil? and
          (version = fixed_version) and
          !fixed_version_id_changed? and
          !assignable_versions.include?(version)

        # temporarily "unalias" assignable_versions
        @assignable_versions = nil
        self.class.send(:alias_method, :assignable_versions, :assignable_versions_without_timelogs)
        validate_issue_without_timelogs
        self.class.send(:alias_method, :assignable_versions, :assignable_versions_with_timelogs)
        @assignable_versions = nil
      else
        validate_issue_without_timelogs
      end
    end
  end

end


unless Issue.included_modules.include?(TimesheetsAppIssuePatch)
  Issue.send(:include, TimesheetsAppIssuePatch)
end
