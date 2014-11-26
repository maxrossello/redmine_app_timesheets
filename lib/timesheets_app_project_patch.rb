module TimesheetsAppProjectPatch

  def self.included(base)
    base.extend ClassMethods
    base.send(:include, InstanceMethods)
    base.instance_eval do
      unloadable

      alias_method_chain :rolled_up_versions, :timelogs
      alias_method_chain :shared_versions, :timelogs

      class << self
        alias_method_chain :allowed_to_condition, :timelogs
      end

    end

  end

  module InstanceMethods

    def rolled_up_versions_with_timelogs
      rolled_up_versions_without_timelogs
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
                               TsPermission.where(:order_id => @shared_versions.all).for_user.map(&:version).compact,
                               ts_project,
                               Project.select(:id).where(Project.allowed_to_condition(User.current, :view_issues)))
      end
      @shared_versions
    end
  end


  module ClassMethods
    # allow to view timelogs in native workspace according to TsPermissions
    def allowed_to_condition_with_timelogs(user, permission, options={})
      statement = allowed_to_condition_without_timelogs(user, permission, options)
      if user.logged? and !user.admin? and (permission == :view_time_entries)
        orders = []
        own_orders = []
        Project.find(Setting.plugin_redmine_app_timesheets['project'].to_i).versions.each do |version|
          perm = TsPermission.over(version).for_user(user).first
          own_orders << version.id if perm.present? and perm.access >= TsPermission::NONE
          orders << version.id if perm.present? and perm.access >= TsPermission::VIEW
        end

        statement = "(#{TimeEntry.table_name}.order_id IN ('#{orders.join('\',\'')}')) OR (#{TimeEntry.table_name}.user_id = #{user.id} AND #{TimeEntry.table_name}.order_id IN ('#{own_orders.join('\',\'')}')) OR #{statement}"
      else
        statement
      end
    end

  end

end


unless Project.included_modules.include?(TimesheetsAppProjectPatch)
  Project.send(:include, TimesheetsAppProjectPatch)
end
