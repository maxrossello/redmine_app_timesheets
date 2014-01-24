class TsPermissions < ActiveRecord::Migration
  def up
    create_table :ts_permissions do |t|
      t.column :order_id, :integer, :null => false
      t.column :user_id, :integer, :null => false
      t.column :access, :integer, :null => false, :default => 0
    end
    add_index :ts_permissions, [:user_id, :order_id]

    backing = Project.find(Setting.plugin_redmine_app_timesheets['project'].to_i)
    if backing != nil
      TsPermission.transaction do
        backing.versions.each do |order|
          backing.users.each do |user|
            if user.allowed_to?(:edit_time_entries, backing)
              TsPermission.create(:order_id => order.id, :user_id => user.id, :access => TsPermission::EDIT)
            elsif user.allowed_to?(:view_time_entries, backing)
              TsPermission.create(:order_id => order.id, :user_id => user.id, :access => TsPermission::VIEW)
            end
          end
        end
      end
    end
  end

  def down
    drop_table :ts_permissions
  end
end
