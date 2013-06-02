require 'rgeo/shapefile'
require 'thread'

#
# Genearate a regional projection map.
# This is a heavy operation so pre-calculated to decrease time spent mapping
# the acutal data.
#

class Projection
  attr_accessor :lat_start, :lat_increment, :lng_start, :lng_increment, :results
end

# should make this command line drivable.
projection_name = 'adelaide_diamond.projection'

def crunch_point(point, bounding_boxes, records, regions, bounding_regions)
  bounding_boxes.each_with_index do |box, i|
    if box.intersects? point
      bounding_regions[i].each do |record| 
        record = records[record]
        record.attributes['SA1_7DIGIT']
        if record.geometry.intersects? point
          return record.attributes['SA1_7DIGIT']
        end
      end
    end
  end
  nil
end

regions = {}
CSV.foreach("data/2011Census_B02_SA_SA1_short.csv", headers: true) do |row|
  mortgage = row['Median_mortgage_repay_monthly'].to_f
  income   = row['Median_Tot_hhd_inc_weekly'].to_f * 4
  if mortgage > 0 && income > 0 
    percent_on_mortgage = (mortgage / income)*100
    regions[row['region_id']] = percent_on_mortgage
  end
end

coords = []
min_lat = 1000
min_lng = 1000
max_lat = -1000
max_lng = -1000

geo_regions = []

records = Marshal.load(File.open('geo_regions.data').read)
factory = RGeo::Geos.factory(:srid => 4326, :native_interface => :capi)

bounding_boxes = []
bounding_box = nil
bounding_regions = Hash.new{ |h, k| h[k] = [] }
count = 0
records.each do |record|
  if count % 70 == 0
    bounding_regions[bounding_boxes.size] << count
    bounding_boxes << bounding_box.to_geometry if bounding_box
    bounding_box = RGeo::Cartesian::BoundingBox.create_from_geometry(record.geometry)
  else
    bounding_regions[bounding_boxes.size] << count
    bounding_box.add(record.geometry)
  end
  # puts record.attributes['SA1_7DIGIT']
  points = record.geometry.first.exterior_ring.points
  points.each do |point|
    min_lat = point.y if point.y < min_lat 
    min_lng = point.x if point.x < min_lng
    max_lat = point.y if point.y > max_lat
    max_lng = point.x if point.x > max_lng
  end
  count += 1
end


# Hard override of min_lat&lngs for Adelaide area.
min_lat = -35.27028070382496
min_lng = 138.1447780163157
max_lat = -34.64946600801455
max_lng = 139.240000

lat_increment = (max_lat - min_lat) / 180
lng_increment = (max_lng - min_lng) / 300
lat_alias = lat_increment / 3
lng_alias = lng_increment / 3

lat = min_lat
lng = min_lng

results = []

0.upto(300) do |x|
  lat = min_lat

  puts x

  if x % 2 == 0
    lat += (lat_increment / 2) 
  end

  results[x] = []

  queue = Queue.new
  (0.upto(180)).each{ |e| queue << e }
  threads = []

  1.times do
    threads << Thread.new do
      while (column = queue.pop(true) rescue nil)
        # Essetially using an anti-aliasing strategy to gather more accurate 
        # data. Need to nice this up some!

        point = factory.point(lng, lat)
        tl    = factory.point(lng - lng_alias, lat - lat_alias)
        tm    = factory.point(lng            , lat - lat_alias)
        tr    = factory.point(lng + lng_alias, lat - lat_alias)
        ml    = factory.point(lng - lng_alias, lat)
        mr    = factory.point(lng + lng_alias, lat)
        bl    = factory.point(lng - lng_alias, lat + lat_alias)
        bm    = factory.point(lng            , lat + lat_alias)
        br    = factory.point(lng + lng_alias, lat + lat_alias)
        
        cpoints = [
          crunch_point(point, bounding_boxes, records, regions, bounding_regions),
          crunch_point(tl, bounding_boxes, records, regions, bounding_regions),
          crunch_point(tm, bounding_boxes, records, regions, bounding_regions),
          crunch_point(tr, bounding_boxes, records, regions, bounding_regions),
          crunch_point(ml, bounding_boxes, records, regions, bounding_regions),
          crunch_point(mr, bounding_boxes, records, regions, bounding_regions),
          crunch_point(bl, bounding_boxes, records, regions, bounding_regions),
          crunch_point(bm, bounding_boxes, records, regions, bounding_regions),
          crunch_point(br, bounding_boxes, records, regions, bounding_regions)
        ].find_all { |region| region }

        if cpoints.size > 0
          results[x][column] = cpoints
        else
          results[x][column] = []
        end

        lat += lat_increment
      end
    end
  end

  threads.each { |x| x.join }
  lng += lng_increment
end

projection = Projection.new
projection.results = results
projection.lat_start = min_lat
projection.lat_increment = lat_increment
projection.lng_start = min_lng
projection.lng_increment = lng_increment

data = Marshal.dump(projection)
File.open(projection_name, 'w') { |file| file.write(data) }
