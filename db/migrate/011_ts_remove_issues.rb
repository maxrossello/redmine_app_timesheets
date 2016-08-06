# is_primary substitutes the watch on order related issues
# group ids are added

class TsRemoveIssues < ActiveRecord::Migration
  def up
    ts_prj = Project.find(Setting.plugin_redmine_app_timesheets['project'].to_i) rescue nil
    ts_prj.issues.destroy_all unless ts_prj.nil?
  end

  def down
    # comment: use of watch is very obsolete. Down would happen only on uninstall.
    # In the weird a downgrade is wanted, the watches are lost
    # raise ActiveRecord::IrreversibleMigration
  end
end
