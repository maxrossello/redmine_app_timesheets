class TimesheetsController < ApplicationController
  unloadable

  before_filter :require_login
  before_filter :get_project
  before_filter :get_user
  before_filter :get_dates
  before_filter :get_timelogs, :except => :save_period
  before_filter :check_is_editor, :only => :index

  helper CustomFieldsHelper

  @@DEFAULT_ACTIVITY = Enumeration.where(:type => 'TimeEntryActivity', :is_default => true).first

  def index
    render_403 if @visibility.empty? and @user != User.current
  end

  def new
    @time_entry = TimeEntry.new
  end

  # add a timelog entry into the timesheet
  def add_entry
    TimeEntry.transaction do
      params[:entry].each do |item|
        entry = TimeEntry.find(item.to_i)
        entry.order_id = params[:entry_order][item].to_i
        if !write_enabled(entry.order_id)
          flash[:error] = l(:label_timesheet_missing_permission_on_order)
          raise ActiveRecord::Rollback
        end
        if entry.project_id == @ts_project
          order_act = TsActivity.where(:order_id => entry.order_id)
          entry.order_activity_id = order_act.where(:activity_id => params[:entry_activity][item].to_i).all.empty? ? order_act.first.activity_id : params[:entry_activity][item].to_i
        else
          order_act = Project.find(entry.project_id).activities
          (order_act = order_act.all) unless order_act.is_a? Array
          entry.order_activity_id = order_act.map(&:id).include?(params[:entry_activity][item].to_i) ? params[:entry_activity][item].to_i : order_act.first.id
        end
        entry.save!
      end
    end if params[:entry]

    redirect_to :back
  end

  def save_period
    if @view != :day
      entries = TsTimeEntry.for_user(@user).spent_between(@period_start,@period_end)
    end

    params[:order].each_with_index do |order_id, idx|

      if @view != :day
        tlogs = entries.where(:order_id => order_id.to_i).where(:order_activity_id => params[:previous_activity][idx].to_i).where(:issue_id => (params[:issue][idx].empty? ? nil : params[:issue][idx].to_i)).all rescue []
      end

      params[:hours].each do |s_date, hours|
        date = s_date.to_date

        if @view == :day
          # day view handles single entries
          daylogs = [ TsTimeEntry.find(params[:entry][idx]) ] rescue nil
          old_sum = daylogs.first.hours rescue 0
        else
          # other views handle sets of similar entries
          daylogs = tlogs.group_by(&:spent_on)[date]
          old_sum = daylogs.inject(0) { |sum,x| sum + x.hours } rescue 0
        end

        next if hours[idx].to_f < 0
        diff = hours[idx].to_f - old_sum

        if !write_enabled(order_id)
          flash[:error] = l(:label_timesheet_missing_permission_on_order) + ": #{order_id}"
          next
        end

        while diff < 0
          item = daylogs.last
          if item.hours + diff <= 0
            diff = diff + item.hours
            TsTimeEntry.delete(item.id)
            daylogs.pop
          else
            entry = item
            entry.hours = entry.hours + diff
            entry.save!
            diff = 0
          end
        end
        if diff > 0
          if daylogs.nil?
            # this is a new row
            activity = Enumeration.find(params[:activity][idx].to_i).id
            if params[:issue][idx].empty?
              entry = TsTimeEntry.create(:project => WorkOrder.find(order_id.to_i).project, :order_id => order_id.to_i, :hours => diff, :user => @user, :spent_on => date, :order_activity_id => activity, :activity_id => activity)
            else
              issue = Issue.find(params[:issue][idx].to_i)
              entry = TsTimeEntry.create(:project => issue.project, :issue => issue, :order_id => order_id.to_i, :hours => diff, :user => @user, :spent_on => date, :order_activity_id => activity, :activity_id => activity)
            end
            daylogs = [entry]
          else
            entry = daylogs.last
            entry.hours = entry.hours + diff
            entry.save!
          end
        end

        entry = (daylogs.last rescue nil) unless entry

        if params[:comment] and entry
          # only in day view
          entry.comments = params[:comment][idx]
          entry.save!
        end

        # check for change of activity
        if params[:activity][idx] != params[:previous_activity][idx] and daylogs
          TsTimeEntry.find(daylogs.map(&:id)).each do |x|
            x.order_activity_id = params[:activity][idx].to_i
            x.save if x.order_activity_id > 0
          end
        end
      end
    end

    #:back
    redirect_to url_for({ :controller => params[:controller], :action => 'index', :user_id => params[:user_id], :view => @view, :day => @current_day})
  end

  def row_entries
    if params[:entry_id]
      entries = TsTimeEntry.find(params[:entry_id]) rescue render_404
      if !write_enabled(entries.order_id)
        flash[:error] = l(:label_timesheet_missing_permission_on_order)
        return []
      end
      [entries]
    else
      entries = TsTimeEntry.for_user(@user).spent_between(@period_start,@period_end).where(:order_activity_id => params[:activity_id])
      if params[:issue_id]
        entries = entries.where(:issue_id => params[:issue_id].to_i)
      end
      if params[:order_id]
        if !write_enabled(params[:order_id].to_i)
          flash[:error] = l(:label_timesheet_missing_permission_on_order)
          return []
        end
        entries = entries.where(:order_id => params[:order_id])
      end
      entries.all
    end
  end

  def delete_row
    TsTimeEntry.delete(row_entries)

    redirect_to :back
  end

  def copy_row
    row_entries.each do |tlog|
      x = tlog.dup
      x.spent_on = x.spent_on+@period_shift
      x.save!
    end

    redirect_to url_for({ :controller => params[:controller], :action => 'index', :user_id => params[:user_id], :view => @view, :day => @current_day + @period_shift})
  end

  def remove_entry
    row_entries.each do |tlog|
      tlog.order_id = nil
      tlog.order_activity_id = nil
      tlog.save!
    end

    redirect_to :back
  end

  private

  def write_enabled(order)
    order_id = order.to_i
    # access granted for own timesheet, non-native versions, or explicit permission
    if @user == User.current or WorkOrder.find(order_id).nil? or @visibility[order_id] == TsPermission::EDIT or @visibility[order_id] == TsPermission::ADMIN
      return true
    else
      return false
    end
  end

  def get_dates
    @current_day = DateTime.strptime(params[:day], Time::DATE_FORMATS[:param_date]) rescue nil
    @current_day ||= DateTime.strptime(DateTime.now.to_s, Time::DATE_FORMATS[:param_date])

    @view = params[:view].to_sym rescue nil
    @view = :week if @view.nil? or params[:view].empty?

    if @view == :week
      @period_start = @current_day.beginning_of_week
      @period_end = @current_day.end_of_week
      @period_length = 7
      @period_shift = 7
    elsif @view == :day
      @period_start = @current_day
      @period_end = @current_day
      @period_length = 0 # do not get items from side days
      @period_shift = 1
    else
      @period_length = params[:view].to_i
      @period_shift = @period_length
      @period_start = @current_day
      @period_end = @current_day + @period_length -1
    end


  end

  def is_order_admin?(user)
    user.admin? or Setting.plugin_redmine_app__space['auth_group']['order_mgmt'].empty? or
        user.is_or_belongs_to?(Group.find(Setting.plugin_redmine_app__space['auth_group']['order_mgmt'].to_i))
  end

  def get_user
    render_403 unless User.current.logged?

    if params[:user_id] and params[:user_id] != User.current.id.to_s
      @user = User.find(params[:user_id]) rescue render_404
    else
      @user = User.current
    end

    # retrieve permissions over orders
    @visibility = TsPermission.for_user.inject({}) do |h,v|
      h[v[:order_id]] = v[:access] if h[v[:order_id]].nil? or h[v[:order_id]] < v[:access]
      h
    end

    WorkOrder.native.all.each do |order|
      if (is_order_admin?(User.current) and @visibility[order.id].present?) # need to be listed anyway
        @visibility[order.id] = TsPermission::ADMIN
      else
        @visibility[order.id] ||= TsPermission::FORBIDDEN
      end
    end

    WorkOrder.not_native.all.each do |order|
      @visibility[order.id] = TsPermission::NONE if User.current.allowed_to? :edit_own_time_entries, order.project
      @visibility[order.id] = TsPermission::VIEW if User.current.allowed_to? :view_time_entries, order.project
      @visibility[order.id] = TsPermission::EDIT if User.current.allowed_to? :edit_time_entries, order.project
      @visibility[order.id] = TsPermission::ADMIN if User.current.admin?
      @visibility[order.id] ||= TsPermission::FORBIDDEN
    end

  end

  def get_project
    @ts_project = Setting.plugin_redmine_app_timesheets['project'].to_i
  end

  def check_is_editor
    if is_order_admin?(User.current)
      @order_admin = true
    else
      @order_admin = TsPermission.where("access >= ?", TsPermission::VIEW).joins(:order).where("#{WorkOrder.table_name}.in_timesheet = ?", true).for_user.any?
    end
  end

  def get_timelogs
    @active_orders = (TsPermission.for_user(@user).joins(:order).includes(:order).map{|t| t.order} +
        WorkOrder.visible(@user)).uniq.sort_by{ |v| v.name.downcase}
    @active_own_orders = (TsPermission.for_user(User.current).joins(:order).includes(:order).map{|t| t.order} +
        WorkOrder.visible(User.current)).uniq.sort_by{ |v| v.name.downcase}
    # native orders assigned to user + visible versions marked as orders
    # + orders associated to existing timelogs even if version no more visible to user
    # + orders associated to issues that are associated to some existing user timelog even if version no more visible to user
    @orders = (@active_orders +
        WorkOrder.includes(:time_entries).merge(TsTimeEntry.for_user(@user)).uniq.all +
        WorkOrder.joins(:issues).merge(Issue.joins(:time_entries).where('time_entries.user_id = ?', @user.id)).uniq.all
    ).uniq.sort_by{ |v| v.name.downcase}

    @daily_totals = {}
    @week_matrix = []
    @available = []
    @visible_orders = []
    @manageable_orders = []

    @orders.each do |order|
      # skip orders not visible to the current user
      next if User.current != @user and (!@active_own_orders.include?(order) or @visibility.empty? or @visibility[order.id] <= TsPermission::NONE)
      @visible_orders << order if @active_orders.include?(order) and order.in_timesheet
      # orders in add row:
      # I am manager of, even if not visible to @user
      # I can edit time only if currently visibile by @user
      if order.in_timesheet
        if  ((User.current == @user and @visibility[order.id] != TsPermission::FORBIDDEN) or
            @visibility[order.id] >= TsPermission::EDIT) #or
            #(@visibility[order.id] == TsPermission::EDIT and @active_orders.include?(order)))

          @manageable_orders << order
        end
      end

      row = {}
      row[:order] = order
      row[:spent] = {}

      row[:readonly] = false
      row[:readonly] = true unless @visible_orders.include?(order)
      row[:readonly] = true if @user != User.current and order.is_native? and @visibility[order.id] == TsPermission::VIEW
      row[:readonly] = true if @user != User.current and !order.is_native? and !User.current.allowed_to?(:edit_time_entries, order.project)

      # readonly for @user but writable for User.current
      row[:disabled] = row[:readonly]
      row[:disabled] = false if @active_own_orders.include?(order) and order.in_timesheet

      unless order.is_native?
        row[:issues] = order.issues.visible(@user).all
      end
      # format suitable for options_for_select
      row[:activities] = TsActivity.where(:order_id => order).map {|t| [t.activity_name, t.activity_id.to_s]}
      row[:activities] = TimeEntryActivity.shared.active.map {|t| [t.name,t.id.to_s]} if row[:activities].empty?
      entries = TsTimeEntry.for_user(@user).spent_between(@period_start-@period_length,@period_end+@period_length).where(:order_id => order.id)
      entries.all.group_by(&:order_activity_id).each do |activity, values|
        row[:activity] = Enumeration.find(activity)
        values.group_by(&:issue_id).each do |issue, iv|
          row[:spent] = {}
          row[:entries] = {}
          row[:issue] = issue.nil? ? nil : Issue.find(issue)
          iv.group_by(&:spent_on).each do |day, sv|
            row[:spent][day] = sv.inject(0) { | sum, elem |
              sum + elem.hours }
            @daily_totals[day] = row[:spent][day] + (@daily_totals[day] || 0)
            row[:entries] = sv
          end

          row[:emptyrow] = row[:spent].select {|x,y| x >= @period_start and x <= @period_end }.empty?
          row[:emptynextrow] = row[:spent].select {|x,y| x > @period_end }.empty?

          @week_matrix << row unless row[:spent].empty?
          row = row.dup
        end
      end

      @week_total = 0.0
      (@period_start..@period_end).each do |day|
        @week_total += @daily_totals[day].to_f
      end

      if row[:activity].nil?
        row[:activity], row[:days] = @@DEFAULT_ACTIVITY, {}
        @week_matrix << row unless row[:spent].empty?
      end

    end

    # in add row, add orders where I am admin
    @manageable_orders << WorkOrder.enabled.where("id IN (?)", @visibility.select{|k,v| v == TsPermission::ADMIN}.keys )
    @manageable_orders = @manageable_orders.flatten.uniq

    # time entries available to enter the timesheet
    @available = TimeEntry.for_user(@user).where(:order_id => nil).where("issue_id IS NOT NULL").spent_between(@period_start,@period_end).all

    if params[:newrow]
      # add the new empty row
      if params[:order].nil? or params[:activity].nil?
        render_404
      else
        row = {}
        row[:order] = WorkOrder.find(params[:order])
        unless row[:order].project_id == @ts_project
          row[:issues] = row[:order].issues.visible(@user).all
        end
        row[:activities] = TsActivity.where(:order_id => params[:order].to_i).map {|t| [t.activity_name, t.activity_id.to_s]}
        row[:activities] = TimeEntryActivity.where('project_id IS NULL OR project_id = ?', row[:order].project_id).active.map {|t| [t.name,t.id.to_s]} if row[:activities].empty?
        row[:activity] = Enumeration.find(params[:activity])
        row[:issue] = (params[:issue].blank? ? nil : Issue.find(params[:issue]))
        row[:spent] = {}
        # add only if unique
        @week_matrix << row if @week_matrix.select{|x| x if x[:order] == row[:order] and x[:activity] == row[:activity] and x[:issue] == row[:issue]}.empty?
      end
      params.delete :order
      params.delete :activity
      params.delete :issue
      params.delete :newrow

    else
      # while building the new row
      if params[:order] and !params[:order].empty?
        new_order = WorkOrder.find(params[:order])
        @activities = TsActivity.where(:order_id => params[:order].to_i).map {|t| [t.activity_name, t.activity_id.to_s]}
        @activities = new_order.project.activities.sort{|x,y| x.name <=> y.name}.map{ |x| [ x.name, x.id] } if @activities.empty?
      end

      if params[:activity] && new_order.project_id != @ts_project
        # select among the issues linked to the version only
        @issues = new_order.fixed_issues.visible(@user).all
      end
    end

  end

end
