class ReportsController < ApplicationController
  if :view_in_mobile
    skip_authorization_check
  else
	  before_filter :authenticate_user!
	  authorize_resource
  end

	respond_to :js, :only => :update_letter_returned, :layout => 'false'

	# GET /reports
	# GET /reports.json
	def index
		@header = 'Report'
		@per_page = params[:per_page] ||= Settings.pagination.per_page
		
		@search = Report.search(params[:search])
		@reports = @search.order("report_log.report_id DESC").paginate(:per_page => @per_page, :page => params[:page])

		respond_to do |format|
			format.html # index.html.erb
			format.json { render json: @reports }
		end
	end

	# GET /reports/1/download
	def download
		begin
			#IN DEV
			if Rails.env.developmentdb?
				filename = "WorkList.pdf"
				send_file "#{Rails.root}/files/reports/#{filename}", :type => 'application/pdf', :filename => filename
			else
				@report = Report.find_by_report_id obfuscate_decrypt(params[:id], session).to_i
				filename = @report.name
				name = filename.split('/').last
				send_file "#{filename}", :type => 'application/pdf', :filename => name
			end
    rescue => e
      #ExceptionNotifier::Notifier.background_exception_notification(e)
			redirect_to :back, notice: "We're sorry, but that report is unavailable at this time. Please try again later."
		end

		# Update report to indicate a user has viewed it
		if !@report.nil? and @report.report_app_data.nil? and current_user.role? :user
      rad = ReportAppData.new
      rad.report_id = @report.id
      rad.status = 2
      rad.save!
			#ReportAppData.create!(:report_id => @report.id, :status => 2)
		end
	end

	# GET /reports/1/view
	def view
		begin
			#IN DEV
			if Rails.env.developmentdb?
				filename = "WorkList.pdf"
				send_file "#{Rails.root}/files/reports/#{filename}", :type => 'application/pdf', :filename => filename, :disposition => 'inline'
			else
				@report = Report.find_by_report_id obfuscate_decrypt(params[:id], session).to_i
        filename = @report.name
				name = filename.split('/').last
				send_file "#{filename}", :type => 'application/pdf', :filename => name, :disposition => 'inline'
			end
		rescue => e
      #ExceptionNotifier::Notifier.background_exception_notification(e)
      redirect_to :back, notice: "We're sorry, but that report is unavailable at this time. Please try again later. #{e.to_s}"
		end
	end

    # GET /reports/1/view_in_mobile
    def view_in_mobile
      begin
        #IN DEV
        if Rails.env.developmentdb?
          filename = "WorkList.pdf"
          send_file "#{Rails.root}/files/reports/#{filename}", :type => 'application/pdf', :filename => filename, :disposition => 'inline'
        else
          #filename = "/opt/vdis/prod/vdis/outputFiles/reports/patient/129821-113995-PatientReminder.pdf"
          filename = "/tmp/message_zdm.html"
          #filename = @report.name
          name = filename.split('/').last
          send_file "#{filename}", :type => 'application/pdf', :filename => name, :disposition => 'attachment'
        end
      rescue => e
        #ExceptionNotifier::Notifier.background_exception_notification(e)
        request.env['HTTP_REFERER'] = 'http://173.203.154.139:83'
        redirect_to :back, notice: "We're sorry, but that report is unavailable at this time. Please try again later."
      end
    end

    # GET /reports/view_selected
	def view_selected
    begin
		  if params[:report_ids]
			  @reports = Report.find(params[:report_ids])
			  if Rails.env.developmentdb?
				  file_locations = Dir[]
				  @reports.each do |report|
					  file_locations << "#{Rails.root}/files/pdf1.pdf"
				  end
				  pdfs = file_locations.join(" ")
				  `files/pdftk #{pdfs} output files/test.pdf`
			  else
				  file_locations = Dir[]
				  @reports.each do |report|
					  file_locations << "#{report.name}"
				  end
				  pdfs = file_locations.join(" ")
				  `pdftk #{pdfs} output files/temp/pes_report_collection#{current_user.id}.pdf`
			  end
			  # Now send the file correctly
			  if params[:_select_button] == "View All Selected"
				  if Rails.env.developmentdb?
					  send_file "#{Rails.root}/files/test.pdf", :type => 'application/pdf', :filename => 'test.pdf', :disposition => 'inline'
				  else
					  send_file "#{Rails.root}/files/temp/pes_report_collection#{current_user.id}.pdf", :type => 'application/pdf', :filename => 'test.pdf', :disposition => 'inline'
				  end
			  elsif params[:_select_button] == "Download All Selected"
				  if Rails.env.developmentdb?
					  send_file "#{Rails.root}/files/test.pdf", :type => 'application/pdf', :filename => 'test.pdf'
				  else
					  send_file "#{Rails.root}/files/temp/pes_report_collection#{current_user.id}.pdf", :type => 'application/pdf', :filename => 'test.pdf'
				  end
			  else
				  redirect_to :back, notice: 'Not a valid action'
			  end
		  else
			  redirect_to :back, notice: 'Must select at least one report to view'
      end
    rescue => e
      redirect_to :back, notice: "We're sorry, but those reports are unavailable at this time. Please try again later."
    end
	end

	# GET /reports/inbox
	def inbox
		@header = 'Report'
		@per_page = Settings.pagination.per_page
		get_reports({:report_file_name_contains_any => ['FlowSheet', 'ProviderReminder']})
		render 'index'
	end

	# GET /reports/patient
	def patient
		@header = 'Patient Letter'
		@per_page = Settings.pagination.per_page
		get_reports({:report_file_name_contains_any => ['PatientAlert', 'PatientReminder']})
		render 'index'
	end

	def update_letter_returned

		@report = Report.find(obfuscate_decrypt(params[:id], session).to_i)

		if @report.letter_returned == 'Y'
			@report.letter_returned = 'N'
		else
			@report.letter_returned = 'Y'
		end
		@report.save

		respond_to do |format|
			format.js
		end

	end

	private

	def get_reports(search_params = {})
		@selection = params[:selection] ||= Settings.reports.default_selection
		unless @selection == 'All'
			case @selection
				when 'week'
					time = 7.days
				when 'month'
					time = 30.days
				when '2months'
					time = 60.days
				when '3months'
					time = 90.days
				when '6months'
					time = 180.days
				when 'year'
					time = 365.days
				else
					time = 7.days
			end
			search_params = search_params.merge({:report_create_time_greater_than_or_equal_to => Date.today - time})
    end
    # Added first where clause so as not to display ProviderReminders (or any other report) that are generated by not sent.  Tom P. 12/26/2013 as part of Case Manager work.
		@reports = current_user.contact.reports.where("report_status != 'S'").patient_is_visible_dm_or_ckd.search(search_params).order("report_log.report_create_time DESC").paginate(:per_page => @per_page, :page => params[:page])
	end

end
