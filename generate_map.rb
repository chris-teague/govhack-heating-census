#
# Genearate a google map using a projection file & data set
#
require 'csv'

class Projection
  attr_accessor :lat_start, :lat_increment, :lng_start, :lng_increment, :results
end

# Other Sets:
# load 'sets/median_household_weekly_income.rb'
# load 'sets/median_age.rb'
# load 'sets/average_household_size.rb'

load              'sets/mortgage_stress.rb'
output_file     = 'adelaide_stress.html'
projection_file = 'adelaide_diamond.projection'


projection = Marshal.load(File.open(projection_file).read)
region_values = process

max_value = 0
region_values.each do |_, val|
  max_value = val if val > max_value
end

coords = []

lat = projection.lat_start
lng = projection.lng_start

projection.results.each_with_index do |i, x|
  lat = projection.lat_start

  if x % 2 == 0
    lat += (projection.lat_increment / 2) 
  end

  i.each_with_index do |regions, y|
    values = regions.collect { |region| region_values[region] }
    values = values.find_all { |val| val && val > 0 }
    # don't plot if no values exist for a region.
    if values.size > 0
      value = values.inject(0){ |sum, val| val += sum } / values.size
      coords << "{lat: #{lat}, lng: #{lng}, count: #{value.to_i}} \n\r"
    end
    lat += projection.lat_increment
  end
  lng += projection.lng_increment
end

html =<<endhtml
<!DOCTYPE html>
<html lang="en"><head>
  <script type="text/javascript" src="http://maps.google.com/maps/api/js?sensor=false"></script>
  </head>
  <body>
  <div style='position:absolute;z-index:1000;padding:6px 12px;background-color:#eee;'>
    <a href='adelaide_stress.html'>Adelaide Affordability</a><br />
    <a href='adelaide_stress.html'>SA Affordability</a><br />
    <a href='adelaide_median_age.html'>Adelaide Median Age</a><br />
  </div>
  <div style='position:absolute;z-index:1000;
  margin-top:400px;padding:6px 12px;background-color:#eee;'>
    <b>LEGEND</b><br />
    Nothing = no data.<br />
    Green = Low<br />
    Yellow = Medium<br />
    Red = High<br />

    <small>Data Courtesy of ABS 2011 Census</small>
  </div>

  <div id="heatmapArea" class="well" style="width:100%;padding:0;height:900px;cursor:pointer;position:relative;"></div>
  <script type="text/javascript" src="js/jquery.js"></script>
  <script type="text/javascript" src="heatmap.js"></script>
  <script type="text/javascript" src="heatmap-gmaps.js"></script>
  <script type="text/javascript">
  window.onload = function(){
  // standard gmaps initialization
  var myLatlng = new google.maps.LatLng(-34.944553, 138.55864);
  // define map properties
  var myOptions = {
  zoom: 12,
  center: myLatlng,
  mapTypeId: google.maps.MapTypeId.ROADMAP,
  disableDefaultUI: false,
  scrollwheel: true,
  draggable: true,
  navigationControl: true,
  mapTypeControl: false,
  scaleControl: true,
  disableDoubleClickZoom: false
  };
  // we'll use the heatmapArea
  var map = new google.maps.Map($("#heatmapArea")[0], myOptions);
  // let's create a heatmap-overlay
  // with heatmap config properties
  var heatmap = new HeatmapOverlay(map, {
  "radius":10,
  "visible":true,
  "opacity":60,
  "gradient": { 0.35: "white", 0.45: "green", 0.75: "yellow", 1.0: "red" }
  });
   
  // here is our dataset
  // important: a datapoint now contains lat, lng and count property!
  var testData={
  max: #{max_value},
  data: [
    #{coords*','}
  ]
  };
   
  // now we can set the data
  google.maps.event.addListenerOnce(map, "idle", function(){
  // this is important, because if you set the data set too early, the latlng/pixel projection doesn't work
  heatmap.setDataSet(testData);
  });
   
  };
  </script>
  </body>
</html>
endhtml

File.open(output_file, 'w') { |file| file.write(html) }
