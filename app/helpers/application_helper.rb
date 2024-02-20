module ApplicationHelper
  def format_progress(progress)
    "%.2f%" % (progress * 100.0)
  end

  def date_format(arg1, arg2)
  	format = @company.date_format
  	if format == "MM/dd/yyyy"
      format = "%m/%d/%Y"
    elsif format == "dd/MM/yyyy"
      format = "%d/%m/%Y"
    elsif format == "MMM DD, YYYY"
      format = "%b %d, %Y"
    else
      format = "%y/%m/%d"
  	end
    if arg1.strftime(format) == arg2.strftime(format)
      arg1.strftime(format)
    else
      arg1.strftime(format) + " - " +  arg2.strftime(format)
    end
  end

  def company_name(version)
    version.company_name || get_user_company_name(version)
  end

  def get_user_company_name(version)
    user = who_made_the_change(version.whodunnit, false) 
    if user && user.is_a?(User)
      user.company.name
    else
      'None'
    end
  end

  def format_date(date)
    date&.strftime('%d %b %Y  %H:%M:%S')
  end

  def who_made_the_change(whodunnit, format_user_name)
    if !whodunnit
      'Data Migration'
    elsif whodunnit.include?(':')
      'Console'
    else
      get_user(whodunnit, format_user_name)
    end
  end

  def get_user(id, format_user_name)
    user = User.find_by(id: id)
    if user && format_user_name
      user = '' + user.first_name + ' ' + user.last_name + ' (ID ' + user.id.to_s + ') ' + user.email 
    end
    user
  end

  def inspect_change_set (version, original_values)
    return nil if version.object_changes.blank?

    changes = PaperTrail.serializer.load(version.object_changes)
    inspected_values = {}
    changes.each { |k,v| inspected_values[k] = original_values ? changes[k][0] : changes[k][1]}
    inspected_values
  end

  def format_papertrail_event(version)
    version.event.capitalize + ' ' + version.item_type
  end
end
