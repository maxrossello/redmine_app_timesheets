module TimesheetsAppIssuePatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable

      alias_method_chain :assignable_versions, :timelogs
    end

  end

  module InstanceMethods

    def assignable_versions_with_timelogs
      assignable_versions_without_timelogs
      @assignable_versions.reject! { |version| version.project_id == Setting.plugin_redmine_app_timesheets['project'].to_i ? Issue.select(:fixed_version_id).where(:project_id => Setting.plugin_redmine_app_timesheets['project'].to_i).where(:fixed_version_id => version.id).watched_by(User.current).all.empty? : !User.current.allowed_to?(:view_issues, version.project) } unless Setting.public_versions?
      @assignable_versions
    end

  end

end

