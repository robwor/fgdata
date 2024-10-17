define([
        'knockout', 'text!./Map.html', './Map/NavdbLayer', './Map/AILayer', './Map/RouteLayer'
], function(ko, htmlString, NavdbLayer ) {

    function StoredSettings(key, settings, session ) {
      this.key = key;
      this.settings = settings;
      if( session ) this.session = true;
      else this.session = false;
    }

    StoredSettings.prototype.save = function() {
      if(typeof(Storage) === "undefined") {
        console.log("Storage not supported :-(");
        return;
      }

      var storage = this.session ? sessionStorage : localStorage;

      for( var setting in this.settings ) {
        var settingKey = this.key + "_" + setting;
        if( null == this.settings[setting] ) {
            storage.removeItem(settingKey);
        } else {
            var t = JSON.stringify(this.settings[setting]);
            storage.setItem(settingKey,JSON.stringify(this.settings[setting]));
        }
      }
    }

    StoredSettings.prototype.load = function() {
      if(typeof(Storage) === "undefined") {
        console.log("Storage not supported :-(");
        return;
      }

      var storage = this.session ? sessionStorage : localStorage;

      for( var setting in this.settings ) {
        var settingKey = this.key + "_" + setting;
        var storedSetting = storage.getItem(settingKey);
        if( storedSetting != null ) {
          this.settings[setting] = JSON.parse(storedSetting);
        }
      }
    }


    function ViewModel(params) {
        var self = this;

        this.storedSettings = new StoredSettings("flightgear_map", {
          selectedBase: null,
          selectedOverlays: [],
        }, true);

        this.storedSettings.load();
        self.selectedOverlays = this.storedSettings.settings.selectedOverlays;

        var trackLayer = new L.GeoJSON(null, {});

        trackLayer.maxTrackPoints = 1000;

        trackLayer.track = {
            "type" : "Feature",
            "geometry" : {
                "type" : "LineString",
                "coordinates" : []
            },
            "properties" : {
                "type" : "FlightHistory",
                "last" : 0
            }
        }

        trackLayer.update = function(id) {
            var self = this;
            if (id != self.updateId)
                return;

            var url = "/flighthistory/track.json?count=" + self.maxTrackPoints + "&last=" + trackLayer.track.properties.last;

            var jqxhr = $.get(url).done(function(data) {
                self.clearLayers();
                Array.prototype.push.apply(trackLayer.track.geometry.coordinates, data.geometry.coordinates);
                if (data.properties) {
                    trackLayer.track.properties.last = data.properties.last || 0;
                }
                self.addData(trackLayer.track);

                // update fast until we have all points
                var updateDelay = data.geometry.coordinates.length < self.maxTrackPoints ? 120000 : 200;

                setTimeout(function() {
                    self.update(id)
                }, updateDelay);

            }).fail(function() {
                var r = confirm("Error loading flight history. Retry?");
                if (!r)
                    self.updateId++;
            }).always(function() {
            });

        }

        trackLayer.updateId = 0;
        trackLayer.start = function() {
            this.update(++this.updateId);
            return this;
        }

        trackLayer.stop = function() {
            ++this.updateId;
            return this;
        }

        trackLayer.onAdd = function(map) {
            this.start();
            return L.GeoJSON.prototype.onAdd.call(this, map);

        }

        trackLayer.onRemove = function(map) {
            this.stop();
            return L.GeoJSON.prototype.onRemove.call(this, map);
        }

        var NavDBLayerName = "Navigation Data",
            TrackLayerName = "Flight History",
            AILayerName = "Other Traffic";


        self.overlays = {
            "Flight History" : trackLayer,
            "Route Manager" : L.routeLayer(),
            "Navigation Data": L.navdbLayer(),
            "Other Traffic": L.aiLayer(),

            "OpenFlightMaps":  new L.TileLayer("https://nwy-tiles-api.prod.newaydata.com/tiles/{z}/{x}/{y}.png?path=latest/aero/latest", {
                maxZoom: 13,
                minZoom: 7,
                attribution: '<a target="_blank" href="https://openflightmaps.org">&copy; open flightmaps association</a>'
            }),

            "VFRMap.com Sectionals (US)" : new L.TileLayer('https://vfrmap.com/20240711/tiles/vfrc/{z}/{y}/{x}.jpg', {
                maxZoom : 12,
                minZoom : 3,
                attribution : '&copy; <a target="_blank" href="https://vfrmap.com">VFRMap.com</a>',
                tms : true,
                opacity : 0.5,
                bounds : L.latLngBounds(L.latLng(16.0, -179.0), L.latLng(72.0, -60.0)),
            }),

            "VFRMap.com - Low IFR (US)" : new L.TileLayer('https://vfrmap.com/20240711/tiles/ifrlc/{z}/{y}/{x}.jpg', {
                maxZoom : 12,
                minZoom : 5,
                attribution : '&copy; <a target="_blank" href="https://vfrmap.com">VFRMap.com</a>',
                tms : true,
                opacity : 0.5,
                bounds : L.latLngBounds(L.latLng(16.0, -179.0), L.latLng(72.0, -60.0)),
            }),

            "Germany VFR" : new L.TileLayer(
                    'https://secais.dfs.de/static-maps/icao500/tiles/{z}/{x}/{y}.png', {
                        minZoom : 5,
                        maxZoom : 15,
                        attribution : '&copy; <a target="_blank" href="http://www.dfs.de">DFS</a>',
                        bounds : L.latLngBounds(L.latLng(46.0, 5.0), L.latLng(55.1, 16.5)),
                    }),

            "Germany Lower Airspace" : new L.TileLayer('https://secais.dfs.de/static-maps/lower/tiles/{z}/{x}/{y}.png',
                    {
                        minZoom : 5,
                        maxZoom : 15,
                        attribution : '&copy; <a target="_blank" href="http://www.dfs.de">DFS</a>',
                        bounds : L.latLngBounds(L.latLng(46.0, 5.0), L.latLng(55.1, 16.5)),
                    }),
        }

        self.mapResize = function(a,b) {
          self.overlays[NavDBLayerName].invalidate();
        }

        self.mapZoomend = function() {
          self.overlays[NavDBLayerName].invalidate();
        }

        self.mapMoveend = function() {
          self.overlays[NavDBLayerName].invalidate();
        }

        self.mapUnload = function(evt) {
          var map = evt.target,
              settings = self.storedSettings.settings;
          settings.selectedOverlays.length = 0;
          for( var layerName in self.overlays ) {
            var layer = self.overlays[layerName];
            if( layer.stop && typeof(layer.stop === 'function' )) {
                layer.stop();
            }
            if( map.hasLayer(layer) ) { 
              settings.selectedOverlays.push(layerName);
            }
          }
          self.storedSettings.save();
        }

    }

    // Return component definition
    return {
        viewModel : ViewModel,
        template : htmlString
    };
});
