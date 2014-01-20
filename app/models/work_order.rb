
class WorkOrder < Version
  def spent_hours
    @spent_hours ||= TsTimeEntry.where(:order_id => id).sum(:hours).to_f
  end
end