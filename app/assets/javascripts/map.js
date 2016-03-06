function loadMap() {
  var projection = d3.geo.mercator();
  var path = d3.geo.path().projection(projection);
  var tooltip = document.getElementById('tooltip');
  var zoom = d3.behavior.zoom()
      .scaleExtent([1, 20])
      .on("zoom", function() {
        container.attr("transform", "translate(" + d3.event.translate + ") scale(" + d3.event.scale + ")").attr('data-scale', d3.event.scale);//.style('r', 7 / d3.event.scale);
        container.selectAll('circle').each(function(d,i) { setPinSize(this, d, false); });
      });

  var container = d3.select('#map').call(zoom).insert('g', ':first-child').attr('class', 'map');

  container.append("path")
    .datum(d3.geo.graticule())
    .attr("class", "graticule")
    .attr("d", path);

  d3.selection.prototype.moveToFront = function() {
    return this.each(function(){
      this.parentNode.appendChild(this);
    });
  };

  d3.json('https://raw.githubusercontent.com/mbostock/topojson/master/examples/world-110m.json', function(error, world) {
    if (error) {
      throw error;
    }

    container.selectAll('path')
        .data(topojson.feature(world, world.objects.countries).features)
        .enter()
        .append('path')
        .attr('d', path)
        .attr('class', 'country');

    container.selectAll("circle")
      .data(document.querySelectorAll('#organizations .city'))
      .enter()
      .append('circle')
      .attr('cx', function(d) {return projection([d.dataset.o, d.dataset.a])[0];})
      .attr('cy', function(d) {return projection([d.dataset.o, d.dataset.a])[1];})
      .attr('class', 'city')
      .each(function(d,i) { setPinSize(this, d, false); })
      .on('mouseover', function(d){
        d3.select(this).moveToFront();
        setPinSize(this, d, true);
        var city = document.getElementById(d.id);
        var orgCount = Number.parseInt(d.dataset.s);
        tooltip.innerHTML = '<div class="h3">' + getLocationName(city) + (orgCount > 1 ? ' (' + orgCount + ') ' : '') + '</div>';
        tooltip.className = 'open';
      })
      .on('mouseout', function(d){
        setPinSize(this, d, false);
        tooltip.className = '';
      })
      .on('click', function(d){
        window.location.hash = d.id;
      });
  });

  function setPinSize(pin, data, isZoomed) {
    var mapScale = Number.parseFloat(container.attr('data-scale')) || 1;
    var d3pin = d3.select(pin);
    var orgSize = Number.parseInt(data.dataset.s) || 1;
    d3pin.attr('r', (2 + orgSize) / mapScale).attr('stroke-width', (isZoomed ? 12 : 6) / mapScale);
  }

  function getLocationName(city) {
    var territory = city.parentNode.parentNode.parentNode.querySelector('.territory');
    var country = (territory || city).parentNode.parentNode.parentNode.querySelector('.country');
    
    return city.innerHTML + (territory ? ', ' + territory.innerHTML : '') + ', ' + country.innerHTML;
  }

  zoom.event(container);
  d3.select("#map").attr('class', 'loaded');
}

document.onreadystatechange = function () {
  if (document.readyState == 'complete') {
    loadMap();
  }
};
