
class TsTimeEntry < TimeEntry
  default_scope where("order_id IS NOT NULL")
end