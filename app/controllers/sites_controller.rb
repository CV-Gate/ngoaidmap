class SitesController < ApplicationController

  layout :sites_layout

  def home
    map_data = APICache.get('projects1', :cache => 3600, timeout: 60) do
      HTTParty.get('http://localhost:9292/projects')
    end
    @map_data = map_data.to_json
    @map_data_max_count = 0
  end

  def downloads
    respond_to do |format|
      format.csv do
        send_data Project.to_csv(@site, {}),
          :type => 'text/plain; charset=utf-8; application/download',
          :disposition => "attachment; filename=#{@site.id}_projects.csv"
      end
      format.xls do
        send_data Project.to_excel(@site, {}),
          :type        => 'application/vnd.ms-excel',
          :disposition => "attachment; filename=#{@site.id}_projects.xls"
      end
      format.kml do
        send_data Project.to_kml(@site, {}),
        # :type        => 'application/vnd.google-earth.kml+xml, application/vnd.google-earth.kmz',
          :disposition => "attachment; filename=#{@site.id}_projects.kml"
      end
      format.xml do
        @rss_items = Project.custom_find @site, :start_in_page => 0, :random => false, :per_page => 1000

        render :site_home
      end
    end
  end

  def about
  end

  def about_interaction
  end

  def contact
  end


end
