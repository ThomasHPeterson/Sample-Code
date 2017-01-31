class Report < ActiveRecord::Base

  belongs_to :patient, :foreign_key => 'patient_id'
  belongs_to :client
  belongs_to :contact
  has_one :report_app_data
  has_many :report_tests
	has_one :patient_status, :through => :patient
	has_one :report_visibility, :through => :patient
	has_one :status_lookup, :through => :patient_status

	attr_accessible #none

	audited :protect => false

	default_scope where("report_log.report_create_time is not null and report_log.patient_id is not null")

	scope :on_date, lambda {|date| where("report_create_time >= ? and report_create_time < ?", date, date + 1.day)}
	scope :not_suppressed, where("report_file_name not like '%suppress%'")
  scope :patient_reminders, where("report_file_name like '%PatientReminder%'")
  scope :provider_reminders, where("report_file_name like '%ProviderReminder%'")
  scope :patient_alerts, where("report_file_name like '%PatientAlert%'")
  scope :flowsheets, where("report_file_name like '%FlowSheet%'")
	scope :today, lambda { {:conditions => ["report_create_time >= ?", Date.today.beginning_of_day] } }
	scope :patient_is_visible_dm, joins(:status_lookup).where("patient_status_lookup.pcp_panel_type in ('A', 'I')")
	scope :patient_is_visible_ckd, joins(:report_visibility).where("v_report_visibility.visibility in ('ACTIVE', 'INACTIVE')")
	scope :patient_is_visible_dm_or_ckd, joins(:patient).joins("left join patient_status on patient.patient_id = patient_status.patient_id left join patient_status_lookup on patient_status.patient_status_id = patient_status_lookup.patient_status_id left join v_report_visibility on patient.patient_id = v_report_visibility.patient_id").where("patient_status_lookup.pcp_panel_type in ('A', 'I') or v_report_visibility.visibility in ('ACTIVE', 'INACTIVE')")
  scope :cm_patient_is_visible_dm_or_ckd, lambda { |case_manager_id| joins(:patient).joins("left join patient_status on patient.patient_id = patient_status.patient_id left join patient_status_lookup on patient_status.patient_status_id = patient_status_lookup.patient_status_id left join v_report_visibility on patient.patient_id = v_report_visibility.patient_id left join case_manager_patient on patient.patient_id = case_manager_patient.patient_id").where("(patient_status_lookup.pcp_panel_type in ('A', 'I') or v_report_visibility.visibility in ('ACTIVE', 'INACTIVE')) and case_manager_patient.case_manager_id = ?", case_manager_id) }
  scope :provider_patient_is_visible_dm_or_ckd, lambda { |provider_id| joins(:patient).joins("left join patient_status on patient.patient_id = patient_status.patient_id left join patient_status_lookup on patient_status.patient_status_id = patient_status_lookup.patient_status_id left join v_report_visibility on patient.patient_id = v_report_visibility.patient_id").where("(patient_status_lookup.pcp_panel_type in ('A', 'I') or v_report_visibility.visibility in ('ACTIVE', 'INACTIVE')) and patient.primary_provider = ?", provider_id) }

  self.table_name = "report_log"
  self.primary_key = "report_id"
  
  set_integer_columns :report_id, :contact_id, :client_id, :patient_id
  
  alias_attribute "create_time", "report_create_time"
  alias_attribute "name", "report_file_name"
  alias_attribute "path", "windows_path"
  
  def type
    name.split('/').last.split('-').last
  end


end
