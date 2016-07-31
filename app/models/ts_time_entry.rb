
class TsTimeEntry < TimeEntry
  belongs_to :order, :class_name => 'WorkOrder', :foreign_key => 'order_id'

  default_scope { where("#{TsTimeEntry.table_name}.order_id IS NOT NULL") }

  def validate_time_entry
    super
    # do not complain for locally overridden activities
    errors.delete :activity_id if activity_id_changed? && project && project.activities.map(&:parent).compact.include?(activity)
  end

end
