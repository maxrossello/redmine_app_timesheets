class TimesheetController < AppspaceController
  unloadable

  before_filter :require_login

  def index
    #@tab = {
    #    :name => "timesheet",
    #    :view => "appspace/blocks/news",
    #    #:partial => 'appspace/tab',
    #    #:label => :label_timesheet
    #}
    @application = "timesheet"
    @example = "Timesheet app"

    super
  end

end