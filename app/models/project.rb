# == Schema Information
#
# Table name: projects
#
#  id                                      :integer         not null, primary key
#  name                                    :string(2000)
#  description                             :text
#  primary_organization_id                 :integer
#  implementing_organization               :text
#  partner_organizations                   :text
#  cross_cutting_issues                    :text
#  start_date                              :date
#  end_date                                :date
#  budget                                  :float
#  target                                  :text
#  estimated_people_reached                :integer(8)
#  contact_person                          :string(255)
#  contact_email                           :string(255)
#  contact_phone_number                    :string(255)
#  site_specific_information               :text
#  created_at                              :datetime
#  updated_at                              :datetime
#  the_geom                                :string
#  activities                              :text
#  intervention_id                         :string(255)
#  additional_information                  :text
#  awardee_type                            :string(255)
#  date_provided                           :date
#  date_updated                            :date
#  contact_position                        :string(255)
#  website                                 :string(255)
#  verbatim_location                       :text
#  calculation_of_number_of_people_reached :text
#  project_needs                           :text
#  idprefugee_camp                         :text
#

class Project < ActiveRecord::Base
  belongs_to :primary_organization, foreign_key: :primary_organization_id, class_name: 'Organization'
  has_and_belongs_to_many :clusters
  has_and_belongs_to_many :sectors
  has_and_belongs_to_many :regions
  has_and_belongs_to_many :countries
  has_and_belongs_to_many :tags
  has_and_belongs_to_many :geolocations
  #has_many :resources, :conditions => proc {"resources.element_type = #{Iom::ActsAsResource::PROJECT_TYPE}"}, :foreign_key => :element_id, :dependent => :destroy
  #has_many :media_resources, :conditions => proc {"media_resources.element_type = #{Iom::ActsAsResource::PROJECT_TYPE}"}, :foreign_key => :element_id, :dependent => :destroy, :order => 'position ASC'
  has_many :donations, :dependent => :destroy
  has_many :donors, :through => :donations
  has_many :cached_sites, :class_name => 'Site'#, :finder_sql => 'select sites.* from sites, projects_sites where projects_sites.project_id = #{id} and projects_sites.site_id = sites.id'

  scope :active, -> {where("end_date > ?", Date.today.to_s(:db))}
  scope :closed, -> {where("end_date < ?", Date.today.to_s(:db))}
  scope :with_no_country, -> {select('projects.*').
                          joins(:regions).
                          includes(:countries).
                          where('countries_projects.project_id IS NULL AND regions.id IS NOT NULL')}
  scope :organizations, -> (orgs){where(organizations: {id: orgs})}
  scope :sectors, -> (sectors){where(sectors: {id: sectors})}
  scope :donors, -> (donors){where(donors: {id: donors})}
  scope :countries, -> (countries){where(countries: {id: countries})}
  scope :regions, -> (regions){where(regions: {id: regions})}

  def self.fetch_all(options = {})
    projects = Project.includes([:primary_organization]).eager_load(:countries, :regions, :sectors, :donors).references(:organizations)
    projects = projects.organizations(options[:organizations]) if options[:organizations]
    projects = projects.countries(options[:countries])         if options[:countries]
    projects = projects.regions(options[:regions])             if options[:regions]
    projects = projects.sectors(options[:sectors])             if options[:sectors]
    projects = projects.donors(options[:donors])               if options[:donors]
    projects = projects.offset(options[:offset])               if options[:offset]
    projects = projects.limit(options[:limit])                 if options[:limit]
    projects = projects.active
    projects = projects.group('projects.id', 'countries.id', 'regions.id', 'sectors.id', 'donors.id', 'organizations.id')
    projects = projects.uniq
    projects
  end

  def self.export_headers(options = {})
    options = {show_private_fields: false}.merge(options || {})

    if options[:show_private_fields]
      %w(organization interaction_intervention_id org_intervention_id project_tags project_name project_description activities additional_information start_date end_date clusters sectors cross_cutting_issues budget_numeric international_partners local_partners prime_awardee estimated_people_reached target_groups location verbatim_location idprefugee_camp project_contact_person project_contact_position project_contact_email project_contact_phone_number project_website date_provided date_updated status donors)
    else
      %w(organization interaction_intervention_id org_intervention_id project_tags project_name project_description activities additional_information start_date end_date clusters sectors cross_cutting_issues budget_numeric international_partners local_partners prime_awardee estimated_people_reached target_groups location project_contact_person project_contact_position project_contact_email project_contact_phone_number project_website date_provided date_updated status donors)
    end
  end

  def self.to_csv(options = {})
    projects = all
    csv_headers = self.export_headers(options[:headers_options])
    csv_data = CSV.generate(:col_sep => ',') do |csv|
      csv << csv_headers
      projects.each do |project|
        line = []
        csv_headers.each do |field_name|
          v = project[field_name]
          line << if v.nil?
            ""
          else
            if %W{ start_date end_date date_provided date_updated }.include?(field_name)
              if v =~ /^00(\d\d\-.+)/
                "20#{$1}"
              else
                v
              end
            else
              v.to_s.text2array.join(',')
            end
          end
        end
        csv << line
      end
    end
    csv_data
  end

  def self.to_excel(options = {})
    all.to_xls(headers: self.export_headers(options[:headers_options]))
  end

  ############################################## IATI ##############################################

  def activity_status
    if self.start_date > Time.now.in_time_zone
      1
    elsif self.end_date > Time.now.in_time_zone
      2
    else
      3
    end
  end

  def activity_scope_code
    geos = self.geolocations
    if geos.present?
      if geos.length == 1
        activity_scope_code = case geos.first.adm_level
                                when 0
                                  4
                                when 1
                                  6
                                when 2
                                  7
                                else
                                  8
                                end
      elsif geos.pluck(:country_code).uniq.length > 1
         activity_scope_code = 3
      else
        activity_scope_code = 5
      end
    else
      activity_scope_code = 1
    end
    activity_scope_code
  end

  def iati_countries
    self.geolocations.pluck(:country_code)
  end

  def iati_locations
    self.geolocations.where('adm_level > 0')
  end

end
