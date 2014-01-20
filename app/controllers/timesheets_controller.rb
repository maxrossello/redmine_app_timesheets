class TimesheetsController < ApplicationController
  unloadable

  before_filter :require_login
  before_filter :get_project
  before_filter :get_user
  before_filter :access_control, :except => :index
  before_filter :get_dates
  before_filter :get_timelogs, :except => :save_period

  helper CustomFieldsHelper

  @@DEFAULT_ACTIVITY = Enumeration.where(:type => 'TimeEntryActivity', :is_default => true).first

  def index
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
        if entry.project_id == @ts_project
          order_act = TsActivity.where(:order_id => entry.order_id)
          entry.order_activity_id = order_act.where(:activity_id => params[:entry_activity][item].to_i).all.empty? ? order_act.first.activity_id : params[:entry_activity][item].to_i
        else
          order_act = Project.find(entry.project_id).activities
          entry.order_activity_id = order_act.where(:id => params[:entry_activity][item].to_i).all.empty? ? order_act.first.id : params[:entry_activity][item].to_i
        end
        entry.save!
      end
    end

    redirect_to :back
  end

  def save_period
    if @view != :day
      #REMOVE
      #entries = TsTimeEntry.for_user(@user).spent_between(@period_start,@period_end).joins("LEFT OUTER JOIN issues ON #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id").all
      entries = TsTimeEntry.for_user(@user).spent_between(@period_start,@period_end)
    #else
    #  entries = []
    end

    params[:order].each_with_index do |order_id, idx|

      #REMOVE
      #tlogs = entries.select {|x| (x.order_id == order_id.to_i or (x.issue.fixed_version_id == order_id.to_i rescue false)) and
      #    x.activity_id == params[:previous_activity][idx].to_i and
      #    x.issue_id == (params[:issue][idx].empty? ? nil : params[:issue][idx].to_i)} rescue []
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

        while diff < 0
          item = daylogs.last
          if item.hours + diff <= 0
            diff = diff + item.hours
            TsTimeEntry.delete(item.id)
            daylogs.pop
          else
            #REMOVE need to find entries because join makes tlogs read only
            #entry = TsTimeEntry.find(item.id)
            entry = item
            entry.hours = entry.hours + diff
            entry.save!
            diff = 0
          end
        end
        if diff > 0
          if daylogs.nil?
            # this is a new row
            if params[:issue][idx].empty?
              entry = TsTimeEntry.create(:project => WorkOrder.find(order_id.to_i).project, :order_id => order_id.to_i, :hours => diff, :user => @user, :spent_on => date, :order_activity_id => Enumeration.find(params[:activity][idx].to_i).id)
            else
              issue = Issue.find(params[:issue][idx].to_i)
              entry = TsTimeEntry.create(:project => issue.project, :issue => issue, :order_id => issue.fixed_version_id, :hours => diff, :user => @user, :spent_on => date, :order_activity_id => Enumeration.find(params[:activity][idx].to_i).id)
            end
            daylogs = [entry]
          else
            #REMOVE need to find entries because join makes tlogs read only
            #entry = TsTimeEntry.find(daylogs.last.id)
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
            x.save
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
      entries
    else
      entries = TsTimeEntry.for_user(@user).spent_between(@period_start,@period_end).where(:order_activity_id => params[:activity_id])
      if params[:issue_id]
        #REMOVE entries = entries.joins("LEFT OUTER JOIN issues ON #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id").where("#{Issue.table_name}.fixed_version_id = ?", params[:order_id])
        entries = entries.where(:issue_id => params[:issue_id].to_i)
      end
      if params[:order_id]
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
    row_entries.each do |x|
      #REMOVE tlog = TimeEntry.find(x.id).dup
      x.spent_on = x.spent_on+@period_shift
      x.save!
    end

    redirect_to url_for({ :controller => params[:controller], :action => 'index', :user_id => params[:user_id], :view => @view, :day => @current_day + @period_shift})
  end

  def remove_entry
    row_entries.each do |tlog|
      #REMOVE tlog = TimeEntry.find(x.id)
      tlog.order_id = nil
      tlog.order_activity_id = nil
      tlog.save!
    end

    redirect_to :back
  end

  private

  def access_control
    render_403 unless @visibility == :edit or @user == User.current
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

  def get_user
    render_403 unless User.current.logged?

    if params[:user_id] and params[:user_id] != User.current.id.to_s
      @user = User.find(params[:user_id]) rescue render_404
    else
      @user = User.current
    end

    if User.current.admin? or User.current.allowed_to?(:edit_time_entries, Project.find(@ts_project))
      @visibility = :edit
    elsif User.current.allowed_to?(:view_time_entries, Project.find(@ts_project))
      @visibility = :view
    else
      redirect_to url_for params.except :user_id if @user != User.current
      @visibility = :edit_own
    end

  end

  def get_project
    @ts_project = Setting.plugin_redmine_app_timesheets['project'].to_i
  end

  def get_timelogs
    # version of issues in @ts_project + shared versions visible in @ts_project
    # + versions associated to existing timelogs even if version no more visible to user
    # + versions associated to issues that are associated to some existing timelog
    @active_orders = (Issue.where(:project_id => @ts_project).watched_by(@user).joins(:fixed_version).map(&:fixed_version) +
        Project.find(@ts_project).shared_versions.visible(@user).all).uniq.sort_by{ |v| v.name.downcase}
    @active_own_orders = (Issue.where(:project_id => @ts_project).watched_by(User.current).joins(:fixed_version).map(&:fixed_version) +
        Project.find(@ts_project).shared_versions.visible.all).uniq.sort_by{ |v| v.name.downcase}
    @orders = (@active_orders +
        Version.where(:id => TsTimeEntry.for_user(@user).map(&:order_id)).all +
        Version.where(:id => Issue.joins(:time_entries).where('user_id = ?', @user.id).where(:fixed_version_id => Project.find(@ts_project).shared_versions.map(&:id)).map(&:fixed_version_id)).all
    ).uniq.sort_by{ |v| v.name.downcase}

    @daily_totals = {}
    @week_matrix = []
    @available = []
    @visible_orders = []

    @orders.each do |order|
      # skip orders not visible to the current user
      next if User.current != @user and !@active_own_orders.include?(order)
      @visible_orders << order if @active_orders.include?(order)

      row = {}
      row[:order] = order
      row[:spent] = {}

      unless order.project_id == @ts_project
        row[:issues] = Issue.visible(@user).where(:fixed_version_id => order.id)
      end
      # format suitable for options_for_select
      row[:activities] = TsActivity.where(:order_id => order).map {|t| [t.activity_name, t.activity_id.to_s]}
      row[:activities] = TimeEntryActivity.shared.active.map {|t| [t.name,t.id.to_s]} if row[:activities].empty?
      #REMOVE entries = TsTimeEntry.for_user(@user).spent_between(@period_start-@period_length,@period_end+@period_length).joins("LEFT OUTER JOIN issues ON #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id").where("#{TimeEntry.table_name}.fixed_version_id = ? OR #{Issue.table_name}.fixed_version_id = ?", order.id, order.id)
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
          @week_matrix << row unless row[:spent].empty?
          row = row.dup
        end
      end


      if row[:activity].nil?
        row[:activity], row[:days] = @@DEFAULT_ACTIVITY, {}
        @week_matrix << row unless row[:spent].empty?
      end

      #REMOVE time entries available to enter the timesheet
      #TimeEntry.for_user(@user).where(:order_id => nil).spent_between(@period_start,@period_end).joins("LEFT OUTER JOIN issues ON #{TimeEntry.table_name}.issue_id = #{Issue.table_name}.id").where("#{TimeEntry.table_name}.fixed_version_id = ? OR #{Issue.table_name}.fixed_version_id = ?", order.id, order.id).each do |entry|
      #  @available << { :order => order, :timelog => entry }
      #end

    end

    # time entries available to enter the timesheet
    @available = TimeEntry.for_user(@user).where(:order_id => nil).where("issue_id IS NOT NULL").spent_between(@period_start,@period_end).all

    if params[:newrow]
      # add the new empty row
      if params[:order].nil? or params[:activity].nil?
        render_404
      else
        row = {}
        row[:order] = Version.find(params[:order])
        unless row[:order].project_id == @ts_project
          row[:issues] = Issue.visible(@user).where(:fixed_version_id => row[:order].id)
        end
        row[:activities] = TsActivity.where(:order_id => params[:order].to_i).map {|t| [t.activity_name, t.activity_id.to_s]}
        row[:activities] = TimeEntryActivity.shared.active.map {|t| [t.name,t.id.to_s]} if row[:activities].empty?
        row[:activity] = Enumeration.find(params[:activity])
        row[:issue] = (params[:issue].nil? or params[:issue].empty?) ? nil : Issue.find(params[:issue])
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
