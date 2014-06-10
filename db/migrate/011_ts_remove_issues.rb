# is_primary substitutes the watch on order related issues
# group ids are added

class TsRemoveIssues < ActiveRecord::Migration
  def up
    ts_prj = Project.find(Setting.plugin_redmine_app_timesheets['project'].to_i) rescue nil
    ts_prj.issues.destroy_all unless ts_prj.nil?
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
