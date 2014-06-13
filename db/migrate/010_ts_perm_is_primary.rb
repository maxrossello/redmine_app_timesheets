# is_primary substitutes the watch on order related issues
# group ids are added

class TsPermIsPrimary < ActiveRecord::Migration
  def up
    add_column :ts_permissions, :is_primary, :boolean, :default => false, :null => false
    TsPermission.reset_column_information

    issues = Project.find(Setting.plugin_redmine_app_timesheets['project'].to_i).issues rescue nil
    unless issues.blank?
      principals = issues.map{|i| i.watchers.map{|w| Principal.find(w.user_id)}}.flatten.uniq
      issues.each do |i|
        next if i.fixed_version.nil?
        principals = i.watchers.map{|w| Principal.find(w.user_id)}
        principals.each do |p|
          perm = TsPermission.where(:order_id => i.fixed_version_id, :principal_id => p.id).first
          if perm.nil?
            perm = TsPermission.new(:order_id => i.fixed_version_id, :principal_id => p.id)
            # weird: object created with wrong attributes!
            perm.order_id = i.fixed_version_id
            perm.principal_id = p.id
            perm.access = TsPermission::NONE
          end
          perm.is_primary = true
          perm.save!
          if p.is_a?(Group)
            p.users.active.each do |u|
              uperm = TsPermission.where(:order_id => i.fixed_version_id, :principal_id => u.id).first
              unless uperm.nil?
                uperm.is_primary = false unless principals.include?(u)
                uperm.save!
              end
            end
          end
        end
      end
    end
  end

  def down
    TsPermission.destroy(TsPermission.select{|p| p.principal.is_a?(Group)})
    remove_column :ts_permissions, :is_primary
  end
end
