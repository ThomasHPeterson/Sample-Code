class Account::ReportsController < Account::BaseController
	before_filter :authenticate_user!
	authorize_resource

	# GET /reports
	# GET /reports.json
	def index
		@header = 'Report'
		@per_page = params[:per_page] ||= Settings.pagination.per_page

		unless params[:search].nil?
			params[:search][:patient_last_name_starts_with] = params[:search][:patient_last_name_starts_with].upcase unless params[:search][:patient_last_name_starts_with].nil?
			params[:search][:patient_first_name_starts_with] = params[:search][:patient_first_name_starts_with].upcase unless params[:search][:patient_first_name_starts_with].nil?
			params[:search][:contact_last_name_starts_with] = params[:search][:contact_last_name_starts_with].upcase unless params[:search][:contact_last_name_starts_with].nil?
			params[:search][:contact_first_name_starts_with] = params[:search][:contact_first_name_starts_with].upcase unless params[:search][:contact_first_name_starts_with].nil?
		end

		@search = Report.includes(:patient, :contact, :client).search(params[:search])
		@reports = @search.order("report_log.report_id DESC").paginate(:per_page => @per_page, :page => params[:page])

		respond_to do |format|
			format.html # index.html.erb
			format.json { render json: @reports }
		end
	end

	def daily
		@header = 'Daily Report'
		@per_page = params[:per_page] ||= Settings.pagination.per_page
		@reports_checked = {}

    if params[:search].nil?
			search = {:report_file_name_contains_any => ['PatientAlert', 'PatientReminder']}
		else
			reports = []
			@reports_checked = params[:search][:include_reports]
			params[:search][:include_reports].each do |k, v|
				v == '1' ? (reports << k) : false
			end
			search = {:report_file_name_contains_any => reports}
		end

		if params[:search] and params[:search][:on_date].present?
			@date = params[:search][:on_date].to_date
		elsif params[:last_selected_date].present?
			@date = params[:last_selected_date].to_date
		else
			@date = Date.today
		end
		@reports = Report.includes(:patient).joins(:contact).not_suppressed.on_date(@date).search(search).order("contact.last_name, contact.first_name, report_log.report_id").paginate(:per_page => @per_page, :page => params[:page])
	end

	# GET /reports/1
	# GET /reports/1.json
	def show
		@report = Report.find(params[:id])

		respond_to do |format|
			format.html # show.html.erb
			format.json { render json: @report }
		end
	end

	# GET /reports/1/download
	def download
		@report = Report.find(params[:id])
		begin
			#IN DEV
			if Rails.env.developmentdb?
				filename = "WorkList.pdf"
				send_file "#{Rails.root}/files/reports/#{filename}", :type => 'application/pdf', :filename => filename
			else
				filename = @report.name
				name = filename.split('/').last
				send_file "#{filename}", :type => 'application/pdf', :filename => name
			end
		rescue => e
			redirect_to :back, notice: "We're sorry, but that report is unavailable at this time. Please try again later."
		end

		if @report.status.id == 1 and current_user.role? :user
			app_data = ReportAppData.find_by_id(@report.report_app_data.id)
			app_data.status = 2
			app_data.save
		end
	end

	# GET /reports/1/view
	def view
		@report = Report.find(params[:id])
		begin
			#IN DEV
			if Rails.env.developmentdb?
				filename = "WorkList.pdf"
				send_file "#{Rails.root}/files/reports/#{filename}", :type => 'application/pdf', :filename => filename, :disposition => 'inline'
			else
				filename = @report.name
				name = filename.split('/').last
				send_file "#{filename}", :type => 'application/pdf', :filename => name, :disposition => 'inline'
			end
		rescue => e
			redirect_to :back, notice: "We're sorry, but that report is unavailable at this time. Please try again later."
		end

		if @report.status.id == 1 and current_user.role? :user
			app_data = ReportAppData.find_by_id(@report.report_app_data.id)
			app_data.status = 2
			app_data.save
		end
	end

	# GET /reports/1/delete
	def delete_report
		@report = Report.find(params[:id])
		@report.report_tests.map do |rt|
			rt.delete
		end
		@report.delete
		redirect_to reports_admin_patient_path(obfuscate_encrypt(@report.patient_id, session)), notice: 'Report successfully deleted from REPORT_LOG. Notice has been sent to admins to delete the physical file.  If you intended to resend this report and did not click the Resend button first, go to the PATIENT_REPORTS_DUE table and delete the relevant row.'

		# send mail prompting admins to delete the physical file on the App Server (web portal is on the Comm Server)
		OpsMailer.delete_file_request @report.report_file_name
	end

	# GET /reports/1/resend
	def resend
		# deleting frees up the report to be resent with report generation the next day
		@report = Report.find(params[:id])
		begin
			prd = PatientReportsDue.from_report_log @report.patient_id, params[:report_id], @report.report_create_time
			prd.delete
			redirect_to reports_admin_patient_path(obfuscate_encrypt(@report.patient_id, session)), notice: 'Patient Reports Due entry successfully deleted. Report will be regenerated with next report generation cycle.'
		rescue => e
			redirect_to reports_admin_patient_path(obfuscate_encrypt(@report.patient_id, session)), notice: e.message
		end
	end

end
