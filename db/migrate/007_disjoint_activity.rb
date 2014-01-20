# use just the time entry's fixed_version_id to understand it's in timesheet

class DisjointActivity < ActiveRecord::Migration
  def up
    add_column :time_entries, :order_activity_id, :integer
    TimeEntry.update_all("order_activity_id = activity_id")
  end

  def down
    remove_column :time_entries, :order_activity_id
  end
end
