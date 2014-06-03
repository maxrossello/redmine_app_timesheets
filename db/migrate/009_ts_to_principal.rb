# is_primary substitutes the watch on order related issues
# group ids are added

class TsToPrincipal < ActiveRecord::Migration
  def up
    add_column :ts_permissions, :principal_id, :integer, :null => false
    TsPermission.all.each do |p|
      p.principal_id = p.user_id
      p.save!
    end
    remove_column :ts_permissions, :user_id
  end

  def down
    add_column :ts_permissions, :user_id, :integer, :null => false
    TsPermission.all.each do |p|
      p.user_id = p.principal_id
      p.save!
    end
    remove_column :ts_permissions, :principal_id
  end
end
