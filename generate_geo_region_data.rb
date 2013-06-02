#
# Takes a census CVS file with a region_id column & finds all Shape file 
# geographical regions that fall within this.
#

require 'rgeo/shapefile'

regions = {}
CSV.foreach("data/2011Census_B02_SA_SA1_short.csv", headers: true) do |row|
  regions[row['region_id']] = ''
end

coords = []
geo_regions = []
  
RGeo::Shapefile::Reader.open('data/SA1_2011_AUST.shp') do |file|
  puts "File contains #{file.num_records} records."
  count = 0
  file.each do |record|
    if record.attributes['STATE_NAME'] == 'South Australia'
      if regions[record.attributes['SA1_7DIGIT']]
        puts count if count % 100 == 0
        geo_regions << record
        count += 1
      end
    end
  end
end

data = Marshal.dump(geo_regions)
File.open('geo_regions2.data', 'w') { |file| file.write(data) }