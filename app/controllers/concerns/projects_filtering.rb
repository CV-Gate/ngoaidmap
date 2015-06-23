module ProjectsFiltering
  extend ActiveSupport::Concern
  require 'digest/sha1'
  included do
    before_action :get_projects,  only: [:home, :show]
  end
  def get_projects
    # timestamp = Project.order('updated_at desc').first.updated_at.to_s
    # string = timestamp + projects_params.inspect
    # digest = Digest::SHA1.hexdigest(string)
    m = ActiveModel::Serializer::ArraySerializer.new(Project.fetch_all(projects_params), each_serializer: ProjectSerializer)
    @map_data = ActiveModel::Serializer::Adapter::JsonApi.new(m, include: ['organization', 'sectors', 'donors', 'countries', 'regions']).to_json
    @map_data_max_count = 0;
    @projects_count = Project.fetch_all(projects_params).uniq.length
    @projects = Project.fetch_all(projects_params).page(params[:page]).per(10)
    puts "*******************************************************#{@projects_count}"
  end
  private
  def projects_params
    params.permit(:page, organizations:[], countries:[], regions:[], sectors:[], donors:[], sectors:[])
  end
end
