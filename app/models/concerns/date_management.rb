module DateManagement
  def change_year date, year
    date.to_time.change(year: year).to_date
  end
end