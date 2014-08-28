module TimesheetsAppProjectPatch

  def self.included(base)
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable

      alias_method_chain :rolled_up_versions, :timelogs
      alias_method_chain :shared_versions, :timelogs
    end

  end

  module InstanceMethods

    def rolled_up_versions_with_timelogs
      rolled_up_versions_without_timelogs
      perm = TsPermission.over(version).for_user.all
      @rolled_up_versions.reject! { |version| version.project_id == Setting.plugin_redmine_app_timesheets['project'].to_i ?
                    TsPermission.permission(User.current, version) == TsPermission::NONE :
                    !User.current.allowed_to?(:view_issues, version.project)
      } if Setting.plugin_redmine_app_timesheets["public_versions"].nil?
      @rolled_up_versions
    end

    def shared_versions_with_timelogs
      shared_versions_without_timelogs
      ts_project = Setting.plugin_redmine_app_timesheets['project'].to_i
      # filter out versions that are in ts_project if user cannot watch the permission holding issue
      # and those not in ts_project if user cannot view issues into the sourcing project
      if Setting.plugin_redmine_app_timesheets["public_versions"].nil?
        @shared_versions = @shared_versions.where("(#{Version.table_name}.project_id = ? AND #{Version.table_name}.id IN (?))
                                                  OR (#{Version.table_name}.project_id != ? AND #{Version.table_name}.project_id IN (?))",
                               ts_project,
                               TsPermission.where(:order_id => @shared_versions.all).for_user.map(&:version),
                               ts_project,
                               Project.where(Project.allowed_to_condition(User.current, :view_issues)))
      end
      @shared_versions
    end
  end

end


unless Project.included_modules.include?(TimesheetsAppProjectPatch)
  Project.send(:include, TimesheetsAppProjectPatch)
end
